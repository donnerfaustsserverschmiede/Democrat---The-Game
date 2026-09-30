-- Country selection, localized game language, and country-specific political sessions.
-- Applied to Supabase project vjiqloioablknekaykgw.

create table if not exists game.countries (
  code text primary key check (code = upper(code) and char_length(code) = 2),
  display_name text not null,
  locale text not null,
  language_name text not null,
  government_name text not null,
  created_at timestamptz not null default now()
);

alter table game.countries enable row level security;
revoke all on game.countries from anon, authenticated;
grant select on game.countries to authenticated;
create policy countries_select_authenticated on game.countries for select to authenticated using (true);

insert into game.countries (code,display_name,locale,language_name,government_name) values
('DE','Deutschland','de-DE','Deutsch','Bundesrepublik Deutschland'),
('ES','España','es-ES','Español','Monarquía parlamentaria'),
('FR','France','fr-FR','Français','République'),
('IT','Italia','it-IT','Italiano','Repubblica parlamentare'),
('US','United States','en-US','English','Federal republic'),
('GB','United Kingdom','en-GB','English','Constitutional monarchy'),
('AT','Österreich','de-AT','Deutsch','Parlamentarische Republik'),
('CH','Schweiz','de-CH','Deutsch','Föderale Republik'),
('CA','Canada','en-CA','English','Federal parliamentary monarchy'),
('AU','Australia','en-AU','English','Federal parliamentary monarchy'),
('BR','Brasil','pt-BR','Português','República federativa'),
('MX','México','es-MX','Español','República federal')
on conflict (code) do update set display_name=excluded.display_name,locale=excluded.locale,language_name=excluded.language_name,government_name=excluded.government_name;

alter table identity.profiles add column if not exists country_code text, add column if not exists locale text;
alter table identity.profiles drop constraint if exists profiles_country_code_fkey;
alter table identity.profiles add constraint profiles_country_code_fkey foreign key (country_code) references game.countries(code);

alter table game.session_types add column if not exists country_code text, add column if not exists locale text;
update game.session_types set country_code='DE',locale='de-DE' where country_code is null;
alter table game.session_types drop constraint if exists session_types_country_code_fkey;
alter table game.session_types add constraint session_types_country_code_fkey foreign key (country_code) references game.countries(code);
alter table game.session_types drop constraint if exists session_types_code_key;
alter table game.session_types add constraint session_types_country_code_code_key unique (country_code,code);

delete from game.session_types
where country_code='DE' and code in ('lower','upper')
and not exists (select 1 from game.sessions s where s.session_type_id=game.session_types.id);
update game.session_types set code='lower',display_name='Landtag' where country_code='DE' and code='landtag';
update game.session_types set code='upper',display_name='Bundestag' where country_code='DE' and code='bundestag';

insert into game.session_types (code,display_name,max_players,country_code,locale) values
('lower','Landtag',30,'DE','de-DE'),('upper','Bundestag',30,'DE','de-DE'),
('lower','Congreso de los Diputados',30,'ES','es-ES'),('upper','Senado',30,'ES','es-ES'),
('lower','Assemblée nationale',30,'FR','fr-FR'),('upper','Sénat',30,'FR','fr-FR'),
('lower','Camera dei deputati',30,'IT','it-IT'),('upper','Senato della Repubblica',30,'IT','it-IT'),
('lower','House of Representatives',30,'US','en-US'),('upper','Senate',30,'US','en-US'),
('lower','House of Commons',30,'GB','en-GB'),('upper','House of Lords',30,'en-GB'),
('lower','Landtag',30,'AT','de-AT'),('upper','Nationalrat',30,'AT','de-AT'),
('lower','Nationalrat',30,'CH','de-CH'),('upper','Ständerat',30,'CH','de-CH'),
('lower','House of Commons',30,'CA','en-CA'),('upper','Senate',30,'CA','en-CA'),
('lower','House of Representatives',30,'AU','en-AU'),('upper','Senate',30,'en-AU'),
('lower','Câmara dos Deputados',30,'BR','pt-BR'),('upper','Senado Federal',30,'pt-BR'),
('lower','Cámara de Diputados',30,'MX','es-MX'),('upper','Senado de la República',30,'es-MX')
on conflict (country_code,code) do update set display_name=excluded.display_name,max_players=excluded.max_players,locale=excluded.locale;

alter table game.session_types alter column country_code set not null;
alter table game.session_types alter column locale set not null;

-- RPCs are intentionally authenticated-only. The read/update helpers use SECURITY DEFINER
-- because identity is a private schema and session data is filtered by the caller's profile.


create or replace function public.get_available_countries()
returns table(code text,display_name text,locale text,language_name text,government_name text)
language sql security invoker stable set search_path=game,pg_catalog
as $$ select code,display_name,locale,language_name,government_name from game.countries order by display_name $$;
revoke all on function public.get_available_countries() from public,anon,authenticated;
grant execute on function public.get_available_countries() to authenticated;

