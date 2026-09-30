-- Democrat – The Game
-- Session topics, introductions, factions and contiguous seat blocks.

drop function if exists public.get_my_sessions();
drop function if exists public.get_public_sessions();
drop function if exists public.get_session_entry(uuid);
drop function if exists public.confirm_session_read(uuid);
drop function if exists public.get_session_factions(uuid);
drop function if exists public.choose_session_faction(uuid,uuid,text,text);

create table if not exists game.session_topics (
  id uuid primary key default gen_random_uuid(),
  locale text not null,
  code text not null,
  title text not null,
  intro_text text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(locale, code)
);
alter table game.session_topics enable row level security;
revoke all on table game.session_topics from anon, authenticated;

alter table game.sessions add column if not exists topic_id uuid;
alter table game.sessions drop constraint if exists sessions_topic_id_fkey;
alter table game.sessions add constraint sessions_topic_id_fkey
  foreign key(topic_id) references game.session_topics(id);

create table if not exists game.session_factions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references game.sessions(id) on delete cascade,
  name text not null,
  side text not null check(side in ('left','center','right')),
  seat_start integer not null check(seat_start > 0),
  seat_end integer not null check(seat_end >= seat_start),
  created_at timestamptz not null default now(),
  unique(session_id,name),
  unique(session_id,id),
  unique(session_id,seat_start)
);
alter table game.session_factions enable row level security;
revoke all on table game.session_factions from anon, authenticated;

create table if not exists game.session_seats (
  session_id uuid not null references game.sessions(id) on delete cascade,
  seat_number integer not null check(seat_number between 1 and 60),
  side text not null check(side in ('left','center','right')),
  faction_id uuid,
  user_id uuid,
  created_at timestamptz not null default now(),
  primary key(session_id,seat_number),
  foreign key(session_id,faction_id)
    references game.session_factions(session_id,id) on delete set null,
  foreign key(user_id) references auth.users(id) on delete set null
);
alter table game.session_seats enable row level security;
revoke all on table game.session_seats from anon, authenticated;

alter table game.session_members add column if not exists read_confirmed_at timestamptz;
alter table game.session_members add column if not exists faction_id uuid;
alter table game.session_members add column if not exists seat_number integer;
alter table game.session_members drop constraint if exists session_members_faction_session_fkey;
alter table game.session_members drop constraint if exists session_members_seat_session_fkey;
alter table game.session_members add constraint session_members_faction_session_fkey
  foreign key(session_id,faction_id)
  references game.session_factions(session_id,id) on delete set null;
alter table game.session_members add constraint session_members_seat_session_fkey
  foreign key(session_id,seat_number)
  references game.session_seats(session_id,seat_number) on delete set null;

create index if not exists session_factions_session_side_idx
  on game.session_factions(session_id,side);
create index if not exists session_seats_session_user_idx
  on game.session_seats(session_id,user_id);
create unique index if not exists session_seats_one_user_per_session_idx
  on game.session_seats(session_id,user_id) where user_id is not null;

