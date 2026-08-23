void SetupIntercepts() {
    Dev::InterceptProc("CSmArenaRulesMode", "Ghosts_SetStartTime", _Ghosts_SetStartTime);
    Dev::InterceptProc("CSmArenaRulesMode", "SpawnPlayer", _SpawnPlayer);
    Dev::InterceptProc("CSmArenaRulesMode", "RespawnPlayer", _RespawnPlayer);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_Add", _Ghost_Add);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_AddWaypointSynced", _Ghost_AddWaypointSynced);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_Remove", _Ghost_Remove);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_RemoveAll", _Ghost_RemoveAll);
    Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Ghost", _Spectator_SetForcedTarget_Ghost);
    // not a proc
    // Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Clear", _Spectator_SetForcedTarget_Clear);
    Dev::InterceptProc("CGameScriptHandlerPlaygroundInterface", "CloseInGameMenu", _CGSHPI_CloseInGameMenu);
    // cannot intercept as not proc
    // Dev::InterceptProc("CGameManiaPlanet", "BackToMainMenu", _BackToMainMenu);
    // Dev::InterceptProc("CTrackMania", "BackToMainMenu", _BackToMainMenu_TM);
}

bool g_BlockNextSpawnPlayer;
uint lastSpawnTime;
int lastGhostsStartOrSpawnTime;
bool _SpawnPlayer(CMwStack &in stack, CMwNod@ nod) {
    auto pg = cast<CSmArenaRulesMode>(nod);
    if (pg !is null) {
        // todo, use start time instead
        lastSpawnTime = pg.Now;
        lastGhostsStartOrSpawnTime = lastSpawnTime;
    }
    if (g_BlockNextSpawnPlayer) {
        log_warn("Blocking spawn player");
        g_BlockNextSpawnPlayer = false;
        return false;
    }
    log_warn("SpawnPlayer: resetting scrubber state");
    if (scrubberMgr !is null) scrubberMgr.ResetAll();
    startnew(CoroutineFunc(scrubberMgr.ResetAll));
    startnew(SetGhostStartTimeToMatchPlayer);
    return true;
}

void SetGhostStartTimeToMatchPlayer() {
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (ps is null || cp is null || cp.Players.Length == 0) return;
    auto p = cast<CSmPlayer>(cp.Players[0]);
    if (p is null) return;
    // dev_trace("SetGhostStartTimeToMatchPlayer");
    Call_Ghosts_SetStartTime(ps, -1);
}

