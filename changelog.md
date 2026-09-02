# Changelog

## 0.4.8.2 (unreleased)

- fix: "Script execution timeout exceeded" aborting the plugin when clicking
  the "Inputs" button on a long ghost. The parse ran synchronously inside the
  UI render callback; a ~440k-tick ghost needs more than the plugin's whole
  4.4 s script budget, so execution was aborted mid-render. The parse now runs
  as a coroutine in ~8 ms wall-time slices (`GhostInputsParser` /
  `GhostInputsLoader` in `Ghosts/ReadCtnGhostInputs.as` + `Interface.as`), the
  Ghost Inputs window shows a progress bar with ticks parsed and an ETA while
  loading, renders input rows as they are parsed, and the parse cancels
  cleanly when superseded, the window is closed, the map changes, or the ghost
  is unloaded. The exported synchronous `GetGhostInputData` API is unchanged.
  Verified on a 207,994-tick ghost: 65,721 input changes — identical count to
  the synchronous parser — with no timeout; also on an 854,590-tick (2 h 22 m)
  ghost in 16.6 s.

- fix: game crash when clicking the "Inputs" button on a loaded ghost (issue #39).
  Root cause is a bug in the AngelScript bytecode optimizer bundled with
  Openplanet 1.29.5 (upstream 2.39.0 WIP): `started = EStart(states & 3)` with
  a uint64 `states` is fused into a single 64-bit write into the 4-byte enum
  variable, zeroing the low dword of the adjacent `res` array handle; the next
  `res.InsertLast(...)` then faults on the corrupted handle. Worked around by
  masking in 32 bits: `EStart(uint(states) & 3)`. Reproduced natively and
  fixed upstream (regression test + patch against AngelScript 2.39.0 WIP,
  submission pending). The parser was also rewritten to read bits directly
  from the ghost's input buffer in game memory (no MemoryBuffer/uint8[] copy
  churn) with null/size guards — a good cleanup, but not the fix: the crash
  reproduced with the rewritten parser too.

- fix: game crash on "Save ghost for later" (issue #39).
  `CreateGhostScript` zeroed CGameGhostScript fields out to +0x50, but the
  struct shrank from 0x58 to 0x38 in the 2026-02-02 engine build, so the last
  four writes landed past the end of the object and corrupted the heap.
  Now only fields that still exist are written.
  Fix and diagnosis by **@jozzzof** in **PR #44** ("2026 compatibility, bug
  fixes and tooling"), which also documents the measured struct layout.
