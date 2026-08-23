// Shows what the game made of the last build.
//
// AngelScript only compiles when Openplanet loads the plugin, so Openplanet.log is the
// build output: compile errors, probe results and runtime exceptions all land there.
//
//   node tools/log.mjs           lines from this plugin, plus any compile errors
//   node tools/log.mjs --all     every line since the game started
//   node tools/log.mjs --errors  errors and warnings from this plugin only
import fs from "node:fs";
import path from "node:path";
import { OPENPLANET_DIR, PLUGIN_ID } from "./config.mjs";

const LOG = path.join(OPENPLANET_DIR, "Openplanet.log");
if (!fs.existsSync(LOG)) {
  console.error(`No log at ${LOG} -- has the game been launched with Openplanet?`);
  process.exit(1);
}

const args = process.argv.slice(2);
const all = args.includes("--all");
const errorsOnly = args.includes("--errors");

// Plain substring tests rather than a built regex: the plugin id and name can both
// contain regex metacharacters.
function isFromPlugin(line) {
  const l = line.toLowerCase();
  return l.includes("[" + PLUGIN_ID + "]") || l.includes(PLUGIN_ID + ".op") || l.includes("ghosts++");
}
function isProblem(line) {
  return line.includes("[ERROR]") || line.includes("[ WARN]");
}
// Compile errors name the source file and line, e.g. "Main.as (12, 5) : ERR : ...".
function isCompileError(line) {
  return line.includes(".as (") && (line.includes("ERR") || line.includes("WARN"));
}

const lines = fs.readFileSync(LOG, "utf8").split(/\r?\n/);
let shown = 0;
let problems = 0;

for (const line of lines) {
  if (!line.trim()) continue;
  const mine = isFromPlugin(line);
  const bad = isProblem(line);
  if (mine && bad) problems++;

  let show;
  if (all) show = true;
  else if (errorsOnly) show = mine && bad;
  else show = mine || isCompileError(line);

  if (show) {
    console.log(line);
    shown++;
  }
}

if (shown === 0) {
  console.log(
    `Nothing from '${PLUGIN_ID}' in the log.\n` +
      "Either the game has not been launched since the build, or the plugin is not\n" +
      "enabled (Openplanet > Develop > Plugins)."
  );
} else {
  console.log(`\n-- ${shown} line(s) shown, ${problems} error/warning(s) from this plugin --`);
}