bool _RespawnPlayer(CMwStack &in stack) {
    log_warn("RespawnPlayer: resetting scrubber state");
    if (scrubberMgr !is null) scrubberMgr.ResetAll();
    return true;
}
bool _CGSHPI_CloseInGameMenu(CMwStack &in stack) {
    auto result = CGameScriptHandlerPlaygroundInterface::EInGameMenuResult(stack.CurrentEnum(0));
    bool isExiting = result == CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit;
    // having ghosts in the paused state can crash the game when exiting a map
    if (isExiting && scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.ResetAll();
        log_trace("Reset paused scrubber due to exit map");
        // startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    return true;
}

uint lastLoadedGhostRaceTime = 0;
bool ghostAddSkipIntercept = false;
[Setting category="Ghosts" name="Prevent duplicate ghosts" description="Blocks loading a ghost that is already loaded -- same player, same time. Without this the game's own \"Personal best\" ghost and your record from the leaderboard both load, leaving two identical ghosts driving on top of each other."]
bool S_PreventDuplicateGhosts = true;

/**
 * Is this exact run already loaded?
 *
 * Identity is player login plus race time. Nickname is unusable for this: the game's own
 * PB ghost is called "$...Personal best" rather than the player's name, so a name
 * comparison never matches it against the same run from the leaderboard.
 *
 * Fails open -- an unidentifiable ghost is allowed through, because a duplicate is a much
 * smaller problem than silently refusing to load something legitimate.
 */
/**
 * Ghosts added since the last map change, as "login|time".
 *
 * The clips manager is not necessarily updated between two Ghost_Add calls in the same
 * frame, so checking it alone misses a same-frame double add -- which is what loading the
 * PB ghost twice at map start looks like.
 */
string[] g_RecentGhostAddKeys;
uint[] g_RecentGhostAddTimes;

/**
 * How long an add stays "recent".
 *
 * Only needs to span the gap between two adds racing each other before the clips manager
 * catches up -- the same frame, in practice. Deliberately short: entries must expire, or
 * unloading a ghost and loading it again would be refused as a duplicate.
 */
const uint RECENT_GHOST_ADD_MS = 2000;

string GhostAddKey(const string &in login, int raceTime) {
    return login + "|" + raceTime;
}

bool WasGhostRecentlyAdded(const string &in login, int raceTime) {
    PruneRecentGhostAdds();
    return g_RecentGhostAddKeys.Find(GhostAddKey(login, raceTime)) >= 0;
}

void NoteGhostAdded(const string &in login, int raceTime) {
    PruneRecentGhostAdds();
    g_RecentGhostAddKeys.InsertLast(GhostAddKey(login, raceTime));
    g_RecentGhostAddTimes.InsertLast(Time::Now);
}

void PruneRecentGhostAdds() {
    while (g_RecentGhostAddTimes.Length > 0
            && g_RecentGhostAddTimes[0] + RECENT_GHOST_ADD_MS < Time::Now) {
        g_RecentGhostAddTimes.RemoveAt(0);
        g_RecentGhostAddKeys.RemoveAt(0);
    }
}

/** Called on map change: ghosts do not survive it, so neither should this list. */
void ClearRecentGhostAdds() {
    g_RecentGhostAddKeys.RemoveRange(0, g_RecentGhostAddKeys.Length);
    g_RecentGhostAddTimes.RemoveRange(0, g_RecentGhostAddTimes.Length);
}

bool IsGhostAlreadyLoaded(const string &in login, int raceTime) {
    if (login.Length == 0) return false;
    auto mgr = GhostClipsMgr::Get(GetApp());
    if (mgr is null) return false;
    for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        auto gm = mgr.Ghosts[i].GhostModel;
        if (gm is null) continue;
        if (int(gm.RaceTime) == raceTime && gm.GhostLogin == login) return true;
    }
    return false;
}

bool _Ghost_Add(CMwStack &in stack, CMwNod@ nod) {
    if (ghostAddSkipIntercept) return true;

    // Runs BEFORE the ps.Now < 1000 early-out below. Ghosts are added within the first
    // second of a map load, so anything gated behind that check never sees them -- which
    // is precisely the window where the PB ghost gets added twice.
    if (S_PreventDuplicateGhosts) {
        auto addingGhost = cast<CGameGhostScript>(stack.CurrentNod(1));
        if (addingGhost !is null && addingGhost.Result !is null) {
            auto ctn = GetCtnGhost(addingGhost);
            if (ctn !is null && ctn.GhostLogin.Length > 0) {
                int raceTime = addingGhost.Result.Time;
                // Two checks, because they cover different cases: the clips manager
                // catches a ghost already present, and the recent-adds list catches two
                // adds landing before the manager has been updated.
                if (IsGhostAlreadyLoaded(ctn.GhostLogin, raceTime)
                        || WasGhostRecentlyAdded(ctn.GhostLogin, raceTime)) {
                    log_info("blocking duplicate ghost add: " + addingGhost.Nickname
                        + " / " + Time::Format(raceTime) + " / login " + ctn.GhostLogin);
                    return false;
                }
                NoteGhostAdded(ctn.GhostLogin, raceTime);
            }
        }
    }

    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null || ps.Now < 1000) return true;

    // having ghosts in the paused state can crash the game when loading ghosts
    // ! sometimes a null ptr exception is thrown here
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        log_trace("Starting DoPause soon b/c adding ghost");
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }

    if (ps !is null) {
        // auto gm = cast<CGameGhostMgrScript>(nod);
        auto ghost = cast<CGameGhostScript>(stack.CurrentNod(1));
        if (ghost !is null) {
            Cache::CheckForNameToAddSoon(ghost.Nickname, ghost.Result.Time);
            lastLoadedGhostRaceTime = ghost.Result.Time;

            // todo: if doing PB detection in future, we cannot test the ghost name. We should instead use the name of the ghost in clip[0] which is always pb if it's loaded/shown.
            // auto ctnGhost = GetCtnGhost(ghost);
            // if (ctnGhost !is null && !ctnGhost.GhostNickname.StartsWith("$")) {
            //     // trace('ctnGhost not null');
            //     // Update_ML_SetGhostLoaded(LoginToWSID(ctnGhost.GhostLogin));
            // } else {
            //     // trace('ctnGhost null');
            // }
        }
    }
    startnew(Update_ML_SyncAll);

    return true;
}

