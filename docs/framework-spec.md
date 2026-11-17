# Phase 0 framework spec (draft 1)

Status: **draft, needs owner review.** Lives in the engine repo until the `game/` repo exists, then moves there.
Every section ends in acceptance tests with numbers. A section is done when its tests pass, not before.

Decisions marked **[OWNER]** are not made yet. Everything else is a proposal: argue with it.

---

## 1. Principles

1. **Godot's node tree is the entity/component model.** No custom ECS. An entity is a scene
   whose root is an `Entity` node; components are child nodes. Reason: the editor, scene
   inheritance, serialization and `MultiplayerSynchronizer` all work on nodes. A parallel ECS
   would mean rebuilding all of that and teaching modders two models.
2. **The server owns state; clients own input and presentation.** Single player is a listen
   server with one peer. There is no code path that only exists offline.
3. **Content is data, behaviour is code, and they're joined by ID.** A vehicle is a definition
   file (`car.hatchback_01`) that names a scene and stats. Code never hard-codes content paths.
4. **The base game is a mod.** `core` content loads through the same loader, IDs and API as any
   third-party mod. If the base game needs a private hook, the API is missing something.
5. **Hot paths stay out of GDScript.** Terrain edits, ballistics and anything per-voxel or
   per-projectile-per-frame go in C++ (module or GDExtension). Gameplay glue stays in GDScript.

## 2. Entities and components

- `Entity` (Node3D): has `entity_id` (stable string ID of its definition, e.g. `vehicle.hatchback_01`)
  and `net_id` (uint32 assigned by the server at spawn, unique for the session).
- Components are child nodes extending `Component`. A component finds siblings via
  `entity.get_component(&"Health")`, never via hard-coded node paths.
- Components declare which properties replicate. The framework builds one
  `MultiplayerSynchronizer` per entity from those declarations; modders don't hand-wire them.
- Spawning goes through `World.spawn(def_id, transform, owner_peer)` on the server only.
  Clients calling it is an error. Replication to clients uses `MultiplayerSpawner`.

Acceptance:
- A test entity with 3 components spawns on server and appears on 2 headless clients within
  **200 ms** on localhost, with matching `net_id` and component state.
