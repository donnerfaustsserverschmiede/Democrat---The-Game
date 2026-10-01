-- Fix the current choose_session_faction implementation after later migrations reintroduced
-- unqualified seat_number references that collide with the RETURNS TABLE output name.
-- All seat_number references are explicitly qualified.
create or replace function public.choose_session_faction(
  p_session_id uuid,
  p_faction_id uuid default null,
  p_faction_name text default null,
  p_side text default null,
  p_color_code text default null
)
returns table(faction_id uuid,faction_name text,faction_side text,seat_number integer,color_code text)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_member game.session_members%rowtype;
  v_faction game.session_factions%rowtype;
  v_old_seat integer;
  v_new_seat integer;
  v_name text;
  v_color text;
  v_sector_start integer;
  v_sector_end integer;
  v_candidate integer;
  v_member_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select sm.* into v_member from game.session_members sm where sm.session_id=p_session_id and sm.user_id=v_uid for update;
  if not found then raise exception 'not_session_member'; end if;
  if v_member.read_confirmed_at is null then raise exception 'session_read_required'; end if;
  if v_member.eliminated_at is not null then raise exception 'player_eliminated'; end if;
  if exists(select 1 from game.sessions s where s.id=p_session_id and s.status='ended') then raise exception 'session_ended'; end if;

  v_old_seat:=v_member.seat_number;

  if p_faction_id is not null then
    select sf.* into v_faction from game.session_factions sf where sf.id=p_faction_id and sf.session_id=p_session_id for update;
    if not found then raise exception 'faction_not_found'; end if;
    if exists(select 1 from game.session_faction_stats fs where fs.session_id=p_session_id and fs.faction_id=v_faction.id and fs.eliminated_at is not null) then raise exception 'faction_eliminated'; end if;
  else
    v_name:=nullif(btrim(p_faction_name),'');
    if v_name is null or char_length(v_name)<2 or char_length(v_name)>40 then raise exception 'faction_name_invalid'; end if;
    if p_side not in('left','center','right') then raise exception 'faction_side_required'; end if;
    if exists(select 1 from game.session_factions sf2 where sf2.session_id=p_session_id and lower(sf2.name)=lower(v_name)) then raise exception 'faction_name_taken'; end if;
    if (select count(*) from game.session_factions sf3 where sf3.session_id=p_session_id)>=6 then raise exception 'faction_limit_reached'; end if;

    v_color:=lower(trim(coalesce(p_color_code,'')));
    if v_color='' then
      select c.color into v_color
      from (values ('red'),('blue'),('green'),('yellow'),('purple'),('orange')) c(color)
      where not exists(select 1 from game.session_factions sf4 where sf4.session_id=p_session_id and sf4.color_code=c.color)
      order by c.color limit 1;
      if v_color is null then raise exception 'faction_limit_reached'; end if;
    elsif v_color not in ('red','blue','green','yellow','purple','orange') then
      raise exception 'invalid_faction_color';
    elsif exists(select 1 from game.session_factions sf5 where sf5.session_id=p_session_id and sf5.color_code=v_color) then
      raise exception 'faction_color_taken';
    end if;
  end if;

  if v_old_seat is not null then
    update game.session_seats ss set user_id=null,faction_id=null
    where ss.session_id=p_session_id and ss.seat_number=v_old_seat and ss.user_id=v_uid;
    delete from game.session_bots sb
    where sb.session_id=p_session_id and sb.seat_number=v_old_seat;
  end if;

  if p_faction_id is null then
    v_sector_start:=case p_side when 'left' then 1 when 'center' then 21 else 41 end;
    v_sector_end:=v_sector_start+19;
    select ss.seat_number into v_candidate
    from game.session_seats ss
    where ss.session_id=p_session_id
      and ss.seat_number between v_sector_start and v_sector_end
      and ss.user_id is null and ss.faction_id is null
    order by ss.seat_number limit 1 for update;
    if v_candidate is null then raise exception 'sector_full'; end if;

    insert into game.session_factions(session_id,name,side,seat_start,seat_end,color_code,leader_user_id)
    values(p_session_id,v_name,p_side,v_candidate,v_candidate,v_color,v_uid)
    returning * into v_faction;
    perform game.ensure_session_faction_stat(p_session_id,v_faction.id);
  end if;

  select count(*) into v_member_count
  from game.session_members sm2
  where sm2.session_id=p_session_id and sm2.faction_id=v_faction.id
    and sm2.user_id<>v_uid and sm2.eliminated_at is null;
  if v_member_count>=10 then raise exception 'faction_full'; end if;

  select ss.seat_number into v_new_seat
  from game.session_seats ss
  where ss.session_id=p_session_id and ss.faction_id=v_faction.id
    and ss.user_id is null and ss.side=v_faction.side
  order by ss.seat_number limit 1 for update;

  if v_new_seat is null then
    v_sector_start:=case v_faction.side when 'left' then 1 when 'center' then 21 else 41 end;
    v_sector_end:=v_sector_start+19;
    select ss.seat_number into v_new_seat
    from game.session_seats ss
    where ss.session_id=p_session_id and ss.user_id is null and ss.faction_id is null
      and ss.seat_number between v_sector_start and v_sector_end
    order by ss.seat_number limit 1 for update;
  end if;
  if v_new_seat is null then raise exception 'sector_full'; end if;

  delete from game.session_bots sb
  where sb.session_id=p_session_id and sb.seat_number=v_new_seat;

  update game.session_seats ss
  set user_id=v_uid,faction_id=v_faction.id,side=v_faction.side
  where ss.session_id=p_session_id and ss.seat_number=v_new_seat;

  update game.session_members sm3
  set faction_id=v_faction.id,seat_number=v_new_seat
  where sm3.session_id=p_session_id and sm3.user_id=v_uid;

  update game.session_factions sf6
  set seat_start=x.min_seat,seat_end=x.max_seat
  from (
    select min(ss2.seat_number) min_seat,max(ss2.seat_number) max_seat
    from game.session_seats ss2
    where ss2.session_id=p_session_id and ss2.faction_id=v_faction.id
    group by ss2.faction_id
  ) x
  where sf6.id=v_faction.id;

  perform game.fill_session_bots(p_session_id);
  select sf7.* into v_faction from game.session_factions sf7 where sf7.id=v_faction.id;
  return query select v_faction.id,v_faction.name,v_faction.side,v_new_seat,v_faction.color_code;
end;
$function$;