bool _Ghost_AddWaypointSynced(CMwStack &in stack) {
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        log_trace("Starting DoPause soon b/c _Ghost_AddWaypointSynced");
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    return true;
}

uint allowSetStartTimeNow_BeforeEq = 0;

bool _Ghost_Remove(CMwStack &in stack) {
    // having ghosts in the paused state can crash the game when removing a ghost
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        log_trace("Starting DoPause soon b/c _Ghost_Remove");
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    startnew(Update_ML_SyncAll);
    allowSetStartTimeNow_BeforeEq = Time::Now + 100;
    return true;
}

bool _Ghost_RemoveAll(CMwStack &in stack) {
    // having ghosts in the paused state can crash the game when removing a ghost
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        log_trace("Starting DoPause soon b/c _Ghost_RemoveAll");
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    return true;
}

bool g_BlockNextGhostsSetTimeReset;
bool g_BlockNextGhostsSetTimeAny;
bool g_BlockAllGhostsSetTimeNow = true;
bool g_AllowNextForceGhostDespiteNowBlock = true;
uint lastBlockedSetStartTimeNow = 1;

/**
 * When we were last actually spectating a ghost. Updated from the scrubber each frame.
 *
 * The end-of-run restart this guards against fires at precisely the moment a ghost stops
 * being spectatable, so testing IsSpectatingGhost() at that instant answers "no" and lets
 * the restart through -- ghosts jump back to the start and the timeline pins itself at
 * 0:00.001 with nothing playing. Asking whether we were spectating a moment ago is the
 * question that was actually meant.
 */
uint lastSpectatingGhostAt = 0;
const uint SPECTATING_RECENTLY_MS = 1500;

void NoteSpectatingGhost() {
    lastSpectatingGhostAt = Time::Now;
}

bool WasSpectatingGhostRecently() {
    if (IsSpectatingGhost()) {
        lastSpectatingGhostAt = Time::Now;
        return true;
    }
    return lastSpectatingGhostAt > 0
        && lastSpectatingGhostAt + SPECTATING_RECENTLY_MS >= Time::Now;
}
int lastSetStartTime = 5000;
bool _Ghosts_SetStartTime(CMwStack &in stack, CMwNod@ nod) {
    auto ghostStartTime = stack.CurrentInt(0);
    // log_debug("_Ghosts_SetStartTime: " + ghostStartTime);
    // if (false && g_BlockNextGhostsSetTimeReset && int(ghostStartTime) < 0) {
    //     warn("blocking ghost SetStartTime reset");
    //     g_BlockNextGhostsSetTimeReset = false;
    //     return false;
    // }

    auto ps = cast<CSmArenaRulesMode>(nod);

    if (g_BlockAllGhostsSetTimeNow && WasSpectatingGhostRecently() && Time::Now > allowSetStartTimeNow_BeforeEq) {
        bool isNearlyNow = ghostStartTime == int(ps.Now) - 1;
        if (ghostStartTime == int(ps.Now) || isNearlyNow) {
            warn("blocking ghost SetStartTime Now" + (isNearlyNow ? "-1" : ""));
            lastBlockedSetStartTimeNow = Time::Now;
            return false;
        } else {
            dev_trace("ghost SetStartTime not Now: " + ghostStartTime + " / " + ps.Now);
        }
    }

    if (g_BlockNextGhostsSetTimeAny && Time::Now > allowSetStartTimeNow_BeforeEq) {
        warn("blocking ghost SetStartTime any: " + ghostStartTime);
        g_BlockNextGhostsSetTimeAny = false;
        return false;
    }

    lastSetStartTime = ghostStartTime;
    // lastGhostsStartOrSpawnTime = Math::Max(lastGhostsStartOrSpawnTime, ghostStartTime);
    lastGhostsStartOrSpawnTime = ghostStartTime;
    return true;
}

