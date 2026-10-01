-- Fix PL/pgSQL name ambiguity in get_player_profile.
-- The output column faction_wins conflicted with the CTE column faction_wins.
create or replace function public.get_player_profile()
returns table(
  profile_name text,
  level integer,
  public_opinion numeric,
  money bigint,
  sessions_participated integer,
  sessions_won integer,
  faction_wins integer,
  decisions integer,
  good_decisions integer,
  bad_decisions integer
)
language plpgsql
stable security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with memberships as (
    select distinct m.session_id
    from game.session_members m
    where m.user_id=v_uid
  ),
  decision_rows as (
    select ss.citizen_impact, sv.choice,
      case
        when ss.citizen_impact > 0 and sv.choice='approve' then 1
        when ss.citizen_impact < 0 and sv.choice='reject' then 1
        else 0
      end as good,
      case
        when ss.citizen_impact > 0 and sv.choice='reject' then 1
        when ss.citizen_impact < 0 and sv.choice='approve' then 1
        else 0
      end as bad
    from game.session_votes sv
    join game.session_statements ss on ss.id=sv.statement_id
    where sv.user_id=v_uid
  ),
  wins as (
    select
      count(distinct s.id) filter(where s.winner_user_id=v_uid)::integer as player_wins,
      count(distinct s.id) filter(
        where s.winner_faction_id is not null
          and sv.faction_id=s.winner_faction_id
      )::integer as faction_wins_count
    from game.session_votes sv
    join game.sessions s on s.id=sv.session_id and s.status='ended'
    where sv.user_id=v_uid
  ),
  money as (
    select coalesce(sum(ps.money),0)::bigint as total_money
    from game.session_player_stats ps
    join game.sessions s on s.id=ps.session_id
    where ps.user_id=v_uid and s.status='active'
  ),
  decision_counts as (
    select
      count(*)::integer as decisions_count,
      coalesce(sum(good),0)::integer as good_count,
      coalesce(sum(bad),0)::integer as bad_count
    from decision_rows
  )
  select
    coalesce(p.profile_name,'Spieler'),
    greatest(1,least(50,1+(select count(*)::integer
      from memberships
      join game.sessions s on s.id=memberships.session_id
      where s.status='ended'))),
    private.player_public_opinion(v_uid),
    (select m.total_money from money m),
    (select count(*)::integer from memberships),
    (select w.player_wins from wins w),
    (select w.faction_wins_count from wins w),
    (select d.decisions_count from decision_counts d),
    (select d.good_count from decision_counts d),
    (select d.bad_count from decision_counts d)
  from identity.profiles p
  where p.user_id=v_uid;
end;
$function$;
