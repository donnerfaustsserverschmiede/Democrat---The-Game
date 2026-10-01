-- Stagger bot votes across the 10-minute statement window so the live vote bar visibly moves over time.
-- The deployed migration adds scheduled_at, releases at most one due bot per state refresh,
-- and forces remaining bots only at the 10-minute resolution boundary.

alter table game.session_bot_votes add column if not exists scheduled_at timestamptz;

-- See deployed Supabase migration 20261001 for the complete function definitions.
