# Democrat – The Game | Unreal Engine 5

This directory is the new 3D game foundation for Democrat.

## Current prototype

- Unreal Engine 5.6 project
- C++ game module
- Third-person player character
- WASD movement and mouse camera
- Runtime-generated government-building blockout
- Spawn/world foundation centered on the main entrance
- Parliamentary core with a large plenary hall
- Multiple committee/session rooms
- Election hall
- Faction, press and television areas
- Future-ready office wings

## Architectural direction

The building is an original fictional government complex strongly inspired by the spatial language of German parliamentary architecture. It must not reproduce the Bundestag 1:1 and must contain no German state symbols, Bundestag branding, federal eagle or other official insignia.

The complete playable world is the building interior. The exterior will later be represented by a non-playable visual environment through windows.

## Planned first playable milestone

1. Start the UE5 project.
2. Spawn the player in the entrance hall.
3. Walk through the building.
4. Enter the planned rooms.
5. Add visual materials, doors, windows, lighting and architectural detail.
6. Add the character-creation and clothing systems.
7. Add multiplayer/server architecture.
8. Add political gameplay systems room by room.

The old browser/PWA implementation remains in the repository as legacy code while the Unreal project is developed separately.


## Architecture specification

The authoritative building plan, dimensions, circulation strategy, spawn design and staged construction plan are maintained in:

- `Unreal/Docs/GovernmentBuildingArchitecture.md`

The procedural C++ blockout is intentionally a structural foundation. Final Unreal level assets, meshes, materials and lighting are built in the Unreal Editor once the project is opened locally.
