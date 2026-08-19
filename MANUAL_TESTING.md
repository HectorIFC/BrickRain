# Manual device test checklist

The pure game logic is covered by the automated suites (`npm run test:logic`,
and `npm run test:device` on hardware). SceneGraph rendering and remote input
cannot be asserted headlessly, so verify them on a real Roku (or the brs-engine
simulator) with this checklist after each significant UI change.

## Setup

1. Enable **developer mode** on the Roku (Home ×3, Up, Up, Right, Left, Right,
   Left, Right), note the device IP and set a dev-mode password.
2. `cp .env.example .env` and fill in `ROKU_DEV_TARGET` (IP) and
   `ROKU_DEV_PASSWORD`.
3. `npm install`
4. `npm run deploy` - builds `out/brickrain.zip` and sideloads it.

## Checklist

### Boot & dashboard
- [ ] Channel boots to the dashboard in under ~3 s; the BRICK RAIN logo shows.
- [ ] With no scores stored, the empty state reads "No scores yet - be the first!".
- [ ] The **Start Game** button is focused on entry.

### Nickname dialog
- [ ] Pressing Start opens the keyboard dialog.
- [ ] On a second run, the dialog is pre-filled with the last nickname used.
- [ ] Entering fewer than 2 or more than 12 chars, or a symbol/space, keeps the
      dialog open with the validation message; a valid 2-12 alphanumeric name is
      accepted.
- [ ] Cancel returns to the dashboard without starting a game.

### Gameplay & controls
- [ ] Left/Right move the piece; holding repeats after ~0.25 s, then quickly (DAS).
- [ ] Down soft-drops (score +1/cell) and holding repeats.
- [ ] Up hard-drops instantly and locks (score +2/cell).
- [ ] OK rotates clockwise; Rewind (◄◄) rotates counter-clockwise.
- [ ] Rotating against a wall/stack kicks the piece into a legal spot (SRS).
- [ ] Fast-forward (►►) sends the active piece to Hold and pulls it back next time
      (once per piece). *(Hold has no button in the PRD controls table; the free
      fast-forward key was chosen - see README controls note.)*
- [ ] The side panel shows score, level, lines, the next 3 pieces and the hold slot.
- [ ] Clearing 1/2/3/4 lines scores 100/300/500/800 × level; the board collapses.
- [ ] Reaching 10 cleared lines increases the level and speeds up the fall.

### Sounds (all 9)
- [ ] move, rotate, hard-drop, lock, line-clear, level-up each play on their action.
- [ ] On game over, `game_over` plays; on a new best, `new_record` follows it.
- [ ] Menu navigation/pause plays `menu_select`.

### Pause & game over
- [ ] Play/Pause or Back opens the pause overlay and freezes the game.
- [ ] Resume continues from the exact same state; Restart starts a fresh game;
      Quit returns to the dashboard.
- [ ] Topping out shows Game Over with the final score and best; "NEW RECORD!"
      appears only when the score beats the player's previous best.
- [ ] Play Again starts a new game with the same nickname; Back to Dashboard
      returns and the ranking now includes the new result (sorted by score).

### Persistence (the key requirement)
- [ ] After playing, the dashboard ranking shows nickname | score | dd/mm/yyyy,
      sorted by score descending.
- [ ] A lower later score for the same nickname does **not** replace a higher one.
- [ ] **Reboot the Roku** (Settings → System → Power → System restart). After
      reboot, relaunch the channel: the leaderboard and last nickname **survive**.

---

# Web build (Godot / Facebook Instant Games)

Audio cannot be verified headlessly - no test in this repository can tell you
whether a sound actually reached the speakers. That gap once let the web build
ship completely silent while every automated check stayed green: the files were
intact, the mixer ran at full rate, and `playing` reported `true`, because Godot
was routing audio to a path that silently dropped it. **Listen to it.**

Run `make godot-play`, then:

### Audio
- [ ] Music starts when you press **Play** on the dashboard - never before, since
      browsers block audio until a user gesture.
- [ ] Effects are audible on move, rotate, hard drop, lock and line clear.
      `move` and `menu_select` are ~50 ms blips by design; listen for a tick,
      not a tone.
- [ ] The music loops without an audible seam at 30 s.
- [ ] Music turns tense (pitched up, muffled) when the stack nears the top.
- [ ] **SOUND / MUTED** silences everything, including effects, and the choice
      survives a reload.
- [ ] Game over plays the descending defeat cue; only a run that beats the
      dashboard record adds the rising fanfare on top.
- [ ] The browser console shows `music ready: <length>` and **no** warning about
      a stream that "cannot be sampled".

### Visual & layout
- [ ] The loading screen shows the BrickRain splash, not the Godot logo.
- [ ] Resize the window to portrait and to landscape: the panel and well
      rearrange, and the well always stays fully on screen.

### Celebration effects & sounds (added with combo scoring)
- [ ] Clearing a line flashes the row, bursts particles in the pieces' colours
      and floats "+points" up from the well; no screen shake for 1-3 lines.
