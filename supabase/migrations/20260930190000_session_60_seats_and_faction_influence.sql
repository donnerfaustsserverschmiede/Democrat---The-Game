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

  select max(l.created_at) into v_last
  from game.session_faction_action_log l
  where l.session_id=p_session_id
    and l.faction_id=v_faction.id
    and l.action_code=v_action.action_code;

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


CREATE OR REPLACE FUNCTION public.choose_session_faction(p_session_id uuid, p_faction_id uuid DEFAULT NULL::uuid, p_faction_name text DEFAULT NULL::text, p_side text DEFAULT NULL::text)\\
 RETURNS TABLE(faction_id uuid, faction_name text, faction_side text, seat_number integer, color_code text)\\
 LANGUAGE plpgsql\\
 SECURITY DEFINER\\
 SET search_path TO ''\\
AS $function$\\
declare\\
  v_uid uuid := (select auth.uid());\\
  v_member game.session_members%rowtype;\\
  v_faction game.session_factions%rowtype;\\
  v_old_seat integer;\\
  v_new_seat integer;\\
  v_name text;\\
  v_color text;\\
  v_sector_start integer;\\
  v_sector_end integer;\\
  v_candidate integer;\\
  v_min integer;\\
  v_max integer;\\
  v_member_count integer;\\
begin\\
  if v_uid is null then raise exception 'not_authenticated'; end if;\\
\\
  select sm.* into v_member\\
  from game.session_members sm\\
  where sm.session_id=p_session_id and sm.user_id=v_uid\\
  for update;\\
\\
  if not found then raise exception 'not_session_member'; end if;\\
  if v_member.read_confirmed_at is null then raise exception 'session_read_required'; end if;\\
\\
  v_old_seat:=v_member.seat_number;\\
\\
  if p_faction_id is not null then\\
    select sf.* into v_faction\\
    from game.session_factions sf\\
    where sf.id=p_faction_id and sf.session_id=p_session_id\\
    for update;\\
    if not found then raise exception 'faction_not_found'; end if;\\
  else\\
    v_name:=nullif(btrim(p_faction_name),'');\\
    if v_name is null then raise exception 'faction_name_required'; end if;\\
    if char_length(v_name)<2 or char_length(v_name)>40 then raise exception 'faction_name_invalid'; end if;\\
    if p_side not in('left','center','right') then raise exception 'faction_side_required'; end if;\\
\\
    if exists(\\
      select 1 from game.session_factions sf2\\
      where sf2.session_id=p_session_id and lower(sf2.name)=lower(v_name)\\
    ) then raise exception 'faction_name_taken'; end if;\\
\\
    if (select count(*) from game.session_factions sf3 where sf3.session_id=p_session_id)>=6\\
    then raise exception 'faction_limit_reached'; end if;\\
\\
    v_sector_start:=case p_side when 'left' then 1 when 'center' then 21 else 41 end;\\
    v_sector_end:=v_sector_start+19;\\
\\
    select ss.seat_number into v_candidate\\
    from game.session_seats ss\\
    where ss.session_id=p_session_id\\
      and ss.seat_number between v_sector_start and v_sector_end\\
      and ss.user_id is null\\
      and ss.faction_id is null\\
    order by ss.seat_number\\
    limit 1\\
    for update;\\
\\
    if v_candidate is null then raise exception 'sector_full'; end if;\\
\\
    v_color:=game.next_faction_color(p_session_id);\\
\\
    insert into game.session_factions(\\
      session_id,name,side,seat_start,seat_end,color_code,leader_user_id\\
    )\\
    values(p_session_id,v_name,p_side,v_candidate,v_candidate,v_color,v_uid)\\
    returning * into v_faction;\\
  end if;\\
\\
  if v_member.faction_id=v_faction.id and v_old_seat is not null then\\
    return query select v_faction.id,v_faction.name,v_faction.side,v_old_seat,v_faction.color_code;\\
    return;\\
  end if;\\
\\
  if v_member.faction_id is not null then\\
    select count(*) into v_member_count\\
    from game.session_members\\
    where session_id=p_session_id and faction_id=v_faction.id and user_id<>v_uid;\\
  else\\
    select count(*) into v_member_count\\
    from game.session_members\\
    where session_id=p_session_id and faction_id=v_faction.id;\\
  end if;\\
\\
  if v_member_count>=10 then raise exception 'faction_full'; end if;\\
\\
  if v_old_seat is not null then\\
    update game.session_seats\\
    set user_id=null\\
    where session_id=p_session_id\\
      and seat_number=v_old_seat\\
      and user_id=v_uid;\\
  end if;\\
\\
  -- First use an empty seat already controlled by the faction.\\
  select ss.seat_number into v_new_seat\\
  from game.session_seats ss\\
  where ss.session_id=p_session_id\\
    and ss.faction_id=v_faction.id\\
    and ss.user_id is null\\
    and ss.side=v_faction.side\\
  order by ss.seat_number\\
  limit 1\\
  for update;\\
\\
  if v_new_seat is null then\\
    v_sector_start:=case v_faction.side when 'left' then 1 when 'center' then 21 else 41 end;\\
    v_sector_end:=v_sector_start+19;\\
\\
    select ss.seat_number into v_new_seat\\
    from game.session_seats ss\\
    where ss.session_id=p_session_id\\
      and ss.user_id is null\\
      and ss.faction_id is null\\
      and ss.seat_number between v_sector_start and v_sector_end\\
    order by ss.seat_number\\
    limit 1\\
    for update;\\
  end if;\\
\\
  if v_new_seat is null then raise exception 'sector_full'; end if;\\
\\
  update game.session_seats\\
  set user_id=v_uid,faction_id=v_faction.id,side=v_faction.side\\
  where session_id=p_session_id and seat_number=v_new_seat;\\
\\
  update game.session_members\\
  set faction_id=v_faction.id,seat_number=v_new_seat\\
  where session_id=p_session_id and user_id=v_uid;\\
\\
  update game.session_factions sf\\
  set seat_start=x.min_seat,seat_end=x.max_seat\\
  from (\\
    select ss2.faction_id,min(ss2.seat_number) min_seat,max(ss2.seat_number) max_seat\\
    from game.session_seats ss2\\
    where ss2.session_id=p_session_id and ss2.faction_id=v_faction.id\\
    group by ss2.faction_id\\
  ) x\\
  where sf.id=v_faction.id;\\
\\
  select sf5.* into v_faction\\
  from game.session_factions sf5\\
  where sf5.id=v_faction.id;\\
\\
  return query select v_faction.id,v_faction.name,v_faction.side,v_new_seat,v_faction.color_code;\\
end\\
$function$
