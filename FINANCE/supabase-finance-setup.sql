-- ============================================================
-- NS FINANCE — Supabase setup
-- Project: https://zdnxsjqwziodsktomxyx.supabase.co
-- Paste this whole file into Supabase Dashboard -> SQL Editor -> New query -> Run
-- Safe to run more than once.
--
-- BEFORE USING THE PORTAL, ALSO DO THESE IN THE DASHBOARD:
--   1. Authentication -> Sign In / Providers -> turn OFF "Allow new users to sign up"
--      (accounts are created by the admin only).
--   2. Authentication -> Users -> "Add user" for each finance staff member
--      (tick "Auto Confirm User").
--   3. Add the same emails to fin_staff (section 1 below). Only emails on that
--      list can read or change anything, even if they have a login.
-- ============================================================

-- 1. WHO MAY USE NS FINANCE --------------------------------------------------
create table if not exists fin_staff (
  email text primary key,
  full_name text,
  added_at timestamptz not null default now()
);

-- Add finance staff here (one line each). Change or add emails as needed.
insert into fin_staff (email, full_name) values
  ('capt.ivanevangelio@gmail.com', 'Admin')
on conflict (email) do nothing;

create or replace function fin_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from fin_staff
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- 2. DATA ------------------------------------------------------------------------
-- One row per record (vessel, client, invoice, payroll run, employee, ...).
-- `collection` is the portal's list name, e.g. invoices, payrolls, employees.
create table if not exists fin_records (
  collection text not null,
  id text not null,
  pos int not null default 0,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  primary key (collection, id)
);

-- Single-value items: company settings, document counters, GF details.
create table if not exists fin_settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);

-- 3. AUDIT LOG: every add / change / delete is recorded automatically -----------
create table if not exists fin_audit (
  id bigserial primary key,
  at timestamptz not null default now(),
  user_id uuid,
  user_email text,
  action text not null,          -- INSERT / UPDATE / DELETE
  collection text,
  record_id text,
  old_data jsonb                 -- the record as it was before the change
);

create or replace function fin_audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_TABLE_NAME = 'fin_records' then
    insert into fin_audit (user_id, user_email, action, collection, record_id, old_data)
    values (auth.uid(), auth.jwt() ->> 'email', TG_OP,
            coalesce(new.collection, old.collection), coalesce(new.id, old.id),
            case when TG_OP = 'INSERT' then null else old.data end);
  elsif coalesce(new.key, old.key) <> 'counters' then   -- counters change constantly; not audited
    insert into fin_audit (user_id, user_email, action, collection, record_id, old_data)
    values (auth.uid(), auth.jwt() ->> 'email', TG_OP,
            'settings', coalesce(new.key, old.key),
            case when TG_OP = 'INSERT' then null else old.value end);
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists fin_records_audit on fin_records;
create trigger fin_records_audit after insert or update or delete on fin_records
  for each row execute function fin_audit_trigger();

drop trigger if exists fin_settings_audit on fin_settings;
create trigger fin_settings_audit after insert or update or delete on fin_settings
  for each row execute function fin_audit_trigger();

-- 4. DOCUMENT NUMBERS: counters only ever go up, even with several users ----------
create or replace function fin_merge_counters(incoming jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  merged jsonb;
  k text;
begin
  if not fin_is_staff() then raise exception 'not allowed'; end if;
  insert into fin_settings (key, value) values ('counters', '{}'::jsonb)
    on conflict (key) do nothing;
  select coalesce(value, '{}'::jsonb) into merged from fin_settings where key = 'counters' for update;
  for k in select jsonb_object_keys(coalesce(incoming, '{}'::jsonb)) loop
    if jsonb_typeof(incoming -> k) = 'number'
       and (jsonb_typeof(merged -> k) is distinct from 'number'
            or (incoming ->> k)::numeric > (merged ->> k)::numeric) then
      merged := jsonb_set(merged, array[k], incoming -> k);
    end if;
  end loop;
  update fin_settings set value = merged, updated_at = now(), updated_by = auth.uid()
    where key = 'counters';
  return merged;
end $$;

-- 5. ACCESS RULES: finance staff only --------------------------------------------
alter table fin_staff    enable row level security;
alter table fin_records  enable row level security;
alter table fin_settings enable row level security;
alter table fin_audit    enable row level security;

drop policy if exists "finance staff read staff list" on fin_staff;
create policy "finance staff read staff list" on fin_staff
  for select using (fin_is_staff());

drop policy if exists "finance staff full access to records" on fin_records;
create policy "finance staff full access to records" on fin_records
  for all using (fin_is_staff()) with check (fin_is_staff());

drop policy if exists "finance staff full access to settings" on fin_settings;
create policy "finance staff full access to settings" on fin_settings
  for all using (fin_is_staff()) with check (fin_is_staff());

drop policy if exists "finance staff read audit" on fin_audit;
create policy "finance staff read audit" on fin_audit
  for select using (fin_is_staff());
-- (no insert/update/delete policy on fin_audit: only the trigger writes to it)

-- 6. FILES: contract scans, receipts, policies (private bucket) -------------------
insert into storage.buckets (id, name, public)
values ('fin-files', 'fin-files', false)
on conflict (id) do nothing;

drop policy if exists "finance staff read fin-files" on storage.objects;
create policy "finance staff read fin-files" on storage.objects
  for select using (bucket_id = 'fin-files' and fin_is_staff());

drop policy if exists "finance staff upload fin-files" on storage.objects;
create policy "finance staff upload fin-files" on storage.objects
  for insert with check (bucket_id = 'fin-files' and fin_is_staff());

drop policy if exists "finance staff update fin-files" on storage.objects;
create policy "finance staff update fin-files" on storage.objects
  for update using (bucket_id = 'fin-files' and fin_is_staff());

drop policy if exists "finance staff delete fin-files" on storage.objects;
create policy "finance staff delete fin-files" on storage.objects
  for delete using (bucket_id = 'fin-files' and fin_is_staff());
