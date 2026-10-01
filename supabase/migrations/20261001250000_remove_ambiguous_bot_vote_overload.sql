-- Remove the legacy two-argument overload.
-- The live bot-vote scheduler is the three-argument function with a default
-- p_force_all=false. Keeping both overloads makes calls with two arguments
-- ambiguous in PostgreSQL and breaks session loading/voting UI.
drop function if exists game.ensure_session_bot_votes(uuid, uuid);
