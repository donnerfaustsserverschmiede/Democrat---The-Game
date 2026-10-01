-- Finalize Democrat session opinion-point scoring.
-- Players and factions start at 50 points. Good decisions add the statement impact,
-- bad decisions subtract it. 0 eliminates; first to 100 ends the session.

create or replace function public.cast_session_vote(p_session_id uuid,p_choice text)
returns table(statement_id uuid,choice text,resolved boolean,outcome text,player_approval integer,faction_approval integer)
language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid:=(select auth.uid()); v_session game.sessions%rowtype; v_member game.session_members%rowtype; v_statement game.session_statements%rowtype;
 v_yes int; v_no int; v_faction_yes int; v_faction_no int; v_faction_eligible int; v_faction_voted int; v_session_eligible int; v_session_voted int;
 v_player_delta int; v_faction_delta int; v_player_points int; v_faction_points int; v_outcome text; v_ended boolean:=false;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_choice not in ('approve','interject','reject') then raise exception 'invalid_choice'; end if;

 select * into v_session from game.sessions s where s.id=p_session_id for update;
 if not found then raise exception 'session_not_found'; end if;
 if v_session.status='ended' then raise exception 'session_ended'; end if;

 select * into v_member from game.session_members m where m.session_id=p_session_id and m.user_id=v_uid for update;
 if not found then raise exception 'not_session_member'; end if;
 if v_member.eliminated_at is not null then raise exception 'player_eliminated'; end if;
 if v_member.faction_id is null then raise exception 'faction_required'; end if;
 if exists(select 1 from game.session_faction_stats fs where fs.session_id=p_session_id and fs.faction_id=v_member.faction_id and fs.eliminated_at is not null) then raise exception 'faction_eliminated'; end if;

 perform game.ensure_session_player_stat(p_session_id,v_uid);
 perform game.ensure_session_faction_stat(p_session_id,v_member.faction_id);
 perform public.ensure_active_session_statement(p_session_id);

 select * into v_statement from game.session_statements s
 where s.session_id=p_session_id and s.status='open'
 order by s.statement_number desc limit 1 for update;
 if not found then raise exception 'no_active_statement'; end if;
 if exists(select 1 from game.session_votes sv where sv.statement_id=v_statement.id and sv.user_id=v_uid) then raise exception 'already_voted'; end if;

 insert into game.session_votes(statement_id,session_id,user_id,faction_id,choice)
 values(v_statement.id,p_session_id,v_uid,v_member.faction_id,p_choice);

 if p_choice='interject' or v_statement.citizen_impact=0 then v_player_delta:=0;
 elsif (v_statement.citizen_impact>0 and p_choice='approve')
    or (v_statement.citizen_impact<0 and p_choice='reject') then v_player_delta:=abs(v_statement.citizen_impact);
 else v_player_delta:=-abs(v_statement.citizen_impact); end if;

 update game.session_player_stats
 set approval=greatest(0,least(100,approval+v_player_delta)),updated_at=now()
 where session_id=p_session_id and user_id=v_uid
 returning approval into v_player_points;

 if v_player_points=0 then
   update game.session_members set eliminated_at=coalesce(eliminated_at,now())
   where session_id=p_session_id and user_id=v_uid;
 end if;

 select count(*) filter(where sv_vote.choice='approve')::int,
       count(*) filter(where sv_vote.choice='reject')::int
 into v_yes,v_no
 from game.session_votes sv_vote where sv_vote.statement_id=v_statement.id;

 if v_player_points>=100 then
   update game.sessions set status='ended',winner_type='player',winner_user_id=v_uid,winner_faction_id=null,ended_at=now(),end_reason='player_reached_100'
   where id=p_session_id;
   update game.session_statements
   set status='resolved',
       outcome=case when v_yes>v_no then 'approved' when v_no>v_yes then 'rejected' else 'tie' end,
       resolved_at=now()
   where id=v_statement.id;
   select fs.approval into v_faction_points from game.session_faction_stats fs
   where fs.session_id=p_session_id and fs.faction_id=v_member.faction_id;
   return query select v_statement.id,p_choice,true,
     (select s.outcome from game.session_statements s where s.id=v_statement.id),
     v_player_points,v_faction_points;
   return;
 end if;

 select count(*) filter(where sv_faction.choice='approve')::int,
       count(*) filter(where sv_faction.choice='reject')::int
 into v_faction_yes,v_faction_no
 from game.session_votes sv_faction where sv_faction.statement_id=v_statement.id and sv_faction.faction_id=v_member.faction_id;

 select count(*)::int into v_faction_eligible
 from game.session_members m
 left join game.session_votes sv on sv.statement_id=v_statement.id and sv.user_id=m.user_id
 where m.session_id=p_session_id and m.faction_id=v_member.faction_id
   and (m.eliminated_at is null or sv.user_id is not null);

 select count(*)::int into v_faction_voted
 from game.session_votes where statement_id=v_statement.id and faction_id=v_member.faction_id;

 if v_faction_yes>v_faction_no then v_outcome:='approved';
 elsif v_faction_no>v_faction_yes then v_outcome:='rejected';
 else v_outcome:='tie'; end if;

 if v_faction_voted=v_faction_eligible then
   v_faction_delta:=case
     when v_outcome='tie' or v_statement.citizen_impact=0 then 0
     when (v_statement.citizen_impact>0 and v_outcome='approved')
       or (v_statement.citizen_impact<0 and v_outcome='rejected') then abs(v_statement.citizen_impact)
     else -abs(v_statement.citizen_impact) end;

   update game.session_faction_stats
   set approval=greatest(0,least(100,approval+v_faction_delta)),updated_at=now()
   where session_id=p_session_id and faction_id=v_member.faction_id
   returning approval into v_faction_points;

   if v_faction_points=0 then
     update game.session_faction_stats set eliminated_at=coalesce(eliminated_at,now())
     where session_id=p_session_id and faction_id=v_member.faction_id;
   end if;

   if v_faction_points>=100 then
     update game.sessions set status='ended',winner_type='faction',winner_user_id=null,winner_faction_id=v_member.faction_id,
       ended_at=now(),end_reason='faction_reached_100'
     where id=p_session_id;
     v_ended:=true;
   end if;
 else
   select fs.approval into v_faction_points
   from game.session_faction_stats fs
   where fs.session_id=p_session_id and fs.faction_id=v_member.faction_id;
 end if;

 select count(*)::int into v_session_eligible
 from game.session_members m
 left join game.session_votes sv on sv.statement_id=v_statement.id and sv.user_id=m.user_id
 where m.session_id=p_session_id and (m.eliminated_at is null or sv.id is not null);

 select count(*)::int into v_session_voted
 from game.session_votes sv_vote where sv_vote.statement_id=v_statement.id;

 if not v_ended and v_session_voted=v_session_eligible then
   update game.session_statements
   set status='resolved',outcome=case when v_yes>v_no then 'approved' when v_no>v_yes then 'rejected' else 'tie' end,resolved_at=now()
   where id=v_statement.id;
 elsif v_ended then
   update game.session_statements
   set status='resolved',outcome=case when v_yes>v_no then 'approved' when v_no>v_yes then 'rejected' else 'tie' end,resolved_at=now()
   where id=v_statement.id;
 end if;

 if not v_ended and not exists(select 1 from game.session_members where session_id=p_session_id and eliminated_at is null) then
   update game.sessions set status='ended',winner_type=null,winner_user_id=null,winner_faction_id=null,ended_at=now(),end_reason='all_players_eliminated'
   where id=p_session_id;
 end if;

 select ps_final.approval into v_player_points from game.session_player_stats ps_final where session_id=p_session_id and user_id=v_uid;
 select fs_final.approval into v_faction_points from game.session_faction_stats fs_final where session_id=p_session_id and faction_id=v_member.faction_id;

 return query select v_statement.id,p_choice,
   (select s.status='resolved' from game.session_statements s where s.id=v_statement.id),
   (select s.outcome from game.session_statements s where s.id=v_statement.id),
   v_player_points,v_faction_points;
