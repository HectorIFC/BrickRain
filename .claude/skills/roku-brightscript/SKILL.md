---
name: roku-brightscript
description: Conventions and gotchas for Roku development in this repo — BrightScript/BrighterScript syntax, SceneGraph patterns, Rooibos testing, roku-deploy usage. Consult before writing or editing any .bs, .brs or SceneGraph .xml file.
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
- Remote key handling: onKeyEvent — https://developer.roku.com/docs/developer-program/core-concepts/handling-application-events.md
- Rooibos: https://github.com/rokucommunity/rooibos
- roku-deploy: https://github.com/rokucommunity/roku-deploy

## Verification rule
BrightScript is a niche language: when uncertain about a SceneGraph node
field, component signature, or OS-version behavior, FETCH the official doc
page above instead of relying on memory.
