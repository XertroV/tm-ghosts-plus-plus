# Changelog

## 0.4.8.2 (unreleased)

- fix: game crash when clicking the "Inputs" button on a loaded ghost.
  The ghost input parser was rewritten to read bits directly from the ghost's
  input buffer in game memory instead of copying the whole buffer through a
  MemoryBuffer and a uint8[] script array first; that allocation churn was
  corrupting the freshly created result array (access violation inside
  openplanet.dll's array code on the first insert, with the buffer pointer
  garbage). Null/size guards added so malformed or changed ghost layouts now
  fail with a script error instead of reading wild pointers.

- fix: game crash on "Save ghost for later" (issue #39).
  `CreateGhostScript` zeroed CGameGhostScript fields out to +0x50, but the
  struct shrank from 0x58 to 0x38 in the 2026-02-02 engine build, so the last
  four writes landed past the end of the object and corrupted the heap.
  Now only fields that still exist are written.
  Fix and diagnosis by **@jozzzof** in **PR #44** ("2026 compatibility, bug
  fixes and tooling"), which also documents the measured struct layout.
