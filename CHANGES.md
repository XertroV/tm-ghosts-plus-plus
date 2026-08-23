# Changes in this branch

Draft PR opened only to make the code visible — not asking for a merge. Take whatever
is useful and ignore the rest.

**Disclosure: this code was written by an AI agent (Claude Code), directed and tested
in-game by me.** Every change was run in the game before release and several were reverted
when they turned out to be wrong. Memory offsets were measured in the running game with a
diagnostic dump rather than guessed.

Ordered by how self-contained each change is.

File layout, plugin name, module name and info.toml are left exactly as yours -- the
fork renamed things and reorganised src/, and none of that belongs in a PR.

---

## 1. Independent bug fixes (small, no dependencies)

These stand alone and can be taken individually.

### Heap overflow when saving a ghost — likely #39
`src/MkGhostScript.as`

`CreateGhostScript` zeroes fields out to `0x50`, assuming `CGameGhostScript` is `0x58`
bytes. Openplanet's reflection dump reports it as `0x38` on 2026-02-02_17_51, so the
writes at `0x38`, `0x40`, `0x48` and `0x50` land past the end of the object. Corrupting
adjacent heap crashes later and elsewhere, which is why the reports have no stack trace.

Fix: derive the loop bound from `Reflection::GetType("CGameGhostScript").Size` and only
zero fields that fit.

### Crash on plugin reload / disable
`src/Main.as`, `OnDestroyed()`

Original order:

```
NodPtrs::Unload();      // frees the nod-pointer scratch page
NoFlashCar::IsApplied = false;
CameraPolish::Hook_CameraUpdatePos.Stop();
Unload();               // still resolves nod pointers through that page
```

`Unload()` runs `scrubberMgr.ResetAll()`, MLHook unregistration and
`CheckUnhookAllRegisteredHooks()`, any of which can convert a pointer to a nod through the
page that was just freed. Reloading or disabling the plugin crashes the game consistently.

Fix: remove hooks and patches first, then `Unload()`, then free the scratch page last.
`Dev_GetArbitraryNodAt()` also now throws instead of writing through the stale handle.

### Camera resets at the end of a run — #33
`src/Intercepts.as`, `_Spectator_SetForcedTarget_Ghost`

```angelscript
lastBlockedSetStartTimeNow + 2 >= Time::Now
```

`Time::Now` is milliseconds, so this is a 2 ms window. A frame at 60 fps is ~16 ms, so it
has almost always expired by the time the follow-up call arrives. The same file uses 100 ms
for the equivalent guard (`allowSetStartTimeNow_BeforeEq`), so the `2` looks like a frame
count written as a duration.

Fix: 100 ms, **and** scope the block to the case where the mode is re-asserting the ghost
already being spectated. Blocking a target change to a *different* ghost breaks spectating
entirely — camera detached, nothing playing until the timeline is scrubbed.

### Camera stranded and timeline pinned after a run ends
`src/CameraPolish.as`, `src/Intercepts.as`

Two parts of the same moment:

- `CameraPolish` holds the camera at its last position while the ghost's entity is missing,
  with no time limit, so once a run ends the camera stays pinned there forever. Now bounded
  to 1.5 s after the entity was last seen.
- The guard against the end-of-run `Ghosts_SetStartTime(Now)` restart tests
  `IsSpectatingGhost()`, but that restart fires at exactly the moment a ghost stops being
  spectatable — so it answers "no" precisely when it needs to answer "yes". Now asks whether
  we were spectating within the last 1.5 s.

### Personal best loads twice as two overlapping ghosts
`src/Interface.as`, `IsGhostLoaded`

Dedupe compares race time **and nickname**. The game's own PB ghost is named
`$7FAPersonal best`, not the player's name, so a leaderboard copy of the same run never
matches and loads a second time. Now matches on account via
`NadeoServices::LoginToAccountId(gm.GhostLogin)`, with nickname as a fallback.

Note: the two PB ghosts are not equivalent. One is the launched-CP ghost that stays in
sync with your own checkpoint respawns; that sync makes it **stutter and wobble** when
spectated or scrubbed, while a plain loaded ghost replays smoothly. `src/DedupeGhosts.as`
keeps the plain copy. This may be relevant to the stuttering issue you mentioned.

