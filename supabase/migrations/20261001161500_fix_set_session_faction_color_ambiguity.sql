-- Fix color_code ambiguity in the faction color RPC.
-- The function returns a color_code column, so every table column must be qualified.
create or replace function public.set_session_faction_color(
  p_session_id uuid,
  p_color_code text
)
returns table(faction_id uuid,color_code text)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_member game.session_members%rowtype;
  v_faction game.session_factions%rowtype;
  v_color text := lower(trim(p_color_code));
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if v_color not in ('red','blue','green','yellow','purple','orange') then
    raise exception 'invalid_faction_color';
  end if;

  select sm.* into v_member
  from game.session_members sm
  where sm.session_id=p_session_id and sm.user_id=v_uid
  for update;

  if not found then raise exception 'not_session_member'; end if;
  if v_member.faction_id is null then raise exception 'faction_required'; end if;

  select sf.* into v_faction
  from game.session_factions sf
  where sf.id=v_member.faction_id and sf.session_id=p_session_id
  for update;

  if not found then raise exception 'faction_not_found'; end if;

  if v_faction.leader_user_id <> v_uid
     and coalesce(v_faction.deputy_user_id,'00000000-0000-0000-0000-000000000000'::uuid) <> v_uid then
    raise exception 'faction_color_permission_denied';
  end if;

  if exists(
    select 1
    from game.session_factions sf2
    where sf2.session_id=p_session_id
      and sf2.color_code=v_color
      and sf2.id<>v_faction.id
  ) then
    raise exception 'faction_color_taken';
  end if;

  if v_faction.color_code is distinct from v_color then
    update game.session_factions sf3
    set color_code=v_color
    where sf3.id=v_faction.id
      and sf3.session_id=p_session_id;
  end if;

  return query select v_faction.id,v_color;
end;
$function$;