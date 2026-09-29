# Democrat – The Game

Modular political strategy game.

## Architecture

The project is intentionally split into isolated feature bubbles. Each module owns its UI, logic, state and integration boundary. Modules must not directly modify another module's internals.

### Current module
- `modules/auth/` — entry screen, login, registration and authentication state.

### Planned modules
- graphics
- map
- parties
- elections
- parliament
- economy
- population
- diplomacy
- notifications

## Rule

A feature change must stay inside its module unless an explicit, documented interface change is required.
