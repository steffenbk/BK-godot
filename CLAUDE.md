# CLAUDE.md — BK engine / mil-sim project

Read this first in every session. Current status and next steps are in `HANDOFF.md`.

## What this project is

The base for an open-source, moddable mil-sim in the spirit of Arma Reforger,
built on a Godot fork. The thing that sets it apart: **destructible, diggable
terrain** (craters, trenches, tunnels) that changes how fights play out,
something Reforger's engine (Enfusion) can't do without source access.

The goal is a **base game plus frameworks** that other people build mods and
content on. Official content ships as a mod on the same API modders use.

The owner (Steffen) works as project manager and drives AI for implementation.
He can't debug C++ by reading it, so results must be objectively verifiable
(tests, benchmarks, numbers), not "looks right".

## Repo layout

- `bk/4.7` is **the engine branch**. Godot `4.7.2-stable` + our commits. Work here.
- `master` mirrors upstream Godot (4.8 beta). Never build or work on it.
- `modules/voxel` is the Voxel Tools submodule (Zylann/godot_voxel), pinned to `v1.7` (`2ac9f5f8`).
- `bk/` holds our build scripts, module smoke test, README and `CHANGES.md`.
- `.github/workflows/bk-build.yml` is our CI. Upstream workflows were removed on purpose.

The game project will be a separate repo (`game/`) that uses this engine. It doesn't exist yet.

## Build

- Windows (the owner's machine, Windows 10): `bk\build-windows.bat [variant]` (runs `bk/build.sh` via Git Bash)
- Linux: `bk/build.sh [variant]`
- Variants: `editor`, `editor-double`, `template`, `template-double`, `editor-tracy`
- Smoke test: `bin/<editor binary> --headless --script bk/check_modules.gd`
- A first full build is slow (37 min on 2 cores). Incremental builds are fast.

## Hard rules

1. **Don't change Godot or Voxel Tools source unless a module or GDExtension can't do it.**
   Every engine change is a small commit with a message starting `bk:`, plus an entry in `bk/CHANGES.md`.
2. **Don't bump Godot or Voxel Tools casually.** Pin to the Godot version Voxel Tools' own CI builds
   against (`.github/workflows/linux.yml` in their repo). Upgrades are a deliberate, separate task.
3. **Multiplayer and server authority from the first line of gameplay code.** Clients propose,
   the server decides, even in single player. Retrofitting networking means rewriting.
4. **Gameplay data lives in data files with stable IDs** (vehicle stats, soil types, crater
   profiles, weapons). That's what makes modding possible.
5. **"Done" is decided by tests and benchmark numbers, not by the AI.** Every task gets
   acceptance criteria written as numbers before work starts.
6. **Small, verifiable steps.** One module and one acceptance test at a time, committed between steps.
7. **Respect the "not now" list** in `HANDOFF.md`. Don't build ahead of the current phase.
8. **Asset licensing:** no Arma or other third-party game assets in the repo. Check every
   source's licence before anything is added.

## Known facts (verified, don't rediscover)

- Jolt physics is compiled in, but only editor-created projects default to it. The game's
  `project.godot` must set `physics/3d/physics_engine = "Jolt Physics"` explicitly.
- Jolt has heightmap and concave-mesh shapes (`modules/jolt_physics/shapes/`).
- Godot's `modules/multiplayer` has a spawner, a synchronizer and RPCs. Interest management has
  primitives only: per-peer visibility on `MultiplayerSynchronizer` (`add_visibility_filter`,
  `set_visibility_for`); the relevance policy is ours. Synchronizer state above `sync_mtu`
  (1350 bytes default) is dropped, not split.
- Voxel Tools' network sync (`VoxelTerrainMultiplayerSynchronizer`) works only with `VoxelTerrain`
  (fixed LOD). `VoxelLodTerrain` has no network support in v1.7. `VoxelTerrain` view distance is
  capped at 512 voxels on unbounded volumes (`voxel_terrain.h:44`). See `docs/framework-spec.md` §7.
- GDScript has no sandbox: mod scripts get full file, network and process access.
- There's no voxel terrain in Godot core, which is why we use Voxel Tools.
- The Windows build needs Godot's Direct3D 12 deps (`misc/scripts/install_d3d12_sdk_windows.py`).
  `bk/build.sh` installs them automatically. Under Git Bash they go to `bin/build_deps`.
- `VoxelTool` sphere edits on a `VoxelBuffer` work in this build (verified headless).
- Double-precision builds (`precision=double`) are available. A project built with them needs the
  matching double export template. The precision choice has to be made early.

## Working style

- Before writing C++ for Godot or Voxel Tools, read the actual source in this repo. Don't rely on
  memory of the APIs; Godot APIs change between versions.
- Unity-style or outdated Godot 3 APIs are a common AI mistake. Check against 4.7.2.
- When a bug only shows in the profiler or in play (frame spikes, jitter, desync), ask the owner
  for a profiler capture or exact repro steps instead of guessing.
- Have a second, fresh session review engine changes adversarially against these rules.