create or replace function public.get_country_preferences()
returns table(country_code text,locale text,display_name text,language_name text)
language sql security definer stable set search_path=identity,game,pg_catalog
as $$ select p.country_code,p.locale,c.display_name,c.language_name from identity.profiles p left join game.countries c on c.code=p.country_code where p.user_id=(select auth.uid()) $$;
revoke all on function public.get_country_preferences() from public,anon,authenticated;
grant execute on function public.get_country_preferences() to authenticated;

create or replace function game.ensure_country_open_sessions(p_country_code text)
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_type record;
begin
  for v_type in select id from game.session_types where country_code=upper(p_country_code) loop
    perform game.ensure_open_session(v_type.id);
  end loop;
end $$;
revoke all on function game.ensure_country_open_sessions(text) from public;

create or replace function public.set_country_preferences(p_country_code text)
returns table(country_code text,locale text,display_name text,language_name text)
language plpgsql security definer set search_path=identity,game,pg_catalog
as $$
declare v_country game.countries%rowtype; v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_country from game.countries where code=upper(trim(p_country_code));
  if not found then raise exception 'country_not_supported'; end if;
  update identity.profiles set country_code=v_country.code,locale=v_country.locale,updated_at=now() where user_id=v_uid;
  if not found then raise exception 'profile_not_found'; end if;
  perform game.ensure_country_open_sessions(v_country.code);
  return query select v_country.code,v_country.locale,v_country.display_name,v_country.language_name;
end $$;
revoke all on function public.set_country_preferences(text) from public,anon,authenticated;
grant execute on function public.set_country_preferences(text) to authenticated;

drop function if exists public.get_my_sessions();
create or replace function public.get_my_sessions()
returns table(id uuid,display_name text,player_count integer,max_players integer,created_at timestamptz,country_code text,locale text,session_code text)
language sql security definer stable set search_path=game,identity,pg_catalog
as $$ select s.id,s.display_name,s.player_count,s.max_players,s.created_at,st.country_code,st.locale,st.code from game.sessions s join game.session_members sm on sm.session_id=s.id join game.session_types st on st.id=s.session_type_id join identity.profiles p on p.user_id=(select auth.uid()) where sm.user_id=(select auth.uid()) and st.country_code=p.country_code order by s.display_name $$;
revoke all on function public.get_my_sessions() from public,anon,authenticated;
grant execute on function public.get_my_sessions() to authenticated;

drop function if exists public.get_public_sessions();
create or replace function public.get_public_sessions()
returns table(id uuid,display_name text,player_count integer,max_players integer,created_at timestamptz,country_code text,locale text,session_code text)
language sql security definer stable set search_path=game,identity,pg_catalog
as $$ select s.id,s.display_name,s.player_count,s.max_players,s.created_at,st.country_code,st.locale,st.code from game.sessions s join game.session_types st on st.id=s.session_type_id join identity.profiles p on p.user_id=(select auth.uid()) where s.player_count<s.max_players and st.country_code=p.country_code order by s.display_name $$;
revoke all on function public.get_public_sessions() from public,anon,authenticated;
grant execute on function public.get_public_sessions() to authenticated;

create or replace function game.join_session(p_session_id uuid)
returns game.sessions language plpgsql security definer set search_path=game,identity,pg_catalog
as $$
declare v_session game.sessions%rowtype; v_uid uuid := (select auth.uid()); v_country text; v_session_country text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select country_code into v_country from identity.profiles where user_id=v_uid;
  if v_country is null then raise exception 'country_selection_required'; end if;
  select s.* into v_session from game.sessions s where s.id=p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select country_code into v_session_country from game.session_types where id=v_session.session_type_id;
  if v_session_country<>v_country then raise exception 'wrong_country_session'; end if;
  if exists(select 1 from game.session_members where session_id=p_session_id and user_id=v_uid) then return v_session; end if;
  if v_session.player_count>=v_session.max_players then raise exception 'session_full'; end if;
  insert into game.session_members(session_id,user_id) values(p_session_id,v_uid);
  select * into v_session from game.sessions where id=p_session_id;
  return v_session;
end $$;
revoke all on function game.join_session(uuid) from public;

drop function if exists public.join_session(uuid);
create or replace function public.join_session(p_session_id uuid)
returns game.sessions language plpgsql security invoker set search_path=game,pg_catalog
as $$ begin if (select auth.uid()) is null then raise exception 'not_authenticated'; end if; return game.join_session(p_session_id); end $$;
revoke all on function public.join_session(uuid) from public,anon,authenticated;
grant execute on function public.join_session(uuid) to authenticated;
