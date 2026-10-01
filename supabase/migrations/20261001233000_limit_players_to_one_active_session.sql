-- Limit each player to one active session at a time.
-- Existing memberships remain untouched; new joins are restricted.
create or replace function game.join_session(p_session_id uuid)
returns game.sessions
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_session game.sessions%rowtype;
  v_uid uuid := (select auth.uid());
  v_country text;
  v_session_country text;
  v_bot game.session_bots%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select country_code into v_country from identity.profiles where user_id=v_uid;
  if v_country is null then raise exception 'country_selection_required'; end if;

  select s.* into v_session from game.sessions s where s.id=p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;

  select country_code into v_session_country from game.session_types where id=v_session.session_type_id;
  if v_session_country<>v_country then raise exception 'wrong_country_session'; end if;

  if exists(select 1 from game.session_members where session_id=p_session_id and user_id=v_uid) then
    return v_session;
  end if;

  if exists(
    select 1 from game.session_members sm
    join game.sessions sx on sx.id=sm.session_id
    where sm.user_id=v_uid and sx.status='active'
  ) then
    raise exception 'session_single_session_limit';
  end if;

  if v_session.player_count>=v_session.max_players then raise exception 'session_full'; end if;

  select * into v_bot from game.session_bots
  where session_id=p_session_id order by seat_number limit 1 for update;

  if not found then
    perform game.fill_session_bots(p_session_id);
    select * into v_bot from game.session_bots
    where session_id=p_session_id order by seat_number limit 1 for update;
  end if;

  if not found then raise exception 'no_available_seat'; end if;

  delete from game.session_bots where id=v_bot.id;
  update game.session_seats set user_id=v_uid,faction_id=null
  where session_id=p_session_id and seat_number=v_bot.seat_number;

  insert into game.session_members(session_id,user_id,seat_number)
  values(p_session_id,v_uid,v_bot.seat_number);

  select * into v_session from game.sessions where id=p_session_id;
  perform game.fill_session_bots(p_session_id);
  return v_session;
end
$function$;