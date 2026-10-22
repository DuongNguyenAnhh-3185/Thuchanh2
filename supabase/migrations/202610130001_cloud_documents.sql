begin;

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
create policy users_firebase_project_guard
on public.users as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists users_read_self on public.users;
create policy users_read_self
on public.users for select to anon, authenticated
using (id = (select public.request_uid()));

drop policy if exists users_insert_self on public.users;
create policy users_insert_self
on public.users for insert to anon, authenticated
with check (id = (select public.request_uid()));

drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users for update to anon, authenticated
using (id = (select public.request_uid()))
with check (id = (select public.request_uid()));

drop policy if exists documents_firebase_project_guard on public.documents;
create policy documents_firebase_project_guard
on public.documents as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists documents_read_authorized on public.documents;
create policy documents_read_authorized
on public.documents for select to anon, authenticated
using ((select public.can_read_document(id)));

drop policy if exists documents_insert_owner on public.documents;
create policy documents_insert_owner
on public.documents for insert to anon, authenticated
with check (owner_id = (select public.request_uid()));

drop policy if exists documents_update_editor on public.documents;
create policy documents_update_editor
on public.documents for update to anon, authenticated
using ((select public.can_edit_document(id)))
with check ((select public.can_edit_document(id)));

drop policy if exists documents_delete_owner on public.documents;
create policy documents_delete_owner
on public.documents for delete to anon, authenticated
using ((select public.owns_document(id)));

drop policy if exists permissions_firebase_project_guard on public.permissions;
create policy permissions_firebase_project_guard
on public.permissions as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

drop policy if exists permissions_read_participant on public.permissions;
create policy permissions_read_participant
on public.permissions for select to anon, authenticated
using (
  user_id = (select public.request_uid())
  or (select public.owns_document(document_id))
);

drop policy if exists permissions_insert_owner on public.permissions;
create policy permissions_insert_owner
on public.permissions for insert to anon, authenticated
with check (
  (select public.owns_document(document_id))
  and granted_by = (select public.request_uid())
);

drop policy if exists permissions_update_owner on public.permissions;
create policy permissions_update_owner
on public.permissions for update to anon, authenticated
using ((select public.owns_document(document_id)))
with check ((select public.owns_document(document_id)));

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

commit;
