# PRD - BrickRain: a falling-blocks game for Roku TV

**Status:** ready for implementation
**Executor:** Claude Code
**Owner:** Hector
**Goal:** open-source portfolio project demonstrating real Roku platform experience (BrightScript, SceneGraph, Roku tooling) for job applications.

---

## 0. Instructions for Claude Code (read first)

1. Before writing any code, complete **Section 1 (Environment & skills setup)**.
2. All code, identifiers, comments and docstrings MUST be in English.
3. Work in milestones (Section 9). Do not start a milestone before the previous one's acceptance criteria pass.
4. Game logic must be pure BrighterScript modules with NO SceneGraph dependencies, so it is unit-testable. UI is a thin layer on top.
5. Run `npm run lint` and `npm run test` after every significant change.
6. Never commit secrets, device IPs, developer passwords or Roku signing keys (Section 7).
7. IMPORTANT - naming/legal: the game is called **BrickRain**. Never use the word "Tetris" in code, assets, README, store metadata or commit messages ("Tetris" is a registered trademark; the mechanic of falling tetrominoes is not protected, the brand is). Use the neutral term "falling-blocks game".

---

## 1. Environment & skills setup

### 1.1 Security plugin (official Anthropic)

Install the security-guidance plugin so all generated code is reviewed for
vulnerabilities in-session:

```
/plugin install security-guidance@claude-plugins-official
/reload-plugins
```

Requirements: Claude Code CLI >= 2.1.144, Python 3.8+ on PATH, git repo.
The plugin runs automatically; fix any finding it raises before committing.

### 1.2 Project-local Roku skill (create it)

There is no public Claude skill for Roku/BrightScript (verified June 2026).
Create a project-local skill at `.claude/skills/roku-brightscript/SKILL.md`
with this content, and keep it updated as conventions evolve:

```markdown
---
name: roku-brightscript
description: Conventions and gotchas for Roku development in this repo - BrightScript/BrighterScript syntax, SceneGraph patterns, Rooibos testing, roku-deploy usage. Consult before writing or editing any .bs, .brs or SceneGraph .xml file.
---

# Roku / BrightScript conventions for BrickRain

## Language
- Source is BrighterScript (.bs), transpiled to BrightScript by `bsc`.
- BrightScript is case-insensitive; this repo uses camelCase for variables/functions, PascalCase for components and classes.
- No classes in game-logic modules: use namespaces + pure functions returning AAs (associative arrays), for Rooibos compatibility and clarity.
- `invalid` is BrightScript's null. Always guard: `if node <> invalid`.
- Integer division: `\` operator. Float division: `/`.
- Arrays are `roArray`, maps are `roAssociativeArray` (AA). AA keys are case-insensitive.

## SceneGraph
- UI components live in `components/`, each as a pair `Name.xml` + `Name.bs`.
- Never touch SceneGraph nodes from Task threads; use field observers (`observeField`) for cross-thread communication.
- The render thread must stay light: no heavy loops in observers; game tick computes state in plain data, rendering only updates node fields.
- Reuse node pools for the board cells; do not create/destroy nodes per frame.
- Registry (`roRegistrySection`) is the only persistence; flush with `Flush()` after writes.

## Authoritative references (fetch when unsure about an API)
- SceneGraph API: https://developer.roku.com/docs/references/scenegraph/component-functions/init.md
- BrightScript language: https://developer.roku.com/docs/references/brightscript/language/brightscript-language-reference.md
- Remote key handling: onKeyEvent - https://developer.roku.com/docs/developer-program/core-concepts/handling-application-events.md
- Rooibos: https://github.com/rokucommunity/rooibos
- roku-deploy: https://github.com/rokucommunity/roku-deploy

## Verification rule
BrightScript is a niche language: when uncertain about a SceneGraph node
field, component signature, or OS-version behavior, FETCH the official doc
page above instead of relying on memory.
```

### 1.3 Toolchain (npm dev dependencies)

```bash
npm init -y
npm install --save-dev brighterscript @rokucommunity/bslint rooibos-roku roku-deploy brs-node
```

| Tool | Role |
|---|---|
| `brighterscript` (bsc) | Compiles .bs → .brs, type checking |
| `@rokucommunity/bslint` | Linter |
| `rooibos-roku` | Unit test framework (runs on device/simulator) |
| `roku-deploy` | Zips and sideloads to a Roku device over LAN |
| `brs-node` | BrightScript interpreter for Node - headless logic checks and CI |

