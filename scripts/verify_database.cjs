const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const localRequire = createRequire(path.resolve('build/sql-verification/package.json'));
const { PGlite } = localRequire('@electric-sql/pglite');
const { citext } = localRequire('@electric-sql/pglite/contrib/citext');
const { pgcrypto } = localRequire('@electric-sql/pglite/contrib/pgcrypto');

(async () => {
  const db = new PGlite({ extensions: { citext, pgcrypto } });
  const bootstrap = `
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema storage; create schema extensions;
    create function auth.jwt() returns jsonb language sql stable as
      $$select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb$$;
    grant usage on schema auth, storage, extensions, public to anon, authenticated;
    grant execute on function auth.jwt() to anon, authenticated;
    create table storage.buckets(id text primary key, name text, public boolean default false, file_size_limit bigint);
    create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
    alter table storage.objects enable row level security;
    grant select, insert, update, delete on storage.objects to anon, authenticated;
  `;
  await db.exec(bootstrap);
  const sql = fs.readFileSync('supabase_setup.sql', 'utf8');
  await db.exec(sql);
  console.log('PASS: complete setup executes');
  await db.exec(sql);
  console.log('PASS: setup can be reapplied without dropping tables');
  await db.exec(`
    insert into public.users(id,email,display_name) values
      ('alice','alice@example.com','Alice'), ('bob','bob@example.com','Bob'), ('carol','carol@example.com','Carol');
    insert into public.documents(id,owner_id,title,file_name,storage_path,file_size_bytes,tags,physical_location,latitude,longitude,is_borrowable)
    values ('11111111-1111-4111-8111-111111111111','alice','Flutter guide','guide.pdf',
      'documents/alice/11111111-1111-4111-8111-111111111111/guide.pdf',1024,array['Flutter','SQL'],'Library A',10.8,106.6,true);
    insert into storage.objects(bucket_id,name) values('documents','alice/11111111-1111-4111-8111-111111111111/guide.pdf');
  `);
  let checks=2;
  async function value(sql) { return Object.values((await db.query(sql)).rows[0])[0]; }
  async function equal(sql, expected, label) { assert.equal(await value(sql),expected,label); checks++;console.log('PASS: '+label); }
  async function user(uid, valid=true) {
    await db.exec('reset role');
    const claims = JSON.stringify({sub:uid,email:uid+'@example.com',email_verified:true,
      iss:'https://securetoken.google.com/'+(valid?'device-streaming-33cac12e':'other-project'),aud:valid?'device-streaming-33cac12e':'other-project'});
    await db.query("select set_config('request.jwt.claims', $1, false)",[claims]);
    await db.exec('set role anon');
  }
  await user('carol');
  await equal('select count(*)::int from public.documents',0,'unshared document hidden');
  await equal('select count(*)::int from storage.objects',0,'unshared file hidden');
  await equal('select count(*)::int from public.document_tags',0,'unshared tags hidden');
  await equal('select count(*)::int from public.document_locations',0,'unshared location hidden');
  await equal("select count(*)::int from public.search_borrowable_documents('Flutter')",1,'borrow catalog exposes allowed metadata');
  await db.exec("update public.users set interests=array['flutter'] where id='carol'");
  await equal("select score::int from public.recommend_borrowable_documents('')",3,'recommendations use personal interests');
  await user('bob');
  await db.exec("select public.register_device_token('test-browser-token','web')");
  await equal('select count(*)::int from public.device_tokens',1,'FCM token registration via RPC');
  await db.exec("select public.request_document_borrow('11111111-1111-4111-8111-111111111111','Please share')");
  await db.exec("select public.request_document_borrow('11111111-1111-4111-8111-111111111111','Please share')");
  await equal('select count(*)::int from public.borrow_requests',1,'pending borrow request is idempotent');
  await equal('select count(*)::int from public.documents',0,'pending request grants no document access');
  const requestId=await value('select id from public.borrow_requests limit 1');
  await user('alice');
  await equal('select count(*)::int from public.document_tags',2,'relational tags projected atomically');
  await equal('select count(*)::int from public.document_locations',1,'location projected atomically');
  await db.query("select public.respond_document_borrow($1,'approved')",[requestId]);
  await user('bob');
  await equal('select count(*)::int from public.documents',1,'approval grants document read');
  await equal('select count(*)::int from storage.objects',1,'approval grants private file read');
  await equal('select status from public.borrow_requests limit 1','approved','borrow status persisted');
  await db.exec("select public.record_document_activity('11111111-1111-4111-8111-111111111111','download')");
  await equal('select count(*)::int from public.user_activities',1,'download activity recorded');
  await user('carol');
  await equal('select count(*)::int from public.user_activities',0,'activity history is private');
  await db.exec("select public.register_device_token('test-browser-token','web')");
  await user('bob');
  await equal('select count(*)::int from public.device_tokens',0,'browser token transfers to current account');
  await user('alice');
  await db.exec("select public.revoke_document_permission('11111111-1111-4111-8111-111111111111','bob')");
  await user('bob');
  await equal('select count(*)::int from public.documents',0,'revocation removes metadata access');
  await equal('select count(*)::int from storage.objects',0,'revocation removes file access');
  await user('alice',false);
  await equal('select count(*)::int from public.documents',0,'other Firebase project rejected');
  await db.exec("reset role; select set_config('request.jwt.claims','{}',false); set role anon");
  await equal('select public.is_cashew_firebase_jwt()',false,'missing Firebase JWT returns false');
  await assert.rejects(db.query("select public.respond_document_borrow($1,'rejected')",[requestId]));
  checks++; console.log('PASS: anonymous borrow response rejected');
  await db.close();
  const legacy = new PGlite({extensions:{citext,pgcrypto}});
  await legacy.exec(bootstrap);
  // Simulate the report schema before location/borrow migrations were applied.
  await legacy.exec(fs.readFileSync('supabase/migrations/202610130001_cloud_documents.sql','utf8'));
  await legacy.exec(`
    create table public.borrow_requests (
      id uuid primary key default gen_random_uuid(),
      document_id uuid not null references public.documents(id),
      requester_id text not null references public.users(id),
      owner_id text not null references public.users(id),
      request_type text not null default 'borrow', status text not null default 'pending',
      request_date timestamptz not null default now(), due_date timestamptz,
      return_date timestamptz, notes text, created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    );
    create table public.tags(id uuid primary key default gen_random_uuid(), name varchar not null,
      slug varchar not null unique, color_code varchar, icon_name varchar);
    create table public.document_tags(document_id uuid references public.documents(id),
      tag_id uuid references public.tags(id), created_at timestamptz not null default now(),
      primary key(document_id,tag_id));
  `);
  await legacy.exec(sql);
  checks++; console.log('PASS: setup upgrades the earlier report schema');
  await legacy.close();
  console.log('Database verification: '+checks+' checks passed (local PostgreSQL WASM; cloud not modified).');
})().catch(error => { console.error(error.message); console.error('position: '+error.position); if(error.query && error.position) console.error(error.query.slice(Math.max(0,Number(error.position)-180),Number(error.position)+180)); process.exit(1); });
