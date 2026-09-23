-- ============================================================
-- NS FLEET — Supabase setup
-- Run this in the Supabase project used for NS FLEET.
-- Paste this whole file into Supabase Dashboard -> SQL Editor -> New query -> Run
-- Safe to run more than once.
--
-- BEFORE USING THE PORTAL, ALSO DO THESE IN THE DASHBOARD:
--   1. Authentication -> Sign In / Providers -> turn OFF "Allow new users to sign up"
--      (accounts are created by the admin only).
--   2. Authentication -> Users -> "Add user" for each fleet staff member
--      (tick "Auto Confirm User").
--   3. Add the same emails to fleet_staff (section 1 below). Only emails on that
--      list can read or change anything, even if they have a login.
-- ============================================================

-- 1. WHO MAY USE NS FLEET --------------------------------------------------
create table if not exists fleet_staff (
  email text primary key,
  full_name text,
  added_at timestamptz not null default now()
);

-- Add fleet staff here (one line each). Change or add emails as needed.
insert into fleet_staff (email, full_name) values
  ('capt.ivanevangelio@gmail.com', 'Admin')
on conflict (email) do nothing;

create or replace function fleet_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from fleet_staff
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- 2. DATA ------------------------------------------------------------------------
-- One row per record (vessel, daily report, maintenance job, certificate, ...).
-- `collection` is the list name, e.g. vessels, dailyreports, pmsjobs, certificates.
create table if not exists fleet_records (
  collection text not null,
  id text not null,
  pos int not null default 0,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  primary key (collection, id)
);

-- Single-value items: system details (meta) and document counters.
create table if not exists fleet_settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);

-- 3. AUDIT LOG: every add / change / delete is recorded automatically -----------
create table if not exists fleet_audit (
  id bigserial primary key,
  at timestamptz not null default now(),
  user_id uuid,
  user_email text,
  action text not null,          -- INSERT / UPDATE / DELETE
  collection text,
  record_id text,
  old_data jsonb                 -- the record as it was before the change
);

create or replace function fleet_audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_TABLE_NAME = 'fleet_records' then
    insert into fleet_audit (user_id, user_email, action, collection, record_id, old_data)
    values (auth.uid(), auth.jwt() ->> 'email', TG_OP,
            coalesce(new.collection, old.collection), coalesce(new.id, old.id),
            case when TG_OP = 'INSERT' then null else old.data end);
  elsif coalesce(new.key, old.key) <> 'counters' then   -- counters change constantly; not audited
    insert into fleet_audit (user_id, user_email, action, collection, record_id, old_data)
    values (auth.uid(), auth.jwt() ->> 'email', TG_OP,
            'settings', coalesce(new.key, old.key),
            case when TG_OP = 'INSERT' then null else old.value end);
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists fleet_records_audit on fleet_records;
create trigger fleet_records_audit after insert or update or delete on fleet_records
  for each row execute function fleet_audit_trigger();

drop trigger if exists fleet_settings_audit on fleet_settings;
create trigger fleet_settings_audit after insert or update or delete on fleet_settings
  for each row execute function fleet_audit_trigger();

-- 4. DOCUMENT NUMBERS: counters only ever go up, even with several users ----------
create or replace function fleet_merge_counters(incoming jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  merged jsonb;
  k text;
begin
  if not fleet_is_staff() then raise exception 'not allowed'; end if;
  insert into fleet_settings (key, value) values ('counters', '{}'::jsonb)
    on conflict (key) do nothing;
  select coalesce(value, '{}'::jsonb) into merged from fleet_settings where key = 'counters' for update;
  for k in select jsonb_object_keys(coalesce(incoming, '{}'::jsonb)) loop
    if jsonb_typeof(incoming -> k) = 'number'
       and (jsonb_typeof(merged -> k) is distinct from 'number'
            or (incoming ->> k)::numeric > (merged ->> k)::numeric) then
      merged := jsonb_set(merged, array[k], incoming -> k);
    end if;
  end loop;
  update fleet_settings set value = merged, updated_at = now(), updated_by = auth.uid()
    where key = 'counters';
  return merged;
end $$;

-- 5. ACCESS RULES: fleet staff only --------------------------------------------
alter table fleet_staff    enable row level security;
alter table fleet_records  enable row level security;
alter table fleet_settings enable row level security;
alter table fleet_audit    enable row level security;

drop policy if exists "fleet staff read staff list" on fleet_staff;
create policy "fleet staff read staff list" on fleet_staff
  for select using (fleet_is_staff());

drop policy if exists "fleet staff full access to records" on fleet_records;
create policy "fleet staff full access to records" on fleet_records
  for all using (fleet_is_staff()) with check (fleet_is_staff());

drop policy if exists "fleet staff full access to settings" on fleet_settings;
create policy "fleet staff full access to settings" on fleet_settings
  for all using (fleet_is_staff()) with check (fleet_is_staff());

drop policy if exists "fleet staff read audit" on fleet_audit;
create policy "fleet staff read audit" on fleet_audit
  for select using (fleet_is_staff());
-- (no insert/update/delete policy on fleet_audit: only the trigger writes to it)

-- 6. FILES: certificate and audit attachments (private bucket) -------------------
insert into storage.buckets (id, name, public)
values ('fleet-files', 'fleet-files', false)
on conflict (id) do nothing;

drop policy if exists "fleet staff read fleet-files" on storage.objects;
create policy "fleet staff read fleet-files" on storage.objects
  for select using (bucket_id = 'fleet-files' and fleet_is_staff());

drop policy if exists "fleet staff upload fleet-files" on storage.objects;
create policy "fleet staff upload fleet-files" on storage.objects
  for insert with check (bucket_id = 'fleet-files' and fleet_is_staff());

drop policy if exists "fleet staff update fleet-files" on storage.objects;
create policy "fleet staff update fleet-files" on storage.objects
  for update using (bucket_id = 'fleet-files' and fleet_is_staff());

drop policy if exists "fleet staff delete fleet-files" on storage.objects;
create policy "fleet staff delete fleet-files" on storage.objects
  for delete using (bucket_id = 'fleet-files' and fleet_is_staff());
