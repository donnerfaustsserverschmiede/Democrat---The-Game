-- Speech-driven persuasion for neutral bots during the one-hour topic.
-- Exact speech transcripts are not persisted; only argument direction/strength is stored.
create table if not exists game.session_bot_persuasion (
  statement_id uuid not null references game.session_statements(id) on delete cascade,
  bot_id uuid not null references game.session_bots(id) on delete cascade,
  persuasion_score integer not null default 0,
  argument_count integer not null default 0,
  last_argument_at timestamptz,
  last_speaker_user_id uuid,
  updated_at timestamptz not null default now(),
  primary key(statement_id,bot_id)
);
create index if not exists idx_session_bot_persuasion_statement on game.session_bot_persuasion(statement_id);

create table if not exists game.session_speech_arguments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references game.sessions(id) on delete cascade,
  statement_id uuid not null references game.session_statements(id) on delete cascade,
  slot_id uuid not null references game.session_speech_slots(id) on delete cascade,
  speaker_user_id uuid not null references auth.users(id) on delete cascade,
  argument_direction smallint not null check(argument_direction in (-1,1)),
  argument_strength smallint not null check(argument_strength between 1,5),
  created_at timestamptz not null default now()
);
create index if not exists idx_session_speech_arguments_statement on game.session_speech_arguments(statement_id,created_at);

alter table game.session_bot_persuasion enable row level security;
alter table game.session_speech_arguments enable row level security;
revoke all on table game.session_bot_persuasion from anon,authenticated;
revoke all on table game.session_speech_arguments from anon,authenticated;

