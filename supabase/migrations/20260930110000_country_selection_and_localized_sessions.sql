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
