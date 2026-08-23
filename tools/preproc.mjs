// Wraps ml-scripts/*.Script.txt into AngelScript string constants in src/scripts/.
//
// Port of upstream's pre-proc-scripts.py (removes the python3 build dependency).
// ManiaScript uses `#Const`/`#Include` directives; a leading space keeps AngelScript's
// preprocessor from eating them while staying valid ManiaScript.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { ML_SCRIPTS_DIR, GENERATED_SCRIPTS_DIR } from "./config.mjs";

const TRIPLE_QUOTE_PLACEHOLDER = '_"_"_"_';

function procLine(line) {
  return line.startsWith("#") ? " " + line : line;
}

// Equivalent of Python's str.splitlines(): normalises line endings and, unlike
// String.split, does not emit a trailing empty element for a trailing newline.
function splitLines(text) {
  const lines = text.split(/\r?\n/);
  if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  return lines;
}

function scriptToAsFile(srcFile) {
  const name = path.basename(srcFile);
  // "SetFocusedRecord.Script.txt" -> "SETFOCUSEDRECORD_SCRIPT_TXT"
  const constantName = name.replaceAll(".", "_").toUpperCase();
  // "SetFocusedRecord.Script.txt" -> "SetFocusedRecord.Script.as" (strip last suffix only)
  const outName = name.replace(/\.[^.]+$/, "") + ".as";

  const body = splitLines(
    fs
      .readFileSync(srcFile, "utf8")
      .replaceAll('"""', TRIPLE_QUOTE_PLACEHOLDER)
      .replaceAll("/*CUT\n", "")
      .replaceAll("CUT*/\n", "")
  ).map(procLine);

  const lines = [
    `const string ${constantName} = """`,
    ...body,
    `""".Replace('${TRIPLE_QUOTE_PLACEHOLDER}', '"""');`,
  ];

  const outFile = path.join(GENERATED_SCRIPTS_DIR, outName);
  fs.mkdirSync(GENERATED_SCRIPTS_DIR, { recursive: true });
  fs.writeFileSync(outFile, lines.join("\n"));
  return outFile;
}

export function preprocessScripts({ quiet = false } = {}) {
  const outputs = [];
  for (const entry of fs.readdirSync(ML_SCRIPTS_DIR)) {
    if (!entry.toLowerCase().endsWith(".script.txt")) {
      console.warn(`  ! skipping ${entry} (does not end with .Script.txt)`);
      continue;
    }
    const out = scriptToAsFile(path.join(ML_SCRIPTS_DIR, entry));
    outputs.push(out);
    if (!quiet) console.log(`  ${entry} -> src/scripts/${path.basename(out)}`);
  }
  return outputs;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  preprocessScripts();
}
