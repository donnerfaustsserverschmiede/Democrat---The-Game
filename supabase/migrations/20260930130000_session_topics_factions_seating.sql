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
  references game.session_factions(session_id,id)
    on delete set null (faction_id);
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
declare v_type record;v_open integer;v_number integer;v_session game.sessions%rowtype;
begin
  for v_type in
    select id,locale,max_players,display_name
    from game.session_types where country_code=upper(p_country_code) order by code
  loop
    select count(*) into v_open from game.sessions
    where session_type_id=v_type.id and player_count<max_players;
    while v_open<3 loop
      v_number:=game.next_session_number(v_type.id);
      insert into game.sessions(session_type_id,session_number,display_name,max_players)
      values(v_type.id,v_number,v_type.display_name||' '||lpad(v_number::text,2,'0'),v_type.max_players)
      returning * into v_session;
      perform game.initialize_session(v_session.id,v_type.locale);
      v_open:=v_open+1;
    end loop;
  end loop;
end $$;
do $$
declare r record;
begin
  for r in select s.id,st.locale from game.sessions s join game.session_types st on st.id=s.session_type_id loop
    perform game.initialize_session(r.id,r.locale);
  end loop;
end $$;


create function public.get_my_sessions()
returns table(id uuid,display_name text,player_count integer,max_players integer,created_at timestamptz,country_code text,locale text,session_code text,topic_title text,topic_intro text,read_confirmed boolean,faction_name text,faction_side text,seat_number integer)
language sql stable security definer set search_path=game,identity,pg_catalog
as $$
  select s.id,s.display_name,s.player_count,s.max_players,s.created_at,st.country_code,st.locale,st.code,
         t.title,t.intro_text,(sm.read_confirmed_at is not null),f.name,f.side,sm.seat_number
  from game.sessions s
  join game.session_members sm on sm.session_id=s.id
  join game.session_types st on st.id=s.session_type_id
  join identity.profiles p on p.user_id=(select auth.uid())
  left join game.session_topics t on t.id=s.topic_id
  left join game.session_factions f on f.id=sm.faction_id
  where sm.user_id=(select auth.uid()) and st.country_code=p.country_code
  order by s.created_at desc
$$;

create function public.get_public_sessions()
returns table(id uuid,display_name text,player_count integer,max_players integer,created_at timestamptz,country_code text,locale text,session_code text,topic_title text,topic_intro text)
language sql stable security definer set search_path=game,identity,pg_catalog
as $$
  select s.id,s.display_name,s.player_count,s.max_players,s.created_at,st.country_code,st.locale,st.code,t.title,t.intro_text
  from game.sessions s
  join game.session_types st on st.id=s.session_type_id
  join identity.profiles p on p.user_id=(select auth.uid())
  left join game.session_topics t on t.id=s.topic_id
  where s.player_count<s.max_players and st.country_code=p.country_code
  order by s.created_at asc
$$;

create function public.get_session_entry(p_session_id uuid)
returns table(id uuid,display_name text,chamber_name text,topic_title text,topic_intro text,player_count integer,max_players integer,read_confirmed boolean,faction_id uuid,faction_name text,faction_side text,seat_number integer)
language plpgsql security definer set search_path=game,identity,pg_catalog
as $$
declare v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return query
    select s.id,s.display_name,st.display_name,t.title,t.intro_text,s.player_count,s.max_players,
           (sm.read_confirmed_at is not null),sm.faction_id,f.name,f.side,sm.seat_number
    from game.sessions s
    join game.session_types st on st.id=s.session_type_id
    join game.session_members sm on sm.session_id=s.id and sm.user_id=v_uid
    left join game.session_topics t on t.id=s.topic_id
    left join game.session_factions f on f.id=sm.faction_id
    where s.id=p_session_id;
end $$;

create function public.confirm_session_read(p_session_id uuid)
returns boolean language plpgsql security definer set search_path=game,pg_catalog
as $$
declare v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update game.session_members set read_confirmed_at=coalesce(read_confirmed_at,now())
  where session_id=p_session_id and user_id=v_uid;
  if not found then raise exception 'not_session_member'; end if;
  return true;
end $$;

