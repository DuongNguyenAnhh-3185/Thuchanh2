-- ============================================================================
-- MIGRATION: 202610230001_location_sharing_recommendation.sql
-- Module: Vị trí vật lý, Chia sẻ / Mượn tài liệu & Gợi ý (Recommendation)
-- ============================================================================

begin;

-- 1. Bổ sung các cột vị trí kho vật lý và tags vào bảng documents
alter table public.documents
  add column if not exists storage_room text,
  add column if not exists shelf_code text,
  add column if not exists box_number text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists address text,
  add column if not exists tags text[] default '{}'::text[];

create index if not exists documents_tags_gin_idx on public.documents using gin (tags);
create index if not exists documents_shelf_code_idx on public.documents (shelf_code);

-- Cấp quyền update thêm các trường vị trí và tags cho authenticated / anon nếu dùng Firebase JWT
grant update(title, description, storage_room, shelf_code, box_number, latitude, longitude, address, tags)
  on public.documents to authenticated;

-- 2. Bảng document_shares: Quản lý quyền xem/sửa tài liệu được chia sẻ
create table if not exists public.document_shares (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id text not null references public.users(id) on delete cascade,
  permission text not null check (permission in ('view', 'edit')),
  created_at timestamptz not null default now(),
  constraint document_shares_unique_user unique (document_id, user_id)
);

create index if not exists document_shares_doc_idx on public.document_shares(document_id);
create index if not exists document_shares_user_idx on public.document_shares(user_id);

-- 3. Bảng borrow_requests: Luồng mượn tài liệu vật lý/số
create table if not exists public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  requester_id text not null references public.users(id) on delete cascade,
  status text not null check (status in ('pending', 'approved', 'rejected', 'returned')) default 'pending',
  borrow_date timestamptz not null default now(),
  due_date timestamptz not null,
  notes text,
  created_at timestamptz not null default now(),
  constraint borrow_dates_valid check (due_date >= borrow_date)
);

create index if not exists borrow_requests_doc_idx on public.borrow_requests(document_id);
create index if not exists borrow_requests_requester_idx on public.borrow_requests(requester_id);
create index if not exists borrow_requests_status_idx on public.borrow_requests(status);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

alter table public.document_shares enable row level security;
alter table public.borrow_requests enable row level security;

-- Helper lấy user id hiện tại (hỗ trợ cả Firebase JWT qua request_uid() và Supabase Auth qua auth.uid())
create or replace function public.current_actor_uid()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(auth.jwt()->>'sub', ''),
    auth.uid()::text
  );
$$;

-- Các hàm SECURITY DEFINER kiểm tra quyền (Bypass RLS bên trong hàm để triệt tiêu hoàn toàn lỗi đệ quy 42P17)
create or replace function public.is_document_owner(target_doc_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.id = target_doc_id
      and d.owner_id = public.current_actor_uid()
  );
$$;

create or replace function public.has_document_share_access(target_doc_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.document_shares ds
    where ds.document_id = target_doc_id
      and ds.user_id = public.current_actor_uid()
  );
$$;

-- Policies cho document_shares:
-- 1. Người nhận chia sẻ được xem quyền của chính mình
drop policy if exists document_shares_select_recipient on public.document_shares;
create policy document_shares_select_recipient on public.document_shares
  for select to anon, authenticated
  using (user_id = public.current_actor_uid());

-- 2. Chủ sở hữu tài liệu được toàn quyền xem/thêm/sửa/xóa quyền chia sẻ (dùng SECURITY DEFINER)
drop policy if exists document_shares_owner_all on public.document_shares;
create policy document_shares_owner_all on public.document_shares
  for all to anon, authenticated
  using (public.is_document_owner(document_id))
  with check (public.is_document_owner(document_id));

-- Policies cho borrow_requests:
-- 1. Người gửi yêu cầu được xem các yêu cầu do mình tạo
drop policy if exists borrow_requests_select_requester on public.borrow_requests;
create policy borrow_requests_select_requester on public.borrow_requests
  for select to anon, authenticated
  using (requester_id = public.current_actor_uid());

-- 2. Người gửi yêu cầu được tạo mới yêu cầu mượn
drop policy if exists borrow_requests_insert_requester on public.borrow_requests;
create policy borrow_requests_insert_requester on public.borrow_requests
  for insert to anon, authenticated
  with check (requester_id = public.current_actor_uid());

