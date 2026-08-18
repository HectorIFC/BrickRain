# BrickRain — entry point for both implementations.
#
# This repository holds TWO independent games that build, test and ship
# separately:
#
#   Roku   — the BrightScript/SceneGraph channel at the repository root
#   Godot  — the web game under godot/, targeting Facebook Instant Games
#
# Every platform-specific target is prefixed accordingly, so it is never
# ambiguous which game a command acts on. Only genuinely cross-platform work
# (test, check, doctor, clean) is unprefixed.
#
# These targets wrap the existing npm scripts and Python generators rather than
# reimplementing them; CI calls those scripts directly and must keep working
# without make.
#
# Run `make` for the target list.

PORT ?= 8777
GODOT ?= godot

WEB_DIR := build/web
WEB_BUNDLE := out/brickrain-web.zip
CHANNEL := out/brickrain.zip
WEB_TEMPLATE := build/templates/brickrain_web_nothreads_release.zip
MUSIC := godot/music/theme.ogg

.DEFAULT_GOAL := help

.PHONY: help \
	roku-lint roku-build roku-test roku-play roku-deploy roku-assets \
	godot-import godot-build godot-test godot-layout godot-play godot-serve \
	godot-assets godot-template godot-controls \
	test check doctor clean clean-all

# --------------------------------------------------------------------------
##@ Getting started
# --------------------------------------------------------------------------

help: ## Show this help
	@awk 'BEGIN { FS = ":.*##" } \
		/^##@/ { printf "\n  \033[1m%s\033[0m\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_-]+:.*##/ { printf "    \033[36m%-16s\033[0m %s\n", $$1, $$2 } \
		' $(MAKEFILE_LIST)
	@echo ""
	@echo "  Override PORT or GODOT, e.g. make godot-play PORT=9001"
	@echo ""

# --------------------------------------------------------------------------
##@ Roku — BrightScript channel
# --------------------------------------------------------------------------

roku-lint: node_modules ## BrighterScript validation + bslint
	npm run lint

roku-build: node_modules ## Package the channel into out/brickrain.zip
	npm run build

roku-test: node_modules ## Logic suite, headless under brs-node (no device)
	npm run test:logic

roku-play: roku-build ## Build, then play in the brs-engine web app
	@echo ""
	@echo "  Channel built: $(CHANNEL)"
	@echo ""
	@echo "  There is no local Roku runner. To play without a device, drop"
	@echo "  that zip into the brs-engine web app:"
	@echo ""
	@echo "      https://lvcabral.com/brs/"
	@echo ""
	@echo "  For a real device use 'make roku-deploy' (developer mode required)."
	@echo ""

roku-deploy: node_modules ## Sideload onto a device (requires .env)
	@test -f .env || { \
		echo "missing .env — copy .env.example and fill in your device address"; \
		exit 1; \
	}
	npm run deploy

roku-assets: ## Regenerate the channel's sounds and artwork
	python3 tools/generate_sounds.py
	python3 tools/generate_artwork.py --target roku

# --------------------------------------------------------------------------
##@ Godot — web / Facebook Instant Games
# --------------------------------------------------------------------------

godot-import: godot/.godot ## Populate godot/.godot/ (needed on a fresh clone)

godot-build: node_modules godot/.godot ## Export and package out/brickrain-web.zip
	npm run web:build

godot-test: godot/.godot ## Logic suite — 47 cases, incl. the seed-23 golden values
	npm run web:test

godot-layout: godot/.godot ## Layout smoke test — screens fill, portrait/landscape flip
	npm run web:test:layout

godot-play: godot-build godot-controls ## Build, serve, and open the browser
	@echo "  Serving $(WEB_DIR) at http://127.0.0.1:$(PORT)  (Ctrl-C to stop)"
	@echo ""
	@command -v open >/dev/null 2>&1 && ( sleep 1; open "http://127.0.0.1:$(PORT)" ) & \
		cd $(WEB_DIR) && python3 -m http.server $(PORT)

godot-serve: ## Serve the last build without rebuilding
	@test -f $(WEB_DIR)/index.html || { \
		echo "no build found in $(WEB_DIR) — run 'make godot-build' first"; \
		exit 1; \
	}
	@$(MAKE) --no-print-directory godot-controls
	@echo "  Serving $(WEB_DIR) at http://127.0.0.1:$(PORT)  (Ctrl-C to stop)"
	@echo ""
	@cd $(WEB_DIR) && python3 -m http.server $(PORT)

