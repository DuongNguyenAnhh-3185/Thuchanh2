begin;

create table public.device_tokens (
  token text primary key check (char_length(token) between 1 and 4096),
  user_id text not null references public.users(id) on delete cascade,
  platform text not null
    check (platform in ('web', 'android', 'ios', 'macos', 'windows', 'linux')),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy device_tokens_firebase_project_guard
on public.device_tokens as restrictive to anon, authenticated
using ((select public.is_cashew_firebase_jwt()))
with check ((select public.is_cashew_firebase_jwt()));

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

create table public.notification_dispatches (
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

commit;
