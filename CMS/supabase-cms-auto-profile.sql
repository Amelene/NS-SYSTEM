-- ============================================================
-- NS Crew Management System — keep profiles in step with Authentication -> Users
--   * Add a user in Authentication  -> a row is created in profiles (role: staff)
--   * Change a user's email         -> profiles.email follows
--   * Delete a user                 -> the profile is removed (on delete cascade)
-- Also creates profiles for every user who already exists, and adds an
-- email column so you can see who each profile belongs to.
--
-- Run in the NS-Crew Management System project -> SQL Editor.
-- Safe to run more than once.
--
-- IMPORTANT: keep "Allow new users to sign up" OFF (Authentication -> Sign In / Providers),
-- so only accounts the admin creates get access.
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'staff' check (role in ('admin','staff')),
  created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists email text;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, role, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email), 'staff', new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end $$;

create or replace function public.handle_user_email_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed after update of email on auth.users
  for each row execute function public.handle_user_email_change();

-- users who already exist
insert into public.profiles (id, full_name, role, email)
select u.id, coalesce(u.raw_user_meta_data->>'full_name', u.email), 'staff', u.email
from auth.users u
on conflict (id) do update set email = excluded.email;

-- check: everyone in Authentication should now be listed here
select email, full_name, role, created_at from public.profiles order by created_at;
