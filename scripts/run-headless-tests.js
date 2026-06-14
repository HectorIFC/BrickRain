#!/usr/bin/env node
/**
 * Headless logic test driver:
 *  1. transpiles source/logic + tests to plain BrightScript via bsc
 *  2. runs the result under brs-node (no Roku device needed)
 *  3. exits non-zero unless the runner prints the PASS sentinel
 */
const { execFileSync, spawnSync } = require("node:child_process");
const { readdirSync, statSync } = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const stagingDir = path.join(repoRoot, "out", "headless");

function collectBrsFiles(dir) {
  const files = [];
  for (const entry of readdirSync(dir)) {
    const full = path.join(dir, entry);
    if (statSync(full).isDirectory()) {
      files.push(...collectBrsFiles(full));
    } else if (entry.endsWith(".brs")) {
      files.push(full);
    }
  }
  return files;
}

function bin(name) {
  const suffix = process.platform === "win32" ? ".cmd" : "";
  return path.join(repoRoot, "node_modules", ".bin", name + suffix);
}

console.log("Transpiling logic and tests (bsc)...");
execFileSync(bin("bsc"), ["--project", "bsconfig.headless.json"], {
  cwd: repoRoot,
  stdio: "inherit",
});

// The runner's main() must be the program entry point: pass it first.
const brsFiles = collectBrsFiles(stagingDir).sort((a, b) => {
  const aIsMain = a.includes(path.join("headless", "main.brs")) ? 0 : 1;
  const bIsMain = b.includes(path.join("headless", "main.brs")) ? 0 : 1;
  return aIsMain - bIsMain || a.localeCompare(b);
});
if (brsFiles.length === 0) {
  console.error("No transpiled .brs files found in " + stagingDir);
  process.exit(1);
}

console.log(`Running ${brsFiles.length} files under brs-node...\n`);
const run = spawnSync(bin("brs-cli"), brsFiles, {
  cwd: repoRoot,
  encoding: "utf8",
});

process.stdout.write(run.stdout || "");
process.stderr.write(run.stderr || "");

if (run.error) {
  console.error("Failed to launch brs-cli:", run.error.message);
  process.exit(1);
}
// A crash or abnormal exit is a failure even if the PASS sentinel was printed
// before the process died (a healthy run exits 0).
if (run.status !== 0) {
  console.error(`\nHeadless tests FAILED (brs-cli exit code: ${run.status}).`);
  process.exit(run.status === null ? 1 : run.status);
}
const passed = (run.stdout || "").includes("BRICKRAIN_TESTS_RESULT: PASS");
if (!passed) {
  console.error("\nHeadless tests FAILED (sentinel not found or failures reported).");
  process.exit(1);
}
console.log("\nHeadless tests passed.");
