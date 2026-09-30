-- Democrat: opinion points, elimination and first-to-100 session ending
alter table game.sessions
  add column if not exists status text not null default 'active' check (status in ('active','ended')),
  add column if not exists winner_type text check (winner_type in ('player','faction')),
  add column if not exists winner_user_id uuid references auth.users(id),
  add column if not exists winner_faction_id uuid references game.session_factions(id),
  add column if not exists ended_at timestamptz,
  add column if not exists end_reason text;
alter table game.session_members add column if not exists eliminated_at timestamptz;
alter table game.session_faction_stats add column if not exists eliminated_at timestamptz;