-- 3. Người gửi yêu cầu được cập nhật hủy đơn khi đang pending
drop policy if exists borrow_requests_update_requester on public.borrow_requests;
create policy borrow_requests_update_requester on public.borrow_requests
  for update to anon, authenticated
  using (requester_id = public.current_actor_uid() and status = 'pending')
  with check (requester_id = public.current_actor_uid());

-- 4. Chủ tài liệu được xem tất cả yêu cầu gửi đến cho tài liệu của mình (dùng SECURITY DEFINER)
drop policy if exists borrow_requests_select_owner on public.borrow_requests;
create policy borrow_requests_select_owner on public.borrow_requests
  for select to anon, authenticated
  using (public.is_document_owner(document_id));

-- 5. Chủ tài liệu được duyệt/từ chối/hoàn tất (approved, rejected, returned) (dùng SECURITY DEFINER)
drop policy if exists borrow_requests_update_owner on public.borrow_requests;
create policy borrow_requests_update_owner on public.borrow_requests
  for update to anon, authenticated
  using (public.is_document_owner(document_id))
  with check (public.is_document_owner(document_id));

-- Bổ sung Policy cho documents: Cho phép người có trong document_shares được đọc tài liệu (dùng SECURITY DEFINER)
drop policy if exists documents_read_shared_users on public.documents;
create policy documents_read_shared_users on public.documents
  for select to anon, authenticated
  using (public.has_document_share_access(id));

-- Phân quyền truy cập bảng cho role anon và authenticated
grant select, insert, update, delete on public.document_shares to anon, authenticated;
grant select, insert, update, delete on public.borrow_requests to anon, authenticated;

-- ============================================================================
-- TRIGGER: Tự động cấp/thu hồi quyền đọc khi duyệt mượn tài liệu
-- ============================================================================

create or replace function public.handle_borrow_request_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nếu duyệt đơn mượn: Cấp quyền view tạm thời vào document_shares
  if new.status = 'approved' and old.status != 'approved' then
    insert into public.document_shares (document_id, user_id, permission)
    values (new.document_id, new.requester_id, 'view')
    on conflict (document_id, user_id) 
    do update set permission = 'view';
  end if;

  -- Nếu trả tài liệu hoặc từ chối: Thu hồi quyền chia sẻ phát sinh do mượn
  if new.status in ('returned', 'rejected') and old.status = 'approved' then
    delete from public.document_shares
    where document_id = new.document_id
      and user_id = new.requester_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_borrow_request_status_change on public.borrow_requests;
create trigger trg_borrow_request_status_change
  after update of status on public.borrow_requests
  for each row execute function public.handle_borrow_request_status_change();

-- ============================================================================
-- RPC 1: Chia sẻ quyền truy cập thông qua Email
-- ============================================================================

