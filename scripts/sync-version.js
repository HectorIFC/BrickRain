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

let manifest = readFileSync(manifestPath, "utf8");
manifest = manifest
  .replace(/^major_version=.*$/m, "major_version=" + major)
  .replace(/^minor_version=.*$/m, "minor_version=" + minor)
  .replace(/^build_version=.*$/m, "build_version=" + patch);

writeFileSync(manifestPath, manifest);
console.log(`Manifest version set to ${major}.${minor}.${patch}`);
