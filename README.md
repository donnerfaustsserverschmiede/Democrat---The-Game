# Democrat – The Game

Modular political strategy game.

## Current development state

The game is a browser/PWA application backed by Supabase. The current playable flow is:

1. Legal consent
2. Login, registration or guest account
3. Country selection
4. Session overview
5. Parliamentary session with 60 seats, bots, factions, voting, opinion points, money, rankings, debate and faction management
6. Guest-account upgrade from settings without replacing the existing user ID

## Project structure

- `index.html` — application shell and startup sequence
- `assets/` — game logos and static assets
- `modules/splash/` — startup screen
- `modules/legal/` — legal consent and documents
- `modules/auth/` — authentication and guest accounts
- `modules/country/` — country selection
- `modules/overview/` — session overview, party/settings entry points
- `modules/session/` — live parliamentary session
- `modules/party/` — reserved for the persistent party UI
- Supabase `game` schema — sessions, seats, bots, factions, statements and votes
- Supabase `parties` schema — persistent parties, members, treasury and upgrades

## Architecture rule

A feature change should stay inside its module unless an explicit interface change is required.

## Important game rules currently implemented

- 60 seats per session: 20 left, 20 centre, 20 right
- Up to 30 real players; remaining seats are bots
- Bot tendencies are distributed across approval, rejection and neutral behaviour
- Faction-controlled bot seats follow the faction's human voting majority
- Session economy: 100 € / min. base salary, 125 € / min. deputy, 150 € / min. faction chair
- Extra faction seats: +1 / +2 / +3 with costs of 1,500 / 4,000 / 9,000
- Bot bribery costs 750 €; moral persuasion remains free
- Extra-seat cooldowns: 10 / 20 / 30 minutes
- Maximum 10 extra seats per faction
- New players start with 0 opinion points and do not inherit faction points
- Statement countdown is server-deadline based and advances automatically in the active client
- Guest users use Supabase anonymous authentication and the `authenticated` database role
