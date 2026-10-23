-- CashewDoc TH2: run in Supabase SQL Editor as project owner.
-- Preserves tables and data; review legacy storage paths before applying.
begin;

-- 202610130001_cloud_documents.sql

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

create table if not exists public.users (
  id text primary key,
  email extensions.citext not null unique,
  display_name text not null check (char_length(display_name) between 1 and 120),
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null references public.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  description text not null default '' check (char_length(description) <= 4000),
  file_name text not null check (char_length(file_name) between 1 and 255),
  storage_path text not null unique,
  file_size_bytes bigint not null check (
    file_size_bytes > 0 and file_size_bytes <= 26214400
  ),
  mime_type text not null default 'application/octet-stream',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id text not null references public.users(id) on delete cascade,
  access_level text not null check (access_level in ('viewer', 'editor')),
  granted_by text not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint permissions_one_user_per_document unique (document_id, user_id)
);

create index if not exists documents_owner_id_idx
  on public.documents(owner_id);
create index if not exists documents_updated_at_idx
  on public.documents(updated_at desc);
create index if not exists permissions_user_id_idx
  on public.permissions(user_id);
create index if not exists permissions_document_id_idx
  on public.permissions(document_id);

create or replace function public.request_uid()
returns text
language sql
stable
as $$
  select auth.jwt()->>'sub'
$$;

create or replace function public.is_cashew_firebase_jwt()
returns boolean
language sql
stable
as $$
  select
    auth.jwt()->>'iss' =
      'https://securetoken.google.com/device-streaming-33cac12e'
    and auth.jwt()->>'aud' = 'device-streaming-33cac12e'
$$;

create or replace function public.owns_document(target_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.id = target_document_id
      and d.owner_id = public.request_uid()
  )
$$;

create or replace function public.can_read_document(target_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.id = target_document_id
      and (
        d.owner_id = public.request_uid()
        or exists (
          select 1
          from public.permissions p
          where p.document_id = d.id
            and p.user_id = public.request_uid()
        )
      )
  )
$$;

create or replace function public.can_edit_document(target_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.id = target_document_id
      and (
        d.owner_id = public.request_uid()
        or exists (
          select 1
          from public.permissions p
          where p.document_id = d.id
            and p.user_id = public.request_uid()
            and p.access_level = 'editor'
        )
      )
  )
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_touch_updated_at on public.users;
create trigger users_touch_updated_at
before update on public.users
for each row execute function public.touch_updated_at();

drop trigger if exists documents_touch_updated_at on public.documents;
create trigger documents_touch_updated_at
before update on public.documents
for each row execute function public.touch_updated_at();

drop trigger if exists permissions_touch_updated_at on public.permissions;
create trigger permissions_touch_updated_at
before update on public.permissions
for each row execute function public.touch_updated_at();

alter table public.users enable row level security;
alter table public.documents enable row level security;
alter table public.permissions enable row level security;

drop policy if exists users_firebase_project_guard on public.users;
drop policy if exists users_firebase_project_guard on public.users;
create policy users_firebase_project_guard
on public.users as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists users_read_self on public.users;
drop policy if exists users_read_self on public.users;
create policy users_read_self
on public.users for select to anon, authenticated
using (id = (select public.request_uid()));

drop policy if exists users_insert_self on public.users;
drop policy if exists users_insert_self on public.users;
create policy users_insert_self
on public.users for insert to anon, authenticated
with check (id = (select public.request_uid()));

drop policy if exists users_update_self on public.users;
drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users for update to anon, authenticated
using (id = (select public.request_uid()))
with check (id = (select public.request_uid()));

drop policy if exists documents_firebase_project_guard on public.documents;
drop policy if exists documents_firebase_project_guard on public.documents;
create policy documents_firebase_project_guard
on public.documents as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists documents_read_authorized on public.documents;
drop policy if exists documents_read_authorized on public.documents;
create policy documents_read_authorized
on public.documents for select to anon, authenticated
using ((select public.can_read_document(id)));

