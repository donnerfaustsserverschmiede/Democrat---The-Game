-- Preserve permanent opinion-point history when a completed session is deleted.
alter table identity.player_decision_points
  drop constraint if exists player_decision_points_session_id_fkey,
  drop constraint if exists player_decision_points_statement_id_fkey;

alter table identity.player_decision_points
  alter column session_id drop not null;

create or replace function public.finalize_ended_session(p_session_id uuid)
returns table(points_earned integer,total_points integer)
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_status text;
  v_earned integer:=0;
  v_total integer:=0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  perform pg_advisory_xact_lock(hashtext(p_session_id::text));

  select s.status into v_status
  from game.sessions s
  where s.id=p_session_id
  for update;

  if v_status is null then
    return query select 0,coalesce((select p.points from identity.profiles p where p.user_id=v_uid),0);
    return;
  end if;

  if not exists(
    select 1 from game.session_members m
    where m.session_id=p_session_id and m.user_id=v_uid
  ) then raise exception 'not_session_member'; end if;

  if v_status<>'ended' then raise exception 'session_not_ended'; end if;

  insert into identity.player_decision_points(
    user_id,statement_id,session_id,points,created_at
  )
  select
    v.user_id,v.statement_id,v.session_id,
    case
      when abs(coalesce(s.citizen_impact,0)) between 0 and 3 then 1
      when abs(coalesce(s.citizen_impact,0)) between 4 and 7 then 2
      else 3
    end,
    coalesce(v.created_at,now())
  from game.session_votes v
  join game.session_statements s on s.id=v.statement_id
  where v.session_id=p_session_id
  on conflict(user_id,statement_id) do nothing;

  select coalesce(sum(d.points),0)::integer
  into v_earned
  from identity.player_decision_points d
  where d.user_id=v_uid and d.session_id=p_session_id;

  update identity.profiles p
  set points=coalesce((
    select sum(d.points)::integer
    from identity.player_decision_points d
    where d.user_id=p.user_id
  ),0),
  updated_at=now()
  where p.user_id in (
    select distinct m.user_id
    from game.session_members m
    where m.session_id=p_session_id
  );

  select coalesce(p.points,0) into v_total
  from identity.profiles p where p.user_id=v_uid;

  delete from game.sessions where id=p_session_id;

  return query select v_earned,v_total;
end;
$$;