- [ ] A quad (4 lines) plays its own fanfare (`quad_clear`, brighter and longer
      than the normal chime) and briefly shakes the well - panel and buttons
      stay still.
- [ ] Consecutive clears show "COMBO xN" and the combo blip rises in pitch with
      each step; a piece that locks without clearing resets the chain.
- [ ] Level up: "LEVEL N" in wordmark colours crosses the well with a colour
      wave, a whoosh, and a light shake.
- [ ] The active piece glides between cells instead of teleporting, pops
      slightly on rotation, and drops instantly on hard drop.
- [ ] The score rolls up to its new value; the HOLD slot pulses on a stash.
- [ ] Game over sweeps the well dark before the overlay; a new record adds
      confetti and a pop alongside the fanfare.
- [ ] After the new-record fanfare, a fireworks show starts and loops: rockets
      whistle up from the well floor and pop into coloured radial bursts, each
      boom-and-crackle landing exactly on its visual pop, pitch varying shot
      to shot.
- [ ] Leaving the overlay (Play Again, Dashboard, or a rewarded continue)
      stops the show immediately - no stray boom afterwards. Share keeps it
      running, since the overlay stays open.
- [ ] The BRICKRAIN wordmark on the dashboard and the nickname screen does a
      stadium wave - a crest travelling left to right through the letters,
      continuously. The share card and the in-well popups stay still.

### Dashboard framing (web)
- [ ] The list is headed **"Your best runs"** - it is the player's own history, not a
      ranking of people.
- [ ] Rows show position, date, level and score - no nickname; the current
      name lives in the "Playing as" line above the list. Runs recorded before
      the level field existed leave the level cell empty instead of showing a
      made-up value.
- [ ] Off-platform (make godot-play) there is **no Friends Ranking button**; it only
      exists inside Facebook, same rule as the ad offer and Share.

### Tooling for these checks
- `make godot-play-clean` serves the build on a random throwaway port. Browser
  storage is partitioned per origin (host:port), so the game starts with no
  nickname, no runs and record 0 - the way to retest the first-run flow and
  the new-record fireworks without clearing anything by hand.
- `make godot-capture` records the fast effects (LEVEL popup, fireworks) as
  PNG frames in `build/captures/` via Godot's Movie Maker mode, which renders
  offline at a fixed clock. Use it when an animation is too quick to
  screenshot - and never judge these animations in a background browser tab,
  where throttling stretches the game clock.

## Testing on a real phone

The web build is portrait-first (1080x1920 design space) and already has touch
controls, so most of what matters can only be judged on a real device.

**It has to be https.** A Godot web export refuses to start outside a secure
context. Browsers count `localhost` and `127.0.0.1` as secure even over http,
which is why `make godot-play` works on this machine, but a LAN address like
`http://192.168.1.7:8777` never is: the phone shows

> Error. The following features required to run Godot projects on the Web are
> missing: Secure Context - Check web server configuration (use HTTPS)

That is the platform, not the game. On Facebook the game is always served over
https, so this only ever bites during local testing.

**The device path:** `make godot-tunnel` prints a throwaway
`https://<random>.trycloudflare.com` URL that works on the same Wi-Fi, on mobile
data, and on someone else's phone. Needs `brew install cloudflared`. The link
reaches this machine while the command runs, so stop it when you are done.

**Seeing the console from the phone:** on the iPhone enable Settings > Safari >
Advanced > Web Inspector (Developer Mode under Privacy and Security if the entry
is missing), connect by USB, then on the Mac use Safari > Develop > (your iPhone)
> the BrickRain tab. Console, network and elements mirror the phone live.

### Phone checklist
- [ ] Portrait: the stats become a strip across the top, the well fills the
      middle with the HOLD / pause / SOUND column beside it, and the movement
      row sits at the bottom, clear of the home indicator. Portrait is the
      supported phone and tablet orientation.
- [ ] Portrait puts HOLD / pause / SOUND in a column down the right of the
      well, and `<  >  TURN  v  DROP` across the bottom. Holding `<`, `>` or
      `v` repeats at the same speed as holding the key; TURN and DROP fire
      once. Every button is at least 150 design px on both axes, which
      `make godot-layout` now asserts rather than trusts.
- [ ] The gestures still work alongside the buttons: drag sideways moves, drag
      down soft drops, a fast long flick down hard drops, and a tap rotates.
      (`make godot-touch` covers all four headlessly.)
- [ ] The loading screen fills the whole display with the splash art, no dark
      bands at the edges and no white flash.
- [ ] Rotating the phone to landscape rearranges into panel / well / buttons
      columns and back again without reloading.
- [ ] Dashboard rows are comfortably tappable and the RUNS / BEST / LEVEL band
      reads correctly.
- [ ] Tapping the nickname field raises the system keyboard, what you type
      appears in the field the game draws, and the Go / Enter key submits.
      (The field the finger lands on is a real HTML input placed over the
      canvas; Godot's web build cannot raise a keyboard by itself.)
- [ ] Music and effects are audible **with the ring/silent switch set to
      silent**. On iOS, Web Audio plays on the ringer channel by default, so
      this is the check that catches a regression in the audio session setup.
