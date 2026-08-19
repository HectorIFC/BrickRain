# BrickRain - entry point for both implementations.
#
# This repository holds TWO independent games that build, test and ship
# separately:
#
#   Roku   - the BrightScript/SceneGraph channel at the repository root
#   Godot  - the web game under godot/, targeting Facebook Instant Games
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
	godot-import godot-build godot-test godot-layout godot-touch godot-play godot-serve \
	godot-play-clean godot-capture godot-tunnel \
	godot-assets godot-template godot-controls \
	test check no-dashes doctor clean clean-all

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
##@ Roku - BrightScript channel
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
		echo "missing .env - copy .env.example and fill in your device address"; \
		exit 1; \
	}
	npm run deploy

roku-assets: ## Regenerate the channel's sounds and artwork
	python3 tools/generate_sounds.py
	python3 tools/generate_artwork.py --target roku

# --------------------------------------------------------------------------
##@ Godot - web / Facebook Instant Games
# --------------------------------------------------------------------------

godot-import: godot/.godot ## Populate godot/.godot/ (needed on a fresh clone)

godot-build: node_modules godot/.godot ## Export and package out/brickrain-web.zip
	npm run web:build

godot-test: godot/.godot ## Logic suite - 48 cases, incl. the seed-23 golden values
	npm run web:test

godot-layout: godot/.godot ## Layout smoke test - screens fill, portrait/landscape flip
	npm run web:test:layout

# Nothing else exercises touch: every desktop playtest used the keyboard, so a
# broken gesture would stay invisible until someone opened the game on a phone.
godot-touch: godot/.godot ## Touch input test - drag, tap and flick reach the game
	$(GODOT) --headless --path godot res://tests/TouchInput.tscn

godot-play: godot-build godot-controls ## Build, serve, and open the browser
	@echo "  Serving $(WEB_DIR) at http://127.0.0.1:$(PORT)  (Ctrl-C to stop)"
	@echo ""
	@command -v open >/dev/null 2>&1 && ( sleep 1; open "http://127.0.0.1:$(PORT)" ) & \
		cd $(WEB_DIR) && python3 -m http.server $(PORT)

# Browser storage (IndexedDB) is partitioned per ORIGIN, and the port is part
# of the origin - so a throwaway random port gives an empty save: no nickname,
# no runs, record 0. Perfect for manually testing the first-run flow, the
# "record to beat" logic and the new-record fireworks without touching code.
godot-play-clean: godot-build godot-controls ## Play with EMPTY storage (fresh throwaway origin)
	@P=$$((20000 + $$RANDOM % 20000)); \
	echo "  Fresh origin http://127.0.0.1:$$P - nickname, runs and record start empty"; \
	echo ""; \
	( command -v open >/dev/null 2>&1 && sleep 1 && open "http://127.0.0.1:$$P" ) & \
	cd $(WEB_DIR) && python3 -m http.server $$P

# Movie Maker mode renders offline at a fixed clock, so effects that are too
# fast to screenshot by hand (LEVEL popup, fireworks) come out frame by frame.
godot-capture: godot/.godot ## Record the fast effects as PNG frames (build/captures/)
	@rm -rf build/captures && mkdir -p build/captures
	$(GODOT) --path godot --write-movie ../build/captures/fx.png --fixed-fps 30 res://tests/FxCapture.tscn
	@echo ""
	@echo "  Frames in build/captures/ - fx00000018.png is ~0.6s (LEVEL popup),"
	@echo "  fx00000090.png onward is the fireworks show."