---

## 2. Product overview

Single-player falling-blocks game for Roku TVs. Pieces (tetrominoes) fall
into a 10x20 well; completed horizontal lines clear and score points; speed
increases with level; game ends when the stack reaches the top. Fully
offline: no network calls, no accounts, no data collection.

Target audience: anyone with a Roku device; real audience: technical
reviewers evaluating Hector's Roku skills.

## 3. Functional requirements

### 3.1 Game rules
- **Board:** 10 columns x 20 visible rows (+2 hidden spawn rows).
- **Pieces:** the 7 standard tetrominoes (I, O, T, S, Z, J, L).
- **Randomizer:** 7-bag (shuffle a bag of all 7 pieces, deal, refill).
- **Rotation:** Super Rotation System (SRS) with standard wall kicks.
- **Movement:** left, right, soft drop (accelerated fall), hard drop (instant lock).
- **Lock delay:** 500 ms after the piece touches the stack, reset on successful move/rotation (max 15 resets).
- **Line clear scoring:** 1 line = 100 x level, 2 = 300 x level, 3 = 500 x level, 4 = 800 x level. Soft drop: +1/cell. Hard drop: +2/cell.
- **Leveling:** level up every 10 cleared lines. Gravity interval: `max(80, 1000 - (level - 1) * 90)` ms.
- **Next queue:** show the next 3 pieces. **Hold:** one hold slot, once per piece.
- **Ghost piece:** translucent projection of where the piece will land.
- **Game over:** spawn blocked. Show final score, high score, restart prompt.
- **High score:** persisted in the Roku registry (device-local only).

### 3.2 Controls (Roku remote)
| Button | Action |
|---|---|
| Left / Right | Move piece |
| Down | Soft drop (hold to repeat) |
| OK | Rotate clockwise |
| Up | Hard drop |
| Rewind (<<) | Rotate counter-clockwise |
| Play/Pause | Pause / resume |
| Back | Pause menu; from menu, exit |

DAS (delayed auto-shift): 250 ms initial delay, then 50 ms repeat for held left/right/down.

### 3.3 Screens & flow
1. **Leaderboard dashboard (home screen):** logo + ranking table with columns **nickname | score | date** (date formatted `dd/mm/yyyy`), sorted by score descending, plus a focused **"Start game" button**. Empty state: "No scores yet - be the first!".
2. **Nickname dialog:** shown when "Start game" is pressed. Uses the standard SceneGraph keyboard dialog. Pre-filled with the last used nickname (stored in registry). Nickname rules: 2-12 chars, alphanumeric; trimmed; uniqueness is case-insensitive (see 3.5).
3. **Game screen:** board, score, level, lines, next queue, hold slot, current nickname.
4. **Pause overlay:** resume / restart / quit to dashboard.
5. **Game over overlay:** final score, player's best, "new record" state when applicable, then buttons: play again (same nickname) / back to dashboard.

Flow: `Dashboard → [Start game] → Nickname dialog → Game → Game over → Dashboard (updated ranking)`.

### 3.4 Leaderboard & player identity
- A nickname uniquely identifies a player (case-insensitive comparison, display preserves original casing).
- The leaderboard stores **one entry per nickname**: the player's best score and the date (`dd/mm/yyyy`) when that best score was achieved. A lower new score never downgrades an existing entry.
- Ranking: score descending; ties broken by earliest date.
- Capacity: top 50 entries (entries beyond the cap are dropped from the bottom).
- **Persistence:** Roku registry (`roRegistrySection`), serialized as JSON, flushed after every write. This natively matches the requirement: the registry survives app restarts and TV reboots, and is wiped by the OS when the channel is uninstalled. Total size stays well under the registry quota (50 entries ≈ 3 KB).
- Logic lives in `source/logic/leaderboard.bs` (pure module: upsert, sort, cap, serialize/deserialize), fully unit-tested; the registry I/O is a thin adapter in the UI layer.

### 3.5 Audio (required, milestone 2)
All 9 sound effects are **already provided** in `assets/sounds/` (original
chiptune WAVs synthesized by `tools/generate_sounds.py` - zero copyright
concerns, regenerate or tweak via the script). Play via `roAudioResource`.

