CREATE OR REPLACE FUNCTION public.advance_session_statement(p_session_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_last game.session_statements%rowtype;
  v_status text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select s.status into v_status from game.sessions s where s.id=p_session_id;
  if v_status is null then raise exception 'session_not_found'; end if;
  if v_status='ended' then raise exception 'session_ended'; end if;
  if not exists(select 1 from game.session_members m where m.session_id=p_session_id and m.user_id=v_uid and m.eliminated_at is null) then
    raise exception 'not_session_member';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_session_id::text));

  select * into v_last
  from game.session_statements s
  where s.session_id=p_session_id
  order by s.statement_number desc
  limit 1;

  if found and v_last.status='open' then
    if v_last.opened_at > now() - interval '60 minutes' then
      raise exception 'statement_still_open';
    end if;
    perform public.process_session_statement_timeout(p_session_id);
    select * into v_last
    from game.session_statements s
    where s.session_id=p_session_id
    order by s.statement_number desc
    limit 1;
    if v_last.status='open' then
      raise exception 'statement_resolution_failed';
    end if;
  end if;

  if exists(select 1 from game.sessions where id=p_session_id and status='ended') then
    return v_last.id;
  end if;

  return public.ensure_active_session_statement(p_session_id);
end
$function$
;

CREATE OR REPLACE FUNCTION public.get_session_game_state_v2(p_session_id uuid)
 RETURNS TABLE(statement_id uuid, statement_number integer, statement_text text, citizen_impact smallint, statement_status text, outcome text, statement_opened_at timestamp with time zone, statement_deadline timestamp with time zone, server_now timestamp with time zone, player_opinion_points integer, faction_opinion_points integer, money bigint, my_choice text, approve_votes integer, reject_votes integer, interject_votes integer, faction_approve_votes integer, faction_reject_votes integer, faction_interject_votes integer, faction_member_count integer, faction_voted_count integer, player_eliminated boolean, faction_eliminated boolean, session_status text, winner_type text, winner_user_id uuid, winner_faction_id uuid, winner_name text, end_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_faction uuid;
  v_statement game.session_statements%rowtype;
  v_session_status text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select m.faction_id
    into v_faction
  from game.session_members m
  where m.session_id=p_session_id
    and m.user_id=v_uid;

  if not found then
    raise exception 'not_session_member';
  end if;

  perform game.ensure_session_player_stat(p_session_id,v_uid);
  if v_faction is not null then
    perform game.ensure_session_faction_stat(p_session_id,v_faction);
  end if;

  select s.status
    into v_session_status
  from game.sessions s
  where s.id=p_session_id;

  if v_session_status is null then
    raise exception 'session_not_found';
  end if;

  select st.*
    into v_statement
  from game.session_statements st
  where st.session_id=p_session_id
  order by st.statement_number desc
  limit 1;

  if not found and v_session_status='active' then
    perform public.ensure_active_session_statement(p_session_id);
  else
    if v_statement.status='open'
       and v_statement.opened_at <= now() - interval '60 minutes' then
      perform public.process_session_statement_timeout(p_session_id);
    end if;

    select st.*
      into v_statement
    from game.session_statements st
    where st.session_id=p_session_id
    order by st.statement_number desc
    limit 1;

    if v_statement.status='resolved'
       and v_session_status='active' then
      perform public.ensure_active_session_statement(p_session_id);
    end if;
  end if;

  select st.*
    into v_statement
  from game.session_statements st
  where st.session_id=p_session_id
  order by st.statement_number desc
  limit 1;

  if v_statement.status='open' then
    perform game.ensure_session_bot_votes(p_session_id,v_statement.id);
  end if;

  /*
    LIVE VOTE DISPLAY:
    Every submitted vote represents one seat in the live majority.
    We deliberately do NOT weight a vote by faction size here. This keeps
    the visible ratio at 1/60 = 1.67 percentage points per submitted vote.
    Faction completion still controls when faction approval is actually
    updated/resolved in cast_session_vote/process_session_statement_timeout.
  */
  return query
  select
    s.id,
    s.statement_number,
    s.statement_text,
    s.citizen_impact,
    s.status,
    s.outcome,
    s.opened_at,
    (s.opened_at + interval '60 minutes'),
    now(),
    ps.approval,
    coalesce(fs.approval,50),
    ps.money,
    myv.choice,

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       where sv.statement_id=s.id
         and sv.choice='approve'),0
    )
    +
    coalesce(
      (select count(*)::integer
       from game.session_bot_votes bv
       where bv.statement_id=s.id
         and bv.choice='approve'),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       where sv.statement_id=s.id
         and sv.choice='reject'),0
    )
    +
    coalesce(
      (select count(*)::integer
       from game.session_bot_votes bv
       where bv.statement_id=s.id
         and bv.choice='reject'),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       where sv.statement_id=s.id
         and sv.choice='interject'),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       where sv.statement_id=s.id
         and sv.faction_id=v_faction
         and sv.choice='approve'),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       where sv.statement_id=s.id
         and sv.faction_id=v_faction
         and sv.choice='reject'),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       where sv.statement_id=s.id
         and sv.faction_id=v_faction
         and sv.choice='interject'),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_members sm
       where sm.session_id=p_session_id
         and sm.faction_id=v_faction
         and sm.eliminated_at is null),0
    ),

    coalesce(
      (select count(*)::integer
       from game.session_votes sv
       join game.session_members sm
         on sm.session_id=sv.session_id
        and sm.user_id=sv.user_id
       where sv.statement_id=s.id
         and sv.faction_id=v_faction
         and sm.eliminated_at is null),0
    ),

    (m.eliminated_at is not null),
    coalesce(fs.eliminated_at is not null,false),

    sess.status,
    sess.winner_type,
    sess.winner_user_id,
    sess.winner_faction_id,

    case
      when sess.winner_type='faction' then wf.name
      when sess.winner_type='player' then coalesce(wp.profile_name,'Spieler')
      else null
    end,

    sess.end_reason

  from game.session_members m
  join game.sessions sess
    on sess.id=p_session_id
  join game.session_player_stats ps
    on ps.session_id=p_session_id
   and ps.user_id=v_uid
  left join game.session_faction_stats fs
    on fs.session_id=p_session_id
   and fs.faction_id=v_faction
  left join game.session_statements s
    on s.id=v_statement.id
  left join game.session_votes myv
    on myv.statement_id=s.id
   and myv.user_id=v_uid
  left join identity.profiles wp
    on wp.user_id=sess.winner_user_id
  left join game.session_factions wf
    on wf.id=sess.winner_faction_id
  where m.session_id=p_session_id
    and m.user_id=v_uid;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_session_statement_timeout(p_session_id uuid)
 RETURNS TABLE(processed boolean, result_statement_id uuid, outcome text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_uid uuid:=auth.uid();
 v_statement game.session_statements%rowtype;
 v_yes int:=0; v_no int:=0; v_outcome text;
 v_faction record; v_faction_points int;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if not exists(
   select 1 from game.session_members
   where session_id=p_session_id and user_id=v_uid and eliminated_at is null
 ) then raise exception 'not_session_member'; end if;

 perform pg_advisory_xact_lock(hashtext(p_session_id::text));

 select * into v_statement
 from game.session_statements
 where session_id=p_session_id
 order by statement_number desc limit 1 for update;

 if not found then
   return query select false,null::uuid,null::text; return;
 end if;
 if v_statement.status<>'open' then
   return query select false,v_statement.id,v_statement.outcome; return;
 end if;
 if v_statement.opened_at>now()-interval '60 minutes' then
   return query select false,v_statement.id,null::text; return;
 end if;

 -- At exactly 60 minutes, finish any remaining scheduled bot votes and
 -- resolve using every vote that has actually been submitted.
 perform game.ensure_session_bot_votes(p_session_id,v_statement.id,true);

 select count(*) filter(where choice='approve')::int,
        count(*) filter(where choice='reject')::int
 into v_yes,v_no
 from game.session_votes
 where statement_id=v_statement.id;

 select coalesce(v_yes,0)+coalesce((
          select count(*) from game.session_bot_votes
          where statement_id=v_statement.id and choice='approve'
        ),0),
        coalesce(v_no,0)+coalesce((
          select count(*) from game.session_bot_votes
          where statement_id=v_statement.id and choice='reject'
        ),0)
 into v_yes,v_no;

 v_outcome:=case
   when v_yes>v_no then 'approved'
   when v_no>v_yes then 'rejected'
   else 'tie'
 end;

 update game.session_statements
 set status='resolved',outcome=v_outcome,resolved_at=now()
 where id=v_statement.id;

 for v_faction in
   select f.id,
     count(sv.user_id) filter(where sv.choice='approve')::int yes_count,
     count(sv.user_id) filter(where sv.choice='reject')::int no_count
   from game.session_factions f
   left join game.session_votes sv
     on sv.statement_id=v_statement.id and sv.faction_id=f.id
   where f.session_id=p_session_id
   group by f.id
 loop
   if v_faction.yes_count<>v_faction.no_count then
     v_faction_points:=case
       when v_statement.citizen_impact=0 then 0
       when (v_statement.citizen_impact>0 and v_faction.yes_count>v_faction.no_count)
         or (v_statement.citizen_impact<0 and v_faction.no_count>v_faction.yes_count)
         then abs(v_statement.citizen_impact)
       else -abs(v_statement.citizen_impact)
     end;
     update game.session_faction_stats
     set approval=greatest(0,least(100,approval+v_faction_points)),updated_at=now()
     where session_id=p_session_id and faction_id=v_faction.id;
   end if;
 end loop;

 if not exists(
   select 1 from game.session_members
   where session_id=p_session_id and eliminated_at is null
 ) then
   update game.sessions
   set status='ended',winner_type=null,winner_user_id=null,winner_faction_id=null,
       ended_at=now(),end_reason='all_players_eliminated'
   where id=p_session_id;
 end if;

 return query select true,v_statement.id,v_outcome;
end
$function$
;

CREATE OR REPLACE FUNCTION game.ensure_session_bot_votes(p_session_id uuid, p_statement_id uuid, p_force_all boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_impact smallint;
  v_opened_at timestamptz;
begin
  select citizen_impact, opened_at
    into v_impact, v_opened_at
  from game.session_statements
  where id=p_statement_id and session_id=p_session_id;

  if not found then return; end if;

  /*
    Normal live mode:
    exactly one bot vote is released when its scheduled moment is reached.
    The schedule spreads the chamber's bots across the 60-minute statement
    window instead of creating all bot votes at once.
  */
  if p_force_all then
    insert into game.session_bot_votes(
      statement_id,bot_id,choice,influence_method,scheduled_at
    )
    select
      p_statement_id,
      b.id,
      case
        when b.base_preference > 0 then
          case
            when v_impact > 0 then case when random()<0.75 then 'approve' else 'reject' end
            when v_impact < 0 then case when random()<0.75 then 'reject' else 'approve' end
            else case when random()<0.5 then 'approve' else 'reject' end
          end
        when b.base_preference < 0 then
          case
            when v_impact > 0 then case when random()<0.75 then 'reject' else 'approve' end
            when v_impact < 0 then case when random()<0.75 then 'approve' else 'reject' end
            else case when random()<0.5 then 'approve' else 'reject' end
          end
        else
          case
            when v_impact > 0 then case when random()<0.5 then 'approve' else 'reject' end
            when v_impact < 0 then case when random()<0.5 then 'reject' else 'approve' end
            else case when random()<0.5 then 'approve' else 'reject' end
          end
      end,
      'automatic',
      now()
    from game.session_bots b
    where b.session_id=p_session_id
      and not exists(
        select 1 from game.session_bot_votes bv
        where bv.statement_id=p_statement_id and bv.bot_id=b.id
      )
    on conflict(statement_id,bot_id) do nothing;
  else
    with candidates as (
      select
        b.id,
        row_number() over(order by b.seat_number, b.id) - 1 as bot_index,
        (
          v_opened_at
          + interval '5 seconds'
          + ((row_number() over(order by b.seat_number,b.id)-1) * interval '60 seconds')
          + ((abs(hashtext(b.id::text || p_statement_id::text)) % 4000) * interval '1 millisecond')
        ) as due_at
      from game.session_bots b
      where b.session_id=p_session_id
        and not exists(
          select 1 from game.session_bot_votes bv
          where bv.statement_id=p_statement_id and bv.bot_id=b.id
        )
    )
    insert into game.session_bot_votes(
      statement_id,bot_id,choice,influence_method,scheduled_at
    )
    select
      p_statement_id,
      c.id,
      case
        when b.base_preference > 0 then
          case
            when v_impact > 0 then case when random()<0.75 then 'approve' else 'reject' end
            when v_impact < 0 then case when random()<0.75 then 'reject' else 'approve' end
            else case when random()<0.5 then 'approve' else 'reject' end
          end
        when b.base_preference < 0 then
          case
            when v_impact > 0 then case when random()<0.75 then 'reject' else 'approve' end
            when v_impact < 0 then case when random()<0.75 then 'approve' else 'reject' end
            else case when random()<0.5 then 'approve' else 'reject' end
          end
        else
          case
            when v_impact > 0 then case when random()<0.5 then 'approve' else 'reject' end
            when v_impact < 0 then case when random()<0.5 then 'reject' else 'approve' end
            else case when random()<0.5 then 'approve' else 'reject' end
          end
      end,
      'automatic',
      c.due_at
    from candidates c
    join game.session_bots b on b.id=c.id
    where c.due_at <= now()
    order by c.due_at
    limit 1
    on conflict(statement_id,bot_id) do nothing;
  end if;

  /*
    A claimed faction seat is occupied by a bot, but follows the current
    human faction majority once at least one human faction vote exists.
  */
  update game.session_bot_votes bv
  set choice = case
      when fc.yes_count > fc.no_count then 'approve'
      when fc.no_count > fc.yes_count then 'reject'
      else bv.choice
    end,
    influence_method = case
      when fc.yes_count <> fc.no_count then 'faction'
      else bv.influence_method
    end,
    influenced_by = case
      when fc.yes_count <> fc.no_count then null
      else bv.influenced_by
    end,
    updated_at=now()
  from game.session_bots b
  join game.session_seats ss
    on ss.session_id=b.session_id and ss.seat_number=b.seat_number
  join lateral (
    select
      count(*) filter(where sv.choice='approve')::int as yes_count,
      count(*) filter(where sv.choice='reject')::int as no_count
    from game.session_votes sv
    where sv.statement_id=p_statement_id
      and sv.faction_id=ss.faction_id
  ) fc on true
  where bv.statement_id=p_statement_id
    and bv.bot_id=b.id
    and b.session_id=p_session_id
    and ss.faction_id is not null
    and fc.yes_count+fc.no_count>0;
end
$function$
;

CREATE OR REPLACE FUNCTION public.claim_next_speech_slot(p_session_id uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  v_slot game.session_speech_slots%rowtype;
  v_req game.session_speech_requests%rowtype;
  v_statement game.session_statements%rowtype;
  v_topic_end timestamptz;
begin
  select * into v_slot from game.session_speech_slots
  where session_id=p_session_id and status='active'
  order by started_at desc limit 1 for update;

  select st.* into v_statement from game.session_statements st
  where st.session_id=p_session_id and st.status='open'
  order by st.statement_number desc limit 1;

  if not found then
    if v_slot.id is not null then
      update game.session_speech_slots set status='ended',paused_until=null where id=v_slot.id;
    end if;
    return;
  end if;

  v_topic_end:=v_statement.opened_at+interval '60 minutes';
  if v_topic_end<=now() then
    if v_slot.id is not null then
      update game.session_speech_slots set status='ended',paused_until=null where id=v_slot.id;
    end if;
    return;
  end if;

  if v_slot.id is not null then
    if v_slot.paused_until is not null and v_slot.paused_until <= now() then
      update game.session_speech_slots set paused_until=null where id=v_slot.id;
      v_slot.paused_until:=null;
    end if;
    if v_slot.expires_at <= now() and (v_slot.paused_until is null or v_slot.paused_until <= now()) then
      update game.session_speech_slots set status='ended' where id=v_slot.id;
    else
      return;
    end if;
  end if;

  select * into v_req from game.session_speech_requests
  where session_id=p_session_id and status='pending'
  order by requested_at,id limit 1 for update skip locked;
  if not found then return; end if;

  insert into game.session_speech_slots(session_id,speaker_user_id,started_at,expires_at)
  values(p_session_id,v_req.user_id,now(),least(now()+interval '10 minutes',v_topic_end))
  returning * into v_slot;

  update game.session_speech_requests set status='assigned',assigned_slot_id=v_slot.id where id=v_req.id;
end
$function$;;

CREATE OR REPLACE FUNCTION public.respond_session_speech_interjection(p_interjection_id uuid, p_accept boolean)
 RETURNS TABLE(status text, message text, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_int game.session_speech_interjections%rowtype; v_slot game.session_speech_slots%rowtype; v_new_exp timestamptz; v_topic_end timestamptz;
begin
  select i.* into v_int from game.session_speech_interjections i where i.id=p_interjection_id for update;
  if not found then raise exception 'interjection_not_found'; end if;
  select s.* into v_slot from game.session_speech_slots s where s.id=v_int.speech_slot_id for update;
  if not found then raise exception 'speech_slot_not_found'; end if;
  if v_slot.speaker_user_id<>v_uid then raise exception 'not_current_speaker'; end if;
  if v_int.status<>'pending' then raise exception 'interjection_already_decided'; end if;
  if v_slot.status<>'active' or v_slot.expires_at<=now() then raise exception 'speech_slot_expired'; end if;

  select st.opened_at+interval '60 minutes' into v_topic_end
  from game.session_statements st
  where st.id=(select s.statement_id from game.session_speech_slots s where s.id=v_slot.id) and st.status='open';
  if v_topic_end is null or v_topic_end<=now() then raise exception 'speech_slot_expired'; end if;
  if v_slot.paused_until is not null and v_slot.paused_until>now() then raise exception 'interjection_already_active'; end if;

  if p_accept then
    v_new_exp:=least(now()+interval '2 minutes',v_topic_end);
    update game.session_speech_slots set paused_until=v_new_exp,expires_at=least(expires_at+interval '2 minutes',v_topic_end) where id=v_slot.id;
    update game.session_speech_interjections set status='accepted',decided_at=now(),expires_at=v_new_exp where id=v_int.id;
    return query select 'accepted'::text,'Zwischenruf angenommen.'::text,v_new_exp;
  else
    update game.session_speech_interjections set status='rejected',decided_at=now() where id=v_int.id;
    return query select 'rejected'::text,'Zwischenruf abgelehnt.'::text,null::timestamptz;
  end if;
end;
$function$
;