create or replace function public.share_document_by_email(
  p_document_id uuid,
  p_email text,
  p_permission text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_user_id text;
  v_doc_owner_id text;
  v_share_id uuid;
  v_actor_id text;
begin
  v_actor_id := public.current_actor_uid();

  -- Kiểm tra quyền sở hữu của người gọi hàm
  select owner_id into v_doc_owner_id
  from public.documents
  where id = p_document_id;

  if v_doc_owner_id is null or v_doc_owner_id != v_actor_id then
    raise exception 'Chỉ chủ sở hữu mới có quyền chia sẻ tài liệu này.';
  end if;

  if p_permission not in ('view', 'edit') then
    raise exception 'Quyền chỉ được phép là view hoặc edit.';
  end if;

  -- Tìm user theo email trong public.users (hoặc auth.users)
  select id into v_target_user_id
  from public.users
  where lower(email) = lower(btrim(p_email));

  if v_target_user_id is null then
    raise exception 'Không tìm thấy người dùng với email: %', p_email;
  end if;

  if v_target_user_id = v_actor_id then
    raise exception 'Bạn không thể tự chia sẻ tài liệu cho chính mình.';
  end if;

  -- Thêm hoặc cập nhật quyền
  insert into public.document_shares (document_id, user_id, permission)
  values (p_document_id, v_target_user_id, p_permission)
  on conflict (document_id, user_id)
  do update set permission = excluded.permission, created_at = now()
  returning id into v_share_id;

  return jsonb_build_object(
    'share_id', v_share_id,
    'user_id', v_target_user_id,
    'email', p_email,
    'permission', p_permission
  );
end;
$$;

grant execute on function public.share_document_by_email(uuid, text, text) to anon, authenticated;

-- ============================================================================
-- RPC 2: Content-Based Recommendation (Gợi ý tài liệu dựa trên Tag Overlap)
-- ============================================================================

create or replace function public.get_recommended_documents(
  target_user_id text,
  limit_count int default 6
)
returns table (
  id uuid,
  title text,
  description text,
  file_name text,
  tags text[],
  storage_room text,
  shelf_code text,
  box_number text,
  address text,
  matched_tags text[],
  similarity_score numeric,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_tags text[];
begin
  -- 1. Thu thập profile tags từ tài liệu user đã sở hữu, đã mượn hoặc được chia sẻ
  select coalesce(array_agg(distinct t), '{}'::text[])
  into v_user_tags
  from (
    -- Tags từ tài liệu do user sở hữu
    select unnest(d.tags) as t
    from public.documents d
    where d.owner_id = target_user_id
      and d.tags is not null
    union
    -- Tags từ tài liệu user đã mượn
    select unnest(d.tags) as t
    from public.borrow_requests br
    join public.documents d on d.id = br.document_id
    where br.requester_id = target_user_id
      and d.tags is not null
    union
    -- Tags từ tài liệu được chia sẻ cho user
    select unnest(d.tags) as t
    from public.document_shares ds
    join public.documents d on d.id = ds.document_id
    where ds.user_id = target_user_id
      and d.tags is not null
  ) collected_tags;

  -- Trường hợp cold-start (user mới chưa có tag nào): gợi ý các tài liệu mới nhất chưa sở hữu
  if cardinality(v_user_tags) = 0 then
    return query
    select 
      d.id,
      d.title,
      d.description,
      d.file_name,
      coalesce(d.tags, '{}'::text[]),
      d.storage_room,
      d.shelf_code,
      d.box_number,
      d.address,
      '{}'::text[] as matched_tags,
      0.0::numeric as similarity_score,
      d.created_at
    from public.documents d
    where d.owner_id != target_user_id
    order by d.created_at desc
    limit limit_count;
    return;
  end if;

  -- 2. Tính toán Overlap & Jaccard Similarity index: |A ∩ B| / |A ∪ B|
  return query
  with candidates as (
    select 
      d.id,
      d.title,
      d.description,
      d.file_name,
      d.tags,
      d.storage_room,
      d.shelf_code,
      d.box_number,
      d.address,
      d.created_at,
      -- Các tag trùng khớp (Intersection)
      (
        select coalesce(array_agg(val), '{}'::text[])
        from unnest(d.tags) as val
        where val = any(v_user_tags)
      ) as matched_tags,
      -- Số lượng tag duy nhất của cả 2 tập hợp (Union count)
      (
        select count(distinct val)
        from (
          select unnest(d.tags) as val
          union
          select unnest(v_user_tags) as val
        ) u
      ) as union_tag_count
    from public.documents d
    where d.owner_id != target_user_id
      and d.tags is not null
      and d.tags && v_user_tags -- Lọc nhanh bằng GIN index: có ít nhất 1 tag chung
      and not exists (
        -- Bỏ qua các tài liệu user đang mượn hoặc đã được chia sẻ
        select 1 from public.borrow_requests br 
        where br.document_id = d.id and br.requester_id = target_user_id
      )
  )
  select 
    c.id,
    c.title,
    c.description,
    c.file_name,
    c.tags,
    c.storage_room,
    c.shelf_code,
    c.box_number,
    c.address,
    c.matched_tags,
    case 
      when c.union_tag_count > 0 
        then round((cardinality(c.matched_tags)::numeric / c.union_tag_count::numeric), 4)
      else 0.0
    end as similarity_score,
    c.created_at
  from candidates c
  where cardinality(c.matched_tags) > 0
  order by similarity_score desc, cardinality(c.matched_tags) desc, c.created_at desc
  limit limit_count;
end;
$$;

grant execute on function public.get_recommended_documents(text, int) to anon, authenticated;

commit;
