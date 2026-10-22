-- Firebase ID tokens không có custom claim `role` theo mặc định. Supabase sẽ
-- ánh xạ chúng vào Postgres role `anon`. Các policy dưới đây vẫn chỉ cho phép
-- JWT của đúng Firebase project nhờ policy restrictive kiểm tra iss/aud/sub.
begin;

create or replace function public.is_cashew_firebase_jwt()
returns boolean
language sql
stable
as $$
  select
    auth.jwt()->>'iss' =
      'https://securetoken.google.com/device-streaming-33cac12e'
    and auth.jwt()->>'aud' = 'device-streaming-33cac12e'
    and nullif(auth.jwt()->>'sub', '') is not null
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

commit;
