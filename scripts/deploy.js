#!/usr/bin/env node
/**
 * Sideloads the built channel zip (out/brickrain.zip) onto a Roku device in
 * developer mode. Run `npm run deploy`, which builds first and then invokes
 * this script. Device IP and dev-mode password come from .env via scripts/env.js
 * (never hardcoded). Requires a Roku on the LAN with developer mode enabled.
 */
const path = require("node:path");
const { existsSync } = require("node:fs");
const { rokuDeploy } = require("roku-deploy");
const { loadRokuCredentials, repoRoot } = require("./env");

async function main() {
  const { host, password } = loadRokuCredentials();
  const outDir = path.join(repoRoot, "out");
  const zipPath = path.join(outDir, "brickrain.zip");
  if (!existsSync(zipPath)) {
    console.error("Build artifact not found: " + zipPath + " — run `npm run build` first.");
    process.exit(1);
  }

  console.log(`Sideloading brickrain.zip to ${host} ...`);
  try {
    await rokuDeploy.publish({
      host: host,
      password: password,
      outDir: outDir,
      outFile: "brickrain.zip",
    });
    console.log("Sideload complete. The channel is now installed in developer mode.");
  } catch (error) {
    console.error("Sideload failed:", error.message);
    process.exit(1);
  }
}

main();
