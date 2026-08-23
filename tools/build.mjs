// Node build, as an alternative to build.sh (which needs bash + python3 + 7z).
//
//   node tools/build.mjs [dev|prerelease|unittest|release]
//
// dev/prerelease/unittest install an unzipped plugin folder into Openplanet's Plugins
// directory, which Openplanet hot-reloads. release produces a distributable .op (a zip).
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";
import {
  REPO_ROOT,
  SRC_DIR,
  INFO_TOML,
  EXTRA_PLUGIN_FILES,
  PLUGINS_DIR,
  PLUGIN_ID,
  BUILD_MODES,
} from "./config.mjs";
import { preprocessScripts } from "./preproc.mjs";

// Minimal TOML string lookup -- enough for the handful of keys the build needs,
// without pulling in a TOML parser. Ignores comment lines.
function readTomlString(toml, key) {
  for (const rawLine of toml.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.startsWith("#") || !line.startsWith(key)) continue;
    const eq = line.indexOf("=");
    if (eq < 0 || line.slice(0, eq).trim() !== key) continue;
    const value = line.slice(eq + 1).trim();
    if (value.startsWith('"')) {
      const end = value.indexOf('"', 1);
      if (end > 0) return value.slice(1, end);
    }
  }
  throw new Error(`info.toml: could not find a '${key} = "..."' entry`);
}

// Applies the build mode to info.toml: name suffix + the AngelScript defines line.
function patchInfoToml(toml, mode) {
  const { suffix, define } = BUILD_MODES[mode];
  let out = toml;
  if (suffix) {
    out = out.replace(/^(\s*name\s*=\s*")([^"]*)(")/m, `$1$2${suffix}$3`);
  }
  if (!/^#__DEFINES__/m.test(out)) {
    throw new Error("info.toml: missing the '#__DEFINES__' placeholder line");
  }
  return out.replace(/^#__DEFINES__/m, `defines = ["${define}"]`);
}

// Stages src/* plus the patched info.toml and licence/readme files into an empty dir.
function stage(stageDir, infoToml) {
  fs.rmSync(stageDir, { recursive: true, force: true });
  fs.mkdirSync(stageDir, { recursive: true });
  fs.cpSync(SRC_DIR, stageDir, { recursive: true });
  fs.writeFileSync(path.join(stageDir, "info.toml"), infoToml);
  for (const f of EXTRA_PLUGIN_FILES) {
    const src = path.join(REPO_ROOT, f);
    if (fs.existsSync(src)) fs.cpSync(src, path.join(stageDir, f));
  }
}

function countFiles(dir) {
  let n = 0;
  for (const e of fs.readdirSync(dir, { withFileTypes: true, recursive: true })) {
    if (e.isFile()) n++;
  }
  return n;
}

async function writeOpArchive(stageDir, outFile) {
  let AdmZip;
  try {
    ({ default: AdmZip } = await import("adm-zip"));
  } catch {
    throw new Error(
      "release builds need the 'adm-zip' dev dependency.\n" +
        "  Run: npm install\n" +
        "  (dev builds work without it.)"
    );
  }
  const zip = new AdmZip();
  zip.addLocalFolder(stageDir);
  fs.rmSync(outFile, { force: true });
  zip.writeZip(outFile);
}

export async function build(mode) {
  if (!BUILD_MODES[mode]) {
    throw new Error(
      `unknown build mode '${mode}'. Options: ${Object.keys(BUILD_MODES).join(", ")}`
    );
  }

  console.log(`Build mode: ${mode}`);
  console.log("Preprocessing ml-scripts:");
  preprocessScripts();

  const rawToml = fs.readFileSync(INFO_TOML, "utf8");
  const prettyName = readTomlString(rawToml, "name") + BUILD_MODES[mode].suffix;
  const version = readTomlString(rawToml, "version");
  const infoToml = patchInfoToml(rawToml, mode);

  const stageDir = path.join(os.tmpdir(), `ghosts-pp-build-${process.pid}`);
  stage(stageDir, infoToml);
  const fileCount = countFiles(stageDir);

  if (BUILD_MODES[mode].installsToDevFolder) {
    const dest = path.join(PLUGINS_DIR, PLUGIN_ID);
    if (!fs.existsSync(PLUGINS_DIR)) {
      throw new Error(
        `Openplanet plugins directory not found: ${PLUGINS_DIR}\n` +
          "  Set PLUGINS_DIR if your install lives elsewhere."
      );
    }
    try {
      fs.rmSync(dest, { recursive: true, force: true });
      fs.cpSync(stageDir, dest, { recursive: true });
    } catch (err) {
      throw new Error(
        `could not write to ${dest}: ${err.message}\n` +
          "  Openplanet may have the files locked. In game, use\n" +
          "  Openplanet > Develop > Reload plugin (or unload the plugin) and try again."
      );
    }
    console.log(`\n${prettyName} ${version} -> ${dest} (${fileCount} files)`);
    console.log("Reload in game: Openplanet > Develop > Plugins > Reload");
  } else {
    const outFile = path.join(REPO_ROOT, `${PLUGIN_ID}-${version}.op`);
    await writeOpArchive(stageDir, outFile);
    const kb = (fs.statSync(outFile).size / 1024).toFixed(1);
    console.log(`\n${prettyName} ${version} -> ${path.basename(outFile)} (${fileCount} files, ${kb} KB)`);
  }

  fs.rmSync(stageDir, { recursive: true, force: true });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  build(process.argv[2] || "dev").catch((err) => {
    console.error(`\nBuild failed: ${err.message}`);
    process.exit(1);
  });
}