| File | Trigger |
|---|---|
| `move.wav` | Left / right / soft-drop step |
| `rotate.wav` | Rotation (either direction) |
| `hard_drop.wav` | Hard drop (Up button) |
| `lock.wav` | Piece settles without clearing a line |
| `line_clear.wav` | One or more lines cleared |
| `level_up.wav` | Level increases (every 10 lines) |
| `game_over.wav` | Stack reaches the top |
| `new_record.wav` | Game over with a new personal/leaderboard best |
| `menu_select.wav` | Menu navigation / confirm (dashboard, dialogs, overlays) |

`new_record.wav` plays after `game_over.wav` when applicable. No background
music (licensing risk, out of scope).

### 3.6 Branding & channel artwork (required, milestone 2)
All artwork is **already provided** in `assets/images/` (original pixel-art
generated by `tools/generate_artwork.py` - regenerate or restyle via the
script). Design language: pixel-art wordmark "BRICK RAIN" in the 7-color
tetromino palette over a dark navy gradient with translucent falling pieces,
matching the chiptune audio identity.

Roku-required files and manifest wiring:

| File | Size | Manifest attribute |
|---|---|---|
| `icon_focus_hd.png` | 290x218 | `mm_icon_focus_hd` |
| `icon_focus_sd.png` | 246x140 | `mm_icon_focus_sd` |
| `splash_fhd.png` | 1920x1080 | `splash_screen_fhd` |
| `splash_hd.png` | 1280x720 | `splash_screen_hd` |
| `splash_sd.png` | 720x480 | `splash_screen_sd` |

Manifest snippet:

```
title=BrickRain
major_version=1
minor_version=0
build_version=1
mm_icon_focus_hd=pkg:/images/icon_focus_hd.png
mm_icon_focus_sd=pkg:/images/icon_focus_sd.png
splash_screen_fhd=pkg:/images/splash_fhd.png
splash_screen_hd=pkg:/images/splash_hd.png
splash_screen_sd=pkg:/images/splash_sd.png
splash_color=#080a22
ui_resolutions=fhd
```

