-- Democrat: 60 parliamentary seats + non-colliding faction control of empty seats
-- Physical seats: 60
-- Human players per session: still max 30
-- Faction actions may only claim seats that are both empty and unclaimed.

insert into game.session_seats(session_id, seat_number, side)
select s.id, gs.n,
       case when gs.n <= 20 then 'left'
            when gs.n <= 40 then 'center'
            else 'right' end
from game.sessions s
cross join generate_series(31,60) gs(n)
where not exists (
  select 1 from game.session_seats ss
  where ss.session_id=s.id and ss.seat_number=gs.n
);

create table if not exists game.session_faction_action_types (
  action_code text primary key,
  display_name text not null,
  seat_reward integer not null check (seat_reward between 1 and 10),
  cooldown_seconds integer not null check (cooldown_seconds >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table game.session_faction_action_types enable row level security;
revoke all on table game.session_faction_action_types from anon, authenticated;

insert into game.session_faction_action_types(action_code,display_name,seat_reward,cooldown_seconds)
values
  ('fraktionsrede','Fraktionsrede',1,900),
  ('ausschussarbeit','Ausschussarbeit',2,1800),
  ('oeffentlichkeitsarbeit','Öffentlichkeitsarbeit',3,3600)
on conflict (action_code) do update
set display_name=excluded.display_name,
    seat_reward=excluded.seat_reward,
    cooldown_seconds=excluded.cooldown_seconds,
    active=true;

create table if not exists game.session_faction_action_log (
  id bigint generated always as identity primary key,
  session_id uuid not null references game.sessions(id) on delete cascade,
  faction_id uuid not null references game.session_factions(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  action_code text not null references game.session_faction_action_types(action_code),
  seats_claimed integer not null check (seats_claimed > 0),
  created_at timestamptz not null default now()
);

create index if not exists session_faction_action_log_lookup_idx
on game.session_faction_action_log(session_id,faction_id,action_code,created_at desc);

alter table game.session_faction_action_log enable row level security;
revoke all on table game.session_faction_action_log from anon, authenticated;

create or replace function game.initialize_session(
  p_session_id uuid,
  p_topic_locale text default 'de-DE'
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  s game.sessions%rowtype;
  t game.session_types%rowtype;
  tp game.session_topics%rowtype;
  i integer;
begin
  select * into s from game.sessions where id=p_session_id for update;
  if not found then return; end if;
  select * into t from game.session_types where id=s.session_type_id;

  if s.topic_id is null then
    select * into tp from game.topic_for_locale(coalesce(p_topic_locale,t.locale));
    if found then
      update game.sessions
      set topic_id=tp.id, display_name=t.display_name||' - '||tp.title
      where id=p_session_id;
    end if;
  end if;

  for i in 1..60 loop
    insert into game.session_seats(session_id,seat_number,side)
    values(
      p_session_id,i,
      case when i<=20 then 'left' when i<=40 then 'center' else 'right' end
    )
    on conflict (session_id,seat_number) do nothing;
  end loop;
end
$function$;

create or replace function public.get_session_seats(p_session_id uuid)
returns table(
  seat_number integer,
  side text,
  faction_id uuid,
  faction_name text,
  faction_color text,
  user_id uuid,
  profile_name text
)
language sql
stable
security definer
set search_path = ''
as $function$
select
  ss.seat_number,ss.side,f.id,f.name,f.color_code,ss.user_id,
  coalesce(p.profile_name,'Spieler')
from game.session_seats ss
left join game.session_factions f on f.id=ss.faction_id
left join identity.profiles p on p.user_id=ss.user_id
where ss.session_id=p_session_id
  and ss.seat_number between 1 and 60
  and exists(
    select 1 from game.session_members m
    where m.session_id=p_session_id and m.user_id=(select auth.uid())
  )
order by ss.seat_number
$function$;

create or replace function public.perform_faction_action(
  p_session_id uuid,
  p_action_code text
)
returns table(action_code text,seats_claimed integer,faction_id uuid)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_member game.session_members%rowtype;
  v_faction game.session_factions%rowtype;
  v_action game.session_faction_action_types%rowtype;
  v_last timestamptz;
  v_available integer;
  v_sector_start integer;
  v_sector_end integer;
  v_session game.sessions%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_session from game.sessions
  where id=p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;

  select sm.* into v_member from game.session_members sm
  where sm.session_id=p_session_id and sm.user_id=v_uid for update;
  if not found then raise exception 'not_session_member'; end if;
  if v_member.faction_id is null then raise exception 'faction_required'; end if;

  select sf.* into v_faction from game.session_factions sf
  where sf.id=v_member.faction_id and sf.session_id=p_session_id for update;

  select at.* into v_action from game.session_faction_action_types at
  where at.action_code=p_action_code and at.active for update;
  if not found then raise exception 'action_not_available'; end if;

  select max(created_at) into v_last
  from game.session_faction_action_log
  where session_id=p_session_id
    and faction_id=v_faction.id
    and action_code=v_action.action_code;

  if v_last is not null
     and v_last > now()-make_interval(secs=>v_action.cooldown_seconds)
  then raise exception 'action_cooldown'; end if;

  v_sector_start:=case v_faction.side when 'left' then 1 when 'center' then 21 else 41 end;
  v_sector_end:=v_sector_start+19;

  select count(*) into v_available
  from game.session_seats ss
  where ss.session_id=p_session_id
    and ss.seat_number between v_sector_start and v_sector_end
    and ss.user_id is null and ss.faction_id is null;

  if v_available < v_action.seat_reward then
    raise exception 'not_enough_empty_seats';
  end if;

  update game.session_seats ss
  set faction_id=v_faction.id
  where ss.session_id=p_session_id
    and ss.seat_number in (
      select ss2.seat_number
      from game.session_seats ss2
      where ss2.session_id=p_session_id
        and ss2.seat_number between v_sector_start and v_sector_end
        and ss2.user_id is null and ss2.faction_id is null
      order by ss2.seat_number
      limit v_action.seat_reward
    );

  insert into game.session_faction_action_log(
    session_id,faction_id,actor_user_id,action_code,seats_claimed
  )
  values(
    p_session_id,v_faction.id,v_uid,v_action.action_code,v_action.seat_reward
  );

  update game.session_factions sf
  set seat_start=x.min_seat,seat_end=x.max_seat
  from (
    select min(seat_number) min_seat,max(seat_number) max_seat
    from game.session_seats
    where session_id=p_session_id and faction_id=v_faction.id
  ) x
  where sf.id=v_faction.id;

  return query select v_action.action_code,v_action.seat_reward,v_faction.id;
end
$function$;

revoke all on function public.perform_faction_action(uuid,text) from public,anon;
grant execute on function public.perform_faction_action(uuid,text) to authenticated;
