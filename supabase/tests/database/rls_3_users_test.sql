-- Kiểm thử RLS bằng 3 tài khoản Firebase giả lập.
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

select extensions.is(
  (select count(*) from storage.buckets where id = 'documents'),
  1::bigint,
  'Private Supabase Storage bucket is provisioned'
);

insert into public.users (id, email, display_name) values
  ('firebase-alice', 'alice@example.com', 'Alice'),
  ('firebase-bob', 'bob@example.com', 'Bob'),
  ('firebase-carol', 'carol@example.com', 'Carol');

insert into public.documents (
  id, owner_id, title, file_name, storage_path, file_size_bytes, mime_type,
  is_borrowable
) values
  ('11111111-1111-4111-8111-111111111111', 'firebase-alice', 'Tài liệu Alice',
   'alice.pdf', 'documents/firebase-alice/11111111-1111-4111-8111-111111111111/alice.pdf', 1024, 'application/pdf', true),
  ('22222222-2222-4222-8222-222222222222', 'firebase-bob', 'Tài liệu Bob',
   'bob.pdf', 'documents/firebase-bob/22222222-2222-4222-8222-222222222222/bob.pdf', 2048, 'application/pdf', false);

insert into public.permissions (document_id, user_id, access_level, granted_by)
values (
  '11111111-1111-4111-8111-111111111111',
  'firebase-bob',
  'editor',
  'firebase-alice'
);

