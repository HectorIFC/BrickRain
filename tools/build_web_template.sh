#!/usr/bin/env bash
#
# Builds a size-optimised Godot web export template for BrickRain.
#
# Why this exists: the stock Godot web runtime is ~39.5 MB raw / 6.9 MB brotli
# at zero game content, and the whole BrickRain payload is ~124 KB. The runtime
# is ~99% of what a player downloads, so stripping unused engine modules is the
# only lever that meaningfully changes first-load time (Phase 0 measured this;
# nothing in the game code moves the number).
#
# The output is a single .zip that Godot consumes as a custom export template.
# It is a BUILD ARTIFACT, not source: do not commit it. Build it once, publish
# it (a GitHub Release asset works well), and have CI download it rather than
# rebuild it — a full build is 30-60 minutes.
#
# Usage:
#   tools/build_web_template.sh [godot-version]
#
# Requires: git, python3, and ~15 GB of free disk. emsdk and SCons are
# installed into the work directory; nothing is installed system-wide.

set -euo pipefail

GODOT_VERSION="${1:-4.7.1}"
GODOT_TAG="${GODOT_VERSION}-stable"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${BRICKRAIN_BUILD_DIR:-$ROOT/build/engine}"
EMSDK_DIR="$WORK/emsdk"
SRC_DIR="$WORK/godot-$GODOT_TAG"
OUT_DIR="$ROOT/build/templates"

# Emscripten version must match what the Godot release was built against;
# a mismatch produces a template that links but misbehaves at runtime.
#
# 4.0.20 is not a guess: the stock 4.7.1 template reports
#   "Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support."
# in the browser console, so that is what the official binary was built with.
EMSDK_VERSION="${EMSDK_VERSION:-4.0.20}"

# Modules stripped below are ones a 2D falling-blocks game provably cannot
# reach. Deliberately NOT stripped:
#   svg / freetype  - the default GUI theme and font rendering need them
#   mbedtls         - TLS, needed for any https fetch
#   advanced GUI    - LineEdit and ScrollContainer live close to that line;
#                     the few percent are not worth breaking the nickname
#                     prompt and the dashboard list
SCONS_FLAGS=(
	platform=web
	target=template_release
	"threads=no"                    # Facebook hosting cannot set COOP/COEP
	"optimize=size"
	"lto=full"
	"deprecated=no"
	"disable_3d=yes"                # pure 2D game; the single biggest strip
	"module_text_server_adv_enabled=no"
	"module_text_server_fb_enabled=yes"   # fallback text server drops the ICU data
	"module_navigation_2d_enabled=no"
	"module_navigation_3d_enabled=no"
	"module_csg_enabled=no"
	"module_gridmap_enabled=no"
	"module_multiplayer_enabled=no"
	"module_websocket_enabled=no"
	"module_webrtc_enabled=no"
	"module_upnp_enabled=no"
	"module_openxr_enabled=no"
	"module_webxr_enabled=no"
	"module_theora_enabled=no"
	"module_camera_enabled=no"
	"module_lightmapper_rd_enabled=no"
	"module_raycast_enabled=no"
	"module_xatlas_unwrap_enabled=no"
)

log() { printf '\n=== %s ===\n' "$*"; }

mkdir -p "$WORK" "$OUT_DIR"

log "SCons"
if [ ! -d "$WORK/venv" ]; then
	python3 -m venv "$WORK/venv"
fi
"$WORK/venv/bin/pip" install --quiet --upgrade pip scons
SCONS="$WORK/venv/bin/scons"
"$SCONS" --version | head -2

log "Emscripten $EMSDK_VERSION"
if [ ! -d "$EMSDK_DIR" ]; then
	git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
fi
(
	cd "$EMSDK_DIR"
	./emsdk install "$EMSDK_VERSION"
	./emsdk activate "$EMSDK_VERSION"
)
# shellcheck disable=SC1091
source "$EMSDK_DIR/emsdk_env.sh"
emcc --version | head -1

log "Godot source $GODOT_TAG"
if [ ! -d "$SRC_DIR" ]; then
	git clone --depth 1 --branch "$GODOT_TAG" \
		https://github.com/godotengine/godot.git "$SRC_DIR"
fi

log "Building (this takes 30-60 minutes)"
(
	cd "$SRC_DIR"
	"$SCONS" "${SCONS_FLAGS[@]}" -j"$(getconf _NPROCESSORS_ONLN)"
)

log "Packaging template"
BIN="$SRC_DIR/bin"
ZIP="$OUT_DIR/brickrain_web_nothreads_release.zip"
rm -f "$ZIP"

# Godot expects the template zip to contain the files named godot.*, exactly as
# the official web_nothreads_release.zip does.
STAGE="$WORK/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
for f in "$BIN"/godot.web.template_release.wasm32.nothreads*; do
	[ -e "$f" ] || continue
	base="$(basename "$f")"
	case "$base" in
		*.wasm) cp "$f" "$STAGE/godot.wasm" ;;
		*.js)   cp "$f" "$STAGE/godot.js" ;;
		*.html) cp "$f" "$STAGE/godot.html" ;;
		*.worklet.js) cp "$f" "$STAGE/$base" ;;
		*) cp "$f" "$STAGE/$base" ;;
	esac
done
# The audio worklets and html shell ship alongside the binary.
for extra in godot.audio.worklet.js godot.audio.position.worklet.js godot.html godot.service.worker.js godot.offline.html; do
	[ -f "$BIN/$extra" ] && cp "$BIN/$extra" "$STAGE/$extra"
done

(cd "$STAGE" && zip -q -r "$ZIP" .)

log "Result"
ls -la "$STAGE"
printf '\ntemplate: %s\n' "$ZIP"
printf 'size    : %s\n' "$(du -h "$ZIP" | cut -f1)"
printf '\nPoint godot/export_presets.cfg at it with:\n'
printf '  custom_template/release="%s"\n' "$ZIP"
