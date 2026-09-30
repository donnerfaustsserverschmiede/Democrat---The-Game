# Session Module

Owns the session-entry flow after a player joins a parliamentary session.

## Flow

1. Session has a random topic and a short localized introduction.
2. Player confirms the introduction as read.
3. Player chooses an existing faction or creates a new faction.
4. A faction selects a chamber position: left, centre, or right.
5. The database assigns a contiguous seat block.
6. A faction is limited to 10 players/seats.

The physical chamber currently has 60 seats (20 left, 20 centre, 20 right) while a session has a maximum of 30 players. This allows multiple factions to occupy the same broad sector while each faction retains a contiguous block of up to 10 seats.

All assignment logic is server-side through Supabase RPCs so concurrent players cannot claim the same seat.
