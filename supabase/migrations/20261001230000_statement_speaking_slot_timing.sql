-- Statement speaking slots:
-- The game grants exactly one player a ten-minute speaking slot.
-- The granted player has five minutes to submit; publication keeps the
-- original ten-minute slot and therefore never resets/extends the lock.
-- Waiting requests retain FIFO order and are granted only after the slot ends.

create or replace function public.claim_session_statement_speaker(p_session_id uuid)
returns table(status text, request_id uuid, user_id uuid, profile_name text)
language plpgsql security definer set search_path=''
as $function$
declare
 v_uid uuid:=auth.uid();
 v_row record;
 v_lock record;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if not exists(
   select 1 from game.session_members m
   where m.session_id=p_session_id and m.user_id=v_uid and m.eliminated_at is null
 ) then raise exception 'not_active_session_member'; end if;

 perform pg_advisory_xact_lock(hashtext(p_session_id::text));

 -- Release an unsubmitted speaking slot after its full ten-minute window.
 update game.session_interjections
 set status='expired',reviewed_at=now(),expires_at=granted_at+interval '10 minutes'
 where session_id=p_session_id
   and status='granted'
   and granted_at is not null
   and granted_at<=now()-interval '10 minutes';

 -- A granted or published speaker owns the complete ten-minute slot.
 select i.id,i.status,i.granted_at,i.expires_at
 into v_lock
 from game.session_interjections i
 where i.session_id=p_session_id
   and i.granted_at is not null
   and i.granted_at>now()-interval '10 minutes'
   and i.status in ('granted','approved')
 order by i.granted_at desc
 limit 1
 for update;

 if found then return; end if;

 -- FIFO: the oldest waiting request receives the next slot.
 select i.id,i.user_id,coalesce(p.profile_name,'Spieler') as profile_name
 into v_row
 from game.session_interjections i
 left join identity.profiles p on p.user_id=i.user_id
 where i.session_id=p_session_id
   and i.status='pending'
   and not exists(
     select 1 from game.session_statement_bans b
     where b.user_id=i.user_id and b.banned_until>now()
   )
   and not exists(
     select 1 from game.session_interjections own
     where own.session_id=p_session_id
       and own.user_id=i.user_id
       and own.status='approved'
       and own.expires_at>now()
   )
 order by i.requested_at asc,i.id asc
 limit 1
 for update skip locked;

 if not found then return; end if;

 update game.session_interjections
 set status='granted',
     granted_at=now(),
     expires_at=now()+interval '10 minutes'
 where id=v_row.id;

 insert into game.session_event_log(
   session_id,event_type,title,description,actor_user_id,metadata
 )
 values(
   p_session_id,'statement_word_granted','Wort erteilt',
   coalesce(v_row.profile_name,'Spieler')||' erhält das Wort und verfasst ein Statement.',
   v_row.user_id,
   jsonb_build_object(
     'interjection_id',v_row.id,
     'write_deadline',now()+interval '5 minutes',
     'slot_expires_at',now()+interval '10 minutes'
   )
 );

 return query select 'granted'::text,v_row.id,v_row.user_id,v_row.profile_name;
end;
$function$;

