-- Session participation and temporary faction management.
-- Parties remain a separate, persistent alliance system.

alter table game.session_factions
  add column if not exists leader_user_id uuid references auth.users(id) on delete set null,
  add column if not exists deputy_user_id uuid references auth.users(id) on delete set null;

create or replace function game.join_session(p_session_id uuid)
returns game.sessions
language plpgsql security definer
set search_path=game,identity,pg_catalog
as $$
declare v_session game.sessions%rowtype; v_uid uuid:=auth.uid(); v_country text; v_session_country text; v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select country_code into v_country from identity.profiles where user_id=v_uid;
  if v_country is null then raise exception 'country_selection_required'; end if;
  select s.* into v_session from game.sessions s where s.id=p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select country_code into v_session_country from game.session_types where id=v_session.session_type_id;
  if v_session_country<>v_country then raise exception 'wrong_country_session'; end if;
  if exists(select 1 from game.session_members where session_id=p_session_id and user_id=v_uid) then return v_session; end if;
  select count(*) into v_count from game.session_members where user_id=v_uid;
  if v_count>=5 then raise exception 'session_limit_reached'; end if;
  if v_session.player_count>=v_session.max_players then raise exception 'session_full'; end if;
  insert into game.session_members(session_id,user_id) values(p_session_id,v_uid);
  select * into v_session from game.sessions where id=p_session_id;
  return v_session;
end $$;

create or replace function game.handle_session_member_departure()
returns trigger language plpgsql security definer set search_path=game,identity,pg_catalog
as $$
declare v_f game.session_factions%rowtype; v_next uuid;
begin
  if old.faction_id is null then return old; end if;
  select * into v_f from game.session_factions where id=old.faction_id for update;
  if not found then return old; end if;
  if v_f.leader_user_id=old.user_id then
    if v_f.deputy_user_id is not null and exists(select 1 from game.session_members where session_id=old.session_id and faction_id=old.faction_id and user_id=v_f.deputy_user_id) then
      update game.session_factions set leader_user_id=v_f.deputy_user_id,deputy_user_id=null where id=old.faction_id;
    else
      select user_id into v_next from game.session_members where session_id=old.session_id and faction_id=old.faction_id order by joined_at,user_id limit 1;
      if v_next is null then delete from game.session_factions where id=old.faction_id;
      else update game.session_factions set leader_user_id=v_next,deputy_user_id=null where id=old.faction_id; end if;
    end if;
  elsif v_f.deputy_user_id=old.user_id then
    update game.session_factions set deputy_user_id=null where id=old.faction_id;
  elsif not exists(select 1 from game.session_members where session_id=old.session_id and faction_id=old.faction_id) then
    delete from game.session_factions where id=old.faction_id;
  end if;
  return old;
end $$;

drop trigger if exists trg_session_member_departure on game.session_members;
create trigger trg_session_member_departure after delete on game.session_members
for each row execute function game.handle_session_member_departure();

create or replace function public.get_session_faction_management(p_session_id uuid)
returns table(faction_id uuid,faction_name text,faction_side text,color_code text,leader_user_id uuid,deputy_user_id uuid,user_id uuid,profile_name text,member_role text,seat_number integer)
language sql security definer stable set search_path=game,identity,pg_catalog
as $$
select f.id,f.name,f.side,f.color_code,f.leader_user_id,f.deputy_user_id,m.user_id,coalesce(p.profile_name,'Spieler'),
case when m.user_id=f.leader_user_id then 'leader' when m.user_id=f.deputy_user_id then 'deputy' else 'member' end,m.seat_number
from game.session_factions f join game.session_members m on m.session_id=f.session_id and m.faction_id=f.id
left join identity.profiles p on p.user_id=m.user_id
where f.session_id=p_session_id and exists(select 1 from game.session_members me where me.session_id=p_session_id and me.user_id=auth.uid())
order by f.name,m.joined_at,m.user_id
$$;

