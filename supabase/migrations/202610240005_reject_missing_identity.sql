begin;
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