create function public.get_session_factions(p_session_id uuid)
returns table(id uuid,name text,side text,member_count bigint,max_members integer)
language sql stable security definer set search_path=game,pg_catalog
as $$
  select f.id,f.name,f.side,count(sm.user_id) filter(where sm.faction_id=f.id),10
  from game.session_factions f
  left join game.session_members sm on sm.session_id=f.session_id and sm.faction_id=f.id
  where f.session_id=p_session_id
    and exists(select 1 from game.session_members m where m.session_id=p_session_id and m.user_id=(select auth.uid()))
  group by f.id,f.name,f.side,f.seat_start
  order by f.seat_start
$$;

create function public.choose_session_faction(p_session_id uuid,p_faction_id uuid default null,p_faction_name text default null,p_side text default null)
returns table(faction_id uuid,faction_name text,faction_side text,seat_number integer)
language plpgsql security definer set search_path=game,pg_catalog
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_member game.session_members%rowtype;
  v_session game.sessions%rowtype;
  v_faction game.session_factions%rowtype;
  v_start integer;v_end integer;v_seat integer;v_name text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_member from game.session_members where session_id=p_session_id and user_id=v_uid for update;
  if not found then raise exception 'not_session_member'; end if;
  if v_member.read_confirmed_at is null then raise exception 'session_read_required'; end if;
  select * into v_session from game.sessions where id=p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;

  if p_faction_id is not null then
    select * into v_faction from game.session_factions where id=p_faction_id and session_id=p_session_id for update;
    if not found then raise exception 'faction_not_found'; end if;
  else
    v_name:=nullif(btrim(p_faction_name),'');
    if v_name is null then raise exception 'faction_name_required'; end if;
    if char_length(v_name)<2 or char_length(v_name)>40 then raise exception 'faction_name_invalid'; end if;
    if p_side not in('left','center','right') then raise exception 'faction_side_required'; end if;
    select * into v_faction from game.session_factions
      where session_id=p_session_id and lower(name)=lower(v_name) for update;
    if not found then
      for v_start in select x from unnest(
        case p_side when 'left' then array[1,11] when 'center' then array[21,31] else array[41,51] end
      ) x loop
        if not exists(select 1 from game.session_factions where session_id=p_session_id and seat_start=v_start) then
          v_end:=v_start+9;
          insert into game.session_factions(session_id,name,side,seat_start,seat_end)
          values(p_session_id,v_name,p_side,v_start,v_end)
          returning * into v_faction;
          exit;
        end if;
      end loop;
      if v_faction.id is null then raise exception 'sector_full'; end if;
    end if;
  end if;

  select min(ss.seat_number) into v_seat
  from game.session_seats ss
  where ss.session_id=p_session_id
    and ss.seat_number between v_faction.seat_start and v_faction.seat_end
    and ss.user_id is null;
  if v_seat is null then raise exception 'faction_full'; end if;

  if v_member.seat_number is not null then
    update game.session_seats set user_id=null,faction_id=null
    where session_id=p_session_id and seat_number=v_member.seat_number;
  end if;

  update game.session_seats set user_id=v_uid,faction_id=v_faction.id
  where session_id=p_session_id and seat_number=v_seat;
  update game.session_members set faction_id=v_faction.id,seat_number=v_seat
  where session_id=p_session_id and user_id=v_uid;

  return query select v_faction.id,v_faction.name,v_faction.side,v_seat;
end $$;

revoke all on function public.get_my_sessions() from public,anon;
revoke all on function public.get_public_sessions() from public,anon;
revoke all on function public.get_session_entry(uuid) from public,anon;
revoke all on function public.confirm_session_read(uuid) from public,anon;
revoke all on function public.get_session_factions(uuid) from public,anon;
revoke all on function public.choose_session_faction(uuid,uuid,text,text) from public,anon;

grant execute on function public.get_my_sessions() to authenticated;
grant execute on function public.get_public_sessions() to authenticated;
grant execute on function public.get_session_entry(uuid) to authenticated;
grant execute on function public.confirm_session_read(uuid) to authenticated;
grant execute on function public.get_session_factions(uuid) to authenticated;
grant execute on function public.choose_session_faction(uuid,uuid,text,text) to authenticated;
