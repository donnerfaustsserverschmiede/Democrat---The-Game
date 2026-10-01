-- Finalize statement speaker claiming:
-- avoid PL/pgSQL RETURNS TABLE name collisions and keep one FIFO ten-minute slot.
create or replace function public.claim_session_statement_speaker(p_session_id uuid)
returns table(status text, request_id uuid, user_id uuid, profile_name text)
language plpgsql security definer set search_path=''
as $function$
declare
 v_uid uuid:=auth.uid();
 v_row record;
 v_profile_name text;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if not exists(select 1 from game.session_members m where m.session_id=p_session_id and m.user_id=v_uid and m.eliminated_at is null) then
   raise exception 'not_active_session_member';
 end if;
 perform pg_advisory_xact_lock(hashtext(p_session_id::text));

 update game.session_interjections as si
 set status='expired',reviewed_at=now(),expires_at=si.granted_at+interval '10 minutes'
 where si.session_id=p_session_id and si.status='granted'
   and si.granted_at is not null
   and si.granted_at<=now()-interval '10 minutes';

 if exists(
   select 1 from game.session_interjections active_slot
   where active_slot.session_id=p_session_id
     and active_slot.granted_at is not null
     and active_slot.granted_at>now()-interval '10 minutes'
     and active_slot.status in ('granted','approved')
 ) then return; end if;

 select i.id,i.user_id into v_row
 from game.session_interjections i
 where i.session_id=p_session_id and i.status='pending'
   and not exists(select 1 from game.session_statement_bans b where b.user_id=i.user_id and b.banned_until>now())
   and not exists(
     select 1 from game.session_interjections own
     where own.session_id=p_session_id and own.user_id=i.user_id
       and own.status='approved' and own.expires_at>now()
   )
 order by i.requested_at asc,i.id asc
 limit 1 for update skip locked;

 if not found then return; end if;

 select coalesce(p.profile_name,'Spieler') into v_profile_name
 from identity.profiles p where p.user_id=v_row.user_id;

 update game.session_interjections as si
 set status='granted',granted_at=now(),expires_at=now()+interval '10 minutes'
 where si.id=v_row.id;

 insert into game.session_event_log(session_id,event_type,title,description,actor_user_id,metadata)
 values(
   p_session_id,'statement_word_granted','Wort erteilt',
   coalesce(v_profile_name,'Spieler')||' erhält das Wort und verfasst ein Statement.',
   v_row.user_id,
   jsonb_build_object('interjection_id',v_row.id,'write_deadline',now()+interval '5 minutes','slot_expires_at',now()+interval '10 minutes')
 );

 return query select 'granted'::text,v_row.id,v_row.user_id,coalesce(v_profile_name,'Spieler');
end;
$function$;