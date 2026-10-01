-- Fix guest profile persistence: RETURNS TABLE(user_id, ...) made ON CONFLICT(user_id)
-- ambiguous inside the PL/pgSQL function. Use the primary-key constraint explicitly.

create or replace function public.set_guest_profile(p_profile_name text)
returns table(user_id uuid, profile_name text, is_guest boolean)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_name text := nullif(btrim(p_profile_name), '');
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 32 then
    raise exception 'guest_name_invalid';
  end if;

  if not coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) then
    raise exception 'guest_only';
  end if;

  insert into identity.profiles(user_id, profile_name, created_at, updated_at)
  values(v_uid, v_name, now(), now())
  on conflict on constraint profiles_pkey do update
    set profile_name = excluded.profile_name,
        updated_at = now();

  return query
  select v_uid, v_name, true;
end
$function$;

create or replace function public.sync_profile_name(p_profile_name text)
returns table(user_id uuid, profile_name text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_name text := nullif(btrim(p_profile_name), '');
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 32 then
    raise exception 'profile_name_invalid';
  end if;

  insert into identity.profiles(user_id, profile_name, created_at, updated_at)
  values(v_uid, v_name, now(), now())
  on conflict on constraint profiles_pkey do update
    set profile_name = excluded.profile_name,
        updated_at = now();

  return query
  select v_uid, v_name;
end
$function$;
