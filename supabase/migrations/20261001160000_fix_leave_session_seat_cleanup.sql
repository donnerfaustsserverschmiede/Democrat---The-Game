-- Fix leave_session so membership deletion and physical seat release are
-- handled explicitly and the freed seat is safely refilled by a bot.
create or replace function game.leave_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_member game.session_members%rowtype;
  v_session_id uuid;
  v_seat integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_session_id is null then raise exception 'session_id_required'; end if;

  select sm.* into v_member
  from game.session_members sm
  where sm.session_id=p_session_id and sm.user_id=v_uid
  for update;

  if not found then raise exception 'not_session_member'; end if;

  v_session_id:=v_member.session_id;
  v_seat:=v_member.seat_number;

  delete from game.session_members sm
  where sm.session_id=v_session_id and sm.user_id=v_uid;

  if v_seat is not null then
    update game.session_seats ss
    set user_id=null,faction_id=null
    where ss.session_id=v_session_id
      and ss.seat_number=v_seat
      and ss.user_id=v_uid;

    delete from game.session_bots sb
    where sb.session_id=v_session_id and sb.seat_number=v_seat;
  end if;

  perform game.fill_session_bots(v_session_id);
end;
$function$;