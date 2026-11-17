#!/usr/bin/env bash
# Build the BK Godot engine from the repo root.
#
# Usage: bk/build.sh <variant> [extra scons args...]
#   editor           editor, single precision      (day-to-day work)
#   editor-double    editor, double precision      (large maps)
#   template         release export template, single precision
#   template-double  release export template, double precision
#   editor-tracy     editor with the Tracy profiler (needs TRACY_PATH)
#
# Platform is detected automatically (linuxbsd / windows / macos).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARIANT="${1:-editor}"; shift || true
cd "$ROOT"

# Voxel Tools is a git submodule; make sure it's checked out at the pinned commit.
if [ ! -f modules/voxel/SCsub ]; then
  echo "== Initialising Voxel Tools submodule"
  git submodule update --init --recursive modules/voxel
fi

case "$(uname -s)" in
  Linux*)                 PLATFORM=linuxbsd ;;
  Darwin*)                PLATFORM=macos ;;
  MINGW*|MSYS*|CYGWIN*)   PLATFORM=windows ;;
  *) echo "Unknown OS $(uname -s)" >&2; exit 1 ;;
esac

ARGS=(platform="$PLATFORM" tests=no)
case "$VARIANT" in
  editor)          ARGS+=(target=editor           precision=single) ;;
  editor-double)   ARGS+=(target=editor           precision=double) ;;
  template)        ARGS+=(target=template_release precision=single production=yes) ;;
  template-double) ARGS+=(target=template_release precision=double production=yes) ;;
  editor-tracy)
    : "${TRACY_PATH:?Set TRACY_PATH to a Tracy source checkout matching your Tracy viewer version}"
    ARGS+=(target=editor precision=single profiler=tracy profiler_path="$TRACY_PATH") ;;
  *) echo "Unknown variant: $VARIANT" >&2; exit 1 ;;
esac

# Windows: Godot's Direct3D 12 driver needs Mesa/NIR + Agility SDK libraries
# that aren't in the repo. Install them once with Godot's own script.
# (Under Git Bash, MSYSTEM is set, so Godot looks in bin/build_deps;
# from cmd/PowerShell it looks in %LOCALAPPDATA%\Godot\build_deps.)
if [ "$PLATFORM" = windows ]; then
  PY="$(command -v python || command -v python3)"
  if [ -n "${MSYSTEM:-}" ]; then DEPS="$ROOT/bin/build_deps"
  else DEPS="${LOCALAPPDATA:-}/Godot/build_deps"; fi
  if ! ls -d "$DEPS"/mesa* >/dev/null 2>&1; then
    echo "== Installing Direct3D 12 build dependencies (one-time)"
    "$PY" misc/scripts/install_d3d12_sdk_windows.py
  fi
fi

JOBS="${JOBS:-$( (nproc || sysctl -n hw.ncpu) 2>/dev/null || echo 4)}"
echo "== scons ${ARGS[*]} $* -j$JOBS"
scons "${ARGS[@]}" "$@" -j"$JOBS"
echo "Binaries:"; ls -1 bin | grep -v '^obj$' | grep -v '^build_deps$' || true
