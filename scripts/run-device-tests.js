#!/usr/bin/env node
/**
 * Runs the Rooibos test suite on a real Roku device (or the brs-engine
 * simulator) using bsconfig.test.json. Device IP and password come from .env
 * via scripts/env.js, so credentials never live in package.json or bsconfig.
 * The Rooibos CLI builds the test channel, sideloads it and reports results,
 * including native code-coverage for source/logic.
 */
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { loadRokuCredentials, repoRoot } = require("./env");

function bin(name) {
  const suffix = process.platform === "win32" ? ".cmd" : "";
  return path.join(repoRoot, "node_modules", ".bin", name + suffix);
}

const { host, password } = loadRokuCredentials();

console.log(`Running Rooibos tests against ${host} ...`);
const run = spawnSync(
  bin("rooibos"),
  ["--project", "bsconfig.test.json", "--host", host, "--password", password],
  { cwd: repoRoot, stdio: "inherit" }
);

if (run.error) {
  console.error("Failed to launch the Rooibos CLI:", run.error.message);
  process.exit(1);
}
process.exit(run.status === null ? 1 : run.status);
