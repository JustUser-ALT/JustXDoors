# Doors → JustXDoors: architecture and integrity audit

Audit date: 2026-10-15

## Scope

This audit compares the default branches of:

- Source: https://github.com/JustUser-ALT/Doors
- Target: https://github.com/JustUser-ALT/JustXDoors

Observed Git tree IDs at inspection time:

- Doors: `47b111ba77e713a88b7f57f0f580bd938d9e9667`
- JustXDoors: `5f23f2ead49e7c5d484e89a744e560aef41081bb`

These IDs identify the snapshots inspected; they may change if either default branch advances.

## Source layout

- `Loader.lua` — entry point; loads components and selects the lobby or main game entry point.
- `Interface.lua` — interface adapter for the source project's UI API.
- `Components/Environment.luau` — executor-environment capability tests and wrappers.
- `Components/ESP.luau` — ESP rendering and tracking implementation.
- `Game/*.luau` — game-specific entry points and feature modules.

Source file count: 14.

## Target layout

- `Loader.lua` — fetches and initializes `Connector.lua`.
- `Connector.lua` — coordinates module loading, initialization, and session cleanup.
- `Core.lua` — UI/library setup and cleanup registration.
- `Game/Main.lua` and `Game/Main/UI/*.lua` — main-game features and UI modules.
- `Game/Hotel.lua`, `Game/Hotel/*.lua`, and `Game/Hotel/UI/*.lua` — hotel-game features and UI modules.

Target file count before this audit branch: 21.

## Integrity comparison

At inspection time:

- No source file had both the same path and the same Git blob SHA in the target.
- `Loader.lua` exists in both repositories, but its blob SHA differs.
- The source-only paths are:
  - `Components/ESP.luau`
  - `Components/Environment.luau`
  - `Game/Archives.luau`
  - `Game/Backdoors.luau`
  - `Game/General.luau`
  - `Game/Hotel.luau`
  - `Game/Lobby.luau`
  - `Game/Main.luau`
  - `Game/Mines.luau`
  - `Game/Outdoors.luau`
  - `Game/Stairwell.luau`
  - `Game/Visions.luau`
  - `Interface.lua`

The target has its own files at different paths, so path-level replacement would not preserve its existing module contracts. The existing main branches were not modified by this audit.

## Neutral infrastructure added on this branch

- `Infrastructure/ModuleLoader.lua`: a host-agnostic loader that receives source-fetch and compilation functions by dependency injection. It includes caching, circular-load detection, and a protected `TryLoad` API. It does not fetch remote code or compile code on its own.
- `Infrastructure/ResourceScope.lua`: a cleanup registry that runs callbacks in reverse order, is idempotent, and continues cleanup if an individual callback fails.

These are standalone infrastructure primitives. They are not yet wired into `Connector.lua`; doing so requires an explicit integration pass and tests against the target project's expected runtime.

## Not transferred

Executor capability checks, ESP/gameplay features, anti-detection or bypass functions, and game-specific behavior were not copied or rewritten as part of this neutral infrastructure pass.