void Call_Ghosts_SetStartTime(CSmArenaRulesMode@ ps, int startTime) {
    g_BlockAllGhostsSetTimeNow = false;
    if (ps is null) return;
    ps.Ghosts_SetStartTime(startTime);
    // log_debug("ghosts call set start time: " + startTime);
    g_BlockAllGhostsSetTimeNow = true;
}

MwId lastSpectatedGhostInstanceId = MwId(uint(-1));
uint lastSpectatedGhostRaceTime = 0;

/**
 * How long after blocking a "SetStartTime Now" we keep refusing target changes.
 *
 * When a ghost reaches the end of its run the mode tries to restart it, and the follow-up
 * Spectator_SetForcedTarget_Ghost is what resets the camera. Suppressing that follow-up
 * only works if the window is still open when it arrives.
 *
 * This was 2ms. Time::Now is in milliseconds, so at 60fps -- one frame being ~16ms -- the
 * window had almost always closed by the time the follow-up landed, and the camera reset
 * anyway (upstream #33). The rest of this file already uses 100ms for the same kind of
 * guard (see allowSetStartTimeNow_BeforeEq), so 2 looks like it was meant as a frame
 * count rather than a duration.
 */
const uint BLOCK_AFTER_SET_START_TIME_MS = 100;

bool _Spectator_SetForcedTarget_Ghost(CMwStack &in stack, CMwNod@ nod) {
    auto ghostInstId = stack.CurrentId(0);
    bool sameGhost = lastSpectatedGhostInstanceId.Value == ghostInstId.Value;

    // Suppress only the mode re-asserting the ghost already being spectated. That is the
    // end-of-run camera reset this guard exists for (upstream #33).
    //
    // Scoping it to the same ghost matters: a target change to a *different* ghost is the
    // player choosing one. Blocking that leaves the camera detached with nothing playing
    // until the timeline is scrubbed or unlocked -- which is what widening this window
    // from 2ms to 100ms caused, until it was narrowed to same-ghost re-asserts only.
    //
    // g_AllowNextForceGhostDespiteNowBlock stays as a second exemption, for target changes
    // the player asked for explicitly (records UI, or the Spectate button).
    bool blockSameGhostReassert =
        lastBlockedSetStartTimeNow + BLOCK_AFTER_SET_START_TIME_MS >= Time::Now
        && IsSpectatingGhost()
        && sameGhost
        && !g_AllowNextForceGhostDespiteNowBlock;

    if (sameGhost) {
        dev_trace("SetForcedTarget_Ghost called for same ghost instance id; ignoring but applying last SpectatorForceCameraType");
        auto uiAll = cast<CGamePlaygroundUIConfig>(nod);
        if (uiAll !is null) uiAll.SpectatorForceCameraType = lastSetForcedCamera;
    }

    auto mgr = GhostClipsMgr::Get(GetApp());
    auto ghost = mgr is null ? null : GhostClipsMgr::GetGhostFromInstanceId(mgr, ghostInstId.Value);

    if (ghost !is null) {
        // Logs the incoming instance id, not the previous one -- the old line reported
        // lastSpectatedGhostInstanceId here, which is whatever we were watching before.
        log_trace('SetForcedTarget_Ghost: ' + string(ghost.GhostModel.GhostNickname)
            + " / InstanceId: " + Text::Format("#%08x", ghostInstId.Value)
            + " / RaceTime: " + ghost.GhostModel.RaceTime);
    } else {
        log_info("SetForcedTarget_Ghost called for a ghost that does not exist; inst id: " + Text::Format("#%08x", ghostInstId.Value));
    }

    if (blockSameGhostReassert) {
        log_trace("blocking SetForcedTarget_Ghost: mode re-asserting the same ghost right after a blocked SetStartTime Now");
        return false;
    }

    g_AllowNextForceGhostDespiteNowBlock = false;

    lastSpectatedGhostInstanceId = ghostInstId;
    lastSpectatedGhostRaceTime = (ghost is null) ? 0 : ghost.GhostModel.RaceTime;
    g_SaveGhostTab.StartWatchGhostsLoopLoop();
    if (lastSpectatedGhostRaceTime > 0) {
        CheckUnlockTimelinePrompt(lastSpectatedGhostRaceTime);
    }

    return true;
}

