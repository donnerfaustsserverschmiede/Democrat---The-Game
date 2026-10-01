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
  select citizen_impact,opened_at
    into v_impact,v_opened_at
  from game.session_statements
  where id=p_statement_id and session_id=p_session_id;

  if not found then return; end if;

  if p_force_all then
    insert into game.session_bot_votes(
      statement_id,bot_id,choice,influence_method,influenced_by,scheduled_at
    )
    select
      p_statement_id,
      b.id,
      case
        when ss.faction_id is not null then
          case
            when fc.yes_count>fc.no_count then 'approve'
            when fc.no_count>fc.yes_count then 'reject'
            else case when b.base_preference>0 then 'approve'
                 when b.base_preference<0 then 'reject'
                 when v_impact>0 then 'approve'
                 else 'reject' end
          end
        else
          case when b.base_preference
                    +coalesce(bp.persuasion_score,0)>0
               then 'approve'
               when b.base_preference
                    +coalesce(bp.persuasion_score,0)<0
               then 'reject'
               else case when v_impact>0 then 'approve' else 'reject' end
          end
      end,
      case
        when ss.faction_id is not null and fc.yes_count<>fc.no_count then 'faction'
        when coalesce(bp.persuasion_score,0)<>0 then 'speech'
        else 'automatic'
      end,
      case
        when coalesce(bp.persuasion_score,0)<>0 then bp.last_speaker_user_id
        else null
      end,
      now()
    from game.session_bots b
    join game.session_seats ss
      on ss.session_id=b.session_id
     and ss.seat_number=b.seat_number
    left join game.session_bot_persuasion bp
      on bp.statement_id=p_statement_id and bp.bot_id=b.id
    left join lateral (
      select
        count(*) filter(where sv.choice='approve')::int as yes_count,
        count(*) filter(where sv.choice='reject')::int as no_count
      from game.session_votes sv
      where sv.statement_id=p_statement_id
        and sv.faction_id=ss.faction_id
    ) fc on true
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
        ss.faction_id,
        row_number() over(order by b.seat_number,b.id)-1 as bot_index,
        (
          v_opened_at
          + interval '5 seconds'
          + ((row_number() over(order by b.seat_number,b.id)-1)*interval '60 seconds')
          + ((abs(hashtext(b.id::text||p_statement_id::text))%4000)*interval '1 millisecond')
        ) as due_at
      from game.session_bots b
      join game.session_seats ss
        on ss.session_id=b.session_id
       and ss.seat_number=b.seat_number
      where b.session_id=p_session_id
        and not exists(
          select 1 from game.session_bot_votes bv
          where bv.statement_id=p_statement_id and bv.bot_id=b.id
        )
    )
    insert into game.session_bot_votes(
      statement_id,bot_id,choice,influence_method,influenced_by,scheduled_at
    )
    select
      p_statement_id,
      c.id,
      case
        when c.faction_id is not null then
          case when coalesce(fc.yes_count,0)>coalesce(fc.no_count,0) then 'approve'
               when coalesce(fc.no_count,0)>coalesce(fc.yes_count,0) then 'reject'
               else case when b.base_preference>0 then 'approve'
                         when b.base_preference<0 then 'reject'
                         when v_impact>0 then 'approve' else 'reject' end
          end
        else
          case when b.base_preference+coalesce(bp.persuasion_score,0)>0 then 'approve'
               when b.base_preference+coalesce(bp.persuasion_score,0)<0 then 'reject'
               else case when v_impact>0 then 'approve' else 'reject' end
          end
      end,
      case
        when c.faction_id is not null and coalesce(fc.yes_count,0)<>coalesce(fc.no_count,0) then 'faction'
        when coalesce(bp.persuasion_score,0)<>0 then 'speech'
        else 'automatic'
      end,
      case when coalesce(bp.persuasion_score,0)<>0 then bp.last_speaker_user_id else null end,
      c.due_at
    from candidates c
    join game.session_bots b on b.id=c.id
    left join game.session_bot_persuasion bp
      on bp.statement_id=p_statement_id and bp.bot_id=b.id
    left join lateral (
      select
        count(*) filter(where sv.choice='approve')::int as yes_count,
        count(*) filter(where sv.choice='reject')::int as no_count
      from game.session_votes sv
      where sv.statement_id=p_statement_id
        and sv.faction_id=c.faction_id
    ) fc on true
    where c.due_at<=now()
    order by c.due_at
    limit 1
    on conflict(statement_id,bot_id) do nothing;
  end if;

  -- If all 60 seats have now voted, resolve the topic immediately.
  -- Otherwise the topic remains open so later speeches can still influence
  -- bots whose scheduled vote has not happened yet.
  declare
    v_total_votes integer;
    v_yes_votes integer;
    v_no_votes integer;
  begin
    select count(*) into v_total_votes
    from (
      select sv.user_id::text
      from game.session_votes sv
      where sv.statement_id=p_statement_id
      union all
      select bv.bot_id::text
      from game.session_bot_votes bv
      where bv.statement_id=p_statement_id
    ) all_votes;

    if v_total_votes>=60 then
      select count(*) filter(where sv.choice='approve')::int,
             count(*) filter(where sv.choice='reject')::int
      into v_yes_votes,v_no_votes
      from (
        select choice from game.session_votes where statement_id=p_statement_id
        union all
        select choice from game.session_bot_votes where statement_id=p_statement_id
      ) sv;

      update game.session_statements
      set status='resolved',
          outcome=case when v_yes_votes>v_no_votes then 'approved'
                       when v_no_votes>v_yes_votes then 'rejected'
                       else 'tie' end,
          resolved_at=now()
      where id=p_statement_id and status='open';
    end if;
  end;

  -- A faction bot follows the current human faction majority.
  update game.session_bot_votes bv
  set choice=case
      when fc.yes_count>fc.no_count then 'approve'
      when fc.no_count>fc.yes_count then 'reject'
      else bv.choice
    end,
    influence_method=case
      when fc.yes_count<>fc.no_count then 'faction'
      else bv.influence_method
    end,
    influenced_by=case
      when fc.yes_count<>fc.no_count then null
      else bv.influenced_by
    end,
    updated_at=now()
  from game.session_bots b
  join game.session_seats ss
    on ss.session_id=b.session_id
   and ss.seat_number=b.seat_number
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

