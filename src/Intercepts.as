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
bool _Ghost_Add(CMwStack &in stack, CMwNod@ nod) {
    if (ghostAddSkipIntercept) return true;
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
int lastSetStartTime = 5000;
bool _Ghosts_SetStartTime(CMwStack &in stack, CMwNod@ nod) {
    auto ghostStartTime = stack.CurrentInt(0);
    // log_debug("ghosts set start time: " + ghostStartTime);
    // if (false && g_BlockNextGhostsSetTimeReset && int(ghostStartTime) < 0) {
    //     warn("blocking ghost SetStartTime reset");
    //     g_BlockNextGhostsSetTimeReset = false;
    //     return false;
    // }

    auto ps = cast<CSmArenaRulesMode>(nod);

    if (g_BlockAllGhostsSetTimeNow && IsSpectatingGhost() && Time::Now > allowSetStartTimeNow_BeforeEq) {
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

bool _Spectator_SetForcedTarget_Ghost(CMwStack &in stack, CMwNod@ nod) {
    bool blockAfterBlockedSetStartTime = lastBlockedSetStartTimeNow + 2 >= Time::Now
        && IsSpectatingGhost();
#if DEV
#else
    if (blockAfterBlockedSetStartTime) {
        // if we just blocked a set start time, don't let the mode change target ghost
        log_trace("blocking SetForcedTarget_Ghost due to blocked SetStartTime Now");
        return false;
    }
#endif


    auto ghostInstId = stack.CurrentId(0);
    if (lastSpectatedGhostInstanceId.Value == ghostInstId.Value) {
        dev_trace("SetForcedTarget_Ghost called for same ghost instance id; ignoring but applying last SpectatorForceCameraType");
        auto uiAll = cast<CGamePlaygroundUIConfig>(nod);
        if (uiAll !is null) uiAll.SpectatorForceCameraType = lastSetForcedCamera;
    }

    auto mgr = GhostClipsMgr::Get(GetApp());
    auto ghost = mgr is null ? null : GhostClipsMgr::GetGhostFromInstanceId(mgr, ghostInstId.Value);

    if (ghost !is null) {
        log_trace('SetForcedTarget_Ghost: ' + (ghost is null ? "null" : string(ghost.GhostModel.GhostNickname)) + " / InstanceId: " + Text::Format("#%08x", lastSpectatedGhostInstanceId.Value) + " / RaceTime: " + lastSpectatedGhostRaceTime);
    } else {
        log_info("SetForcedTarget_Ghost called for a ghost that does not exist; inst id: " + Text::Format("#%08x", ghostInstId.Value));
    }

#if DEV
    // if we just blocked a set start time, don't let the mode change target ghost
    if (blockAfterBlockedSetStartTime) {
        log_trace("[DEV] Blocking set forced target ghost due to blocked set start time now");
        return false;
    }
#endif

    // if (lastBlockedSetStartTimeNow == Time::Now && !g_AllowNextForceGhostDespiteNowBlock) {
    //     warn("Blocking set forced target ghost due to blocked set start time now");
    //     return false;
    // }
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