Claude Code: verify attribute names and current size requirements against
the official manifest reference before finalizing
(https://developer.roku.com/docs/developer-program/getting-started/architecture/channel-manifest.md).
The in-game title rendering (dashboard header) reuses the same pixel
wordmark style for visual consistency. Channel Store poster/screenshot
artwork is out of scope (publication is out of scope).

## 4. Non-functional requirements
- Smooth gameplay on low-end devices (Roku Express class): game tick via a single SceneGraph `Timer`, render updates only on state change, node pooling for cells.
- UI designed at 1920x1080 (FHD) with `ui_resolutions=fhd` and autoscale.
- Boot to title screen < 3 s on Express-class hardware.
- Zero network permissions in the manifest. Zero PII beyond a self-chosen nickname stored locally. Registry stores only the leaderboard JSON (top 50, ~3 KB) and the last used nickname.
- All logic modules deterministic and seedable (the bag randomizer accepts an optional seed) for reproducible tests.

## 5. Architecture

```
brickrain/
├── manifest                      # channel metadata, fhd flag, no network
├── source/
│   ├── main.bs                   # entry point, shows MainScene
│   └── logic/                    # PURE modules, no SceneGraph imports
│       ├── board.bs              # grid state, collision, line detection/clear
│       ├── piece.bs              # tetromino shapes, SRS rotation + wall kicks
│       ├── bag.bs                # 7-bag randomizer (seedable)
│       ├── score.bs              # scoring + leveling rules
│       ├── leaderboard.bs        # upsert by nickname, sort, cap, (de)serialize
│       └── game.bs               # game state machine: spawn→fall→lock→clear→over
├── components/
│   ├── MainScene.xml/.bs         # routing between screens, key handling
│   ├── LeaderboardScreen.xml/.bs # home: ranking table + Start game button
│   ├── NicknameDialog.xml/.bs    # keyboard dialog wrapper, validation
│   ├── GameScreen.xml/.bs        # ticks Timer, maps state→nodes, DAS handling
│   ├── BoardView.xml/.bs         # node-pooled 10x20 cell grid + ghost piece
│   ├── SidePanel.xml/.bs         # score/level/lines/next/hold/nickname
│   └── overlays/PauseOverlay, GameOverOverlay
├── assets/
│   ├── sounds/                   # 9 provided WAVs (see 3.5)
│   └── images/                   # icons + splash screens (see 3.6)
├── tools/
│   ├── generate_sounds.py        # regenerates assets/sounds from scratch
│   └── generate_artwork.py       # regenerates assets/images from scratch
├── docs/                         # GitHub Pages site (index.html, style.css)
│   └── media/                    # reserved: gameplay.mp4 (added post-recording)
├── .github/workflows/
│   ├── ci.yml                    # lint + build + tests + coverage gate (>=80%)
│   └── release.yml               # conventional commits → tag → GitHub Release
├── tests/                        # Rooibos suites mirroring source/logic + integration
├── .claude/skills/roku-brightscript/SKILL.md
├── bsconfig.json                 # bsc + rooibos + bslint config
├── package.json                  # scripts: build, lint, test, test:logic, deploy
├── .env.example                  # ROKU_DEV_TARGET=, ROKU_DEV_PASSWORD=
├── .gitignore                    # .env, out/, node_modules/, *.pkg, signing keys
└── README.md                     # screenshots, architecture notes, how to run
```

**Key principle:** `source/logic/` is a pure functional core - plain data in,
plain data out. `components/` is an imperative shell that renders state and
forwards input. This is what makes the game testable without a device.

## 6. Testing strategy

**Coverage policy: target 100%, hard minimum 80%** (line coverage on
`source/logic/`). CI fails below 80%. Rooibos' built-in code coverage
produces the report; the CI gate parses it. UI components (`components/`)
are exempt from the numeric gate (SceneGraph rendering is validated by the
manual device checklist) but their extracted logic must live in testable
modules - if a component function grows beyond trivial glue, move it to
`source/logic/` where it is covered.

- **Unit tests (Rooibos)** for every logic module. Minimum scenarios:
  - SRS rotation against walls and stack (wall-kick table cases)
  - Line clear: single, double, triple, quad, and non-contiguous lines
  - 7-bag: all 7 pieces appear exactly once per bag (seeded)
  - Scoring and leveling boundaries (level-up at exactly 10 lines)
  - Lock delay reset cap (15 resets)
  - Game-over on blocked spawn
  - Leaderboard: upsert keeps best score per nickname (case-insensitive), never downgrades, sorts by score desc with date tiebreak, caps at 50, date formatted `dd/mm/yyyy`, JSON round-trip
- **Integration tests:** drive the full game state machine (`game.bs` wiring board + piece + bag + score + leaderboard) with scripted input sequences under `brs-node`. Minimum scenarios: a complete seeded game from spawn to game-over reproducing an exact final score and line count; a quad clear followed by level-up in one flow; game-over score correctly upserted into the leaderboard; pause/resume preserving state.
- **Headless logic check:** `npm run test:logic` runs the pure modules under `brs-node` so CI needs no Roku device.
- **CI (GitHub Actions, `ci.yml`):** on push and PR - install, lint, build (bsc), unit + integration tests, coverage gate (fail < 80%). No secrets in CI.
- **Device testing:** documented in README (developer mode, `npm run deploy`), executed by Hector.

## 7. Security & privacy requirements
- security-guidance plugin active for the whole implementation (1.1).
- `.env` holds `ROKU_DEV_TARGET` (device IP) and `ROKU_DEV_PASSWORD` (dev-mode password); `.env` is gitignored; `.env.example` documents the variables with placeholder values. roku-deploy reads from env, never from hardcoded values.
- Roku **signing keys / .pkg files must never enter the repo** (gitignore `*.pkg`, `*.key`). Packaging for the Channel Store is out of scope and documented as a manual step.
- Manifest requests no network features; code contains no `roUrlTransfer` usage.
- Dependencies pinned via `package-lock.json`; only the RokuCommunity packages listed in 1.3 (well-maintained, widely used) - no unvetted packages.
- No analytics, no tracking, no PII (relevant for Channel Store privacy declarations later).

## 8. Repository, documentation & releases

### 8.1 GitHub Pages (project site)
Static site served from the `docs/` folder on `main` (enable Pages with
source = `main` / `docs/` in repo settings; document this step in README).
Style: same pixel-art identity (dark navy background `#080a22`, tetromino
palette accents, the wordmark image as header). No build framework - plain
`docs/index.html` + `docs/style.css`, keeping the page dependency-free.

Page sections, in order:
1. **Hero:** BrickRain logo (`splash_fhd.png` artwork or the wordmark), one-line tagline, GitHub repo link, CI + release badges.
2. **Gameplay video (RESERVED):** an empty, clearly marked section with an HTML comment `<!-- GAMEPLAY VIDEO: replace placeholder with docs/media/gameplay.mp4 when recorded -->` and a hidden `<video controls>` snippet pointing to `docs/media/gameplay.mp4`, ready to be un-commented. Until then, show a styled placeholder card: "Gameplay video on a real Roku TV - coming soon". Create `docs/media/` with a `.gitkeep`.
3. **How to play:** controls table (remote buttons → actions) and game rules summary.
4. **How to run it:** two paths - (a) on a real Roku: enable developer mode, `npm install`, configure `.env`, `npm run deploy`; (b) without a Roku: run in the browser via brs-engine. Copy-paste commands for both.
5. **Architecture & credits:** short write-up linking to the README deep dive; note that all art and audio are original, generated by the scripts in `tools/`.

### 8.2 README.md structure
1. Logo (wordmark image) + badges (CI status, coverage, latest release tag, license).
2. **Gameplay video (RESERVED):** a `## Gameplay` section containing an HTML comment placeholder: `<!-- Drag and drop gameplay.mp4 here in the GitHub editor when recorded - GitHub will host it and render an inline player -->`. (Drag-and-drop in the GitHub editor is the reliable way to get an inline video player in a README; also commit the same file to `docs/media/gameplay.mp4` for the Pages site.)
3. Features, controls table, screenshots/GIF.
4. Quick start (device + brs-engine paths), test/coverage instructions.
5. Architecture overview (pure-core/imperative-shell, link to PRD).
6. Versioning & release process (8.3), license (MIT).

### 8.3 Automatic versioning & releases
Replicate the Tessera pattern (HectorIFC/tessera `release.yml`):
- **Conventional commits** drive SemVer: `feat!:`/`BREAKING CHANGE:` → major, `feat:` → minor, `fix:`/`build:`/`chore:` → patch. Squash-merge PR titles must be conventional commits; document this in CONTRIBUTING.md.
- Workflow `.github/workflows/release.yml` triggered on push to `main`, with `concurrency: group: release, cancel-in-progress: false` and checkout with `fetch-depth: 0`.
- Use `mathieudutour/github-tag-action@v6.2` (`tag_prefix: v`, `default_bump: patch`) to compute and create the tag; skip the release when no releasable commits exist (new tag == previous tag).
- After tagging: build the sideloadable channel zip (`npm run build`), name it `brickrain-vX.Y.Z.zip`, and attach it to a **GitHub Release** with auto-generated notes - every release is directly installable on a Roku in developer mode.
- Write the version into the manifest (`major_version`/`minor_version`/`build_version`) during the release build so the installed channel reports the real version.

## 9. Milestones & acceptance criteria

**M1 - Pure game logic + tests**
- All `source/logic/` modules implemented; Rooibos + headless suites green; lint clean.
- Acceptance: `npm run test:logic` passes; a scripted simulation (seeded bag, fixed input sequence) reproduces a known final score.

**M2 - Playable SceneGraph UI**
- Leaderboard dashboard (home) with ranking table and Start game button, nickname dialog with validation, game screen with board/side panel, key handling with DAS, pause and game-over overlays, registry persistence (leaderboard + last nickname), all 9 sound effects wired.
- Acceptance: `npm run build` clean; deployable zip produced; manual checklist in README all green on device or brs-engine, including: reboot the device and confirm the leaderboard survives.

**M3 - Polish & portfolio**
- Ghost piece, level-based color themes, GitHub Pages site (8.1) with the reserved gameplay-video section, README per 8.2 with reserved video section, release workflow (8.3) producing the first tagged release with attached channel zip, coverage badge, architecture write-up.
- Acceptance: Pages site live; pushing a `feat:` commit to main produces a new tag + GitHub Release with `brickrain-vX.Y.Z.zip` attached; coverage gate enforced in CI; repo presentable as a portfolio piece without further explanation.

## 10. Out of scope
- Channel Store publication (documented as future work)
- Multiplayer, leaderboards, network features of any kind
- Background music
- Tizen/Android TV ports