drop policy if exists documents_insert_owner on public.documents;
drop policy if exists documents_insert_owner on public.documents;
create policy documents_insert_owner
on public.documents for insert to anon, authenticated
with check (owner_id = (select public.request_uid()));

drop policy if exists documents_update_editor on public.documents;
drop policy if exists documents_update_editor on public.documents;
create policy documents_update_editor
on public.documents for update to anon, authenticated
using ((select public.can_edit_document(id)))
with check ((select public.can_edit_document(id)));

drop policy if exists documents_delete_owner on public.documents;
drop policy if exists documents_delete_owner on public.documents;
create policy documents_delete_owner
on public.documents for delete to anon, authenticated
using ((select public.owns_document(id)));

drop policy if exists permissions_firebase_project_guard on public.permissions;
drop policy if exists permissions_firebase_project_guard on public.permissions;
create policy permissions_firebase_project_guard
on public.permissions as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists permissions_read_participant on public.permissions;
drop policy if exists permissions_read_participant on public.permissions;
create policy permissions_read_participant
on public.permissions for select to anon, authenticated
using (
  user_id = (select public.request_uid())
  or (select public.owns_document(document_id))
);

drop policy if exists permissions_insert_owner on public.permissions;
drop policy if exists permissions_insert_owner on public.permissions;
create policy permissions_insert_owner
on public.permissions for insert to anon, authenticated
with check (
  (select public.owns_document(document_id))
  and granted_by = (select public.request_uid())
);

drop policy if exists permissions_update_owner on public.permissions;
drop policy if exists permissions_update_owner on public.permissions;
create policy permissions_update_owner
on public.permissions for update to anon, authenticated
using ((select public.owns_document(document_id)))
with check ((select public.owns_document(document_id)));

drop policy if exists permissions_delete_owner on public.permissions;
drop policy if exists permissions_delete_owner on public.permissions;
create policy permissions_delete_owner
on public.permissions for delete to anon, authenticated
using ((select public.owns_document(document_id)));

