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
- `modules/overview/` — session overview, party/profile/settings entry points
- `modules/player/` — politician profile and public-opinion statistics
- `modules/party/` — persistent party dashboard, members and party upgrades
- `modules/session/` — live parliamentary session

- Supabase `game` schema — sessions, seats, bots, factions, statements and votes
- Supabase `parties` schema — persistent parties, members, treasury and upgrades

## Player and party system

- **Profile:** Level, public opinion, money across active sessions, session participation, personal wins, faction wins and decision balance.
- **Public opinion:** calculated from the player's actual votes and the citizen impact of decisions in completed sessions.
- **Level:** starts at Level 1 and increases by one for each completed session, up to Level 50. A player may create a party from Level 10.
- **Party membership:** from Level 1 a player can join an existing party. Once inside a party, the player sees the own-party dashboard instead of the party directory.
- **Party treasury:** 500 € daily base income per member, credited server-side when the party dashboard is accessed.
- **Party opinion:** average public opinion of all members, modified by party upgrades.
- **Roles:** chairman and deputy may remove members; only the chairman may appoint the deputy.
- **Party actions:** member capacity, public image, campaign network and election influence can be upgraded with party treasury funds.

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
