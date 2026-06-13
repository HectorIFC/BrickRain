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
4. `npm run deploy` — builds `out/brickrain.zip` and sideloads it.

## Checklist

### Boot & dashboard
- [ ] Channel boots to the dashboard in under ~3 s; the BRICK RAIN logo shows.
- [ ] With no scores stored, the empty state reads "No scores yet — be the first!".
- [ ] The **Start Game** button is focused on entry.

### Nickname dialog
- [ ] Pressing Start opens the keyboard dialog.
- [ ] On a second run, the dialog is pre-filled with the last nickname used.
- [ ] Entering fewer than 2 or more than 12 chars, or a symbol/space, keeps the
      dialog open with the validation message; a valid 2–12 alphanumeric name is
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
      fast-forward key was chosen — see README controls note.)*
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
