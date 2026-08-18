#!/usr/bin/env node
'use strict';

// Packages the Godot web export as a Facebook Instant Games bundle.
//
// Facebook hosts the bundle: you upload a ZIP via App Dashboard -> Web Hosting
// -> Upload Version. The archive must contain index.html and fbapp-config.json
// at its ROOT, not inside a wrapping folder - a nested layout is accepted by
// the uploader and then fails to boot, so the layout is verified here rather
// than discovered in the dashboard.
//
// Usage: node scripts/package-web.js

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const WEB_DIR = path.join(ROOT, 'build', 'web');
const CONFIG_SRC = path.join(ROOT, 'godot', 'fbapp-config.json');
// The music is deliberately NOT in the pck: everything in res:// is downloaded
// in full before the first frame, so packing it would delay the boot for every
// player. It is excluded from the export and copied in here instead, then
// fetched over HTTP at runtime by platform/music.gd.
const MUSIC_SRC = path.join(ROOT, 'godot', 'music', 'theme.ogg');
const OUT_DIR = path.join(ROOT, 'out');
const ZIP_PATH = path.join(OUT_DIR, 'brickrain-web.zip');

// Entries that must sit at the archive root for the bundle to boot.
const REQUIRED_ROOT_ENTRIES = [
  'index.html',
  'index.js',
  'index.wasm',
  'index.pck',
  'fbapp-config.json',
  'theme.ogg',
];

function fail(message) {
  console.error(`package-web: ${message}`);
  process.exit(1);
}

function humanMB(bytes) {
  return `${(bytes / 1048576).toFixed(2)} MB`;
}

if (!fs.existsSync(path.join(WEB_DIR, 'index.html'))) {
  fail(`no export found at ${path.relative(ROOT, WEB_DIR)}; run the Godot web export first.`);
}
if (!fs.existsSync(CONFIG_SRC)) {
  fail(`missing ${path.relative(ROOT, CONFIG_SRC)}.`);
}
if (!fs.existsSync(MUSIC_SRC)) {
  fail(`missing ${path.relative(ROOT, MUSIC_SRC)}; run python3 tools/generate_music.py.`);
}

// These live with the Godot project (they are source, not build output) and are
// copied in at packaging time.
fs.copyFileSync(CONFIG_SRC, path.join(WEB_DIR, 'fbapp-config.json'));
fs.copyFileSync(MUSIC_SRC, path.join(WEB_DIR, 'theme.ogg'));

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.rmSync(ZIP_PATH, { force: true });

// Zipping from inside build/web is what puts the files at the archive root.
execFileSync('zip', ['-r', '-q', ZIP_PATH, '.'], { cwd: WEB_DIR, stdio: 'inherit' });

const listing = execFileSync('unzip', ['-Z1', ZIP_PATH], { encoding: 'utf8' })
  .split('\n')
  .map((line) => line.trim())
  .filter(Boolean);

const missing = REQUIRED_ROOT_ENTRIES.filter((entry) => !listing.includes(entry));
if (missing.length > 0) {
  fail(`these entries are not at the archive root: ${missing.join(', ')}`);
}

const zipBytes = fs.statSync(ZIP_PATH).size;
const rawBytes = fs
  .readdirSync(WEB_DIR)
  .map((name) => fs.statSync(path.join(WEB_DIR, name)))
  .filter((stat) => stat.isFile())
  .reduce((total, stat) => total + stat.size, 0);

console.log(`bundle : ${path.relative(ROOT, ZIP_PATH)}`);
console.log(`files  : ${listing.length}`);
console.log(`raw    : ${humanMB(rawBytes)}`);
console.log(`zipped : ${humanMB(zipBytes)}`);

// Meta's documented ceiling for a hosted bundle. Worth failing the build on,
// because the upload would be rejected anyway.
const LIMIT_BYTES = 200 * 1024 * 1024;
if (zipBytes > LIMIT_BYTES) {
  fail(`bundle is ${humanMB(zipBytes)}, over the 200 MB Instant Games limit.`);
}
