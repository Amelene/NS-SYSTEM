-- ============================================================
-- NAVI Crewing System — cloud storage for the Crewing Management page
-- Paste this whole file into Supabase Dashboard -> SQL Editor -> New query -> Run
-- Safe to run more than once.
-- ============================================================

-- 1. RECORDS: one row per crew member, document, vessel and log entry.
--    `collection` is one of: crew, documents, vessels, log
--    `data` holds the full record exactly as the app uses it.
create table if not exists navi_records (
  collection text not null,
  id text not null,
  pos int not null default 0,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) default auth.uid(),
  primary key (collection, id)
);

-- 2. SETTINGS: small shared values (e.g. the crew control number counter).
create table if not exists navi_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) default auth.uid()
);

alter table navi_records enable row level security;
alter table navi_settings enable row level security;

drop policy if exists "logged-in staff full access to navi_records" on navi_records;
create policy "logged-in staff full access to navi_records" on navi_records
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists "logged-in staff full access to navi_settings" on navi_settings;
create policy "logged-in staff full access to navi_settings" on navi_settings
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- 3. FILES: crew photos, document scans, vessel certificates and the logo
--    live in a private Storage bucket called 'navi-files'.
insert into storage.buckets (id, name, public)
values ('navi-files', 'navi-files', false)
on conflict (id) do nothing;

drop policy if exists "logged-in staff read navi-files" on storage.objects;
create policy "logged-in staff read navi-files" on storage.objects
  for select using (bucket_id = 'navi-files' and auth.uid() is not null);

drop policy if exists "logged-in staff upload navi-files" on storage.objects;
create policy "logged-in staff upload navi-files" on storage.objects
  for insert with check (bucket_id = 'navi-files' and auth.uid() is not null);

drop policy if exists "logged-in staff update navi-files" on storage.objects;
create policy "logged-in staff update navi-files" on storage.objects
  for update using (bucket_id = 'navi-files' and auth.uid() is not null);

drop policy if exists "logged-in staff delete navi-files" on storage.objects;
create policy "logged-in staff delete navi-files" on storage.objects
  for delete using (bucket_id = 'navi-files' and auth.uid() is not null);
