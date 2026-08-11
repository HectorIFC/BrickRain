# Publishing BrickRain to Facebook Instant Games

The web implementation lives in `godot/` and ships as a ZIP that **Facebook hosts** — there
is no server to run and no CORS or MIME configuration to get right.

Everything in "Build the bundle" is automated. Everything in "Meta-side steps" has to be
done by a human with access to the Facebook developer account.

---

## Build the bundle

```bash
npm run web:test          # 44 logic cases, including the seed-23 golden values
npm run web:test:layout   # screens fill the viewport; portrait/landscape flip
npm run web:build         # export + package -> out/brickrain-web.zip
```

`npm run web:build` verifies that `index.html` and `fbapp-config.json` land at the **root**
of the archive. A nested layout is accepted by the uploader and then fails to boot, so it
is worth failing the build on.

CI (`.github/workflows/godot-ci.yml`) runs the same steps on every push and attaches the
ZIP as a workflow artifact, so there is always a reviewable bundle to download.

### Optional: the size-optimised runtime

The stock Godot runtime is ~99% of the download. A stripped custom template cuts it by
about 27%:

| | raw | gzip | brotli |
|---|---:|---:|---:|
| stock | 38.12 MB | 9.74 MB | 6.76 MB |
| stripped | 27.12 MB | 7.01 MB | 4.90 MB |

```bash
tools/build_web_template.sh        # ~8 minutes; needs ~15 GB free disk
npm run web:build                  # picks the template up automatically
```

The template is a **build artifact** and is not committed. Build it once, publish it (a
GitHub Release asset works well), and point CI at a downloaded copy with
`BRICKRAIN_WEB_TEMPLATE=/path/to/template.zip`. `scripts/export-web.js` uses it when
present and the stock template otherwise, so a clean clone always exports.

---

## Meta-side steps

These need the Facebook developer account and cannot be scripted from this repo.

### 1. Create the app

App Dashboard → Create App → **Instant Games**.

Every game created after 2025-08-01 runs under **Network Enabled Zero Permissions**, which
is why the SDK is pinned to v8.0 in `godot/web/index.html`.

> Zero Permissions removes `player.getName()` and `player.getPhoto()`. This is why the game
> asks for a nickname itself (`godot/scenes/nickname_entry.gd`) rather than reading one from
> the SDK — that flow is required, not decorative. Player **ID** is still available.

### 2. Create the ad placement and wire the id in

Monetization → create a **Rewarded Video** placement, then put its id in
`godot/app_config.json`:

```json
{
  "rewarded_placement_id": "<paste the id here>",
  "leaderboard_name": "brickrain_high_scores"
}
```

Placement ids are configuration, never compiled into source. **An empty id is a supported
state**: the rewarded "Continue" offer is simply not shown, and nothing errors. That is the
correct behaviour before this step is done.

Rebuild after editing (`npm run web:build`) — the config ships inside the bundle.

### 3. Upload

Web Hosting → **Upload Version** → `out/brickrain-web.zip`, then push it to production when
you are ready.

### 4. Test

Test in the Instant Games test environment first, then in the real Messenger / Facebook
mobile app. Worth checking specifically, because none of it can be verified off-platform:

- [ ] Loading bar advances and the game starts (`initializeAsync` → `startGameAsync`)
- [ ] Nickname prompt accepts input and the software keyboard appears on a phone
- [ ] Portrait layout on a real handset; landscape if you support rotating
- [ ] Score persists across sessions (`player.setDataAsync` / `getDataAsync`)
- [ ] The rewarded "Continue" offer appears at game over **only when an ad is loaded**
- [ ] Watching the ad through continues the run; **dismissing it early does not**
- [ ] Scores appear on the Facebook social leaderboard

### 5. App Review + Business Verification

Required for real-time data access before the game can be public. This is the long pole in
the schedule — start it in parallel with the testing above, not after.

---

## How the platform layer is put together

| File | Role |
|---|---|
| `godot/web/index.html` | Custom Godot shell: SDK tag, boot sequence, `BrickRainFB` shim |
| `godot/platform/fb_bridge.gd` | Autoload; the only code that talks to the SDK |
| `godot/platform/ads.gd` | Rewarded video state machine |
| `godot/platform/storage.gd` | Cloud save + local `user://` fallback + merge |
| `godot/platform/app_config.gd` | Reads `app_config.json` |
| `godot/fbapp-config.json` | Bundle manifest; copied to the ZIP root at packaging |

Two design points worth knowing before changing any of it:

**Everything degrades off-platform.** No caller branches on the environment; each platform
call resolves to a defined "unavailable" result. This is what keeps the game runnable in
the editor and on a plain web server.

**`initializeAsync` is bounded by a timeout.** Off platform the SDK script still loads from
Meta's CDN, so `FBInstant` exists — but `initializeAsync` then never resolves *and never
rejects*. Awaiting it unguarded means the game never starts at all. The shim races it
against a 5 s timeout and falls through to unavailable. Do not remove that guard.

## Two leaderboards, on purpose

- **In-game dashboard** — one row per game played, so the same nickname can appear many
  times. This is the Roku model, kept identical.
- **Facebook social leaderboard** — one best score per player, via `setScoreAsync`.
  Facebook's own overlay renders the names and photos that Zero Permissions no longer
  exposes to the game.

They are different products and both are intentional.

## Known limits

- **First load misses NFR01 (<3 s) on a typical mobile connection.** At 4.90 MB brotli it
  is roughly 4.4 s of transfer at 9 Mbps plus ~2 s of engine boot. It meets <3 s above
  ~40 Mbps and on every cached repeat load. The stripped template was the last significant
  lever; further gains would mean cutting engine features the game uses.
- Meta's documented bundle ceiling is 200 MB and the packager fails above it. At ~7 MB
  zipped there is a lot of headroom. Worth confirming the current figure in the dashboard,
  since it is documented outside the main SDK reference.
- Deploy is manual. Meta publishes no first-party GitHub Action for bundle upload, and
  automating it means a long-lived Graph API token in repo secrets.
