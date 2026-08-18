#!/usr/bin/env node
'use strict';

// Exports the Godot web build, using the size-optimised custom template when
// one is available and the stock template otherwise.
//
// The custom template (tools/build_web_template.sh) is a build artifact with a
// machine-specific absolute path, so it cannot simply be committed into
// export_presets.cfg - a checkout without the template would fail to export.
// Instead the preset is patched in place for the duration of the export and
// restored afterwards, so the committed config always works from a clean
// clone.
//
// Usage:
//   node scripts/export-web.js
//   BRICKRAIN_WEB_TEMPLATE=/path/to/template.zip node scripts/export-web.js

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const PRESETS = path.join(ROOT, 'godot', 'export_presets.cfg');
const OUT_DIR = path.join(ROOT, 'build', 'web');
const DEFAULT_TEMPLATE = path.join(ROOT, 'build', 'templates', 'brickrain_web_nothreads_release.zip');

const templatePath = process.env.BRICKRAIN_WEB_TEMPLATE || DEFAULT_TEMPLATE;
const useCustom = fs.existsSync(templatePath);

const original = fs.readFileSync(PRESETS, 'utf8');
let restored = false;

function restore() {
  if (!restored) {
    fs.writeFileSync(PRESETS, original);
    restored = true;
  }
}

// Restore even if the export throws or the process is interrupted, so a failed
// run never leaves a machine-specific path committed in the preset.
process.on('exit', restore);
process.on('SIGINT', () => { restore(); process.exit(130); });

try {
  if (useCustom) {
    const patched = original.replace(
      /^custom_template\/release=.*$/m,
      `custom_template/release="${templatePath}"`
    );
    if (patched === original) {
      console.error('export-web: could not find custom_template/release in the preset.');
      process.exit(1);
    }
    fs.writeFileSync(PRESETS, patched);
    console.log(`template: custom (${path.relative(ROOT, templatePath)})`);
  } else {
    console.log('template: stock (no custom template built; run tools/build_web_template.sh)');
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });
  execFileSync(
    'godot',
    ['--headless', '--path', 'godot', '--export-release', 'Web', '../build/web/index.html'],
    { cwd: ROOT, stdio: 'inherit' }
  );
} finally {
  restore();
}

const wasm = path.join(OUT_DIR, 'index.wasm');
if (fs.existsSync(wasm)) {
  console.log(`wasm    : ${(fs.statSync(wasm).size / 1048576).toFixed(2)} MB raw`);
}
