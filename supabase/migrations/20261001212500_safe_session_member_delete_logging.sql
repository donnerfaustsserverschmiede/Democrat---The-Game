create or replace function game.trg_log_session_member()
returns trigger
language plpgsql
security definer
set search_path to 'game','public'
as $$
declare
  v_name text;
  v_session_exists boolean;
begin
  if tg_op='INSERT' then
    select coalesce(p.profile_name,'Spieler') into v_name
    from identity.profiles p where p.user_id=new.user_id;
    perform game.log_session_event(
      new.session_id,'player_joined','Spieler beigetreten',v_name,
      new.user_id,null,jsonb_build_object('user_id',new.user_id)
    );
    return new;
  elsif tg_op='DELETE' then
    select exists(select 1 from game.sessions s where s.id=old.session_id)
    into v_session_exists;
    if v_session_exists then
      select coalesce(p.profile_name,'Spieler') into v_name
      from identity.profiles p where p.user_id=old.user_id;
      perform game.log_session_event(
        old.session_id,'player_left','Spieler hat die Sitzung verlassen',
        v_name,old.user_id,null,jsonb_build_object('user_id',old.user_id)
      );
    end if;
    return old;
  end if;
  return null;
end
$$;
