-- Fix PL/pgSQL ambiguity between RETURNS TABLE(statement_id) and
-- the player_decision_points primary-key column statement_id.
-- The named constraint avoids interpreting statement_id as the output variable.
create or replace function public.cast_session_vote(p_session_id uuid, p_choice text)
returns table(statement_id uuid, choice text, resolved boolean, outcome text, player_approval integer, faction_approval integer)
language plpgsql security definer set search_path=''
as $function$
declare
 v_uid uuid:=auth.uid();
 v_session game.sessions%rowtype;
 v_member game.session_members%rowtype;
 v_statement game.session_statements%rowtype;
 v_yes int:=0; v_no int:=0; v_bot_yes int:=0; v_bot_no int:=0;
 v_faction_yes int:=0; v_faction_no int:=0;
 v_faction_eligible int:=0; v_faction_voted int:=0;
 v_online_eligible int:=0; v_online_voted int:=0;
 v_player_points int:=0; v_faction_points int:=0;
 v_player_delta int:=0; v_faction_delta int:=0;
 v_outcome text; v_decision_points int; v_points_inserted int:=0;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_choice not in ('approve','interject','reject') then raise exception 'invalid_choice'; end if;
 select * into v_session from game.sessions where id=p_session_id for update;
 if not found then raise exception 'session_not_found'; end if;
 if v_session.status='ended' then raise exception 'session_ended'; end if;
 select * into v_member from game.session_members where session_id=p_session_id and user_id=v_uid for update;
 if not found then raise exception 'not_session_member'; end if;
 if v_member.eliminated_at is not null then raise exception 'player_eliminated'; end if;
 if v_member.faction_id is null then raise exception 'faction_required'; end if;
 if exists(select 1 from game.session_faction_stats fs where fs.session_id=p_session_id and fs.faction_id=v_member.faction_id and fs.eliminated_at is not null) then raise exception 'faction_eliminated'; end if;

 insert into game.session_presence(session_id,user_id,last_seen_at) values(p_session_id,v_uid,now())
 on conflict(session_id,user_id) do update set last_seen_at=excluded.last_seen_at;
 perform game.ensure_session_player_stat(p_session_id,v_uid);
 perform game.ensure_session_faction_stat(p_session_id,v_member.faction_id);
 perform public.ensure_active_session_statement(p_session_id);

 select * into v_statement from game.session_statements where session_id=p_session_id and status='open'
 order by statement_number desc limit 1 for update;
 if not found then raise exception 'no_active_statement'; end if;
 if exists(select 1 from game.session_votes sv_existing where sv_existing.statement_id=v_statement.id and sv_existing.user_id=v_uid) then raise exception 'already_voted'; end if;

 insert into game.session_votes(statement_id,session_id,user_id,faction_id,choice)
 values(v_statement.id,p_session_id,v_uid,v_member.faction_id,p_choice);

 v_decision_points:=case when abs(coalesce(v_statement.citizen_impact,0))>=8 then 3 when abs(coalesce(v_statement.citizen_impact,0))>=4 then 2 else 1 end;

 insert into identity.player_decision_points(user_id,statement_id,session_id,points)
 values(v_uid,v_statement.id,p_session_id,v_decision_points)
 on conflict on constraint player_decision_points_pkey do nothing;

 if found then
   v_points_inserted:=v_decision_points;
   update identity.profiles set points=coalesce(points,0)+v_points_inserted,updated_at=now() where user_id=v_uid;
 end if;

 if p_choice='interject' or coalesce(v_statement.citizen_impact,0)=0 then v_player_delta:=0;
 elsif (v_statement.citizen_impact>0 and p_choice='approve') or (v_statement.citizen_impact<0 and p_choice='reject') then v_player_delta:=abs(v_statement.citizen_impact);
 else v_player_delta:=-abs(v_statement.citizen_impact); end if;

 update game.session_player_stats set approval=greatest(0,least(100,approval+v_player_delta)),updated_at=now()
 where session_id=p_session_id and user_id=v_uid returning approval into v_player_points;
 if v_player_points=0 then update game.session_members set eliminated_at=coalesce(eliminated_at,now()) where session_id=p_session_id and user_id=v_uid; end if;

 perform game.ensure_session_bot_votes(p_session_id,v_statement.id);

 select count(*) filter(where sv.choice='approve')::int,count(*) filter(where sv.choice='reject')::int into v_yes,v_no
 from game.session_votes sv where sv.statement_id=v_statement.id;
 select count(*) filter(where bv.choice='approve')::int,count(*) filter(where bv.choice='reject')::int into v_bot_yes,v_bot_no
 from game.session_bot_votes bv where bv.statement_id=v_statement.id;
 v_yes:=coalesce(v_yes,0)+coalesce(v_bot_yes,0); v_no:=coalesce(v_no,0)+coalesce(v_bot_no,0);

 select count(*)::int into v_faction_eligible from game.session_members m join game.session_presence p on p.session_id=m.session_id and p.user_id=m.user_id
 where m.session_id=p_session_id and m.faction_id=v_member.faction_id and m.eliminated_at is null and p.last_seen_at>now()-interval '15 seconds';
 select count(*)::int into v_faction_voted from game.session_votes sv join game.session_members mm on mm.session_id=sv.session_id and mm.user_id=sv.user_id
 where sv.statement_id=v_statement.id and sv.faction_id=v_member.faction_id and mm.eliminated_at is null;
 select count(*) filter(where sv.choice='approve')::int,count(*) filter(where sv.choice='reject')::int into v_faction_yes,v_faction_no
 from game.session_votes sv where sv.statement_id=v_statement.id and sv.faction_id=v_member.faction_id;

 if v_faction_eligible>0 and v_faction_voted>=v_faction_eligible then
   v_faction_delta:=case when v_faction_yes=v_faction_no or v_statement.citizen_impact=0 then 0
     when (v_statement.citizen_impact>0 and v_faction_yes>v_faction_no) or (v_statement.citizen_impact<0 and v_faction_no>v_faction_yes) then abs(v_statement.citizen_impact)
     else -abs(v_statement.citizen_impact) end;
   update game.session_faction_stats set approval=greatest(0,least(100,approval+v_faction_delta)),updated_at=now()
   where session_id=p_session_id and faction_id=v_member.faction_id returning approval into v_faction_points;
 else
   select approval into v_faction_points from game.session_faction_stats where session_id=p_session_id and faction_id=v_member.faction_id;
 end if;

 select count(*)::int into v_online_eligible from game.session_members m join game.session_presence p on p.session_id=m.session_id and p.user_id=m.user_id
 where m.session_id=p_session_id and m.eliminated_at is null and p.last_seen_at>now()-interval '15 seconds';
 select count(*)::int into v_online_voted from game.session_votes sv join game.session_members m on m.session_id=sv.session_id and m.user_id=sv.user_id
 where sv.statement_id=v_statement.id and m.eliminated_at is null and exists(select 1 from game.session_presence p where p.session_id=sv.session_id and p.user_id=sv.user_id and p.last_seen_at>now()-interval '15 seconds');

 if v_online_eligible>0 and v_online_voted>=v_online_eligible then
   v_outcome:=case when v_yes>v_no then 'approved' when v_no>v_yes then 'rejected' else 'tie' end;
   update game.session_statements set status='resolved',outcome=v_outcome,resolved_at=now() where id=v_statement.id;
 else v_outcome:=null; end if;

 if not exists(select 1 from game.session_members where session_id=p_session_id and eliminated_at is null) then
   update game.sessions set status='ended',winner_type=null,winner_user_id=null,winner_faction_id=null,ended_at=now(),end_reason='all_players_eliminated' where id=p_session_id;
 end if;

 return query select v_statement.id,p_choice,
   (select ss_out.status='resolved' from game.session_statements ss_out where ss_out.id=v_statement.id),
   (select ss_out.outcome from game.session_statements ss_out where ss_out.id=v_statement.id),
   v_player_points,v_faction_points;
end;
$function$;