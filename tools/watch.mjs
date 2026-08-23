// Rebuilds the dev plugin whenever a source file changes.
// Openplanet picks up the unzipped dev folder on reload, so this gives a fast edit loop.
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT, SRC_DIR, ML_SCRIPTS_DIR, INFO_TOML, GENERATED_SCRIPTS_DIR } from "./config.mjs";
import { build } from "./build.mjs";

const mode = process.argv[2] || "dev";
const DEBOUNCE_MS = 150;

let timer = null;
let building = false;
let queued = false;

async function rebuild(reason) {
  if (building) {
    queued = true;
    return;
  }
  building = true;
  console.log(`\n--- rebuild (${reason}) ${new Date().toLocaleTimeString()} ---`);
  try {
    await build(mode);
  } catch (err) {
    console.error(`Build failed: ${err.message}`);
  }
  building = false;
  if (queued) {
    queued = false;
    await rebuild("queued change");
  }
}

function onChange(filename, reason) {
  // Ignore our own generated output, or the watcher would loop forever.
  if (filename && path.resolve(filename).startsWith(GENERATED_SCRIPTS_DIR)) return;
  clearTimeout(timer);
  timer = setTimeout(() => rebuild(reason), DEBOUNCE_MS);
}

for (const dir of [SRC_DIR, ML_SCRIPTS_DIR]) {
  fs.watch(dir, { recursive: true }, (_event, filename) => {
    onChange(filename ? path.join(dir, filename) : null, filename || path.basename(dir));
  });
}
fs.watch(INFO_TOML, () => onChange(INFO_TOML, "info.toml"));

console.log(`Watching for changes in ${path.relative(REPO_ROOT, SRC_DIR)}/, ` +
  `${path.relative(REPO_ROOT, ML_SCRIPTS_DIR)}/ and info.toml  (mode: ${mode})`);
console.log("Ctrl+C to stop.\n");
await rebuild("initial build");