CREATE OR REPLACE FUNCTION public.record_session_speech_argument(p_session_id uuid, p_slot_id uuid, p_text text)
 RETURNS TABLE(accepted boolean, direction smallint, strength smallint, affected_bots integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_slot game.session_speech_slots%rowtype;
  v_statement game.session_statements%rowtype;
  v_member game.session_members%rowtype;
  v_text text:=lower(trim(coalesce(p_text,'')));
  v_positive integer:=0;
  v_negative integer:=0;
  v_direction smallint;
  v_strength smallint;
  v_now timestamptz:=now();
  v_affected integer:=0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if length(v_text)<4 then return query select false,0::smallint,0::smallint,0; return; end if;

  select * into v_slot
  from game.session_speech_slots
  where id=p_slot_id and session_id=p_session_id and speaker_user_id=v_uid and status='active'
  for update;
  if not found then raise exception 'speech_slot_not_active'; end if;
  if v_slot.expires_at<=v_now then raise exception 'speech_slot_expired'; end if;

  select st.* into v_statement
  from game.session_statements st
  where st.session_id=p_session_id and st.status='open'
  order by st.statement_number desc limit 1;
  if not found then raise exception 'no_active_statement'; end if;

  select * into v_member
  from game.session_members
  where session_id=p_session_id and user_id=v_uid and eliminated_at is null;
  if not found then raise exception 'not_session_member'; end if;

  if exists(select 1 from game.session_speech_arguments a where a.statement_id=v_statement.id and a.speaker_user_id=v_uid and a.created_at>v_now-interval '4 seconds') then
    return query select false,0::smallint,0::smallint,0; return;
  end if;

  v_positive :=
      (length(v_text)-length(replace(v_text,'dafür','')))/5
    + (length(v_text)-length(replace(v_text,'zustimm','')))/6
    + (length(v_text)-length(replace(v_text,'unterstütz','')))/11
    + (length(v_text)-length(replace(v_text,'verbess','')))/7
    + (length(v_text)-length(replace(v_text,'stärk','')))/6
    + (length(v_text)-length(replace(v_text,'schaff','')))/6
    + (length(v_text)-length(replace(v_text,'entlast','')))/7
    + (length(v_text)-length(replace(v_text,'spart','')))/5
    + (length(v_text)-length(replace(v_text,'vorteil','')))/7
    + (length(v_text)-length(replace(v_text,'chance','')))/6
    + (length(v_text)-length(replace(v_text,'gerecht','')))/7
    + (length(v_text)-length(replace(v_text,'sicher','')))/6
    + (length(v_text)-length(replace(v_text,'effizient','')))/9
    + (length(v_text)-length(replace(v_text,'modern','')))/6
    + (length(v_text)-length(replace(v_text,'arbeitsplätz','')))/12
    + (length(v_text)-length(replace(v_text,'fördert','')))/7
    + (length(v_text)-length(replace(v_text,'erleichtert','')))/11
    + (length(v_text)-length(replace(v_text,'notwendig','')))/10
    + (length(v_text)-length(replace(v_text,'sinnvoll','')))/9;
  v_negative :=
      (length(v_text)-length(replace(v_text,'dagegen','')))/7
    + (length(v_text)-length(replace(v_text,'ablehn','')))/6
    + (length(v_text)-length(replace(v_text,'schadet','')))/7
    + (length(v_text)-length(replace(v_text,'belast','')))/7
    + (length(v_text)-length(replace(v_text,'kostet','')))/6
    + (length(v_text)-length(replace(v_text,'risiko','')))/6
    + (length(v_text)-length(replace(v_text,'gefähr','')))/7
    + (length(v_text)-length(replace(v_text,'ungerecht','')))/9
    + (length(v_text)-length(replace(v_text,'bürokr','')))/7
    + (length(v_text)-length(replace(v_text,'überwach','')))/8
    + (length(v_text)-length(replace(v_text,'freiheits','')))/9
    + (length(v_text)-length(replace(v_text,'steuer','')))/6
    + (length(v_text)-length(replace(v_text,'schulden','')))/7
    + (length(v_text)-length(replace(v_text,'nachteil','')))/8
    + (length(v_text)-length(replace(v_text,'problem','')))/7
    + (length(v_text)-length(replace(v_text,'unnöt','')))/7
    + (length(v_text)-length(replace(v_text,'ineffiz','')))/8
    + (length(v_text)-length(replace(v_text,'falsch','')))/6
    + (length(v_text)-length(replace(v_text,'teuer','')))/5
    + (length(v_text)-length(replace(v_text,'einschränk','')))/10
    + (length(v_text)-length(replace(v_text,'verhindert','')))/10;

  if v_positive=v_negative then
    if v_text~'(^|[^a-zäöüß])(ja|wir sollten|ich bin dafür)([^a-zäöüß]|$)' then v_direction:=1;
    elsif v_text~'(^|[^a-zäöüß])(nein|wir sollten nicht|ich bin dagegen)([^a-zäöüß]|$)' then v_direction:=-1;
    else return query select false,0::smallint,0::smallint,0; return; end if;
  else
    v_direction:=case when v_positive>v_negative then 1 else -1 end;
  end if;

  v_strength:=least(5,greatest(1,abs(v_positive-v_negative)+case when length(v_text)>=120 then 1 else 0 end+case when length(v_text)>=260 then 1 else 0 end));

  insert into game.session_speech_arguments(session_id,statement_id,slot_id,speaker_user_id,argument_direction,argument_strength)
  values(p_session_id,v_statement.id,p_slot_id,v_uid,v_direction,v_strength);

  with neutral_bots as (
    select b.id
    from game.session_bots b
    join game.session_seats ss on ss.session_id=b.session_id and ss.seat_number=b.seat_number
    where b.session_id=p_session_id and ss.faction_id is null
      and not exists(select 1 from game.session_bot_votes bv where bv.statement_id=v_statement.id and bv.bot_id=b.id)
  )
  insert into game.session_bot_persuasion(statement_id,bot_id,persuasion_score,argument_count,last_argument_at,last_speaker_user_id,updated_at)
  select v_statement.id,nb.id,v_direction*v_strength,1,v_now,v_uid,v_now from neutral_bots nb
  on conflict(statement_id,bot_id) do update set
    persuasion_score=greatest(-20,least(20,game.session_bot_persuasion.persuasion_score+excluded.persuasion_score)),
    argument_count=game.session_bot_persuasion.argument_count+1,last_argument_at=excluded.last_argument_at,
    last_speaker_user_id=excluded.last_speaker_user_id,updated_at=excluded.updated_at;
  get diagnostics v_affected=row_count;
  return query select true,v_direction,v_strength,v_affected;
end
$function$

revoke execute on function public.record_session_speech_argument(uuid,uuid,text) from public;
grant execute on function public.record_session_speech_argument(uuid,uuid,text) to authenticated;

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

revoke execute on function game.ensure_session_bot_votes(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function game.ensure_session_bot_votes(uuid,uuid,boolean) to authenticated;
