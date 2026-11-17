# BK engine

Godot `4.7.2-stable` plus [Voxel Tools](https://github.com/Zylann/godot_voxel)
`v1.7` as a submodule, plus a short list of our own changes (`bk/CHANGES.md`).

Why 4.7.2 and not Godot's latest: it's the version Voxel Tools builds its own
release binaries against (checked 2026-11-17). Godot's `master` (4.8 beta) is
not supported by the module's release.

Most contributors never build this. Download a prebuilt editor from Releases
or the latest CI run instead.

## Branches

- `bk/4.7` is the engine branch. Work here.
- `master` mirrors upstream Godot. Don't build or work on it.

## Builds

| Variant           | Use |
|-------------------|-----|
| `editor`          | Everyday development |
| `editor-double`   | Large maps (double-precision coordinates) |
| `template`        | Release export template |
| `template-double` | Export template for double-precision projects |
| `editor-tracy`    | Profiling with Tracy (local only, set `TRACY_PATH`) |

A project made with `editor-double` must ship with `template-double`. Pick one
precision for the game early; switching later breaks saved data that stores
positions.

## Physics engine

Jolt is compiled in, but only projects *created in the editor* default to it.
The game project must set `physics/3d/physics_engine = "Jolt Physics"` in
`project.godot` explicitly; otherwise you silently get Godot Physics.

## Building on Windows 10/11

One-time setup:

1. **Git for Windows** (includes Git Bash): https://git-scm.com/download/win
2. **Python 3** from python.org. Tick "Add python.exe to PATH" in the installer.
3. In a new terminal: `pip install scons`
4. **Visual Studio 2022** (Community or Build Tools) with the
   "Desktop development with C++" workload.
5. Keep the repo at a reasonably short path. Godot's build creates deep
   folder paths that can fail under very long ones.

Then double-click `bk\build-windows.bat` (or run it from a terminal). The
first run also downloads the Voxel Tools submodule and Godot's Direct3D 12
build dependencies. Binaries land in `bin\`.

The first build takes a long time (tens of minutes to over an hour depending
on your CPU). Rebuilds after small changes are much faster.

Optional: Windows Defender scans every file the compiler writes, which slows
builds a lot. Adding the repo folder as a Defender exclusion speeds them up.
That's a security trade-off, so it's your call.

## Building on Linux

```bash
pip install scons          # plus the X11/Wayland/ALSA dev packages, see Godot's docs
bk/build.sh editor         # binaries land in bin/
```

## Changing engine code

1. Make the change on `bk/4.7` (or a branch off it).
2. Build and test.
3. Commit with a message starting `bk:` and add an entry to `bk/CHANGES.md`.

## Upgrading Godot or Voxel Tools

1. Check which Godot version Voxel Tools' CI builds against
   (`.github/workflows/linux.yml` in their repo).
2. Create a new branch (e.g. `bk/4.8`) from the new upstream tag.
3. Cherry-pick or rebase the `bk:` commits onto it, and move the submodule
   to the matching Voxel Tools tag.
4. Run CI plus the benchmark scene and compare against the previous numbers
   before switching over.

## CI

`.github/workflows/bk-build.yml` builds Linux and Windows editors (single and
double precision) and release templates on every push to `bk/**`, checks the
required modules are compiled in (`bk/check_modules.gd`), and uploads the
binaries as artifacts. Pushing a tag named `engine-v*` publishes a GitHub
Release with zipped binaries.

Actions are disabled on forks by default. Enable them in the repo's
**Actions** tab once.
