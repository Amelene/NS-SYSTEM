-- ============================================================
-- NS FINANCE — keep fin_staff in step with Authentication -> Users
--   * Add a user in Authentication  -> they are added to fin_staff
--   * Change a user's email         -> fin_staff follows
--   * Delete a user                 -> they are removed from fin_staff
-- Also copies every user who already exists into fin_staff.
--
-- Run in the NS - FINANCE project -> SQL Editor (after supabase-finance-setup.sql).
-- Safe to run more than once.
--
-- IMPORTANT: keep "Allow new users to sign up" OFF (Authentication -> Sign In / Providers),
-- so only accounts the admin creates get access.
-- ============================================================

create or replace function fin_sync_staff_from_auth() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    if new.email is not null then
      insert into public.fin_staff (email, full_name)
      values (lower(new.email), coalesce(new.raw_user_meta_data->>'full_name', new.email))
      on conflict (email) do nothing;
    end if;
  elsif TG_OP = 'UPDATE' then
    if new.email is distinct from old.email and new.email is not null then
      delete from public.fin_staff where lower(email) = lower(old.email);
      insert into public.fin_staff (email, full_name)
      values (lower(new.email), coalesce(new.raw_user_meta_data->>'full_name', new.email))
      on conflict (email) do nothing;
    end if;
  elsif TG_OP = 'DELETE' then
    delete from public.fin_staff where lower(email) = lower(old.email);
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists fin_staff_on_auth_insert on auth.users;
create trigger fin_staff_on_auth_insert after insert on auth.users
  for each row execute function fin_sync_staff_from_auth();

drop trigger if exists fin_staff_on_auth_update on auth.users;
create trigger fin_staff_on_auth_update after update of email on auth.users
  for each row execute function fin_sync_staff_from_auth();

drop trigger if exists fin_staff_on_auth_delete on auth.users;
create trigger fin_staff_on_auth_delete after delete on auth.users
  for each row execute function fin_sync_staff_from_auth();

-- users who already exist
insert into public.fin_staff (email, full_name)
select lower(u.email), coalesce(u.raw_user_meta_data->>'full_name', u.email)
from auth.users u
where u.email is not null
on conflict (email) do nothing;

-- check: everyone in Authentication should now be listed here
select email, full_name, added_at from public.fin_staff order by added_at;
