create schema if not exists game;

create table if not exists game.session_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  display_name text not null,
  max_players integer not null default 30 check (max_players > 0),
  created_at timestamptz not null default now()
);

create table if not exists game.sessions (
  id uuid primary key default gen_random_uuid(),
  session_type_id uuid not null references game.session_types(id) on delete restrict,
  session_number integer not null,
  display_name text not null,
  max_players integer not null default 30 check (max_players > 0),
  player_count integer not null default 0 check (player_count >= 0 and player_count <= max_players),
  created_at timestamptz not null default now(),
  unique(session_type_id, session_number)
);

create table if not exists game.session_members (
  session_id uuid not null references game.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

create index if not exists sessions_type_open_idx
  on game.sessions(session_type_id, player_count, created_at);

alter table game.session_types enable row level security;
alter table game.sessions enable row level security;
alter table game.session_members enable row level security;

revoke all on schema game from anon;
grant usage on schema game to authenticated;
revoke all on game.session_types from anon, authenticated;
revoke all on game.sessions from anon, authenticated;
revoke all on game.session_members from anon, authenticated;
grant select on game.session_types to authenticated;
grant select on game.sessions to authenticated;
grant select on game.session_members to authenticated;

drop policy if exists session_types_select_authenticated on game.session_types;
create policy session_types_select_authenticated on game.session_types
for select to authenticated using (true);

drop policy if exists sessions_select_visible on game.sessions;
create policy sessions_select_visible on game.sessions
for select to authenticated
using (
  player_count < max_players
  or exists (
    select 1 from game.session_members sm
    where sm.session_id = sessions.id
      and sm.user_id = (select auth.uid())
  )
);

drop policy if exists session_members_select_own on game.session_members;
create policy session_members_select_own on game.session_members
for select to authenticated using (user_id = (select auth.uid()));

create or replace function game.next_session_number(p_type_id uuid)
returns integer language plpgsql security definer
set search_path = game, pg_catalog
as $$
declare n integer;
begin
  select coalesce(max(session_number), 0) + 1 into n
  from game.sessions where session_type_id = p_type_id;
  return n;
end;
$$;
revoke all on function game.next_session_number(uuid) from public, anon, authenticated;

create or replace function game.ensure_open_session(p_type_id uuid)
returns uuid language plpgsql security definer
set search_path = game, pg_catalog
as $$
declare
  v_session game.sessions%rowtype;
  v_type game.session_types%rowtype;
  v_number integer;
begin
  select * into v_type from game.session_types where id = p_type_id for update;
  if not found then raise exception 'session_type_not_found'; end if;

  select * into v_session from game.sessions
  where session_type_id = p_type_id and player_count < max_players
  order by session_number limit 1 for update;

  if found then return v_session.id; end if;

  v_number := game.next_session_number(p_type_id);
  insert into game.sessions(session_type_id, session_number, display_name, max_players)
  values (p_type_id, v_number, v_type.display_name || ' ' || lpad(v_number::text, 2, '0'), v_type.max_players)
  returning * into v_session;
  return v_session.id;
end;
$$;
revoke all on function game.ensure_open_session(uuid) from public, anon, authenticated;

create or replace function game.after_session_membership_change()
returns trigger language plpgsql security definer
set search_path = game, pg_catalog
as $$
declare
  v_session_id uuid;
  v_count integer;
  v_type_id uuid;
  v_max_players integer;
begin
  v_session_id := coalesce(new.session_id, old.session_id);
  select session_type_id, max_players into v_type_id, v_max_players
  from game.sessions where id = v_session_id for update;

  select count(*)::integer into v_count
  from game.session_members where session_id = v_session_id;

  update game.sessions set player_count = v_count where id = v_session_id;

  if v_count >= v_max_players then
    perform game.ensure_open_session(v_type_id);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_session_membership_change on game.session_members;
create trigger trg_session_membership_change
after insert or delete on game.session_members
for each row execute function game.after_session_membership_change();

create or replace function game.join_session(p_session_id uuid)
returns game.sessions language plpgsql security definer
set search_path = game, pg_catalog
as $$
declare
  v_session game.sessions%rowtype;
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_session from game.sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;

  if exists (
    select 1 from game.session_members
    where session_id = p_session_id and user_id = v_uid
  ) then return v_session; end if;

  if v_session.player_count >= v_session.max_players then
    raise exception 'session_full';
  end if;

  insert into game.session_members(session_id, user_id) values (p_session_id, v_uid);
  select * into v_session from game.sessions where id = p_session_id;
  return v_session;
end;
$$;
revoke all on function game.join_session(uuid) from public, anon, authenticated;
grant execute on function game.join_session(uuid) to authenticated;

create or replace function game.leave_session(p_session_id uuid)
returns void language plpgsql security definer
set search_path = game, pg_catalog
as $$
begin
  if (select auth.uid()) is null then raise exception 'not_authenticated'; end if;
  delete from game.session_members
  where session_id = p_session_id and user_id = (select auth.uid());
end;
$$;
revoke all on function game.leave_session(uuid) from public, anon, authenticated;
grant execute on function game.leave_session(uuid) to authenticated;

create or replace function public.get_my_sessions()
returns table (id uuid, display_name text, player_count integer, max_players integer, created_at timestamptz)
language sql security definer set search_path = pg_catalog
as $$
  select s.id, s.display_name, s.player_count, s.max_players, s.created_at
  from game.sessions s join game.session_members sm on sm.session_id = s.id
  where sm.user_id = (select auth.uid()) order by s.display_name;
$$;

create or replace function public.get_public_sessions()
returns table (id uuid, display_name text, player_count integer, max_players integer, created_at timestamptz)
language sql security definer set search_path = pg_catalog
as $$
  select s.id, s.display_name, s.player_count, s.max_players, s.created_at
  from game.sessions s where s.player_count < s.max_players order by s.display_name;
$$;

create or replace function public.join_session(p_session_id uuid)
returns game.sessions language plpgsql security definer set search_path = game, pg_catalog
as $$
begin
  if (select auth.uid()) is null then raise exception 'not_authenticated'; end if;
  return game.join_session(p_session_id);
end;
$$;

create or replace function public.leave_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = game, pg_catalog
as $$
begin
  if (select auth.uid()) is null then raise exception 'not_authenticated'; end if;
  perform game.leave_session(p_session_id);
end;
$$;

revoke all on function public.get_my_sessions() from public, anon;
revoke all on function public.get_public_sessions() from public, anon;
revoke all on function public.join_session(uuid) from public, anon;
revoke all on function public.leave_session(uuid) from public, anon;
grant execute on function public.get_my_sessions() to authenticated;
grant execute on function public.get_public_sessions() to authenticated;
grant execute on function public.join_session(uuid) to authenticated;
grant execute on function public.leave_session(uuid) to authenticated;

insert into game.session_types(code, display_name, max_players)
values ('landtag', 'Landtag', 30), ('bundestag', 'Bundestag', 30)
on conflict (code) do update set display_name=excluded.display_name, max_players=excluded.max_players;

do $$
declare t record;
begin
  for t in select id from game.session_types loop
    perform game.ensure_open_session(t.id);
  end loop;
end $$;
