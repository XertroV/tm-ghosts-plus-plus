# G++ ghost playback stutter after the physicalized-ghost update

Diagnosed 2026-08-24. Native clock notes live in E++ `research/2026-08-24-GhostsSetStartTime.md`.

## Symptom

After the ~January 2026 game update (when `Ghost_AddPhysicalized` / `EGhostPhyMode` landed), racing against ghosts **with G++ loaded** hitches. The local car is fine; the *ghost cars* stutter.

This is **not** new as of 2026-08-24. It existed through 2H 2025-era G++ on the post-January game, including the long-standing StdPlayback 1x path.

## Retracted (do not chase)

These were written up in the first pass and are **wrong** as stutter causes:

| Hypothesis | Why it is out |
|---|---|
| `FLAG_GameVer2025` / clip offsets `0x20` vs `0x30` | Offsets moved forward then back. G++ does not need a 2025-vs-2026 compat flag. **Wrong clip-player pointers would crash.** The game does not crash. Scrubbing works. |
| SoftCollisions / `CtnGhost+0x240` bit 0 | Not the stutter. (Phy-mode RE is still useful elsewhere; do not pin this hitch on it.) |
| `Ghost_AddPhysicalized` as the normal add path | Physicalized ghosts exist in some modes. Official race ghosts are `Ghost_Add(ghost, IsGhostLayer)`. |
| `EnsureCustomSpeed` (added 2026-08-24 night) | Last-night experiment. **It does not work.** Before it, G++ used StdPlayback at 1x. **Both versions stuttered.** The experiment also calls `DoPause()`, which writes the actual bug field (`+0x340 = 1`). |

`EnsureCustomSpeed` / `SetPlaybackSpeed` comments that say “always use CustomSpeed (avoids stutter)” are aspirational, not evidence. Revert that experiment; do not pile more playback-mode changes on top.

## Confirmed mechanism (Ghidra 2026-08-24, evening)

Idle G++ + normal race does **not** write `Ghosts_SetStartTime` every tick. The hitch is leftover clip-player state from `DoUnpause` / `DoPause` / `ResetAll` (every `SpawnPlayer`).

### Official ghost invariant

`NGameGhost_CreateGhostPlayer` (`0x140cff240`) constructs a `CGameCtnMediaClipPlayer` (size `0x348`) whose **ctor default** of `+0x340` is **1** (MediaTracker delta-advance). It then **forces `+0x340 = 0`** at `0x140cff337` before `Play`.

`+0x340` is **DoDeltaAdvance**, not “smooth pause”. `CGameCtnMediaClipPlayer_Advance` (`0x141076a50`):

```
+0x308 = dt
if (+0x340 != 0) {
    +0x338 += +0x334 * dt * +0x1B8
    if (speed > 1e-5 && +0x330 <= cursor) { end-callback; if (+0x31c == 0) return }
}
ApplyTracks at +0x338
```

Ghost clock (`ApplyGhostOrigin` `0x140cff1c0`) is **absolute**:

```
SetCurrentTime(player, (Now - origin) * 0.001 + extra)   // +0x338 = t
Advance(player, dt)                                       // must NOT add dt again
ApplyCurrentTime(player)                                  // pose at +0x338
```

Podium/intro clips (`FUN_140fdddf0`) also zero `+0x340` before the same SetCurrentTime+Advance pair.

`Play` (`CGameCtnMediaClipPlayer_Play` `0x1410755e0`) sets `+0x31c = 1` and does **not** restore `+0x340`. Ghosts stay at 0 for the rest of the clip player’s life unless something writes 1.

### What G++ does

`SetGhostClipPlayerPaused` and `SetGhostClipPlayerUnpaused` both wrote `O_GHOSTCLIPPLAYER_DO_DELTA_ADVANCE` (`+0x340`, was misnamed `SMOOTH_PAUSE`) = **1**.

`ResetAll()` → `DoUnpause()` runs on every `SpawnPlayer` / `RespawnPlayer` / map change. After that, ghost clips have DoDeltaAdvance **on** for the whole race.

Then every `UpdateAsync`:

1. Official sets `+0x338 = (Now-origin)/1000`.
2. `Advance` adds one frame of `dt` (`+0x334` is 1.0 while origin is valid).
3. Pose is sampled ~1 frame ahead.
4. Next tick `SetCurrentTime`: `d = t_new - (t_old + dt_advance)`. If `d < 0` (frame dt vs Now-delta mismatch), it **snaps backward and zeros `+0x33c`** (no interpolation that frame) → hitch.

The local car is a phy body on the 10 ms packet. It does not use this clip cursor, so it stays smooth.

Scrubbing still *looks* OK because G++ slams absolute clip time every seek; the idle-race path never does.

### Why EnsureCustomSpeed failed

It does not clear `+0x340`. It sets CustomSpeed and `DoPause()`, which wrote `+0x340 = 1` again and then fights the official `+0x338` slam every tick (`PauseClipPlayers`, `SetStartTime(Now - pauseAt)`). Same bug, more write-fight.

### Probe / fix

Write **0** to `+0x340` in pause and unpause (match `CreateGhostPlayer`). Live-verify: idle race with G++ loaded, ghosts should no longer hitch. If they still do, this mechanism is incomplete.

Phy-ghost landing in the same era is still only correlation — possibly vis interpolation started using `+0x33c` harder, which made an old G++ leftover visible.

## What G++ still does on every playground tick

`MLHook` playground callback → `ML_PG_Callback` → `scrubberMgr.Update()` whenever `PlaygroundScript` is set.

In a **normal race** (not spectating, not paused, `unpausedFlag == true`, StdPlayback):

1. Intercept `_Ghosts_SetStartTime` records `lastSetStartTime` / `lastGhostsStartOrSpawnTime` (official scripts typically `SetStartTime(-1)` while racing, `SetStartTime(Now)` on replay loop).
2. `Update()` else-branch only recomputes `pauseAt = Now - min(Now, lastGhostsStartOrSpawnTime)`. It does **not** call `Ghosts_SetStartTime` in that branch.
3. `DrawScrubber` does not write clip fields on the idle StdPlayback path.

So the hitch is **not** “G++ writes SetStartTime every tick while racing” — at least not on the StdPlayback 1x path. It is spawn-time clip-player mutation that sticks.

## Native clock (answered 2026-08-24)

Full call graph: E++ `research/2026-08-24-GhostsSetStartTime.md`.

- `CSmArenaRulesMode+0x14f8` is **`CSmArenaRules*`** (size `0x208`). `+0x44` is **`GhostsStartTime`**, not `RulesStateStartTime` (`+0x3c`).
- Per-frame reader: `CSmArenaClient_UpdateAsync` (`0x141311350`) → `CSmArenaClient_UpdateMediaAndGhostClips` (`0x1412241d0`) → `NGameGhostClips_SMgr_UpdatePlaybackTime` (`0x140cff870`) → `CGameCtnMediaClipPlayer_ApplyGhostOrigin` (`0x140cff1c0`).
- Formula: `ghostTime_s = (Now - origin) * 0.001 + SMgr+0x98`, cursor at clip `+0x338`. Origin `-1` resolves to `max(RulesStateStartTime, player.StartTime)` or freezes (`+0x334 = 0`).
- Official **does not** rewrite `+0x44` every tick. It **does** slam clip `+0x318/+0x334/+0x338` every `UpdateAsync`.
- `SetCurrentTime` (`0x141075c00`): cursor **always** becomes `t`. Forward `d > 0.2` only clamps the stored delta at `+0x33c` (not the cursor). Backward `d < 0` snaps cursor and **zeros `+0x33c`**.
- Current StdPlayback idle-race path still does **not** call `SetStartTime`.

## Official vs G++ clock

`CSmArenaRulesMode_Ghosts_SetStartTime` (`0x141350550`) only writes `*(this+0x14f8)+0x44 = t` (`-1` if `t < 0`). It does not walk clips.

G++ spectate/scrub (when it *is* seeking): `Ghosts_SetStartTime(Now - pauseAt)` + clip-player pause/unpause. That path works (scrubbing is smooth). The broken case is **idle G++ + normal race** after `ResetAll`/`DoUnpause` has turned DoDeltaAdvance back on.
