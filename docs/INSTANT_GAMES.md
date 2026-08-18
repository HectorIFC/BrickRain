# Publishing BrickRain to Facebook Instant Games

The web implementation lives in `godot/` and ships as a ZIP that **Facebook hosts** — there
is no server to run and no CORS or MIME configuration to get right.

Everything in "Build the bundle" is automated. Everything in "Meta-side steps" has to be
done by a human with access to the Facebook developer account.

---

## Build the bundle

```bash
make godot-test     # 48 logic cases, including the seed-23 golden values
make godot-layout   # screens fill the viewport; portrait/landscape flip
make godot-build    # export + package -> out/brickrain-web.zip
make godot-play     # ...or build it and play it locally in one step
```

(These wrap `npm run web:test`, `web:test:layout` and `web:build`, which CI calls directly.)

`npm run web:build` verifies that `index.html`, `fbapp-config.json` and `theme.ogg` land at
the **root** of the archive. A nested layout is accepted by the uploader and then fails to
boot, so it is worth failing the build on.

If `godot/music/theme.ogg` is missing, regenerate it with
`python3 tools/generate_music.py`. It is deliberately kept out of `index.pck` — everything
in the pck is downloaded before the first frame, so packing the 725 KB track would delay
the boot for every player. It is fetched lazily instead, and the game runs fine without it.

CI (`.github/workflows/godot-ci.yml`) runs the same steps on every push and attaches the
ZIP as a workflow artifact, so there is always a reviewable bundle to download.

### Optional: the size-optimised runtime

The Godot runtime dominates the download. A stripped custom template cuts about a quarter
off the whole bundle — measured on the current content, music included:

| | raw | gzip | brotli |
|---|---:|---:|---:|
| stock | 38.85 MB | 10.47 MB | 7.42 MB |
| stripped | 27.91 MB | 7.72 MB | **5.59 MB** |
| saving | 10.99 MB | 2.77 MB | 1.86 MB (25%) |

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

> **On the accuracy of this section.** The navigation labels below come from the sources
> listed at the end, not from a live dashboard. Meta reshuffles these flows regularly, so
> treat the labels as "look for something like this", not as coordinates. Where a step is
> a documented behaviour rather than a label — status transitions, prerequisites, review
> times — it is called out as such, because those are the parts that actually bite.

### Do these in this order, not the order they are numbered

Business Verification gates App Review and takes **up to four weeks**; the review itself
takes **3-5 business days**. So verification starts on day one and runs in the background
while everything else happens. Left to the end, the submission sits idle for a month
waiting on something that could have been started immediately.

```
Day 1    ├── Step 0  Business Verification ....................... (up to 4 weeks)
         ├── Step 1  Create the app
         ├── Step 2  Rewarded video placement
         ├── Step 3  Upload the bundle
         └── Step 4  Test on device
                                          Step 5  Submit ── (3-5 business days)
                                          ↑ needs Step 0 finished
```

---

### Step 0 — Business Verification (start immediately)

App Review requires the game to be linked to a **verified business**, and verification is
the long pole in the whole schedule.

Prerequisites, both easy to miss:

- The admin starting the verification needs **two-factor authentication** enabled on their
  personal Facebook account.
- The Business Manager needs an **app connected to it**. Step 1 satisfies this, so if you
  do Step 1 first the connection is already there.

Expect **up to 4 weeks**. Nothing in Step 5 can be submitted until this clears.

### Step 1 — Create the app

Meta for Developers → **Create App** → app type **Games** → add the **Instant Games**
product. During setup you are asked whether the game uses Instant Games (**yes**) and for
an **orientation** — choose **portrait**, which is what the layout is designed around
(`godot/scenes/game.gd` stacks panel / well / controls when height ≥ width).

Every game created after 2025-08-01 runs under **Network Enabled Zero Permissions**, which
is why the SDK is pinned to v8.0 in `godot/web/index.html`.

> Zero Permissions removes `player.getName()` and `player.getPhoto()`. This is why the game
> asks for a nickname itself (`godot/scenes/nickname_entry.gd`) rather than reading one from
> the SDK — that flow is required, not decorative. Player **ID** is still available.

### Step 2 — Rewarded video placement

Two different surfaces are involved, which is the part that trips people up: the **app
dashboard** enables the product, but the placement itself is created in **Monetization
Manager**, inside Business Manager.

1. App dashboard → **Add a Product** → **Audience Network** → Set Up.
2. **Monetization Manager** → choose or create a business → choose country → create a
   **property** and name it.
3. Choose the display format — **Rewarded Video** — and create the placement.
4. **Copy ID**.

Paste it into `godot/app_config.json`:

```json
{
  "rewarded_placement_id": "<paste the id here>",
  "leaderboard_name": "brickrain_high_scores"
}
```

Then rebuild — the config ships inside the bundle:

```bash
make godot-build
```

Three things worth knowing before you judge whether it works:

- **Ads are not served to desktop browsers.** The "Continue (watch ad)" option will never
  appear in Chrome on a computer. That is the platform, not a bug — test ads on a phone.
- **Payout information is a prerequisite.** Until a payment account is attached in
  Business Manager, no ads are served, so the offer stays hidden even on mobile.
- **An empty id is a supported state.** Placement ids are configuration, never compiled
  into source; with the field empty the offer is simply not shown and nothing errors. That
  is the correct behaviour before this step is done.