create or replace function public.submit_session_statement(
 p_session_id uuid,p_request_id uuid,p_message text
)
returns table(status text,message_id uuid,reason text,expires_at timestamptz)
language plpgsql security definer set search_path=''
as $function$
declare
 v_uid uuid:=auth.uid();
 v_message text:=btrim(coalesce(p_message,''));
 v_row game.session_interjections%rowtype;
 v_reason text:=null;
 v_expires timestamptz;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if char_length(v_message)<1 or char_length(v_message)>500 then raise exception 'invalid_message_length'; end if;

 if exists(select 1 from game.session_statement_bans b where b.user_id=v_uid and b.banned_until>now()) then
   raise exception 'statement_banned';
 end if;

 select * into v_row
 from game.session_interjections
 where id=p_request_id and session_id=p_session_id and user_id=v_uid
 for update;

 if not found then raise exception 'statement_request_not_found'; end if;
 if v_row.status<>'granted' then raise exception 'statement_word_not_granted'; end if;

 if now()>=v_row.granted_at+interval '5 minutes' then
   update game.session_interjections
   set status='expired',reviewed_at=now(),expires_at=v_row.granted_at+interval '10 minutes'
   where id=v_row.id;
   raise exception 'statement_write_window_expired';
 end if;

 if v_message ~* '(https?://|www\\.|discord\\.gg/|t\\.me/|wa\\.me/|bit\\.ly/)' then
   v_reason:='externer_link_oder_einladung';
 elsif v_message ~* '(spam|werbung|promo|kauf jetzt|click here|free money|gratis geld)' then
   v_reason:='werbung_oder_spam';
 elsif v_message ~* '(hurensohn|wichser|fotze|arschloch|fick dich|scheiss(e)? auf dich|idiot|depp|bastard|motherfucker|fuck you|asshole|shithead)' then
   v_reason:='beleidigender_inhalt';
 elsif v_message ~ '[!?]{8,}' or v_message ~ '(.)\\1\\1\\1\\1\\1\\1\\1' then
   v_reason:='stoerender_spam_inhalt';
 elsif char_length(regexp_replace(v_message,'\\s','','g'))<3 then
   v_reason:='inhalt_zu_kurz';
 end if;

 if v_reason is not null then
   update game.session_interjections
   set status='rejected',violation_reason=v_reason,reviewed_at=now(),text=v_message,
       expires_at=v_row.granted_at+interval '10 minutes'
   where id=v_row.id;

   insert into game.session_moderation_log(session_id,user_id,event_type,reason,content_snapshot)
   values(p_session_id,v_uid,'statement_rejected',v_reason,left(v_message,500));

   insert into game.session_statement_bans(user_id,banned_until,reason,updated_at)
   values(v_uid,now()+interval '30 minutes',v_reason,now())
   on conflict(user_id) do update
   set banned_until=greatest(game.session_statement_bans.banned_until,excluded.banned_until),
       reason=excluded.reason,updated_at=now();

   return query select 'rejected'::text,v_row.id,v_reason,v_row.granted_at+interval '10 minutes';
   return;
 end if;

 -- Keep the original slot end. Publishing does NOT start another ten minutes.
 v_expires:=v_row.granted_at+interval '10 minutes';

 update game.session_interjections
 set status='approved',text=v_message,published_at=now(),expires_at=v_expires,reviewed_at=now()
 where id=v_row.id;

 insert into game.session_event_log(
   session_id,event_type,title,description,actor_user_id,metadata
 )
 values(
   p_session_id,'statement_published','Statement veröffentlicht',
   'Ein Spieler hat das Wort erhalten und ein Statement veröffentlicht.',
   v_uid,jsonb_build_object('interjection_id',v_row.id,'expires_at',v_expires)
 );

 return query select 'approved'::text,v_row.id,null::text,v_expires;
end;
$function$;

create or replace function public.get_session_interjection_state(p_session_id uuid)
returns table(
 id uuid,user_id uuid,profile_name text,status text,message text,violation_reason text,
 requested_at timestamptz,granted_at timestamptz,published_at timestamptz,expires_at timestamptz,
 cooldown_until timestamptz,is_mine boolean
)
language plpgsql stable security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if not exists(select 1 from game.session_members m where m.session_id=p_session_id and m.user_id=v_uid and m.eliminated_at is null) then
   raise exception 'not_active_session_member';
 end if;

 return query
 select x.id,x.user_id,coalesce(p.profile_name,'Spieler'),x.status,x.text,x.violation_reason,
   x.requested_at,x.granted_at,x.published_at,x.expires_at,
   case when x.user_id=v_uid then (
     select max(i.published_at)+interval '10 minutes'
     from game.session_interjections i
     where i.session_id=p_session_id and i.user_id=v_uid and i.status='approved'
   ) else null end,
   x.user_id=v_uid
 from game.session_interjections x
 left join identity.profiles p on p.user_id=x.user_id
 where x.session_id=p_session_id
 and (
   x.status in ('pending','granted')
   or (x.status='approved' and x.expires_at>now())
   or (x.user_id=v_uid and x.status in ('rejected','expired') and x.requested_at>now()-interval '2 minutes')
 )
 order by
   case when x.status='granted' then 0 when x.status='approved' then 1 when x.status='pending' then 2 else 3 end,
   x.requested_at asc
 limit 30;
end;
$function$;
