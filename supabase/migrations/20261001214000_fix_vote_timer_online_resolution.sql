-- Vote resolution:
-- * The 10-minute deadline belongs to the statement and is never restarted by a vote.
-- * Immediate resolution requires every currently online human session member to vote.
-- * Offline human members are excluded from the immediate quorum.
-- * At the 10-minute timeout, missing human votes contribute zero; only submitted votes
--   (plus chamber bot votes) determine the majority.
create or replace function public.session_online_voter_count(p_session_id uuid)
returns integer
language sql
security definer
set search_path to ''
as $$
  select count(*)::integer
  from game.session_members m
  join game.session_presence p
    on p.session_id=m.session_id and p.user_id=m.user_id
  where m.session_id=p_session_id
    and m.eliminated_at is null
    and p.last_seen_at > now() - interval '15 seconds'
$$;

-- The deployed functions are defined by the same migration applied to Supabase.
-- Keep this migration as the repository source of truth for the online-voter rule.
