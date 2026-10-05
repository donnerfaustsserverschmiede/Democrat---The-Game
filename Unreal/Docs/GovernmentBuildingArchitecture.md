# Democrat – Government Building Architecture Specification

## Purpose

This document defines the architectural foundation for the 3D Democrat multiplayer political roleplay game in Unreal Engine 5.

The building is a fictional modern government complex. It should evoke the atmosphere and functional logic of a parliamentary institution without reproducing any real German government building one-to-one.

## World rules

- The playable world is the interior of one large government complex.
- There is no explorable outdoor world.
- Windows use a fictional city/government-district backdrop.
- No German flag, federal eagle, Bundestag logo, official coat of arms or other official state insignia.
- Democrat branding is used for signs and interfaces.
- Future rooms are physically reserved from the beginning even when their gameplay is not implemented.

## Spatial hierarchy

### Ground floor

1. Main entrance / large entrance hall
2. Reception
3. Security checkpoint
4. Information area
5. Public seating
6. Large staircase
7. Elevators
8. Cafeteria
9. Toilets
10. Changing room
11. Public circulation corridors

### Parliamentary core

12. Main plenary hall
13. Large committee room
14. Medium committee room
15. Small committee room
16. Conference room
17. Parliamentary circulation spine
18. Visitor access / gallery area

### Election area

19. Election hall
20. Voting booth area
21. Ballot/result area
22. Election waiting area
23. Election support room

### Political/faction area

24. Faction rooms
25. Meeting rooms
26. Representative offices
27. Future government/ministerial offices

### Media

28. Press center
29. Press conference area
30. TV studio
31. Interview area
32. Media workstations

### Infrastructure

33. Security rooms
34. Technical rooms
35. Storage
36. Staff corridors
37. Emergency exits
38. Sanitary facilities
39. Additional stairs
40. Additional elevators

## Architectural dimensions

These are production targets rather than final art dimensions.

- Standard public corridor: 300–400 cm clear width.
- Main ceremonial corridor: 500–700 cm clear width.
- Standard interior door: approximately 100 cm wide.
- Double public door: approximately 180–240 cm wide.
- Standard ceiling: approximately 320–400 cm.
- Main entrance hall: approximately 700–1000 cm clear height.
- Main plenary: approximately 1100–1400 cm overall interior height.
- Main plenary footprint: approximately 7000 x 4300 cm in the current procedural blockout.
- Offices and smaller rooms should use modular dimensions so they can be rearranged without rewriting the entire building.

## Circulation

The entrance hall is the primary orientation point.

The building should use:
- a central public spine,
- clearly readable east/west wings,
- a parliamentary core toward the rear,
- election facilities on a dedicated wing,
- media facilities separated from high-security areas,
- staff/service circulation that can later be restricted by permissions.

Players should always have a believable route from the entrance to major public destinations.

## Spawn

New players spawn in the main entrance hall.

Multiple spawn points should be reserved around the entrance hall so multiplayer arrivals do not overlap.

The initial camera should be third-person, positioned slightly behind and above the character.

## Vertical expansion

The current first-pass blockout is prepared for multiple floors.

Stair and elevator locations are deliberately fixed in the procedural layout so upper-floor additions can reuse the same circulation shafts.

Future floors should contain:
- additional offices,
- government/ministerial areas,
- faction leadership areas,
- staff facilities,
- technical infrastructure.

## Windows and outside view

The exterior is not playable.

Windows should nevertheless create a convincing outside view through:
- fictional city skyline,
- government-district buildings,
- streets and moving traffic,
- trees and public spaces,
- distant lit windows,
- sky/cloud backdrop,
- depth layers/parallax where useful.

The outside scenery must not contain recognizable official German symbols.

## Art direction

Target: serious, modern, prestigious government architecture.

Suggested visual language:
- natural stone or high-quality neutral flooring,
- glass,
- metal,
- wood accents,
- restrained neutral wall materials,
- warm architectural lighting,
- clean institutional signage,
- subtle Democrat identity.

The building should feel expensive and permanent rather than like a game-show set.

## Implementation stages

### Stage 1 – structural blockout
- connected floorplan
- rooms
- circulation
- spawn area
- stairs/elevators
- collision

### Stage 2 – architectural modules
- proper walls
- door openings
- doors
- windows
- glass facade
- stair geometry
- elevator shafts
- ceilings

### Stage 3 – visual pass
- materials
- lighting
- signage
- furniture
- architectural details

### Stage 4 – gameplay pass
- multiplayer spawn
- character creation
- changing room
- sessions
- political roles
- parliamentary gameplay
- elections
- media systems

## Important production note

The C++ procedural building is a foundation/blockout. Unreal Engine binary level assets, final meshes, materials and lighting need to be authored in the Unreal Editor. The repository should keep the architecture specification and procedural source synchronized so the playable level can evolve without losing the planned structure.
