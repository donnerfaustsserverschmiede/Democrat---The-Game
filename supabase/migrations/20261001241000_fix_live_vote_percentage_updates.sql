-- Live vote display: every submitted vote counts as one seat (1/60 = 1.67%).
-- Faction completion/resolution rules remain separate in cast_session_vote/timeout logic.
create or replace function public.get_session_game_state_v2(p_session_id uuid)
returns table(
  statement_id uuid, statement_number integer, statement_text text, citizen_impact smallint,
  statement_status text, outcome text, statement_opened_at timestamptz, statement_deadline timestamptz,
  server_now timestamptz, player_opinion_points integer, faction_opinion_points integer, money bigint,
  my_choice text, approve_votes integer, reject_votes integer, interject_votes integer,
  faction_approve_votes integer, faction_reject_votes integer, faction_interject_votes integer,
  faction_member_count integer, faction_voted_count integer, player_eliminated boolean,
  faction_eliminated boolean, session_status text, winner_type text, winner_user_id uuid,
  winner_faction_id uuid, winner_name text, end_reason text
)
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_faction uuid;
  v_statement game.session_statements%rowtype;
  v_session_status text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select m.faction_id into v_faction
  from game.session_members m
  where m.session_id=p_session_id and m.user_id=v_uid;
  if not found then raise exception 'not_session_member'; end if;

  perform game.ensure_session_player_stat(p_session_id,v_uid);
  if v_faction is not null then perform game.ensure_session_faction_stat(p_session_id,v_faction); end if;

  select s.status into v_session_status from game.sessions s where s.id=p_session_id;
  if v_session_status is null then raise exception 'session_not_found'; end if;

  select st.* into v_statement
  from game.session_statements st
  where st.session_id=p_session_id
  order by st.statement_number desc limit 1;

  if not found and v_session_status='active' then
    perform public.ensure_active_session_statement(p_session_id);
  else
    if v_statement.status='open' and v_statement.opened_at <= now() - interval '10 minutes' then
      perform public.process_session_statement_timeout(p_session_id);
    end if;

    select st.* into v_statement
    from game.session_statements st
    where st.session_id=p_session_id
    order by st.statement_number desc limit 1;

    if v_statement.status='resolved' and v_session_status='active' then
      perform public.ensure_active_session_statement(p_session_id);
    end if;
  end if;

  select st.* into v_statement
  from game.session_statements st
  where st.session_id=p_session_id
  order by st.statement_number desc limit 1;

  if v_statement.status='open' then
    perform game.ensure_session_bot_votes(p_session_id,v_statement.id);
  end if;

  return query
  select
    s.id,s.statement_number,s.statement_text,s.citizen_impact,s.status,s.outcome,s.opened_at,
    (s.opened_at + interval '10 minutes'),now(),ps.approval,coalesce(fs.approval,50),ps.money,myv.choice,
    coalesce((select count(*)::integer from game.session_votes sv where sv.statement_id=s.id and sv.choice='approve'),0)
      + coalesce((select count(*)::integer from game.session_bot_votes bv where bv.statement_id=s.id and bv.choice='approve'),0),
    coalesce((select count(*)::integer from game.session_votes sv where sv.statement_id=s.id and sv.choice='reject'),0)
      + coalesce((select count(*)::integer from game.session_bot_votes bv where bv.statement_id=s.id and bv.choice='reject'),0),
    coalesce((select count(*)::integer from game.session_votes sv where sv.statement_id=s.id and sv.choice='interject'),0),
    coalesce((select count(*)::integer from game.session_votes sv where sv.statement_id=s.id and sv.faction_id=v_faction and sv.choice='approve'),0),
    coalesce((select count(*)::integer from game.session_votes sv where sv.statement_id=s.id and sv.faction_id=v_faction and sv.choice='reject'),0),
    coalesce((select count(*)::integer from game.session_votes sv where sv.statement_id=s.id and sv.faction_id=v_faction and sv.choice='interject'),0),
    coalesce((select count(*)::integer from game.session_members sm where sm.session_id=p_session_id and sm.faction_id=v_faction and sm.eliminated_at is null),0),
    coalesce((select count(*)::integer
              from game.session_votes sv
              join game.session_members sm on sm.session_id=sv.session_id and sm.user_id=sv.user_id
              where sv.statement_id=s.id and sv.faction_id=v_faction and sm.eliminated_at is null),0),
    (m.eliminated_at is not null),coalesce(fs.eliminated_at is not null,false),
    sess.status,sess.winner_type,sess.winner_user_id,sess.winner_faction_id,
    case
      when sess.winner_type='faction' then wf.name
      when sess.winner_type='player' then coalesce(wp.profile_name,'Spieler')
      else null
    end,
    sess.end_reason
  from game.session_members m
  join game.sessions sess on sess.id=p_session_id
  join game.session_player_stats ps on ps.session_id=p_session_id and ps.user_id=v_uid
  left join game.session_faction_stats fs on fs.session_id=p_session_id and fs.faction_id=v_faction
  left join game.session_statements s on s.id=v_statement.id
  left join game.session_votes myv on myv.statement_id=s.id and myv.user_id=v_uid
  left join identity.profiles wp on wp.user_id=sess.winner_user_id
  left join game.session_factions wf on wf.id=sess.winner_faction_id
  where m.session_id=p_session_id and m.user_id=v_uid;
end;
$function$;
