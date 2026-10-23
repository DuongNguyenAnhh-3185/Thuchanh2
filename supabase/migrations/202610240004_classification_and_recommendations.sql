begin;

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

create policy classification_tags_guard on public.tags as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
create policy classification_tags_read on public.tags for select to anon, authenticated
using (exists(select 1 from public.document_tags dt where dt.tag_id = id and public.can_read_document(dt.document_id)));
create policy classification_links_guard on public.document_tags as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
create policy classification_links_read on public.document_tags for select to anon, authenticated
using (public.can_read_document(document_id));
create policy classification_locations_guard on public.document_locations as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
create policy classification_locations_read on public.document_locations for select to anon, authenticated
using (public.can_read_document(document_id));
create policy classification_activities_guard on public.user_activities as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()));
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
commit;
