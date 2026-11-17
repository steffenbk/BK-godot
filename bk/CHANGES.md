# BK engine changes

Every change this branch makes on top of upstream Godot `4.7.2-stable`.
Keep this list short. Each entry is something you'll have to carry over
when upgrading Godot.

Rules:
- **Prefer not changing engine code.** Use a module or GDExtension first.
  Change Godot source only when that can't do the job, and say why below.
- **One concern per commit,** with a message starting `bk:`. Small commits
  survive upgrades; big ones don't.
- **Every engine change gets an entry here** before it's merged, and a second
  reviewer (human or a separate AI session) checks it.
- **On upgrade,** rebase the `bk:` commits onto the new upstream tag. Drop any
  that upstream has fixed.

## Entry template

```
### short-name
- What: one line
- Why: what breaks or is impossible without it
- Files: …
- Upstream status: not reported / issue #… / PR #… / merged in X.Y
```

## Changes

### voxel-module
- What: Voxel Tools added as a git submodule at `modules/voxel`, pinned to `v1.7` (`2ac9f5f8`).
- Why: voxel terrain with runtime editing (craters, trenches, tunnels).
- Files: `.gitmodules`, `modules/voxel`
- Upstream status: third-party module, not intended for upstream.

### ci
- What: upstream `.github/workflows/*` removed, replaced by `bk-build.yml`.
- Why: upstream CI builds every platform; this builds Linux + Windows editors and templates only.
- Files: `.github/workflows/`
- Upstream status: fork-only.

### build-tooling
- What: `bk/` folder with build scripts, module check and docs.
- Why: one-command builds on Windows and Linux.
- Files: `bk/`
- Upstream status: fork-only.