# The bindings live in godot/platform/input_router.gd; printing them here saves
# reading the source to remember which key rotates which way.
godot-controls: ## Print the game controls
	@echo ""
	@echo "  Keyboard                        Touch"
	@echo "    Left / A     move left          drag sideways    move"
	@echo "    Right / D    move right         tap              rotate"
	@echo "    Down / S     soft drop          drag down        soft drop"
	@echo "    Space        HARD DROP          flick down fast  hard drop"
	@echo "    Up / W / X   rotate cw          HOLD button      hold"
	@echo "    Z            rotate ccw         II button        pause"
	@echo "    C / Shift    hold               SOUND button     mute"
	@echo "    Esc / P      pause"
	@echo ""

godot-assets: ## Regenerate the web build's artwork, music and sounds
	python3 tools/generate_artwork.py --target godot
	python3 tools/generate_music.py
	python3 tools/export_godot_assets.py

godot-template: ## Build the size-optimised engine template (~8 min, ~15 GB disk)
	@echo "This compiles Godot from source: roughly 8 minutes and 15 GB of disk."
	@echo "It cuts the payload by about 27%. Ctrl-C now to cancel."
	@echo ""
	tools/build_web_template.sh

# --------------------------------------------------------------------------
##@ Both platforms
# --------------------------------------------------------------------------

# The two cores are independent and cannot import from each other, so this is
# the check that catches drift: both suites must report identical totals.
test: roku-test godot-test ## Run both logic suites — the totals must match
	@echo ""
	@echo "  Both suites above must read: Cases: 47, checks: 275, failed: 0"
	@echo "  Different totals mean the two cores have drifted — see CONTRIBUTING.md"
	@echo ""

check: roku-lint roku-build roku-test godot-test godot-layout ## Full pre-PR gate
	@echo ""
	@echo "  All checks passed."
	@echo ""

doctor: ## Check the toolchain and generated inputs
	@echo ""
	@echo "  Tools"
	@printf "    %-9s " node;    command -v node    >/dev/null 2>&1 && node --version    || echo "MISSING"
	@printf "    %-9s " npm;     command -v npm     >/dev/null 2>&1 && npm --version     || echo "MISSING"
	@printf "    %-9s " godot;   command -v $(GODOT) >/dev/null 2>&1 && $(GODOT) --version || echo "MISSING (needed for every godot- target)"
	@printf "    %-9s " python3; command -v python3 >/dev/null 2>&1 && python3 --version || echo "MISSING"
	@printf "    %-9s " ffmpeg;  command -v ffmpeg  >/dev/null 2>&1 && echo "ok"         || echo "MISSING (needed by godot-assets)"
	@printf "    %-9s " brotli;  command -v brotli  >/dev/null 2>&1 && echo "ok"         || echo "missing (only used for size measurements)"
	@echo ""
	@echo "  Project state"
	@test -d node_modules      && echo "    node_modules    present" || echo "    node_modules    missing — run any target to install"
	@test -d godot/.godot      && echo "    godot/.godot    present" || echo "    godot/.godot    missing — run 'make godot-import'"
	@test -f $(MUSIC)          && echo "    music track     present" || echo "    music track     MISSING — run 'make godot-assets' (godot-build fails without it)"
	@test -f $(WEB_TEMPLATE)   && echo "    engine template custom (optimised, ~27% smaller)" \
	                           || echo "    engine template stock — run 'make godot-template' for the optimised one"
	@echo ""

clean: ## Remove the web build and packaged output
	rm -rf $(WEB_DIR) out
	@echo "removed $(WEB_DIR) and out/"

# build/templates/ is deliberately spared: it is an 8-minute build, and
# export-web.js silently falls back to the stock template if it disappears.
clean-all: clean ## Also remove the Godot import cache and engine build tree
	rm -rf godot/.godot build/engine
	@echo "removed godot/.godot and build/engine (kept build/templates)"

# --------------------------------------------------------------------------
# Prerequisites — real file targets so make can skip work already done
# --------------------------------------------------------------------------

node_modules: package-lock.json
	npm ci
	@touch node_modules

godot/.godot: godot/project.godot
	$(GODOT) --headless --path godot --import
	@touch godot/.godot