- A client calling `World.spawn` logs an error and spawns nothing (test asserts entity count unchanged).
- 1,000 idle entities: server tick cost **< 2 ms** (measured on the owner's PC, number recorded).

## 3. Events

- Two kinds, not one:
  - **Local signals:** plain Godot signals inside an entity. No framework involvement.
  - **Game events:** server-raised, typed, replicated facts (`EntityDamaged`, `TerrainEdited`,
    `PointCaptured`). Defined as `Resource` classes with an ID. Raised only on the server, then
    delivered to interested clients.
- No global "any code can emit anything" bus. That's what turns mod interactions into
  untraceable bugs. Mods subscribe to game events; they don't fake them.
- Every game event has a `tick` (server tick it happened on) so clients can order them.

Acceptance:
- Event raised on server arrives on clients in tick order across **10,000** events with
  simulated 5% packet loss (reliable channel): **0** reordered or missing.
- A client attempting to raise a game event: rejected and logged.

## 4. Data definitions and stable IDs

- Format: Godot `.tres` resources (typed, editor-editable, versioned in git). Not JSON: we'd lose
  type checking and the inspector. **[OWNER]** confirm; JSON only if non-Godot tools must edit them.
- ID format: `<mod_id>:<category>.<name>`, lowercase, e.g. `core:soil.clay`, `core:weapon.rifle_556`.
  Mod prefix prevents two mods colliding on `weapon.ak`.
- IDs never change once released. Renaming = new ID + an alias entry in the mod manifest.
- Godot's `ResourceUID` (`uid://…`) is a file identity, not a gameplay ID: it changes if a file
  is recreated and means nothing to a modder. We use it internally only.
- The `Registry` loads all definitions at startup, indexed by ID. Lookups by ID only.
- Overrides: a mod may override another mod's definition by declaring the same ID and listing
  the original mod as a dependency. Last in load order wins. The registry logs every override.

Acceptance:
- Registry with **5,000** definitions loads in **< 1 s** at startup (owner's PC).
- Duplicate ID without declared override: load fails with an error naming both files.
- Network messages carry a 16-bit or 32-bit numeric index, not the string ID. Server and client
  build identical index tables from the same mod list; a test checks the hash matches.

## 5. Mod packages and load order

- A mod is a folder (dev) or a `.pck` (release) with `mod.tres` at its root:
  `id`, `version` (semver), `api_version`, `dependencies` (id + version range), `load_after`.
- Loading: `ProjectSettings.load_resource_pack(path, replace_files, offset)` (verified in
  `core/config/project_settings.h:148`). Each mod lives under `res://mods/<mod_id>/`.
  **Default `replace_files = false`**: a mod can't silently overwrite another's files.
  Replacing base files is done by definition override (section 4), not file overwrite.
- Load order = topological sort of dependencies, ties broken by `load_after`, then ID. Cycle = error.
- Server sends its mod list (id, version, content hash) on join. Client with a mismatch is refused
  with a message listing what differs. No auto-download in phase 0 (see "not now").

**Security, stated plainly:** GDScript has no sandbox. A mod's script can read and write files,
open sockets, run processes. That's acceptable while mods are installed by hand. It is **not**
acceptable for automatic server-driven downloads. Before any mod browser or auto-download,
we need either a restricted scripting layer or signed/curated mods. **[OWNER]** be aware this
is a real design cost, and why "mod browser" stays on the not-now list.

Acceptance:
- Three test mods A ← B ← C (C depends on B depends on A) load in order A, B, C regardless of
  folder order. A cycle A ↔ B fails with an error naming both.
- Client with a different content hash for one mod is refused, and the message names that mod.
- Mod declaring `api_version` newer than the game: refused with a clear message.

## 6. Server authority and networking

- Fixed server tick: **[OWNER]** 30 Hz proposed (60 Hz doubles server CPU and bandwidth per
  player; measure before choosing higher). Physics may run faster; network state is sent per tick.
- Clients send **input**, not results. Server simulates, then replicates. Client-side prediction
  for the local player's movement and weapon only; everything else is interpolated.
- Hit registration: server-side, with lag compensation (rewind hitboxes to the shooter's
  view time, capped at **200 ms**).
- Interest management: Godot provides per-peer visibility on `MultiplayerSynchronizer`
  (`add_visibility_filter`, `set_visibility_for`, verified in
  `modules/multiplayer/multiplayer_synchronizer.cpp`). We supply the relevance logic (distance
  + grid cells). The primitive exists; the policy is ours.
- Synchronizer packets above `sync_mtu` (default **1350 bytes**,
  `modules/multiplayer/scene_replication_interface.h:93`) are dropped with an error, not split.
  Entity state has to stay small; large data (terrain) goes through its own channel.

Acceptance:
- Movement test: 2 clients, 100 ms simulated latency, 2% loss. Local player has no visible
  correction under normal movement; server/client position error **< 10 cm** after stop.
- Bandwidth: **< 64 kbit/s** per client downstream with 32 moving entities in view.
- Late joiner sees the same world state as existing clients (entity set and component values
  hash-identical) within **5 s** of joining.

## 7. Terrain: what this framework has to account for

Verified in `modules/voxel` (v1.7) during this draft, and it shapes the architecture:

- Voxel Tools' built-in network sync (`VoxelTerrainMultiplayerSynchronizer`,
  `doc/source/multiplayer.md`) works only with **`VoxelTerrain`** (fixed LOD). For
  `VoxelLodTerrain` the doc says: "There is no support for now, but it is planned."
- `VoxelTerrain` view distance is capped at **512 voxels** when the volume is unbounded
  (`MAX_VIEW_DISTANCE_FOR_LARGE_VOLUME`, `terrain/fixed_lod/voxel_terrain.h:44`). At 1 m voxels
  that's ~512 m. Mil-sim engagement and spotting ranges are often 1–3 km.

So one of these has to be true, and the terrain tech test must find out which:

| Option | Idea | Main cost |
|---|---|---|
| A. Hybrid | Heightmap terrain for distance, voxel `VoxelTerrain` near players (and only where edits are possible). Built-in sync works. | Seam between the two, keeping far terrain consistent with edits (craters visible at range). |
| B. LOD voxel + own sync | `VoxelLodTerrain` everywhere, write terrain-edit sync ourselves. | Custom networking for edits and late joiners, likely C++. |
| C. Bounded small map | `VoxelTerrain` on a bounded volume, accept shorter sightlines. | Limits the genre. Fine for phase 1–2 test maps, not for the final game. |

Proposal: **start phase 1 on C** (it's enough to prove craters + multiplayer + fun), and have the
tech test measure A vs B before phase 3. Don't build A or B into gameplay code yet.

Regardless of option, terrain edits are **game events** (section 3): `TerrainEdited { shape_id,
position, radius, tick }`, raised by the server, applied deterministically. Late joiners get
edited blocks, not an edit replay, once the replay would be longer than the block data.

## 8. Versioning of the mod API

- `api_version` is a single integer, bumped on any breaking change to a public class, event
  or definition field. Additive changes don't bump it.
- What's public: classes under `res://framework/api/`, event types, definition resource classes.
  Everything else is internal and can change without notice.
- Breaking changes before 1.0 are allowed but must be listed in `docs/api-changes.md`.

## 9. Not in this spec (not now)

Mod browser, Workshop, auto-download, script sandboxing implementation, mission editor, AI,
vehicles beyond what's needed for the car tech test.

## 10. Open decisions for the owner

1. Data format: `.tres` (proposed) or JSON.
2. Server tick rate: 30 Hz proposed.
3. Map size target for the final game. Decides terrain option A/B/C and single vs double precision.
4. Max players per server target (drives bandwidth and tick budgets above).
5. Mod security stance before any auto-download feature.