### Step 3 — Upload the bundle

```bash
make godot-build      # writes out/brickrain-web.zip
```

App dashboard → **Web Hosting** → **Upload Version** → pick `out/brickrain-web.zip`.

The upload then moves through states on its own:

| State | Meaning |
|---|---|
| **Processing** | Just uploaded; Meta is unpacking it |
| **Standby** | Ready, usually after a minute or two, but **not** serving to anyone |
| **Production** | Serving — set by clicking the **star** ("Push to Production") on the row |

**"Production" does not mean public.** Until the game passes App Review, only people listed
under Roles can open it. Pushing to production is safe, and Step 4 depends on it.

### Step 4 — Test on a real device

**You cannot test at all until a version is starred as production**, so do Step 3 first.

Add whoever should try it: app dashboard → **Roles** → **Add testers**.

On the phone: open **Messenger** → any conversation → the **+** button → **Games** → the
game appears there for accounts that have the tester or developer role.

Now run the checks that cannot be verified anywhere else:

- [ ] Loading bar advances and the game starts (`initializeAsync` → `startGameAsync`)
- [ ] Nickname prompt accepts input and the software keyboard appears
- [ ] Portrait layout on a real handset
- [ ] Score persists across sessions (`player.setDataAsync` / `getDataAsync`)
- [ ] The rewarded "Continue" offer appears at game over **only when an ad is loaded**
- [ ] Watching the ad through continues the run; **dismissing it early does not**
- [ ] Scores appear on the Facebook social leaderboard
- [ ] The **Share** button appears at game over and opens the share dialog with the
      generated score card and the result text
- [ ] **Friends Ranking** on the dashboard opens the native leaderboard overlay with
      friends' names and photos — and pin the real overlayViews entry point in the
      shim if the probe list in `showLeaderboard` missed it (an UNSUPPORTED result
      in the console means exactly that)
- [ ] Audio: music starts on the first tap, effects are audible, mute persists

Two of these only work on a phone: **ads** (not served to desktop) and the **software
keyboard**. Everything else can be sanity-checked with `make godot-play` first.

### Step 5 — App Center listing and submission

The game needs a store listing before it can be reviewed.

1. App dashboard → **App Center** (add the product if it is not there yet).
2. **Details** — upload the icons, screenshots and any video, and write the description.
   Use real screenshots; this is what players see before installing.
3. **Review** sub-section → start a submission → fill in the **App Verification notes**
   (how a reviewer reaches the gameplay, plus anything non-obvious).
4. **Submit for Review** only becomes available once Details and the verification notes are
   both complete — if the button looks disabled, something above is unfinished.

Review takes **3-5 business days**. You can launch **globally or country by country**. Once
approved, the game is not reviewed again unless it is later found to violate policy.

---

## Sources

Meta rewrites these flows often, and `developers.facebook.com` renders through JavaScript,
so the pages cannot be read by simple tooling. These are the references behind the labels
above — re-check them when something does not match:

- [Instant Games launch checklist](https://developers.facebook.com/docs/games/build/instant-games/get-started/launch-checklist)
- [App Center for Instant Games](https://developers.facebook.com/docs/games/build/instant-games/get-started/app-center/)
- [Ads and monetization guide](https://developers.facebook.com/docs/games/instant-games/guides/ads-monetization/)
- [How do I monetize Instant Games with Audience Network?](https://www.facebook.com/business/help/355647874927053)
- [GDevelop: publishing to Facebook Instant Games](https://wiki.gdevelop.io/gdevelop5/publishing/publishing-to-facebook-instant-games/)
- [GDevelop: monetizing an Instant Game](https://wiki.gdevelop.io/gdevelop5/publishing/publishing-to-facebook-instant-games/monetize/)
- [GameMaker: Instant Games getting started](https://gamemaker.io/en/help/articles/facebook-instant-games-getting-started)

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

- **In-game "Your best runs"** — one row per game played, the same model the Roku channel
  uses. On the shared living-room TV that list is a genuine household ranking; on Facebook
  every player is on their own device, so the web UI presents it as what it really is
  there: the player's personal history.
- **Facebook social leaderboard** — one best score per player, via `setScoreAsync`, opened
  from the dashboard's **Friends Ranking** button (shown on-platform only). Facebook's own
  overlay renders the names and photos that Zero Permissions no longer exposes to the
  game. There is deliberately no custom ranking backend: it would cost hosting and
  moderation forever, be trivially cheatable without server-side replay validation, and
  compete with the platform ranking that already exists for free.

They are different products and both are intentional.

## Known limits

- **First load takes longer than the 3 s the PRD asked for on a typical mobile
  connection.** At 5.59 MB brotli it
  is roughly 4.9 s of transfer at 9 Mbps plus ~2 s of engine boot. It meets <3 s above
  ~50 Mbps and on every cached repeat load. The stripped template was the last significant
  lever; further gains would mean cutting engine features the game uses, or shortening the
  soundtrack again (the 90 s track is 725 KB of that figure).
- Meta's documented bundle ceiling is 200 MB and the packager fails above it. At ~7.8 MB
  zipped there is a lot of headroom. Worth confirming the current figure in the dashboard,
  since it is documented outside the main SDK reference.
- Deploy is manual. Meta publishes no first-party GitHub Action for bundle upload, and
  automating it means a long-lived Graph API token in repo secrets.
