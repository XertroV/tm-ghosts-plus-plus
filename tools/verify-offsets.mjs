// Verifies every game class/member this plugin reaches for still exists, using
// Openplanet's reflection dump (OpenplanetNext.json, rewritten each game launch).
//
//   node tools/verify-offsets.mjs              check against the current dump
//   node tools/verify-offsets.mjs --diff OLD   compare current dump against an older one
//
// This is what lets us react to a game update WITHOUT the manual known-good version
// list that upstream Ghosts++ used (and that left it disabled for months).
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { REPO_ROOT, SRC_DIR, REFLECTION_DUMP } from "./config.mjs";

// --- reflection dump -------------------------------------------------------

// The dump nests classes under namespaces; a class is any object carrying an
// id/size/members key. Flatten to a bare className -> classDef index.
function indexClasses(node, out = new Map()) {
  for (const [name, value] of Object.entries(node)) {
    if (!value || typeof value !== "object") continue;
    const isClass = "i" in value || "s" in value || "m" in value || "p" in value;
    if (isClass) out.set(name, value);
    else indexClasses(value, out);
  }
  return out;
}

export function loadDump(file) {
  if (!fs.existsSync(file)) {
    throw new Error(
      `reflection dump not found: ${file}\n` +
        "  Launch Trackmania with Openplanet once to generate it, or set OPENPLANET_DIR."
    );
  }
  const json = JSON.parse(fs.readFileSync(file, "utf8"));
  return {
    openplanetVersion: json.op,
    gameBuild: json.mp,
    classes: indexClasses(json.ns ?? {}),
  };
}

// Members are inherited, so walk the parent chain before declaring one missing.
function findMember(dump, className, memberName) {
  let cls = dump.classes.get(className);
  const seen = new Set();
  while (cls && !seen.has(cls)) {
    seen.add(cls);
    for (const m of cls.m ?? []) {
      if (m.n === memberName) return m;
    }
    cls = cls.p ? dump.classes.get(cls.p) : null;
  }
  return null;
}

// --- source scanning -------------------------------------------------------

function sourceFiles(dir, acc = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) sourceFiles(p, acc);
    else if (e.name.endsWith(".as")) acc.push(p);
  }
  return acc;
}

const RE_GET_OFFSET = /GetOffset(?:Safe)?\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)/g;
const RE_GET_TYPE_MEMBER = /Reflection::GetType\(\s*"([^"]+)"\s*\)\s*\.\s*GetMember\(\s*"([^"]+)"\s*\)/g;
const RE_GET_TYPE = /Reflection::GetType\(\s*"([^"]+)"\s*\)/g;
const RE_LOOSE_MEMBER = /\.GetMember\(\s*"([^"]+)"\s*\)/g;

/**
 * Struct sizes the source hardcodes, as `CLASS_CODEGEN_SIZE`-style constants.
 *
 * Generated accessors bake in field deltas that are only valid for the layout they were
 * generated against, so a size change means every one of those deltas is stale. Reading
 * through a stale offset can hit unmapped memory and kill the game outright, so this has
 * to be caught here rather than at runtime.
 */
const STRUCT_SIZE_ASSERTIONS = [
  { className: "CGameCtnGhost", constant: "DGAMECTNGHOST_CODEGEN_SIZE" },
  { className: "CGameGhostScript", constant: null, maxWrittenOffset: 0x28 },
];

// Finds `const uint NAME = 0x...;` in the source.
function findSizeConstant(name) {
  for (const file of sourceFiles(SRC_DIR)) {
    const text = fs.readFileSync(file, "utf8");
    const m = text.match(new RegExp("\\b" + name + "\\s*=\\s*(0x[0-9a-fA-F]+|\\d+)"));
    if (m) return { value: Number(m[1]), file: path.relative(REPO_ROOT, file) };
  }
  return null;
}

function verifyStructSizes(dump) {
  const problems = [];
  for (const a of STRUCT_SIZE_ASSERTIONS) {
    const cls = dump.classes.get(a.className);
    if (!cls || cls.s === undefined) {
      problems.push(`${a.className}: not in dump, cannot check its size`);
      continue;
    }
    if (a.constant) {
      const found = findSizeConstant(a.constant);
      if (!found) continue;
      if (found.value !== cls.s) {
        problems.push(
          `${a.className}: source assumes 0x${found.value.toString(16)} ` +
            `(${a.constant} in ${found.file}) but this build reports 0x${cls.s.toString(16)}` +
            ` -- generated field offsets for this struct are stale`
        );
      }
    }
    if (a.maxWrittenOffset !== undefined && cls.s < a.maxWrittenOffset) {
      problems.push(
        `${a.className}: only 0x${cls.s.toString(16)} bytes, but the source writes up to ` +
          `0x${a.maxWrittenOffset.toString(16)} -- those writes would run past the object`
      );
    }
  }
  return problems;
}

