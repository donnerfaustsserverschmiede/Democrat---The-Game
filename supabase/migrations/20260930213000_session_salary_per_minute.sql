alter table game.session_player_stats add column if not exists last_salary_at timestamptz;
update game.session_player_stats set last_salary_at=coalesce(last_salary_at,now()) where last_salary_at is null;
alter table game.session_player_stats alter column last_salary_at set default now();

create or replace function game.accrue_session_salary(p_session_id uuid,p_user_id uuid)
returns bigint language plpgsql security definer set search_path=''
as $function$
declare v_last timestamptz; v_minutes bigint; v_rate bigint; v_faction uuid; v_money bigint;
begin
 if p_user_id is null then raise exception 'not_authenticated'; end if;
 select ps.last_salary_at,ps.money,m.faction_id into v_last,v_money,v_faction
 from game.session_player_stats ps join game.session_members m on m.session_id=ps.session_id and m.user_id=ps.user_id
 where ps.session_id=p_session_id and ps.user_id=p_user_id for update;
 if not found then return 0; end if;
 if exists(select 1 from game.sessions where id=p_session_id and status='ended') then return v_money; end if;
 if not game.session_is_active(p_session_id) then return v_money; end if;
 v_minutes:=greatest(0,floor(extract(epoch from (now()-coalesce(v_last,now()))/60))::bigint);
 if v_minutes<=0 then return v_money; end if;
 select case when f.leader_user_id=p_user_id then 500 when f.deputy_user_id=p_user_id then 450 else 300 end into v_rate
 from game.session_factions f where f.id=v_faction;
 v_rate:=coalesce(v_rate,300);
 update game.session_player_stats set money=money+(v_minutes*v_rate),last_salary_at=coalesce(v_last,now())+(v_minutes*interval '1 minute'),updated_at=now()
 where session_id=p_session_id and user_id=p_user_id returning money into v_money;
 return v_money;
end;
$function$;
revoke all on function game.accrue_session_salary(uuid,uuid) from public,anon,authenticated;

create or replace function public.get_session_wallet(p_session_id uuid)
returns table(money bigint,currency_code text,currency_symbol text,salary_per_minute bigint)
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_country text; v_faction uuid; v_rate bigint;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if not exists(select 1 from game.session_members where session_id=p_session_id and user_id=v_uid) then raise exception 'not_session_member'; end if;
 perform game.accrue_session_salary(p_session_id,v_uid);
 select st.country_code into v_country from game.sessions s join game.session_types st on st.id=s.session_type_id where s.id=p_session_id;
 select m.faction_id into v_faction from game.session_members m where m.session_id=p_session_id and m.user_id=v_uid;
 select case when f.leader_user_id=v_uid then 500 when f.deputy_user_id=v_uid then 450 else 300 end into v_rate from game.session_factions f where f.id=v_faction;
 v_rate:=coalesce(v_rate,300);
 return query select ps.money,
 case v_country when 'DE' then 'EUR' when 'ES' then 'EUR' when 'FR' then 'EUR' when 'IT' then 'EUR' when 'AT' then 'EUR' when 'CH' then 'CHF' when 'US' then 'USD' when 'GB' then 'GBP' when 'CA' then 'CAD' when 'AU' then 'AUD' when 'BR' then 'BRL' when 'MX' then 'MXN' else 'EUR' end,
 case v_country when 'DE' then '€' when 'ES' then '€' when 'FR' then '€' when 'IT' then '€' when 'AT' then '€' when 'CH' then 'CHF' when 'US' then '$' when 'GB' then '£' when 'CA' then 'C$' when 'AU' then 'A$' when 'BR' then 'R$' when 'MX' then 'MX$' else '€' end,v_rate
 from game.session_player_stats ps where ps.session_id=p_session_id and ps.user_id=v_uid;
end;
$function$;
revoke all on function public.get_session_wallet(uuid) from public,anon;
grant execute on function public.get_session_wallet(uuid) to authenticated;