end; $$;

create or replace function public.advance_session_statement(p_session_id uuid)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid()); v_last game.session_statements%rowtype; v_status text;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select status into v_status from game.sessions where id=p_session_id;
 if v_status is null then raise exception 'session_not_found'; end if;
 if v_status='ended' then raise exception 'session_ended'; end if;
 if not exists(select 1 from game.session_members where session_id=p_session_id and user_id=v_uid and eliminated_at is null) then raise exception 'not_session_member'; end if;
 perform pg_advisory_xact_lock(hashtext(p_session_id::text));
 select * into v_last from game.session_statements where session_id=p_session_id order by statement_number desc limit 1;
 if found and v_last.status='open' then raise exception 'statement_still_open'; end if;
 return public.ensure_active_session_statement(p_session_id);
end; $$;

drop function if exists public.get_session_game_state_v2(uuid);
create function public.get_session_game_state_v2(p_session_id uuid)
returns table(statement_id uuid,statement_number integer,statement_text text,citizen_impact smallint,statement_status text,outcome text,
 player_opinion_points integer,faction_opinion_points integer,money bigint,my_choice text,
 approve_votes integer,reject_votes integer,interject_votes integer,
 faction_approve_votes integer,faction_reject_votes integer,faction_interject_votes integer,
 faction_member_count integer,faction_voted_count integer,player_eliminated boolean,faction_eliminated boolean,
 session_status text,winner_type text,winner_user_id uuid,winner_faction_id uuid,winner_name text,end_reason text)
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid()); v_faction uuid; v_statement game.session_statements%rowtype;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select faction_id into v_faction from game.session_members where session_id=p_session_id and user_id=v_uid;
 if not found then raise exception 'not_session_member'; end if;
 perform game.ensure_session_player_stat(p_session_id,v_uid);
 if v_faction is not null then perform game.ensure_session_faction_stat(p_session_id,v_faction); end if;
 select * into v_statement from game.session_statements where session_id=p_session_id order by statement_number desc limit 1;
 if not found and exists(select 1 from game.sessions where id=p_session_id and status='active') then
   perform public.ensure_active_session_statement(p_session_id);
   select * into v_statement from game.session_statements where session_id=p_session_id order by statement_number desc limit 1;
 end if;
 return query
 select s.id,s.statement_number,s.statement_text,s.citizen_impact,s.status,s.outcome,
   ps.approval,coalesce(fs.approval,50),ps.money,myv.choice,
   coalesce(vc.approve_votes,0),coalesce(vc.reject_votes,0),coalesce(vc.interject_votes,0),
   coalesce(fvc.approve_votes,0),coalesce(fvc.reject_votes,0),coalesce(fvc.interject_votes,0),
   coalesce(fmc.member_count,0),coalesce(fvcnt.voted_count,0),
   (m.eliminated_at is not null),coalesce(fs.eliminated_at is not null,false),
   sess.status,sess.winner_type,sess.winner_user_id,sess.winner_faction_id,
   case when sess.winner_type='faction' then wf.name when sess.winner_type='player' then coalesce(wp.profile_name,'Spieler') else null end,
   sess.end_reason
 from game.session_members m
 join game.sessions sess on sess.id=p_session_id
 join game.session_player_stats ps on ps.session_id=p_session_id and ps.user_id=v_uid
 left join game.session_faction_stats fs on fs.session_id=p_session_id and fs.faction_id=v_faction
 left join game.session_votes myv on myv.statement_id=s.id and myv.user_id=v_uid
 left join identity.profiles wp on wp.user_id=sess.winner_user_id
 left join game.session_factions wf on wf.id=sess.winner_faction_id
 left join lateral (select count(*) filter(where choice='approve')::int approve_votes,count(*) filter(where choice='reject')::int reject_votes,count(*) filter(where choice='interject')::int interject_votes from game.session_votes where statement_id=s.id) vc on true
 left join lateral (select count(*) filter(where choice='approve')::int approve_votes,count(*) filter(where choice='reject')::int reject_votes,count(*) filter(where choice='interject')::int interject_votes from game.session_votes where statement_id=s.id and faction_id=v_faction) fvc on true
 left join lateral (select count(*)::int member_count from game.session_members where session_id=p_session_id and faction_id=v_faction and eliminated_at is null) fmc on true
 left join lateral (select count(*)::int voted_count from game.session_votes where statement_id=s.id and faction_id=v_faction) fvcnt on true
 where m.session_id=p_session_id and m.user_id=v_uid and (s.id=v_statement.id or v_statement.id is null);
end; $$;

revoke all on function public.get_session_game_state_v2(uuid) from public,anon;
grant execute on function public.get_session_game_state_v2(uuid) to authenticated;
