/**
 * Minimal .env reader (no dependency). Parses KEY=VALUE lines, ignoring blanks
 * and # comments, and returns the requested Roku device credentials. Values
 * are never logged. Exits with a clear message when .env is missing so secrets
 * are never expected to be hardcoded anywhere in the repo.
 */
const { readFileSync, existsSync } = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");

function parseEnvFile(filePath) {
  const values = {};
  const text = readFileSync(filePath, "utf8");
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
}

/** Returns { host, password } from .env (env vars override the file). */
function loadRokuCredentials() {
  const envPath = path.join(repoRoot, ".env");
  let fileValues = {};
  if (existsSync(envPath)) {
    fileValues = parseEnvFile(envPath);
  }
  const host = process.env.ROKU_DEV_TARGET || fileValues.ROKU_DEV_TARGET;
  const password = process.env.ROKU_DEV_PASSWORD || fileValues.ROKU_DEV_PASSWORD;
  if (!host || !password) {
    console.error(
      "Missing Roku credentials. Copy .env.example to .env and set " +
        "ROKU_DEV_TARGET (device IP) and ROKU_DEV_PASSWORD (dev-mode password)."
    );
    process.exit(1);
  }
  return { host, password };
}

module.exports = { loadRokuCredentials, repoRoot };
