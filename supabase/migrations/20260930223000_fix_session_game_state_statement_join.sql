-- Fix get_session_game_state_v2: join the current statement explicitly.
create or replace function public.get_session_game_state_v2(p_session_id uuid)
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
 select m.faction_id into v_faction from game.session_members m where m.session_id=p_session_id and m.user_id=v_uid;
 if not found then raise exception 'not_session_member'; end if;
 perform game.ensure_session_player_stat(p_session_id,v_uid);
 if v_faction is not null then perform game.ensure_session_faction_stat(p_session_id,v_faction); end if;
 select * into v_statement from game.session_statements st where st.session_id=p_session_id order by st.statement_number desc limit 1;
 if not found and exists(select 1 from game.sessions ss where ss.id=p_session_id and ss.status='active') then
   perform public.ensure_active_session_statement(p_session_id);
   select * into v_statement from game.session_statements st where st.session_id=p_session_id order by st.statement_number desc limit 1;
 end if;
 return query
 select s.id,s.statement_number,s.statement_text,s.citizen_impact,s.status,s.outcome,
   ps.approval,coalesce(fs.approval,50),ps.money,myv.choice,
   coalesce(vc.approve_votes,0),coalesce(vc.reject_votes,0),coalesce(vc.interject_votes,0),
   coalesce(fvc.approve_votes,0),coalesce(fvc.reject_votes,0),coalesce(fvc.interject_votes,0),
   coalesce(fmc.member_count,0),coalesce(fvcnt.voted_count,0),
   (m.eliminated_at is not null),coalesce(fs.eliminated_at is not null,false),
   sess.status,sess.winner_type,sess.winner_user_id,sess.winner_faction_id,
   case when sess.winner_type='faction' then wf.name
        when sess.winner_type='player' then coalesce(wp.profile_name,'Spieler')
        else null end,
   sess.end_reason
 from game.session_members m
 join game.sessions sess on sess.id=p_session_id
 join game.session_player_stats ps on ps.session_id=p_session_id and ps.user_id=v_uid
 left join game.session_faction_stats fs on fs.session_id=p_session_id and fs.faction_id=v_faction
 left join game.session_statements s on s.id=v_statement.id
 left join game.session_votes myv on myv.statement_id=s.id and myv.user_id=v_uid
 left join identity.profiles wp on wp.user_id=sess.winner_user_id
 left join game.session_factions wf on wf.id=sess.winner_faction_id
 left join lateral (select count(*) filter(where choice='approve')::integer approve_votes,count(*) filter(where choice='reject')::integer reject_votes,count(*) filter(where choice='interject')::integer interject_votes from game.session_votes v where v.statement_id=s.id) vc on true
 left join lateral (select count(*) filter(where choice='approve')::integer approve_votes,count(*) filter(where choice='reject')::integer reject_votes,count(*) filter(where choice='interject')::integer interject_votes from game.session_votes v where v.statement_id=s.id and v.faction_id=v_faction) fvc on true
 left join lateral (select count(*)::integer member_count from game.session_members sm where sm.session_id=p_session_id and sm.faction_id=v_faction and sm.eliminated_at is null) fmc on true
 left join lateral (select count(*)::integer voted_count from game.session_votes v where v.statement_id=s.id and v.faction_id=v_faction) fvcnt on true
 where m.session_id=p_session_id and m.user_id=v_uid;
end; $$;