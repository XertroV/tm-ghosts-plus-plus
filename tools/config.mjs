// Shared build configuration.
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const SRC_DIR = path.join(REPO_ROOT, "src");
export const ML_SCRIPTS_DIR = path.join(REPO_ROOT, "ml-scripts");
export const GENERATED_SCRIPTS_DIR = path.join(SRC_DIR, "scripts");
export const INFO_TOML = path.join(REPO_ROOT, "info.toml");

// Files copied alongside src/ into the built plugin.
export const EXTRA_PLUGIN_FILES = ["LICENSE", "README.md"];

// Openplanet's plugin directory. Override with PLUGINS_DIR if your install lives elsewhere.
export const PLUGINS_DIR =
  process.env.PLUGINS_DIR || path.join(homedir(), "OpenplanetNext", "Plugins");

// Openplanet's reflection dump, written on every game launch. Used by verify-offsets.mjs.
export const OPENPLANET_DIR =
  process.env.OPENPLANET_DIR || path.join(homedir(), "OpenplanetNext");
export const REFLECTION_DUMP = path.join(OPENPLANET_DIR, "OpenplanetNext.json");

// Plugin identity. Must match info.toml.
export const PLUGIN_ID = "ghosts-pp";

// Build modes -> [name suffix, AngelScript define]
export const BUILD_MODES = {
  dev: { suffix: " (Dev)", define: "DEV", installsToDevFolder: true },
  prerelease: { suffix: " (Prerelease)", define: "RELEASE", installsToDevFolder: true },
  unittest: { suffix: " (UnitTest)", define: "UNIT_TEST", installsToDevFolder: true },
  release: { suffix: "", define: "RELEASE", installsToDevFolder: false },
};
