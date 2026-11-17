# Handoff — 2026-11-17

Moved from a claude.ai chat to Claude Code. Standing rules are in `CLAUDE.md`.

## Decisions made so far

- **Engine: Godot fork**, not Unity. The owner forked `godotengine/godot` → `steffenbk/BK-godot`.
- **Pinned to Godot `4.7.2-stable` + Voxel Tools `v1.7`.** That's the pair Voxel Tools builds its own
  release binaries against. Godot master (4.8 beta) isn't supported by that release.
- **Fork structure:** branch `bk/4.7` from the upstream tag, Voxel Tools as a submodule, our changes
  as `bk:` commits. Upgrade = new branch from the new tag + cherry-pick `bk:` commits.
- **Art style: grounded mid-fidelity realism** is the leaning choice (realistic proportions and
  materials, less detail per asset, strict budgets). To be confirmed by a style test after the
  terrain tech test, with frame-time numbers and feedback from mil-sim modders.
- **Why not a Reforger mod:** the owner already built a Reforger terrain-deformation mod. It swaps
  3D meshes in a 64×64 area for coarser ones. Without engine source access that's the ceiling. The
  mod is useful as proof of concept and as a recruiting channel.

## Roadmap (phases with gates)

| Phase | Build | Gate |
|---|---|---|
| 0. Engine + core framework | Fork builds in CI; then entity/component model, events, data defs with stable IDs, mod loading, server authority | Green build from clean checkout; framework spec written |
| 1. Infantry + terrain destruction | Movement, one weapon, ballistics, craters/trenches, multiplayer from the start | Fun small loop, no frame spikes on edits |
| 2. Playable mode | Small map, two teams, capture points | People want to play it |
| 3. Vehicle framework via cars | Seats, crew roles, damage zones, input→physics model, generic enough for tracks/helis/jets | Car stable on changing terrain |
| 4. Building destruction | Prefab destruction states first, real-time fracture much later | |
| 5. AI | Simple squad AI for co-op and filling servers | |
| 6+. Tracked, helicopters, jets | New physics models + content on the phase 3 framework | |

**Not now:** helicopters, jets, tracked vehicles, AI, building destruction, mission editor,
mod browser, Steam Workshop, console. Don't build these ahead of their phase.

## Current status

**Step 3 (phase 0 engine build): done on Linux, pending on Windows.**

- `bk/4.7` is pushed to GitHub (`steffenbk/BK-godot`) on top of `ed1daf0` (4.7.2-stable). The first
  commit is authored as Claude.
- The owner's local copy is in `C:\Users\Steffen\Documents\A_documents\Github\BK-godot engine\BK-godot`
  and may still be on `master`. Run `git fetch origin` there, then `git checkout bk/4.7`.
- Verified in a Linux sandbox: full editor build (no errors), `bk/check_modules.gd` passes,
  a voxel crater edit works, and `bk/build.sh` does incremental builds.
- **Not yet verified:** the Windows build, the GitHub Actions run, double-precision and Tracy builds.

## Immediate next steps

**Cloud sessions (Claude Code on the web) can't build or test on Windows.** Steps 1–3 need the owner's PC
(or Claude Code running locally there). A cloud session can do Linux builds, step 4 (the spec) and the
Linux side of step 5.

1. **Owner, on Windows:** `git status` (should be clean) → `git checkout bk/4.7` →
   `git submodule update --init`.
2. **Owner:** install prerequisites if missing (Git for Windows, Python 3 on PATH, `pip install scons`,
   VS 2022 with "Desktop development with C++"), then run `bk\build-windows.bat`.
   If it fails, fix from the error output. The D3D12-deps step and MSVC detection under Git Bash
   are the most likely failure points.
3. **Push `bk/4.7`** to origin, enable Actions on the fork, and get the first green CI run
   (Linux + Windows, editor / editor-double / template).
4. **Write the phase 0 framework spec** (`docs/framework-spec.md` in the game repo, or here until
   it exists): entity/component model, event system, data definitions and stable IDs, mod package
   format and load order, server-authority rules, versioning policy for the mod API.
5. **Terrain tech test** (start alongside 4, the real make-or-break):
   - Voxel terrain with crater, trench and tunnel edits, a debug overlay, and a benchmark scene
   - Jolt collision rebuilding while terrain changes
   - A car driving over deforming ground
   - A rut layer as a cheap heightfield delta, not voxel edits
   - Record mesh rebuild ms, collision rebuild ms, frame time. **Set numeric pass/fail bars and a
     deadline before starting.** If they're missed, reassess rather than drift.

## Session 2026-11-17 (cloud) results

- First CI run on `bk/4.7` queued (run #1, includes the Windows jobs). If the Windows jobs pass, the
  Windows build is verified by CI, and steps 2 and 3 only need the owner for running the editor locally.
- Step 4 drafted: `docs/framework-spec.md` (draft 1, needs owner review; open decisions in §10).
- **New constraint for step 5:** Voxel Tools' built-in multiplayer works only with fixed-LOD
  `VoxelTerrain`, which caps view distance at ~512 voxels on unbounded maps. `VoxelLodTerrain` has no
  network sync. The tech test must compare a hybrid (heightmap far + voxel near) against
  `VoxelLodTerrain` with our own sync. Spec §7 proposes starting phase 1 on a small bounded map.

## Open questions for the owner

- Licence for the project's code and for content (Godot itself is MIT). Decide before outside
  contributions.
- Single or double precision for the game, which depends on target map size.
- CPU core count and hours per week (affects build times and planning).
- How many people use the existing Reforger terrain mod (a demand signal and a recruiting pool).
- How much of the Reforger mod work was writing code vs. debugging it (a calibration for AI-driven
  timelines).

## Risks to keep in view

- Collision rebuild spikes and vehicle stability on changing terrain: phases 1 and 3 hinge on these.
- Networked terrain-edit sync and late joiners: fully custom work.
- Contributors may come slowly. Each phase should end in something usable on its own. Consider
  publishing the terrain system as a standalone Godot addon or module to reach Godot developers.
- Architecture drift over many AI sessions: keep `CLAUDE.md` current, and review engine changes.
