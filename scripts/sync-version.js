#!/usr/bin/env node
/**
 * Writes a SemVer version (e.g. "1.4.2") into the channel manifest so the
 * installed channel reports the real release version. Used by the release
 * workflow after the tag is computed:  node scripts/sync-version.js 1.4.2
 *
 * Maps SemVer major.minor.patch -> manifest major_version/minor_version/build_version.
 */
const { readFileSync, writeFileSync } = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const manifestPath = path.join(repoRoot, "manifest");

const rawVersion = (process.argv[2] || "").replace(/^v/, "");
const match = rawVersion.match(/^(\d+)\.(\d+)\.(\d+)$/);
if (!match) {
  console.error('Usage: node scripts/sync-version.js <major.minor.patch> (got "' + rawVersion + '")');
  process.exit(1);
}
const [, major, minor, patch] = match;

// Replace a manifest line, failing loudly if the key is absent so a renamed key
// can never ship a wrong or partial version.
function replaceOrFail(text, pattern, replacement, keyName) {
  if (!pattern.test(text)) {
    console.error(`Manifest is missing required key: ${keyName}`);
    process.exit(1);
  }
  return text.replace(pattern, replacement);
}

let manifest = readFileSync(manifestPath, "utf8");
manifest = replaceOrFail(manifest, /^major_version=.*$/m, "major_version=" + major, "major_version");
manifest = replaceOrFail(manifest, /^minor_version=.*$/m, "minor_version=" + minor, "minor_version");
manifest = replaceOrFail(manifest, /^build_version=.*$/m, "build_version=" + patch, "build_version");

writeFileSync(manifestPath, manifest);
console.log(`Manifest version set to ${major}.${minor}.${patch}`);