create or replace function public.share_document(
  p_document_id uuid,
  p_user_email text,
  p_access_level text
)
returns table (
  user_id text,
  email text,
  display_name text,
  access_level text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user public.users%rowtype;
begin
  if not public.is_cashew_firebase_jwt() then
    raise exception 'JWT Firebase không hợp lệ';
  end if;
  if not public.owns_document(p_document_id) then
    raise exception 'Chỉ chủ sở hữu được chia sẻ tài liệu';
  end if;
  if p_access_level not in ('viewer', 'editor') then
    raise exception 'Quyền chia sẻ không hợp lệ';
  end if;

  select u.* into target_user
  from public.users u
  where u.email = lower(btrim(p_user_email));

  if target_user.id is null then
    raise exception 'Người dùng chưa từng đăng nhập vào ứng dụng';
  end if;
  if target_user.id = public.request_uid() then
    raise exception 'Không thể chia sẻ tài liệu cho chính mình';
  end if;

  insert into public.permissions as permission (
    document_id, user_id, access_level, granted_by
  ) values (
    p_document_id,
    target_user.id,
    p_access_level,
    public.request_uid()
  )
  on conflict on constraint permissions_one_user_per_document
  do update set
    access_level = excluded.access_level,
    granted_by = excluded.granted_by,
    updated_at = now();

  return query select
    target_user.id,
    target_user.email::text,
    target_user.display_name,
    p_access_level;
end;
$$;

create or replace function public.revoke_document_permission(
  p_document_id uuid,
  p_user_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_cashew_firebase_jwt()
     or not public.owns_document(p_document_id) then
    raise exception 'Chỉ chủ sở hữu được thu hồi quyền';
  end if;
  delete from public.permissions p
  where p.document_id = p_document_id and p.user_id = p_user_id;
end;
$$;

create or replace function public.list_document_permissions(p_document_id uuid)
returns table (
  user_id text,
  email text,
  display_name text,
  access_level text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_cashew_firebase_jwt()
     or not public.owns_document(p_document_id) then
    raise exception 'Chỉ chủ sở hữu được xem danh sách quyền';
  end if;
  return query
    select u.id, u.email::text, u.display_name, p.access_level
    from public.permissions p
    join public.users u on u.id = p.user_id
    where p.document_id = p_document_id
    order by u.email;
end;
$$;

revoke all on public.users, public.documents, public.permissions from anon;
grant select, insert, update on public.users to anon;
grant select, insert, delete on public.documents to anon;
grant update(title, description) on public.documents to anon;
grant select, insert, update, delete on public.permissions to anon;
grant select, insert, update on public.users to authenticated;
grant select, insert, delete on public.documents to authenticated;
grant update(title, description) on public.documents to authenticated;
grant select, insert, update, delete on public.permissions to authenticated;

revoke all on function public.share_document(uuid, text, text) from public;
revoke all on function public.revoke_document_permission(uuid, text) from public;
revoke all on function public.list_document_permissions(uuid) from public;
grant execute on function public.share_document(uuid, text, text) to authenticated;
grant execute on function public.revoke_document_permission(uuid, text) to authenticated;
grant execute on function public.list_document_permissions(uuid) to authenticated;
grant execute on function public.share_document(uuid, text, text) to anon;
grant execute on function public.revoke_document_permission(uuid, text) to anon;
grant execute on function public.list_document_permissions(uuid) to anon;



-- 202610130002_firebase_jwt_without_role.sql
-- Firebase ID tokens không có custom claim `role` theo mặc định. Supabase sẽ
-- ánh xạ chúng vào Postgres role `anon`. Các policy dưới đây vẫn chỉ cho phép
-- JWT của đúng Firebase project nhờ policy restrictive kiểm tra iss/aud/sub.

create or replace function public.is_cashew_firebase_jwt()
returns boolean
language sql
stable
as $$
  select coalesce(
    auth.jwt()->>'iss' =
      'https://securetoken.google.com/device-streaming-33cac12e'
    and auth.jwt()->>'aud' = 'device-streaming-33cac12e'
    and nullif(auth.jwt()->>'sub', '') is not null,
    false
  )
$$;

alter policy users_firebase_project_guard
  on public.users to anon, authenticated;
alter policy users_read_self
  on public.users to anon, authenticated;
alter policy users_insert_self
  on public.users to anon, authenticated;
alter policy users_update_self
  on public.users to anon, authenticated;

alter policy documents_firebase_project_guard
  on public.documents to anon, authenticated;
alter policy documents_read_authorized
  on public.documents to anon, authenticated;
alter policy documents_insert_owner
  on public.documents to anon, authenticated;
alter policy documents_update_editor
  on public.documents to anon, authenticated;
alter policy documents_delete_owner
  on public.documents to anon, authenticated;

alter policy permissions_firebase_project_guard
  on public.permissions to anon, authenticated;
alter policy permissions_read_participant
  on public.permissions to anon, authenticated;
alter policy permissions_insert_owner
  on public.permissions to anon, authenticated;
alter policy permissions_update_owner
  on public.permissions to anon, authenticated;
alter policy permissions_delete_owner
  on public.permissions to anon, authenticated;

grant select, insert, update on public.users to anon;
grant select, insert, delete on public.documents to anon;
grant update(title, description) on public.documents to anon;
grant select, insert, update, delete on public.permissions to anon;
grant execute on function public.share_document(uuid, text, text) to anon;
grant execute on function public.revoke_document_permission(uuid, text) to anon;
grant execute on function public.list_document_permissions(uuid) to anon;



-- 202610220001_identity_and_storage_integrity.sql

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

drop policy if exists users_insert_verified_email on public.users;
create policy users_insert_verified_email
on public.users as restrictive for insert to anon, authenticated
with check (public.has_verified_firebase_email(email::text));

drop policy if exists users_update_verified_email on public.users;
create policy users_update_verified_email
on public.users as restrictive for update to anon, authenticated
using (true)
with check (public.has_verified_firebase_email(email::text));

-- Audit legacy rows before VALIDATE; new/updated rows are checked immediately.
alter table public.documents drop constraint if exists documents_storage_path_matches_identity;
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



-- 202610230001_location_and_borrow_requests.sql

alter table public.documents
  add column if not exists tags text[] not null default '{}',
  add column if not exists physical_location text not null default '',
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists is_borrowable boolean not null default false;

alter table public.documents
  drop constraint if exists documents_location_coordinates_valid;
alter table public.documents
  add constraint documents_location_coordinates_valid check (
    (latitude is null) = (longitude is null)
    and (latitude is null or latitude between -90 and 90)
    and (longitude is null or longitude between -180 and 180)
  );

create table if not exists public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  document_title text not null,
  owner_id text not null references public.users(id) on delete cascade,
  requester_id text not null references public.users(id) on delete cascade,
  requester_email text not null,
  requester_name text not null default '',
  message text not null default '' check (char_length(message) <= 1000),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (owner_id <> requester_id)
);

-- Compatibility with the earlier report schema; preserve existing rows.
alter table public.borrow_requests
  add column if not exists document_title text not null default '',
  add column if not exists requester_email text not null default '',
  add column if not exists requester_name text not null default '',
  add column if not exists message text not null default '',
  add column if not exists responded_at timestamptz;
update public.borrow_requests br
set document_title = d.title
from public.documents d where d.id = br.document_id and br.document_title = '';
update public.borrow_requests br
set requester_email = u.email::text, requester_name = u.display_name
from public.users u where u.id = br.requester_id and br.requester_email = '';

create unique index if not exists borrow_requests_one_pending_per_user
  on public.borrow_requests(document_id, requester_id)
  where status = 'pending';
create index if not exists borrow_requests_owner_status_idx
  on public.borrow_requests(owner_id, status, created_at desc);
create index if not exists borrow_requests_requester_idx
  on public.borrow_requests(requester_id, created_at desc);

create or replace function public.guard_borrowable_document_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_borrowable is distinct from old.is_borrowable
     and old.owner_id <> public.request_uid() then
    raise exception 'Chỉ chủ sở hữu được bật hoặc tắt cho mượn';
  end if;
  return new;
end;
$$;

drop trigger if exists documents_borrowable_owner_only on public.documents;
create trigger documents_borrowable_owner_only
before update of is_borrowable on public.documents
for each row execute function public.guard_borrowable_document_owner();

revoke update on public.documents from anon, authenticated;
grant update(title, description, tags, physical_location, latitude, longitude, is_borrowable)
  on public.documents to anon, authenticated;

alter table public.borrow_requests enable row level security;

drop policy if exists borrow_requests_firebase_project_guard on public.borrow_requests;
create policy borrow_requests_firebase_project_guard
on public.borrow_requests as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists borrow_requests_read_participant on public.borrow_requests;
create policy borrow_requests_read_participant
on public.borrow_requests for select to anon, authenticated
using (
  requester_id = (select public.request_uid())
  or owner_id = (select public.request_uid())
);

drop policy if exists borrow_requests_insert_requester on public.borrow_requests;
create policy borrow_requests_insert_requester
on public.borrow_requests for insert to anon, authenticated
with check (requester_id = (select public.request_uid()));

drop policy if exists borrow_requests_update_owner on public.borrow_requests;
create policy borrow_requests_update_owner
on public.borrow_requests for update to anon, authenticated
using (owner_id = (select public.request_uid()) and status = 'pending')
with check (owner_id = (select public.request_uid()));

grant select, insert, update on public.borrow_requests to anon, authenticated;
revoke insert, update on public.borrow_requests from anon, authenticated;
grant select on public.borrow_requests to anon, authenticated;

create or replace function public.request_document_borrow(
  p_document_id uuid,
  p_message text default ''
)
returns setof public.borrow_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_document public.documents%rowtype;
  created_request public.borrow_requests%rowtype;
  current_uid text := public.request_uid();
  current_email text := lower(btrim(auth.jwt()->>'email'));
begin
  if not public.is_cashew_firebase_jwt()
     or coalesce(auth.jwt()->>'email_verified', 'false') <> 'true'
     or coalesce(current_email, '') = '' then
    raise exception 'Cần đăng nhập bằng email Firebase đã xác thực';
  end if;

  select d.* into target_document
  from public.documents d
  where d.id = p_document_id and d.is_borrowable;
  if target_document.id is null then
    raise exception 'Tài liệu không tồn tại hoặc không mở cho mượn';
  end if;
  if target_document.owner_id = current_uid then
    raise exception 'Không thể yêu cầu mượn tài liệu của chính mình';
  end if;

  insert into public.users(id, email, display_name)
  values (
    current_uid,
    current_email,
    coalesce(nullif(btrim(auth.jwt()->>'name'), ''), current_email)
  )
  on conflict (id) do nothing;

  insert into public.borrow_requests(
    document_id, document_title, owner_id, requester_id,
    requester_email, requester_name, message
  )
  values (
    target_document.id, target_document.title, target_document.owner_id,
    current_uid, current_email,
    coalesce(auth.jwt()->>'name', ''), left(btrim(coalesce(p_message, '')), 1000)
  )
  on conflict (document_id, requester_id) where status = 'pending'
  do nothing
  returning * into created_request;

  if created_request.id is null then
    select * into created_request
    from public.borrow_requests br
    where br.document_id = p_document_id
      and br.requester_id = current_uid
      and br.status = 'pending';
  end if;

  return next created_request;
end;
$$;

create or replace function public.search_borrowable_documents(p_query text default '')
returns table (
  id uuid,
  title text,
  description text,
  tags text[],
  physical_location text,
  latitude double precision,
  longitude double precision,
  owner_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select d.id, d.title, d.description, d.tags, d.physical_location,
         d.latitude, d.longitude, u.display_name
  from public.documents d
  join public.users u on u.id = d.owner_id
  where public.is_cashew_firebase_jwt()
    and d.is_borrowable
    and d.owner_id <> public.request_uid()
    and (
      btrim(coalesce(p_query, '')) = ''
      or d.title ilike '%' || btrim(p_query) || '%'
      or d.description ilike '%' || btrim(p_query) || '%'
      or array_to_string(d.tags, ',') ilike '%' || btrim(p_query) || '%'
    )
  order by d.updated_at desc
  limit 100;
$$;

create or replace function public.respond_document_borrow(
  p_request_id uuid,
  p_status text
)
returns setof public.borrow_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  borrow_request public.borrow_requests%rowtype;
begin
  if not public.is_cashew_firebase_jwt()
     or p_status not in ('approved', 'rejected') then
    raise exception 'Yêu cầu phản hồi mượn không hợp lệ';
  end if;

  select * into borrow_request
  from public.borrow_requests br
  where br.id = p_request_id
  for update;
  if borrow_request.id is null
     or borrow_request.owner_id <> public.request_uid()
     or borrow_request.status <> 'pending' then
    raise exception 'Yêu cầu không tồn tại hoặc đã được xử lý';
  end if;

  if p_status = 'approved' then
    insert into public.permissions(document_id, user_id, access_level, granted_by)
    values (
      borrow_request.document_id,
      borrow_request.requester_id,
      'viewer',
      borrow_request.owner_id
    )
    on conflict on constraint permissions_one_user_per_document do nothing;
  end if;

  update public.borrow_requests
  set status = p_status, responded_at = now()
  where id = p_request_id
  returning * into borrow_request;

  return next borrow_request;
end;
$$;

revoke all on function public.request_document_borrow(uuid, text) from public;
revoke all on function public.respond_document_borrow(uuid, text) from public;
revoke all on function public.search_borrowable_documents(text) from public;
grant execute on function public.request_document_borrow(uuid, text)
  to anon, authenticated;
grant execute on function public.respond_document_borrow(uuid, text)
  to anon, authenticated;
grant execute on function public.search_borrowable_documents(text)
  to anon, authenticated;



-- 202610240001_supabase_storage.sql

insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 26214400)
on conflict (id) do update
set public = false, file_size_limit = excluded.file_size_limit;

drop policy if exists documents_bucket_firebase_project_guard
  on storage.objects;
drop policy if exists documents_bucket_firebase_project_guard on storage.objects;
create policy documents_bucket_firebase_project_guard
on storage.objects as restrictive to anon, authenticated
using (
  bucket_id <> 'documents'
  or (select public.is_cashew_firebase_jwt())
)
with check (
  bucket_id <> 'documents'
  or (select public.is_cashew_firebase_jwt())
);

drop policy if exists documents_bucket_read_authorized on storage.objects;
drop policy if exists documents_bucket_read_authorized on storage.objects;
create policy documents_bucket_read_authorized
on storage.objects for select to anon, authenticated
using (
  bucket_id = 'documents'
  and exists (
    select 1
    from public.documents d
    where d.id::text = split_part(name, '/', 2)
      and d.storage_path = 'documents/' || name
      and public.can_read_document(d.id)
  )
);

drop policy if exists documents_bucket_insert_owner on storage.objects;
drop policy if exists documents_bucket_insert_owner on storage.objects;
create policy documents_bucket_insert_owner
on storage.objects for insert to anon, authenticated
with check (
  bucket_id = 'documents'
  and cardinality(string_to_array(name, '/')) = 3
  and split_part(name, '/', 1) = (select public.request_uid())
  and exists (
    select 1
    from public.documents d
    where d.id::text = split_part(name, '/', 2)
      and d.owner_id = (select public.request_uid())
      and d.storage_path = 'documents/' || name
  )
);

drop policy if exists documents_bucket_delete_owner on storage.objects;
drop policy if exists documents_bucket_delete_owner on storage.objects;
create policy documents_bucket_delete_owner
on storage.objects for delete to anon, authenticated
using (
  bucket_id = 'documents'
  and split_part(name, '/', 1) = (select public.request_uid())
  and exists (
    select 1
    from public.documents d
    where d.id::text = split_part(name, '/', 2)
      and d.owner_id = (select public.request_uid())
      and d.storage_path = 'documents/' || name
  )
);



-- 202610240002_device_tokens.sql

create table if not exists public.device_tokens (
  token text primary key check (char_length(token) between 1 and 4096),
  user_id text not null references public.users(id) on delete cascade,
  platform text not null
    check (platform in ('web', 'android', 'ios', 'macos', 'windows', 'linux')),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_firebase_project_guard on public.device_tokens;
create policy device_tokens_firebase_project_guard
on public.device_tokens as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists device_tokens_read_self on public.device_tokens;
create policy device_tokens_read_self
on public.device_tokens for select to anon, authenticated
using (user_id = (select public.request_uid()));

revoke all on public.device_tokens from public;
grant select on public.device_tokens to anon, authenticated;
grant select on public.device_tokens to service_role;

create or replace function public.register_device_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_uid text := public.request_uid();
  current_email text := lower(btrim(auth.jwt()->>'email'));
begin
  if not public.is_cashew_firebase_jwt()
     or coalesce(auth.jwt()->>'email_verified', 'false') <> 'true'
     or current_uid is null
     or current_email is null
     or coalesce(char_length(p_token), 0) not between 1 and 4096
     or p_platform is null
     or p_platform not in ('web', 'android', 'ios', 'macos', 'windows', 'linux') then
    raise exception 'Invalid device token registration';
  end if;

  insert into public.device_tokens(token, user_id, platform)
  values (p_token, current_uid, p_platform)
  on conflict (token) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      updated_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_cashew_firebase_jwt() then
    raise exception 'Invalid Firebase identity';
  end if;
  delete from public.device_tokens
  where token = p_token and user_id = public.request_uid();
end;
$$;

create table if not exists public.notification_dispatches (
  dispatch_key text primary key,
  created_at timestamptz not null default now()
);

revoke all on public.notification_dispatches from public, anon, authenticated;
grant select, insert, delete on public.notification_dispatches to service_role;
revoke all on function public.register_device_token(text, text) from public;
revoke all on function public.unregister_device_token(text) from public;
grant execute on function public.register_device_token(text, text)
  to anon, authenticated;
grant execute on function public.unregister_device_token(text)
  to anon, authenticated;



-- 202610240003_realtime.sql

-- Primary keys are sufficient: clients re-query RLS protected tables.
do $$
declare table_name text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach table_name in array array['documents', 'permissions', 'borrow_requests'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end $$;


-- 202610240004_classification_and_recommendations.sql

alter table public.users add column if not exists interests text[] not null default '{}';
grant update(interests) on public.users to anon, authenticated;

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  name varchar not null,
  slug varchar not null unique,
  color_code varchar,
  icon_name varchar
);
create unique index if not exists tags_slug_unique on public.tags(slug);
create table if not exists public.document_tags (
  document_id uuid not null references public.documents(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(document_id, tag_id)
);
create unique index if not exists document_tags_pair_unique on public.document_tags(document_id, tag_id);
create table if not exists public.document_locations (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null unique references public.documents(id) on delete cascade,
  latitude double precision,
  longitude double precision,
  address text,
  room_shelf varchar,
  address_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null)),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);
create table if not exists public.user_activities (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.users(id) on delete cascade,
  document_id uuid references public.documents(id) on delete set null,
  action_type text not null,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists user_activities_user_date_idx on public.user_activities(user_id, created_at desc);

-- The existing documents API is the write boundary. Projections into relational
-- tables run in the same SQL transaction; clients cannot write inconsistent tags.
create or replace function public.sync_document_classification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.document_tags where document_id = new.id;
  insert into public.tags(name, slug)
  select min(btrim(t)), lower(btrim(t)) from unnest(new.tags) t
  where btrim(t) <> '' group by lower(btrim(t))
  on conflict (slug) do nothing;
  insert into public.document_tags(document_id, tag_id)
  select distinct new.id, t.id from public.tags t
  where t.slug in (select lower(btrim(x)) from unnest(new.tags) x)
  on conflict do nothing;
  if new.physical_location <> '' or new.latitude is not null then
    insert into public.document_locations(document_id, latitude, longitude, address)
    values(new.id, new.latitude, new.longitude, new.physical_location)
    on conflict(document_id) do update
    set latitude = excluded.latitude, longitude = excluded.longitude,
        address = excluded.address, updated_at = now();
  else
    delete from public.document_locations where document_id = new.id;
  end if;
  return new;
end $$;
revoke all on function public.sync_document_classification() from public;
drop trigger if exists documents_sync_classification on public.documents;
create trigger documents_sync_classification
  after insert or update of tags, physical_location, latitude, longitude
  on public.documents for each row execute function public.sync_document_classification();

-- Preserve tags from existing report-schema relations when migrating.
update public.documents d set tags = coalesce((
  select array_agg(distinct t.name::text) from public.document_tags dt
  join public.tags t on t.id = dt.tag_id where dt.document_id = d.id
), '{}') where cardinality(d.tags) = 0
  and exists(select 1 from public.document_tags dt where dt.document_id = d.id);
-- Backfill projections without changing documents or its updated_at timestamp.
insert into public.tags(name, slug)
select min(btrim(t)), lower(btrim(t)) from public.documents d,
  lateral unnest(d.tags) t where btrim(t) <> '' group by lower(btrim(t))
on conflict(slug) do nothing;
insert into public.document_tags(document_id, tag_id)
select distinct d.id, t.id from public.documents d
join public.tags t on t.slug = any(select lower(btrim(x)) from unnest(d.tags) x)
on conflict do nothing;
insert into public.document_locations(document_id, latitude, longitude, address)
select id, latitude, longitude, physical_location from public.documents
where physical_location <> '' or latitude is not null on conflict(document_id) do nothing;

alter table public.tags enable row level security;
alter table public.document_tags enable row level security;
alter table public.document_locations enable row level security;
alter table public.user_activities enable row level security;
revoke all on public.tags, public.document_tags, public.document_locations, public.user_activities from anon, authenticated;
grant select on public.tags, public.document_tags, public.document_locations, public.user_activities to anon, authenticated;

drop policy if exists classification_tags_guard on public.tags;
create policy classification_tags_guard on public.tags as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
drop policy if exists classification_tags_read on public.tags;
create policy classification_tags_read on public.tags for select to anon, authenticated
using (exists(select 1 from public.document_tags dt where dt.tag_id = id and public.can_read_document(dt.document_id)));
drop policy if exists classification_links_guard on public.document_tags;
create policy classification_links_guard on public.document_tags as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
drop policy if exists classification_links_read on public.document_tags;
create policy classification_links_read on public.document_tags for select to anon, authenticated
using (public.can_read_document(document_id));
drop policy if exists classification_locations_guard on public.document_locations;
create policy classification_locations_guard on public.document_locations as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
drop policy if exists classification_locations_read on public.document_locations;
create policy classification_locations_read on public.document_locations for select to anon, authenticated
using (public.can_read_document(document_id));
drop policy if exists classification_activities_guard on public.user_activities;
create policy classification_activities_guard on public.user_activities as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
drop policy if exists classification_activities_read on public.user_activities;
create policy classification_activities_read on public.user_activities for select to anon, authenticated
using (user_id = (select public.request_uid()));

create or replace function public.record_document_activity(p_document_id uuid, p_action text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_cashew_firebase_jwt() or not public.can_read_document(p_document_id)
     or p_action not in ('view', 'download') then
    raise exception 'Document activity is not authorized';
  end if;
  insert into public.user_activities(user_id, document_id, action_type)
  values(public.request_uid(), p_document_id, p_action);
end $$;
revoke all on function public.record_document_activity(uuid, text) from public;
grant execute on function public.record_document_activity(uuid, text) to anon, authenticated;

-- Rank only catalog metadata. Never return storage paths or grant file access.
create or replace function public.recommend_borrowable_documents(p_query text default '')
returns table(id uuid, title text, description text, tags text[], physical_location text,
 latitude double precision, longitude double precision, owner_name text, score bigint)
language sql stable security definer set search_path = '' as $$
  with preference_tags as (
    select lower(btrim(x)) tag, 3::bigint weight from public.users u,
      lateral unnest(u.interests) x where u.id = public.request_uid()
    union all
    select lower(btrim(x)), 1::bigint from public.documents d,
      lateral unnest(d.tags) x where d.owner_id = public.request_uid()
    union all
    select lower(btrim(x)), 2::bigint from public.user_activities a
      join public.documents d on d.id = a.document_id,
      lateral unnest(d.tags) x
      where a.user_id = public.request_uid() and a.created_at > now() - interval '90 days'
    union all
    select lower(btrim(x)), 2::bigint from public.borrow_requests br
      join public.documents d on d.id = br.document_id,
      lateral unnest(d.tags) x
      where br.requester_id = public.request_uid() and br.status = 'approved'
  ), weights as (select tag, sum(weight) weight from preference_tags where tag <> '' group by tag)
  select d.id, d.title, d.description, d.tags, d.physical_location,
    d.latitude, d.longitude, u.display_name,
    coalesce((select sum(w.weight) from weights w
      where w.tag = any(select lower(btrim(x)) from unnest(d.tags) x)), 0)::bigint as score
  from public.documents d join public.users u on u.id = d.owner_id
  where public.is_cashew_firebase_jwt() and d.is_borrowable
    and d.owner_id <> public.request_uid()
    and (btrim(coalesce(p_query, '')) = '' or d.title ilike '%' || btrim(p_query) || '%'
      or d.description ilike '%' || btrim(p_query) || '%'
      or array_to_string(d.tags, ',') ilike '%' || btrim(p_query) || '%')
  order by score desc, d.updated_at desc, d.id limit 100;
$$;
revoke all on function public.recommend_borrowable_documents(text) from public;
grant execute on function public.recommend_borrowable_documents(text) to anon, authenticated;


-- 202610240005_reject_missing_identity.sql

-- Always return false for missing JWT claims; PL/pgSQL IF NOT NULL is not true.
create or replace function public.is_cashew_firebase_jwt()
returns boolean language sql stable as $$
  select coalesce(
    auth.jwt()->>'iss' = 'https://securetoken.google.com/device-streaming-33cac12e'
    and auth.jwt()->>'aud' = 'device-streaming-33cac12e'
    and nullif(auth.jwt()->>'sub', '') is not null,
    false
  )
$$;


commit;
notify pgrst, 'reload schema';
