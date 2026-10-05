# Democrat – Unity Mobile

The active mobile 3D prototype lives here.

## Current playable flow

1. Game starts automatically.
2. Character creation screen appears.
3. Player enters first and last name.
4. Player enters the government building.
5. Third-person character is visible.
6. Left side of the screen moves the character.
7. Right side rotates the camera.
8. Entrance hall, reception, plenary, committee rooms and election hall are generated at runtime.

## Architecture

The first mobile build deliberately uses procedural Unity geometry so the project can be developed without binary scene assets. The next passes replace the blockout with authored architecture, materials, furniture, animations and optimized mobile assets.

## Build

The repository contains the Unity project source. An installable Android APK still has to be produced by a Unity build environment (local Unity Editor or Unity Build Automation). The repository itself cannot execute Unity's build pipeline.

## Next production steps

- persistent character profile
- selectable body type, hair, eyes and clothing
- proper virtual joystick
- polished touch camera
- optimized modular government building
- stairs and elevators
- signage and room navigation
- fictional outside scenery
- multiplayer
- factions, sessions and elections