export function scanSources() {
  const pairs = [];   // {className, memberName, file, line}
  const types = [];   // {className, file, line}
  const loose = [];   // {memberName, file, line} -- class not resolvable statically
  const chained = new Set();

  for (const file of sourceFiles(SRC_DIR)) {
    const rel = path.relative(REPO_ROOT, file);
    const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
    lines.forEach((line, i) => {
      const at = { file: rel, line: i + 1 };
      for (const m of line.matchAll(RE_GET_OFFSET)) {
        pairs.push({ className: m[1], memberName: m[2], ...at });
      }
      for (const m of line.matchAll(RE_GET_TYPE_MEMBER)) {
        pairs.push({ className: m[1], memberName: m[2], ...at });
        chained.add(`${at.file}:${at.line}:${m[2]}`);
      }
      for (const m of line.matchAll(RE_GET_TYPE)) {
        types.push({ className: m[1], ...at });
      }
      for (const m of line.matchAll(RE_LOOSE_MEMBER)) {
        if (!chained.has(`${at.file}:${at.line}:${m[1]}`)) {
          loose.push({ memberName: m[1], ...at });
        }
      }
    });
  }
  return { pairs, types, loose };
}

// --- reporting -------------------------------------------------------------

function verify(dump) {
  const { pairs, types, loose } = scanSources();
  const failures = [];

  console.log(`Reflection dump: Openplanet ${dump.openplanetVersion}, game build ${dump.gameBuild}`);
  console.log(`Indexed ${dump.classes.size} classes\n`);

  const seenPair = new Set();
  for (const p of pairs) {
    const key = `${p.className}::${p.memberName}`;
    if (seenPair.has(key)) continue;
    seenPair.add(key);
    if (!dump.classes.has(p.className)) {
      failures.push({ ...p, why: `class '${p.className}' not in dump` });
    } else if (!findMember(dump, p.className, p.memberName)) {
      failures.push({ ...p, why: `member '${p.memberName}' not on '${p.className}'` });
    }
  }

  const seenType = new Set();
  for (const t of types) {
    if (seenType.has(t.className)) continue;
    seenType.add(t.className);
    if (!dump.classes.has(t.className)) {
      failures.push({ ...t, why: `class '${t.className}' not in dump` });
    }
  }

  console.log(`Class+member references checked: ${seenPair.size}`);
  console.log(`Reflected types checked:          ${seenType.size}`);

  if (loose.length) {
    console.log(
      `\n${loose.length} GetMember() call(s) whose class could not be resolved statically ` +
        `-- these need a runtime capability probe:`
    );
    for (const l of loose) console.log(`  ${l.file}:${l.line}  .GetMember("${l.memberName}")`);
  }

  const sizeProblems = verifyStructSizes(dump);
  console.log(`Hardcoded struct sizes checked:   ${STRUCT_SIZE_ASSERTIONS.length}`);
  if (sizeProblems.length) {
    console.log("\nSTRUCT LAYOUT MISMATCHES:");
    for (const p of sizeProblems) console.log(`  ${p}`);
  }

  if (failures.length === 0 && sizeProblems.length === 0) {
    console.log("\nAll statically-resolvable references are present in this game build.");
    return 0;
  }
  if (failures.length === 0) {
    console.log("\nMember references are all present, but struct layouts have shifted.");
    return 1;
  }
  console.log(`\n${failures.length} BROKEN reference(s):`);
  for (const f of failures) console.log(`  ${f.file}:${f.line}  ${f.why}`);
  return 1;
}

// Preview what a game update changed, before trusting the plugin on it.
function diff(oldFile) {
  const oldDump = loadDump(oldFile);
  const newDump = loadDump(REFLECTION_DUMP);
  console.log(`old: Openplanet ${oldDump.openplanetVersion}, game build ${oldDump.gameBuild}`);
  console.log(`new: Openplanet ${newDump.openplanetVersion}, game build ${newDump.gameBuild}\n`);

  const { pairs } = scanSources();
  const seen = new Set();
  let changed = 0;
  for (const p of pairs) {
    const key = `${p.className}::${p.memberName}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const before = findMember(oldDump, p.className, p.memberName);
    const after = findMember(newDump, p.className, p.memberName);
    if (!before && !after) continue;
    if (!before || !after || before.i !== after.i || before.t !== after.t) {
      changed++;
      console.log(
        `  ${key}\n    before: ${before ? JSON.stringify(before) : "ABSENT"}` +
          `\n    after:  ${after ? JSON.stringify(after) : "ABSENT"}`
      );
    }
  }
  // Struct size changes are the classic silent breaker for hardcoded offset deltas.
  let sizeChanges = 0;
  for (const [name, cls] of newDump.classes) {
    const old = oldDump.classes.get(name);
    if (old && old.s !== undefined && cls.s !== undefined && old.s !== cls.s && seen.has(name)) {
      sizeChanges++;
      console.log(`  ${name}: struct size ${old.s} -> ${cls.s}`);
    }
  }
  console.log(
    changed || sizeChanges
      ? `\n${changed} member change(s), ${sizeChanges} struct-size change(s) affecting this plugin.`
      : "\nNo changes affecting this plugin's references."
  );
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const diffIx = process.argv.indexOf("--diff");
    process.exit(diffIx > -1 ? diff(process.argv[diffIx + 1]) : verify(loadDump(REFLECTION_DUMP)));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}