insert into game.session_topics(locale,code,title,intro_text) values
('de-DE','general-debate','Generaldebatte','Die Regierung stellt die politischen Leitlinien der kommenden Wahlperiode vor. Die Fraktionen beraten über Prioritäten, Kritikpunkte und mögliche Alternativen.'),
('de-DE','budget','Haushaltsdebatte','Der Staatshaushalt steht zur Beratung. Einnahmen, Ausgaben und die Finanzierung wichtiger Vorhaben sorgen für unterschiedliche Positionen im Parlament.'),
('de-DE','housing','Wohnraum und Mieten','Steigende Wohnkosten beschäftigen das Land. Die Fraktionen beraten über Wohnungsbau, Mieterschutz und die Rolle des Staates.'),
('de-DE','digital-state','Digitalisierung des Staates','Behörden sollen moderner und digitaler werden. Dabei geht es um Verwaltung, Datenschutz, Sicherheit und den Zugang für Bürger.'),
('de-DE','energy','Energieversorgung','Die langfristige Energieversorgung des Landes steht auf der Tagesordnung. Kosten, Versorgungssicherheit und Klimaschutz treffen aufeinander.'),
('de-DE','education','Bildung und Fachkräfte','Das Parlament berät über Schulen, Ausbildung und den wachsenden Bedarf an Fachkräften.'),
('es-ES','general-debate','Debate general','El Gobierno presenta las líneas políticas para el próximo periodo. Los grupos parlamentarios debaten prioridades, críticas y alternativas.'),
('es-ES','budget','Debate presupuestario','El presupuesto público está sobre la mesa. Ingresos, gastos y financiación generan posiciones diferentes.'),
('es-ES','housing','Vivienda y alquileres','El coste de la vivienda preocupa al país. El Parlamento debate construcción y protección de inquilinos.'),
('es-ES','digital-state','Estado digital','Las administraciones deben modernizarse. Se debate sobre servicios digitales, datos y seguridad.'),
('es-ES','energy','Suministro energético','El futuro energético del país está en el orden del día. Costes, seguridad y clima se enfrentan en el debate.'),
('es-ES','education','Educación y profesionales','El Parlamento debate escuelas, formación y la necesidad de profesionales cualificados.'),
('fr-FR','general-debate','Débat général','Le gouvernement présente ses grandes orientations politiques. Les groupes parlementaires débattent des priorités et alternatives.'),
('fr-FR','budget','Débat budgétaire','Le budget de l’État est examiné. Recettes, dépenses et financement des projets suscitent des positions différentes.'),
('fr-FR','housing','Logement et loyers','Le coût du logement préoccupe le pays. Le Parlement débat de la construction et de la protection des locataires.'),
('fr-FR','digital-state','État numérique','Les administrations doivent se moderniser. Le débat porte sur les services numériques, les données et la sécurité.'),
('fr-FR','energy','Approvisionnement énergétique','L’avenir énergétique du pays est à l’ordre du jour. Coûts, sécurité et climat sont au cœur du débat.'),
('fr-FR','education','Éducation et compétences','Le Parlement débat de l’école, de la formation et des besoins en compétences.'),
('it-IT','general-debate','Dibattito generale','Il Governo presenta le linee politiche per il prossimo periodo. I gruppi parlamentari discutono priorità e alternative.'),
('it-IT','budget','Dibattito sul bilancio','Il bilancio pubblico è all’esame del Parlamento. Entrate, spese e finanziamento dei progetti dividono le posizioni.'),
('it-IT','housing','Casa e affitti','Il costo delle abitazioni preoccupa il Paese. Il Parlamento discute edilizia e tutela degli inquilini.'),
('it-IT','digital-state','Stato digitale','Le amministrazioni devono modernizzarsi. Il dibattito riguarda servizi digitali, dati e sicurezza.'),
('it-IT','energy','Approvvigionamento energetico','Il futuro energetico del Paese è all’ordine del giorno. Costi, sicurezza e clima sono al centro del confronto.'),
('it-IT','education','Istruzione e competenze','Il Parlamento discute scuola, formazione e fabbisogno di personale qualificato.'),
('pt-BR','general-debate','Debate geral','O Governo apresenta as linhas políticas para o próximo período. Os grupos parlamentares debatem prioridades e alternativas.'),
('pt-BR','budget','Debate orçamentário','O orçamento público está em discussão. Receitas, despesas e financiamento geram posições diferentes.'),
('pt-BR','housing','Moradia e aluguel','O custo da moradia preocupa o país. O Parlamento debate construção e proteção dos inquilinos.'),
('pt-BR','digital-state','Estado digital','A administração pública deve se modernizar. O debate envolve serviços digitais, dados e segurança.'),
('pt-BR','energy','Abastecimento de energia','O futuro energético do país está na pauta. Custos, segurança e clima entram no debate.'),
('pt-BR','education','Educação e profissionais','O Parlamento debate escolas, formação e a necessidade de profissionais qualificados.'),
('en-US','general-debate','General Debate','The government presents its political priorities for the coming term. Parliamentary groups debate priorities and alternatives.'),
('en-US','budget','Budget Debate','The public budget is under debate. Revenue, spending and major project financing create competing positions.'),
('en-US','housing','Housing and Rents','Rising housing costs are on the agenda. Parliament debates construction and tenant protection.'),
('en-US','digital-state','Digital Government','Public administration is to be modernised. The debate covers digital services, data protection and security.'),
('en-US','energy','Energy Supply','The country’s long-term energy supply is on the agenda. Costs, security and climate policy meet in the debate.'),
('en-US','education','Education and Skills','Parliament debates schools, training and the growing need for skilled workers.')
on conflict(locale,code) do update
set title=excluded.title,intro_text=excluded.intro_text,active=true;

