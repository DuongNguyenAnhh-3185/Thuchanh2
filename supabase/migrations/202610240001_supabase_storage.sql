begin;

insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 26214400)
on conflict (id) do update
set public = false, file_size_limit = excluded.file_size_limit;

drop policy if exists documents_bucket_firebase_project_guard
  on storage.objects;
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

commit;
