-- Fix ambiguous seat_number references in faction seat assignment.
-- The return column seat_number shadows the table column inside PL/pgSQL.
create or replace function public.choose_session_faction(p_session_id uuid, p_faction_id uuid default null, p_faction_name text default null, p_side text default null)
returns table(faction_id uuid, faction_name text, faction_side text, seat_number integer, color_code text)
language plpgsql security definer set search_path=game,pg_catalog
as $function$
declare
 v_uid uuid:=auth.uid(); v_member game.session_members%rowtype; v_faction game.session_factions%rowtype;
 v_old_seat integer; v_new_seat integer; v_name text; v_color text; v_sector_start integer; v_sector_end integer; v_candidate integer; v_min integer; v_max integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select * into v_member from game.session_members where session_id=p_session_id and user_id=v_uid for update;
 if not found then raise exception 'not_session_member'; end if;
 if v_member.read_confirmed_at is null then raise exception 'session_read_required'; end if;
 v_old_seat:=v_member.seat_number;
 if p_faction_id is not null then
   select * into v_faction from game.session_factions where id=p_faction_id and session_id=p_session_id for update;
   if not found then raise exception 'faction_not_found'; end if;
 else
   v_name:=nullif(btrim(p_faction_name),'');
   if v_name is null then raise exception 'faction_name_required'; end if;
   if char_length(v_name)<2 or char_length(v_name)>40 then raise exception 'faction_name_invalid'; end if;
   if p_side not in('left','center','right') then raise exception 'faction_side_required'; end if;
   if exists(select 1 from game.session_factions where session_id=p_session_id and lower(name)=lower(v_name)) then raise exception 'faction_name_taken'; end if;
   if (select count(*) from game.session_factions where session_id=p_session_id)>=6 then raise exception 'faction_limit_reached'; end if;
   v_sector_start:=case p_side when 'left' then 1 when 'center' then 11 else 21 end; v_sector_end:=v_sector_start+9;
   select s.seat_number into v_candidate from game.session_seats s where s.session_id=p_session_id and s.seat_number between v_sector_start and v_sector_end and s.user_id is null order by s.seat_number limit 1;
   if v_candidate is null then raise exception 'sector_full'; end if;
   v_color:=game.next_faction_color(p_session_id);
   insert into game.session_factions(session_id,name,side,seat_start,seat_end,color_code,leader_user_id) values(p_session_id,v_name,p_side,v_candidate,v_candidate,v_color,v_uid) returning * into v_faction;
 end if;
 if v_member.faction_id=v_faction.id and v_old_seat is not null then return query select v_faction.id,v_faction.name,v_faction.side,v_old_seat,v_faction.color_code; return; end if;
 if v_old_seat is not null then update game.session_seats set user_id=null,faction_id=null where session_id=p_session_id and seat_number=v_old_seat; end if;
 select min(s.seat_number),max(s.seat_number) into v_min,v_max from game.session_seats s where s.session_id=p_session_id and s.faction_id=v_faction.id;
 if v_min is null then v_new_seat:=v_faction.seat_start;
 else
   select s.seat_number into v_new_seat from game.session_seats s where s.session_id=p_session_id and s.user_id is null and s.seat_number between v_faction.seat_start and v_faction.seat_end and (s.seat_number=v_min-1 or s.seat_number=v_max+1) order by s.seat_number limit 1;
   if v_new_seat is null then select s.seat_number into v_new_seat from game.session_seats s where s.session_id=p_session_id and s.user_id is null and s.seat_number between v_faction.seat_start and v_faction.seat_end order by s.seat_number limit 1; end if;
 end if;
 if v_new_seat is null then raise exception 'faction_full'; end if;
 if (select count(*) from game.session_members where session_id=p_session_id and faction_id=v_faction.id)>=10 and v_member.faction_id is distinct from v_faction.id then raise exception 'faction_full'; end if;
 update game.session_seats set user_id=v_uid,faction_id=v_faction.id,side=v_faction.side where session_id=p_session_id and seat_number=v_new_seat;
 update game.session_members set faction_id=v_faction.id,seat_number=v_new_seat where session_id=p_session_id and user_id=v_uid;
 update game.session_factions f set seat_start=x.min_seat,seat_end=x.max_seat from (select ss.faction_id,min(ss.seat_number) min_seat,max(ss.seat_number) max_seat from game.session_seats ss where ss.session_id=p_session_id and ss.faction_id=v_faction.id group by ss.faction_id)x where f.id=v_faction.id;
 select * into v_faction from game.session_factions where id=v_faction.id;
 return query select v_faction.id,v_faction.name,v_faction.side,v_new_seat,v_faction.color_code;
end $function$;