create or replace function public.delete_session_faction(p_faction_id uuid)
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_uid uuid:=auth.uid(); v_session uuid;
begin
 select session_id into v_session from game.session_factions where id=p_faction_id for update;
 if v_session is null then raise exception 'faction_not_found'; end if;
 if not exists(select 1 from game.session_factions where id=p_faction_id and (leader_user_id=v_uid or deputy_user_id=v_uid)) then raise exception 'faction_manager_required'; end if;
 update game.session_seats set faction_id=null,user_id=null where session_id=v_session and faction_id=p_faction_id;
 update game.session_members set faction_id=null,seat_number=null where session_id=v_session and faction_id=p_faction_id;
 delete from game.session_factions where id=p_faction_id;
end $$;

create or replace function public.kick_session_faction_member(p_faction_id uuid,p_member_id uuid)
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_uid uuid:=auth.uid(); v_session uuid; v_old_seat integer;
begin
 select session_id into v_session from game.session_factions where id=p_faction_id for update;
 if v_session is null then raise exception 'faction_not_found'; end if;
 if not exists(select 1 from game.session_factions where id=p_faction_id and (leader_user_id=v_uid or deputy_user_id=v_uid)) then raise exception 'faction_manager_required'; end if;
 if p_member_id=v_uid then raise exception 'cannot_kick_self'; end if;
 select seat_number into v_old_seat from game.session_members where session_id=v_session and user_id=p_member_id and faction_id=p_faction_id;
 if v_old_seat is null then raise exception 'member_not_found'; end if;
 update game.session_seats set faction_id=null,user_id=null where session_id=v_session and seat_number=v_old_seat;
 delete from game.session_members where session_id=v_session and user_id=p_member_id;
end $$;

create or replace function public.set_session_faction_deputy(p_faction_id uuid,p_member_id uuid)
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_uid uuid:=auth.uid(); v_session uuid;
begin
 select session_id into v_session from game.session_factions where id=p_faction_id for update;
 if v_session is null then raise exception 'faction_not_found'; end if;
 if not exists(select 1 from game.session_factions where id=p_faction_id and leader_user_id=v_uid) then raise exception 'leader_required'; end if;
 if not exists(select 1 from game.session_members where session_id=v_session and user_id=p_member_id and faction_id=p_faction_id) then raise exception 'member_not_found'; end if;
 if p_member_id=v_uid then raise exception 'cannot_promote_self'; end if;
 update game.session_factions set deputy_user_id=p_member_id where id=p_faction_id;
end $$;

create or replace function public.remove_session_faction_deputy(p_faction_id uuid)
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
begin
 if not exists(select 1 from game.session_factions where id=p_faction_id and leader_user_id=auth.uid()) then raise exception 'leader_required'; end if;
 update game.session_factions set deputy_user_id=null where id=p_faction_id;
end $$;

revoke all on function public.get_session_faction_management(uuid) from public,anon;
revoke all on function public.delete_session_faction(uuid) from public,anon;
revoke all on function public.kick_session_faction_member(uuid,uuid) from public,anon;
revoke all on function public.set_session_faction_deputy(uuid,uuid) from public,anon;
revoke all on function public.remove_session_faction_deputy(uuid) from public,anon;
grant execute on function public.get_session_faction_management(uuid) to authenticated;
grant execute on function public.delete_session_faction(uuid) to authenticated;
grant execute on function public.kick_session_faction_member(uuid,uuid) to authenticated;
grant execute on function public.set_session_faction_deputy(uuid,uuid) to authenticated;
grant execute on function public.remove_session_faction_deputy(uuid) to authenticated;

create or replace function game.assign_new_faction_leader()
returns trigger language plpgsql security definer set search_path=game,pg_catalog
as $$
begin
  if new.leader_user_id is null then new.leader_user_id:=auth.uid(); end if;
  return new;
end $$;

drop trigger if exists trg_assign_new_faction_leader on game.session_factions;
create trigger trg_assign_new_faction_leader before insert on game.session_factions
for each row execute function game.assign_new_faction_leader();
