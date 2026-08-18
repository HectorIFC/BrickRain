# Contributing to BrickRain

Thanks for your interest! A few conventions keep the project tidy and let the release
automation work.

## Conventional Commits drive releases

Releases and version numbers are computed automatically from commit messages on `main`, so
commits (and **squash-merge PR titles**) MUST follow
[Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Example | Version bump |
|---|---|---|
| `feat:` | `feat: add ghost piece rendering` | minor |
| `fix:` | `fix: correct SRS kick for I piece` | patch |
| `build:` / `chore:` / `docs:` / `refactor:` / `test:` | `chore: bump bslint` | patch |
| `feat!:` or a `BREAKING CHANGE:` footer | `feat!: change registry schema` | major |

When a PR is squash-merged, GitHub uses the **PR title** as the commit message — so the PR title
must be a valid Conventional Commit.

## Two implementations, one set of game rules

BrickRain ships **two** independent implementations that must behave identically:

| | Roku channel | Web (Facebook Instant Games) |
|---|---|---|
| Core | `source/logic/*.bs` | `godot/core/*.gd` |
| Tests | `tests/cases/*.bs` | `godot/tests/cases/*.gd` |
| Runner | `npm run test:logic` | `npm run web:test` |

**Any change to a game rule must be made in both cores and both suites.** They cannot
import from each other, so nothing but discipline and the tests keeps them in step.

The guard is a deterministic scripted game on **seed 23**, asserted to produce exactly
**1538 points / 5 lines / 38 pieces** by *both* suites. It exercises the Park-Miller RNG,
the 7-bag shuffle, every SRS kick table, collision, line clearing, scoring, lock delay and
the whole state machine — so if the two implementations drift on any rule, that one
assertion fails on one side and not the other.

If you change a rule and the golden values legitimately change, update them in **both**
suites in the **same commit**. A commit that changes them on one side only is a bug.

## Before opening a PR

```bash
make check
```

That runs the whole gate: BrighterScript validation + bslint, the channel build, and both
logic suites plus the web layout smoke test. Without make:

```bash
npm run lint              # BrighterScript validation + bslint must be clean
npm run test:logic        # the full headless logic suite must pass
npm run build             # the channel must build
npm run web:test          # the ported logic suite (same 48 cases)
npm run web:test:layout   # screens fill the viewport; portrait/landscape flip
```

- All code, identifiers, comments and docs are **English only**.
- Keep game rules in the pure core (`source/logic/`, no SceneGraph imports) and add/extend the
  shared test cases in `tests/cases/` — if a component function grows beyond trivial glue, move
  the logic into `source/logic/` where it is covered.
- Never commit secrets: `.env`, device IPs, dev-mode passwords or Roku signing keys (`*.pkg`,
  `*.key`) are gitignored and must stay out of the repo.
- The game is **BrickRain** / a "falling-blocks game" — do not use the trademarked name of the
  classic game anywhere.

## Local device testing

Copy `.env.example` to `.env`, set your Roku's IP and dev-mode password, then `npm run deploy`.
Run through [MANUAL_TESTING.md](MANUAL_TESTING.md) for UI changes.