-- Alice: chỉ nhìn thấy tài liệu do mình sở hữu.
select set_config(
  'request.jwt.claims',
  '{"sub":"firebase-alice","email":"alice@example.com","email_verified":true,"iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}',
  true
);
set local role anon;
select extensions.is(
  (select count(*) from public.documents),
  1::bigint,
  'Alice chỉ thấy tài liệu của mình'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"firebase-alice","email":"alice@example.com","email_verified":true,"iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}', true);
set local role anon;
select extensions.throws_ok(
  $$ update public.users set email = 'victim@example.com' where id = 'firebase-alice' $$,
  '42501', null::text, 'Cannot impersonate another email'
);
select extensions.throws_ok(
  $$ insert into public.documents (id, owner_id, title, file_name, storage_path, file_size_bytes)
     values ('33333333-3333-4333-8333-333333333333', 'firebase-alice', 'Forged path', 'bob.pdf',
       'documents/firebase-bob/22222222-2222-4222-8222-222222222222/bob.pdf', 100) $$,
  '23514', null::text, 'Cannot reference another owner file'
);
reset role;

-- Bob: thấy tài liệu riêng và tài liệu Alice chia sẻ với quyền editor.
select set_config(
  'request.jwt.claims',
  '{"sub":"firebase-bob","email":"bob@example.com","email_verified":true,"iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}',
  true
);
set local role anon;
select extensions.is(
  (select count(*) from public.documents),
  2::bigint,
  'Bob thấy tài liệu riêng và tài liệu được chia sẻ'
);
select extensions.results_eq(
  $$
    update public.documents
    set title = 'Bob đã cập nhật'
    where id = '11111111-1111-4111-8111-111111111111'
    returning title
  $$,
  $$ values ('Bob đã cập nhật'::text) $$,
  'Bob editor cập nhật được metadata'
);
select extensions.is_empty(
  $$
    delete from public.documents
    where id = '11111111-1111-4111-8111-111111111111'
    returning id
  $$,
  'Bob không thể xóa tài liệu của Alice'
);
select extensions.lives_ok(
  $$ select public.register_device_token('dummy-fcm-token-bob', 'web') $$,
  'Verified user can register a push token'
);
select extensions.is(
  (select count(*) from public.device_tokens),
  1::bigint,
  'User can read only their registered push token'
);
select extensions.is(
  (select count(*) from public.search_borrowable_documents('')),
  1::bigint,
  'Borrow catalog only returns documents explicitly opened for borrowing'
);
select extensions.is(
  (
    select status
    from public.request_document_borrow(
      '11111111-1111-4111-8111-111111111111',
      'Tôi muốn mượn tài liệu này'
    )
  ),
  'pending'::text,
  'Bob can create a borrow request for a listed document'
);
select extensions.throws_ok(
  $$ update public.documents set is_borrowable = false
     where id = '11111111-1111-4111-8111-111111111111' $$,
  'P0001', null::text, 'Shared editor cannot change owner borrowing settings'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"firebase-bob","iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}', true);
set local role anon;
select extensions.throws_ok(
  $$ select * from public.share_document('11111111-1111-4111-8111-111111111111', 'carol@example.com', 'editor') $$,
  'P0001', null::text, 'Editor cannot share owner document'
);
reset role;

-- Column restrictions also apply when the Firebase JWT has role=authenticated.
set local role authenticated;
select extensions.throws_ok(
  $$ update public.documents set owner_id = 'firebase-bob'
     where id = '11111111-1111-4111-8111-111111111111' $$,
  '42501', null::text, 'Authenticated editor cannot change owner'
);
select extensions.throws_ok(
  $$ update public.documents set storage_path = 'documents/firebase-bob/forged/file.pdf'
     where id = '11111111-1111-4111-8111-111111111111' $$,
  '42501', null::text, 'Authenticated editor cannot change physical file path'
);
reset role;

-- Carol: trước khi được chia sẻ không nhìn thấy gì.
select set_config(
  'request.jwt.claims',
  '{"sub":"firebase-carol","email":"carol@example.com","email_verified":true,"iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}',
  true
);
set local role anon;
select extensions.is(
  (select count(*) from public.documents),
  0::bigint,
  'Carol chưa được chia sẻ nên không thấy tài liệu'
);
select extensions.is(
  (select count(*) from public.device_tokens),
  0::bigint,
  'Other users cannot read Bob push tokens'
);
reset role;

insert into public.permissions (document_id, user_id, access_level, granted_by)
values (
  '11111111-1111-4111-8111-111111111111',
  'firebase-carol',
  'viewer',
  'firebase-alice'
);

-- Carol: sau khi được chia sẻ viewer có thể đọc nhưng không thể sửa.
select set_config(
  'request.jwt.claims',
  '{"sub":"firebase-carol","email":"carol@example.com","email_verified":true,"iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}',
  true
);
set local role anon;
select extensions.is(
  (select count(*) from public.documents),
  1::bigint,
  'Carol viewer thấy đúng tài liệu được chia sẻ'
);
select extensions.is_empty(
  $$
    update public.documents
    set title = 'Carol không được phép sửa'
    where id = '11111111-1111-4111-8111-111111111111'
    returning id
  $$,
  'Carol viewer không thể cập nhật metadata'
);
select extensions.is_empty(
  $$
    delete from public.documents
    where id = '11111111-1111-4111-8111-111111111111'
    returning id
  $$,
  'Carol viewer không thể xóa tài liệu'
);
reset role;

set local role anon;
select extensions.throws_ok(
  $$ select public.revoke_document_permission('11111111-1111-4111-8111-111111111111', 'firebase-bob') $$,
  'P0001', null::text, 'Viewer cannot revoke shares'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"firebase-alice","iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}', true);
  'request.jwt.claims',
  '{"sub":"firebase-alice","email":"alice@example.com","email_verified":true,"iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}',
  true
);
set local role anon;
select extensions.is(
  (
    select status
    from public.respond_document_borrow(
      (
        select id from public.borrow_requests
        where document_id = '11111111-1111-4111-8111-111111111111'
          and requester_id = 'firebase-bob'
      ),
      'approved'
    )
  ),
  'approved'::text,
  'Owner approval grants borrowing request'
);
select extensions.is(
  (
    select access_level
    from public.permissions
    where document_id = '11111111-1111-4111-8111-111111111111'
      and user_id = 'firebase-bob'
  ),
  'editor'::text,
  'Approving a borrow request does not downgrade existing access'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"firebase-alice","iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}', true);
set local role anon;
select extensions.lives_ok(
  $$ select public.revoke_document_permission('11111111-1111-4111-8111-111111111111', 'firebase-carol') $$,
  'Owner can revoke viewer access'
);
reset role;
select set_config('request.jwt.claims', '{"sub":"firebase-carol","iss":"https://securetoken.google.com/device-streaming-33cac12e","aud":"device-streaming-33cac12e"}', true);
set local role anon;
select extensions.is((select count(*) from public.documents), 0::bigint, 'Revoked viewer loses metadata');
reset role;
select set_config('request.jwt.claims', '{}', true);
set local role anon;
select extensions.is((select count(*) from public.documents), 0::bigint, 'Publishable key alone grants no access');
reset role;
select set_config('request.jwt.claims', '{"sub":"firebase-alice","iss":"https://securetoken.google.com/another-project","aud":"another-project"}', true);
set local role anon;
select extensions.is((select count(*) from public.documents), 0::bigint, 'Other Firebase project is rejected');
reset role;

select * from extensions.finish();
rollback;
