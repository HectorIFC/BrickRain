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

## Before opening a PR

```bash
npm run lint          # BrighterScript validation + bslint must be clean
npm run test:logic    # the full headless logic suite must pass
npm run build         # the channel must build
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
