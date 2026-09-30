-- Session runtime presence: a participating player keeps all of their joined sessions active
-- while the game client is online. Presence expires after 45 seconds without a heartbeat.
create table if not exists game.session_presence (
  session_id uuid not null references game.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  primary key (session_id,user_id)
);
create index if not exists session_presence_last_seen_idx on game.session_presence(session_id,last_seen_at);
alter table game.session_presence enable row level security;
revoke all on game.session_presence from anon,authenticated;

create or replace function game.touch_session_presence(p_session_ids uuid[])
returns integer language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_uid uuid:=auth.uid(); v_count integer:=0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  insert into game.session_presence(session_id,user_id,last_seen_at)
  select m.session_id,v_uid,now()
  from game.session_members m
  where m.user_id=v_uid and m.session_id=any(coalesce(p_session_ids,'{}'::uuid[]))
  on conflict(session_id,user_id) do update set last_seen_at=excluded.last_seen_at;
  get diagnostics v_count=row_count;
  return v_count;
end $$;

create or replace function game.clear_session_presence()
returns integer language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_uid uuid:=auth.uid(); v_count integer:=0;
begin
  if v_uid is null then return 0; end if;
  delete from game.session_presence where user_id=v_uid;
  get diagnostics v_count=row_count;
  return v_count;
end $$;

create or replace function game.session_is_active(p_session_id uuid)
returns boolean language sql stable security definer set search_path=game,pg_catalog
as $$ select exists(
  select 1 from game.session_presence p
  where p.session_id=p_session_id and p.last_seen_at>now()-interval '45 seconds'
) $$;

create or replace function public.get_session_runtime(p_session_id uuid)
returns table(session_id uuid,online_players integer,is_active boolean,last_activity_at timestamptz)
language sql security definer stable set search_path=game,pg_catalog
as $$
select p_session_id,count(*)::integer,count(*)>0,max(last_seen_at)
from game.session_presence p
where p.session_id=p_session_id and p.last_seen_at>now()-interval '45 seconds'
and exists(select 1 from game.session_members m where m.session_id=p_session_id and m.user_id=auth.uid())
$$;

create or replace function public.touch_my_session_presence(p_session_ids uuid[])
returns integer language sql security definer set search_path=game,pg_catalog
as $$ select game.touch_session_presence(p_session_ids) $$;

create or replace function public.clear_my_session_presence()
returns integer language sql security definer set search_path=game,pg_catalog
as $$ select game.clear_session_presence() $$;

revoke all on function game.session_is_active(uuid) from public,anon,authenticated;
revoke all on function public.get_session_runtime(uuid) from public,anon;
revoke all on function public.touch_my_session_presence(uuid[]) from public,anon;
revoke all on function public.clear_my_session_presence() from public,anon;
grant execute on function public.get_session_runtime(uuid) to authenticated;
grant execute on function public.touch_my_session_presence(uuid[]) to authenticated;
grant execute on function public.clear_my_session_presence() to authenticated;

drop function if exists public.get_my_sessions();
create function public.get_my_sessions()
returns table(id uuid,display_name text,player_count integer,max_players integer,created_at timestamptz,country_code text,locale text,session_code text,topic_title text,topic_intro text,read_confirmed boolean,faction_name text,faction_side text,seat_number integer,online_players integer,is_active boolean)
language sql stable security definer set search_path=game,identity,pg_catalog
as $$
select s.id,s.display_name,s.player_count,s.max_players,s.created_at,st.country_code,st.locale,st.code,t.title,t.intro_text,
(sm.read_confirmed_at is not null),f.name,f.side,sm.seat_number,
coalesce(r.online_players,0),coalesce(r.is_active,false)
from game.sessions s
join game.session_types st on st.id=s.session_type_id
join identity.profiles p on p.user_id=auth.uid() and st.country_code=p.country_code
join game.session_members sm on sm.session_id=s.id and sm.user_id=auth.uid()
left join game.session_topics t on t.id=s.topic_id
left join game.session_factions f on f.id=sm.faction_id
left join lateral (
  select count(*)::integer online_players,count(*)>0 is_active
  from game.session_presence sp
  where sp.session_id=s.id and sp.last_seen_at>now()-interval '45 seconds'
) r on true
order by s.created_at desc
$$;
revoke all on function public.get_my_sessions() from public,anon;
grant execute on function public.get_my_sessions() to authenticated;