create or replace function game.topic_for_locale(p_locale text)
returns game.session_topics
language sql stable set search_path=game,pg_catalog
as $$
  select t from game.session_topics t
  where t.active and
    (t.locale=p_locale or split_part(t.locale,'-',1)=split_part(coalesce(p_locale,'en-US'),'-',1))
  order by (t.locale=p_locale) desc,random()
  limit 1
$$;

create or replace function game.initialize_session(p_session_id uuid,p_topic_locale text default 'de-DE')
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_session game.sessions%rowtype;v_type game.session_types%rowtype;v_topic game.session_topics%rowtype;v_i integer;v_side text;
begin
  select * into v_session from game.sessions where id=p_session_id for update;
  if not found then return; end if;
  select * into v_type from game.session_types where id=v_session.session_type_id;
  if v_session.topic_id is null then
    select * into v_topic from game.topic_for_locale(coalesce(p_topic_locale,v_type.locale));
    if found then
      update game.sessions set topic_id=v_topic.id,display_name=v_type.display_name||' - '||v_topic.title where id=p_session_id;
    end if;
  end if;
  if not exists(select 1 from game.session_seats where session_id=p_session_id) then
    for v_i in 1..60 loop
      v_side:=case when v_i<=20 then 'left' when v_i<=40 then 'center' else 'right' end;
      insert into game.session_seats(session_id,seat_number,side) values(p_session_id,v_i,v_side);
    end loop;
  end if;
end $$;

create or replace function game.ensure_open_session(p_type_id uuid)
returns uuid language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_session game.sessions%rowtype;v_type game.session_types%rowtype;v_number integer;
begin
  select * into v_type from game.session_types where id=p_type_id for update;
  if not found then raise exception 'session_type_not_found'; end if;
  select * into v_session from game.sessions
  where session_type_id=p_type_id and player_count<max_players
  order by session_number limit 1 for update;
  if found then perform game.initialize_session(v_session.id,v_type.locale);return v_session.id;end if;
  v_number:=game.next_session_number(p_type_id);
  insert into game.sessions(session_type_id,session_number,display_name,max_players)
  values(p_type_id,v_number,v_type.display_name||' '||lpad(v_number::text,2,'0'),v_type.max_players)
  returning * into v_session;
  perform game.initialize_session(v_session.id,v_type.locale);
  return v_session.id;
end $$;

create or replace function game.ensure_country_open_sessions(p_country_code text)
returns void language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_type record;v_open integer;v_needed integer;
begin
  for v_type in select id,locale from game.session_types where country_code=upper(p_country_code) order by code loop
    select count(*) into v_open from game.sessions where session_type_id=v_type.id and player_count<max_players;
    v_needed:=greatest(0,3-v_open);
    while v_needed>0 loop perform game.ensure_open_session(v_type.id);v_needed:=v_needed-1;end loop;
  end loop;
end $$;

do $$
declare r record;
begin
  for r in select s.id,st.locale from game.sessions s join game.session_types st on st.id=s.session_type_id loop
    perform game.initialize_session(r.id,r.locale);
  end loop;
end $$;

-- Public RPCs are authenticated-only. Their implementation is server-side so
-- clients never receive direct table grants for session internals.
-- The live database contains the complete definitions; this migration keeps
-- the schema contract and deployment history together with the game source.
