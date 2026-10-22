begin;

-- Clients cannot register someone else's email to receive their shares.
create or replace function public.has_verified_firebase_email(candidate text)
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(
    public.is_cashew_firebase_jwt()
    and auth.jwt()->>'email_verified' = 'true'
    and lower(btrim(candidate)) = lower(btrim(auth.jwt()->>'email')),
    false
  )
$$;

create policy users_insert_verified_email
on public.users as restrictive for insert to anon, authenticated
with check (public.has_verified_firebase_email(email::text));

create policy users_update_verified_email
on public.users as restrictive for update to anon, authenticated
using (true)
with check (public.has_verified_firebase_email(email::text));

-- Audit legacy rows before VALIDATE; new/updated rows are checked immediately.
alter table public.documents
  add constraint documents_storage_path_matches_identity check (
    cardinality(string_to_array(storage_path, '/')) = 4
    and split_part(storage_path, '/', 1) = 'documents'
    and split_part(storage_path, '/', 2) = owner_id
    and split_part(storage_path, '/', 3) = id::text
    and length(split_part(storage_path, '/', 4)) > 0
  ) not valid;

-- Supabase default privileges may include table-wide UPDATE for authenticated.
-- Revoke it before granting only editable business fields to both JWT roles.
revoke all on public.documents from authenticated;
grant select, insert, delete on public.documents to authenticated;
grant update(title, description) on public.documents to authenticated;

commit;
