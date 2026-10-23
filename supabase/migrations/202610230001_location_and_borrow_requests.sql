begin;

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

create policy borrow_requests_firebase_project_guard
on public.borrow_requests as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

create policy borrow_requests_read_participant
on public.borrow_requests for select to anon, authenticated
using (
  requester_id = (select public.request_uid())
  or owner_id = (select public.request_uid())
);

create policy borrow_requests_insert_requester
on public.borrow_requests for insert to anon, authenticated
with check (requester_id = (select public.request_uid()));

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

commit;