# THE way to open the game on a phone, and https is not a nicety here: a Godot
# web export refuses to start outside a secure context. Browsers treat
# localhost and 127.0.0.1 as secure even over http, which is why godot-play
# works on this machine, but a LAN address over http never is - it fails with
# "Secure Context - Check web server configuration (use HTTPS)". A quick tunnel
# hands back a real https URL with no account and no router changes.
#
# For testing only: while this runs, anyone holding the link reaches this
# machine.
godot-tunnel: godot-build ## Public https URL for phone testing (needs cloudflared)
	@command -v cloudflared >/dev/null 2>&1 || { \
		echo ""; \
		echo "  cloudflared is not installed. Install it with:"; \
		echo "      brew install cloudflared"; \
		echo ""; \
		exit 1; \
	}
	@echo ""
	@echo "  Starting the tunnel. Open the https://<random>.trycloudflare.com"
	@echo "  address printed below on the phone. Ctrl-C stops both."
	@echo ""
	@cd $(WEB_DIR) && python3 -m http.server $(PORT) >/dev/null 2>&1 & \
	SERVER=$$!; \
	trap 'kill $$SERVER 2>/dev/null' EXIT INT TERM; \
	sleep 1; \
	cloudflared tunnel --url http://127.0.0.1:$(PORT)

godot-serve: ## Serve the last build without rebuilding
	@test -f $(WEB_DIR)/index.html || { \
		echo "no build found in $(WEB_DIR) - run 'make godot-build' first"; \
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
	@echo "  Portrait puts HOLD / II / SOUND in a column right of the well, and"
	@echo "  <  >  TURN  v  DROP across the bottom."
	@echo ""
	@echo "  Keyboard                        Touch: buttons     Touch: gestures"
	@echo "    Left / A     move left            <  (hold)         drag sideways"
	@echo "    Right / D    move right           >  (hold)         drag sideways"
	@echo "    Down / S     soft drop            v  (hold)         drag down"
	@echo "    Space        HARD DROP            DROP              flick down fast"
	@echo "    Up / W / X   rotate cw            TURN              tap"
	@echo "    Z            rotate ccw           -                 -"
	@echo "    C / Shift    hold                 HOLD              -"
	@echo "    Esc / P      pause                II                -"
	@echo "                 mute                 SOUND             -"
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
test: roku-test godot-test ## Run both logic suites - the totals must match
	@echo ""
	@echo "  Both suites above must read: Cases: 48, checks: 282, failed: 0"
	@echo "  Different totals mean the two cores have drifted - see CONTRIBUTING.md"
	@echo ""

# The long dashes read as a tell of machine-written text, so they are banned
# from every tracked file and from commit messages. This makes the rule
# enforceable instead of remembered. The characters are built from their code
# points so this recipe does not itself contain one.
no-dashes: ## Fail if any tracked file contains a long dash
	@BAD=$$(printf '\xe2\x80\x94'); WORSE=$$(printf '\xe2\x80\x93'); \
	if git grep -n -e "$$BAD" -e "$$WORSE" -- . >/dev/null 2>&1; then \
		echo ""; \
		echo "  Long dashes found. Use a plain hyphen or rewrite the sentence:"; \
		echo ""; \
		git grep -n -e "$$BAD" -e "$$WORSE" -- . | sed 's/^/    /'; \
		echo ""; \
		exit 1; \
	fi
	@echo "  No long dashes."

check: no-dashes roku-lint roku-build roku-test godot-test godot-layout godot-touch ## Full pre-PR gate
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
	@printf "    %-9s " cloudflared; command -v cloudflared >/dev/null 2>&1 && echo "ok"   || echo "absent (optional, only for godot-tunnel)"
	@printf "    %-9s " brotli;  command -v brotli  >/dev/null 2>&1 && echo "ok"         || echo "missing (only used for size measurements)"
	@echo ""
	@echo "  Project state"
	@test -d node_modules      && echo "    node_modules    present" || echo "    node_modules    missing - run any target to install"
	@test -d godot/.godot      && echo "    godot/.godot    present" || echo "    godot/.godot    missing - run 'make godot-import'"
	@test -f $(MUSIC)          && echo "    music track     present" || echo "    music track     MISSING - run 'make godot-assets' (godot-build fails without it)"
	@test -f $(WEB_TEMPLATE)   && echo "    engine template custom (optimised, ~27% smaller)" \
	                           || echo "    engine template stock - run 'make godot-template' for the optimised one"
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
# Prerequisites - real file targets so make can skip work already done
# --------------------------------------------------------------------------

node_modules: package-lock.json
	npm ci
	@touch node_modules

godot/.godot: godot/project.godot
	$(GODOT) --headless --path godot --import
	@touch godot/.godot