bool g_BlockNextClearForcedTarget;
bool _Spectator_SetForcedTarget_Clear(CMwStack &in stack) {
    if (g_BlockNextClearForcedTarget) {
        warn("Blocking clear forced target");
        g_BlockNextClearForcedTarget = false;
        return false;
    }
    // warn("SetForcedTarget_Clear");
    return true;

}


// update values set by intercepts
void SetCurrentGhostValues() {
    auto app = cast<CTrackMania>(GetApp());
    auto ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    // auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
    if (ps is null) return;
    // if (!ps.UIManager.UIAll.ForceSpectator) return;
    trace('Setting current ghost values (if non null)');
    // auto currInstIdOffset = GetOffset("CGamePlaygroundUIConfig", "SpectatorCamAutoLatitude") - 0x14;
    // uint instId = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset);
    // 0 none, 1 all players, 2 all map, 3 clan, ? entity, ? landmark, 6 ghost
    // uint specFlag = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset - 0x4);
    // if (specFlag != 6) {
    //     trace('spec target type == ' + specFlag + ' (not ghost)');
    //     return;
    // }
    // trace('current spectating instId: ' + instId);

    // if (instId == 0) return;
    auto mgr = GhostClipsMgr::Get(GetApp());
    if (mgr is null) return;
    auto maxTime = GhostClipsMgr::GetMaxGhostDuration(mgr);
    // auto ghost = GhostClipsMgr::GetGhostFromInstanceId(mgr, instId);
        // lastSpectatedGhostInstanceId = instId;
    lastSpectatedGhostRaceTime = maxTime;
    lastLoadedGhostRaceTime = maxTime;
    lastSetStartTime = GhostClipsMgr::GetCurrentGhostTime(mgr);
    trace('Set current ghost values: ' + lastSetStartTime + ' / ' + lastSpectatedGhostRaceTime); // + ' / ' + Text::Format("%08x", instId));
    if (IsSpectatingGhost()) {
        lastSpectatedGhostInstanceId = GetCurrentlySpecdGhostInstanceId(ps);
        auto g = GhostClipsMgr::GetGhostFromInstanceId(mgr, lastSpectatedGhostInstanceId.Value);
        if (g !is null) lastSpectatedGhostRaceTime = g.GhostModel.RaceTime;
    }
}

// ! clip pausing and unpausing moved to GhostClips.as

// If spectating a ghost, return it's instance ID, otherwise return 0x0FF0000
uint GetCurrentlySpecdGhostInstanceId(CSmArenaRulesMode@ ps) {
    if (ps is null) return 0x0FF00000;
    auto currInstIdOffset = GetOffset("CGamePlaygroundUIConfig", "SpectatorCamAutoLatitude") - 0x14;
    uint instId = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset);
    // 0 none, 1 all players, 2 all map, 3 clan, ? entity, ? landmark, 6 ghost
    uint specFlag = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset - 0x4);
    if (specFlag != 6) {
        log_trace('spec target type == ' + specFlag + ' (not ghost); ghost inst id is: ' + Text::Format("#%08x", instId));
        return 0x0FF00000;
    }
    return instId;
}