CREATE OR REPLACE FUNCTION public.process_session_statement_timeout(p_session_id uuid)
 RETURNS TABLE(processed boolean,result_statement_id uuid,outcome text)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
 v_uid uuid:=auth.uid();
 v_statement game.session_statements%rowtype;
 v_yes int:=0; v_no int:=0; v_outcome text;
 v_faction record; v_faction_points int;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if not exists(select 1 from game.session_members where session_id=p_session_id and user_id=v_uid and eliminated_at is null) then
   raise exception 'not_session_member';
 end if;

 perform pg_advisory_xact_lock(hashtext(p_session_id::text));

 select * into v_statement
 from game.session_statements
 where session_id=p_session_id
 order by statement_number desc limit 1 for update;

 if not found then return query select false,null::uuid,null::text; return; end if;
 if v_statement.status<>'open' then return query select false,v_statement.id,v_statement.outcome; return; end if;
 if v_statement.opened_at>now()-interval '60 minutes' then return query select false,v_statement.id,null::text; return; end if;

 -- The one-hour deadline ends the topic with the votes that actually arrived.
 -- Do NOT manufacture the remaining bot votes at the deadline: unanswered seats
 -- simply do not vote. This preserves the hour as the maximum debate window.
 select count(*) filter(where x.choice='approve')::int,
        count(*) filter(where x.choice='reject')::int
 into v_yes,v_no
 from (
   select choice from game.session_votes where statement_id=v_statement.id
   union all
   select choice from game.session_bot_votes where statement_id=v_statement.id
 ) x;

 v_outcome:=case when v_yes>v_no then 'approved'
                 when v_no>v_yes then 'rejected'
                 else 'tie' end;

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

 if not exists(select 1 from game.session_members where session_id=p_session_id and eliminated_at is null) then
   update game.sessions
   set status='ended',winner_type=null,winner_user_id=null,winner_faction_id=null,
       ended_at=now(),end_reason='all_players_eliminated'
   where id=p_session_id;
 end if;

 return query select true,v_statement.id,v_outcome;
end
$function$;