### Entity-record offset moved
`src/ReadEntRecordData.as`

`CGameCtnGhost` went `0x330` → `0x340`. The checkpoint (`NbRespawns + 0x8`) and player
input (`Validate_GameModeCustomData + 0x18`) offsets are unchanged and still correct, but
the entity record buffer moved from `+0xC0` to `+0xC8`. Measured, not guessed — see §4.

That file is inside `#if FALSE` so this is currently dead code.

---

## 2. Compatibility handling (replaces the version list)

`src/Reflect.as`, `src/CapabilityRegistry.as`, `src/Probes.as`, `src/GameVersionFlags.as`

This is the largest change and the most opinionated, so it is easiest to ignore.

Every version-fragile operation is registered as a capability with a probe. A failing probe
disables one feature and reports why, instead of the whole plugin going inactive. Probes
check values where they can rather than just names — ghost opacity must read back in 0..1,
the active camera type must be in range, the ghost-visibility pointer walk must still land
on a `CGameUserProfile`.

Two details that might be worth taking regardless of the rest:

- **`GetOffsetSafe()`** (`Reflect.as`). The offsets in the codebase are global initialisers
  that run before `Main()`, so one renamed member throws at module load and takes the whole
  plugin down before any check can run. This returns a fallback instead.
- **Probes read cached pattern addresses rather than re-scanning.** `Dev::FindPattern` is
  context-sensitive — your comment in `Scrubber.as` about the camera hook needing to be
  async says as much — and re-scanning from a coroutine gave false negatives for patterns
  the patchers had already located. `HookHelper` gained a `PatternPtr` accessor for this.

---

## 3. Build tooling

`tools/*.mjs` — Node replacements for `build.sh` and `pre-proc-scripts.py`, so a build needs
no bash, python or 7-Zip. `preproc.mjs` output is byte-identical to the python original.

`tools/verify-offsets.mjs` is the one worth a look: it parses Openplanet's
`OpenplanetNext.json` reflection dump and checks every `GetOffset("Class", "Member")` in the
source, **and hardcoded struct sizes**, exiting non-zero on a mismatch. The struct-size check
is what found the `CGameGhostScript` heap overflow above — offline, in about a second. It
can also diff two dumps to show what a game update changed, limited to what the plugin
actually uses.

---

## 4. How the offsets were measured

`src/GhostStructDump.as` (dev builds only) walks the ghost object and reports
every `{pointer, length, capacity}` triple with its offset relative to the reflected anchor
members. Reading *inside* the object is safe — it is mapped and the reflected size bounds
it — and candidate pointers are range-checked but never dereferenced.

Output on 2026-02-02_17_51, 4-checkpoint map:

```
anchors: NbRespawns @ +0x030, Validate_GameModeCustomData @ +0x190,
         Validate_ExtraTool_Info @ +0x230
+0x038  len=5  [NbRespawns + 0x8]                   checkpoints (4 CPs + finish)
+0x1a8  len=1  [Validate_GameModeCustomData + 0x18] player inputs
+0x2f8  len=1  [Validate_ExtraTool_Info + 0xc8]     entity records
```

---

## 5. New features (ignore freely)

Not bug fixes, listed only so the diff makes sense:

- **Compare tab** — per-checkpoint splits for loaded ghosts as deltas against a reference
- **Speed telemetry** — sampled from the VehicleState plugin, so it owns no offsets
- **Library tab** — search/sort/import/remove saved ghosts across maps
- **Camera trigger restore** — records which camera was active where during playback and
  reapplies it when scrubbing, so scrubbing past a forced-camera section is not sticky (#16, #30)

---

## Known unsolved

Reading ghost input data crashes the game. Traced to the first `res.InsertLast(change)` in
`GetProcessedGhostInputData`'s parse loop — construction of the `TmInputChange` succeeds,
the first append does not, with no exception and no stack. Offsets, `BytesPtr` and
`BytesLen` are all verified correct (all 1070 bytes copy without faulting).

Ruled out: stale offsets, the dereference, ImGui index overflow, running off the bit
buffer, malformed data, and the shared-type ABI (removing the `shared` interface from
`TmInputChange` did not help). The feature is disabled in `Probes.as` with these findings
recorded.
