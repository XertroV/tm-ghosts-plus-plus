void SetupIntercepts() {
    Dev::InterceptProc("CSmArenaRulesMode", "Ghosts_SetStartTime", _Ghosts_SetStartTime);
    Dev::InterceptProc("CSmArenaRulesMode", "SpawnPlayer", _SpawnPlayer);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_Add", _Ghost_Add);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_AddWaypointSynced", _Ghost_AddWaypointSynced);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_Remove", _Ghost_Remove);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_RemoveAll", _Ghost_RemoveAll);
    Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Ghost", _Spectator_SetForcedTarget_Ghost);
    Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Clear", _Spectator_SetForcedTarget_Clear);
    Dev::InterceptProc("CGameScriptHandlerPlaygroundInterface", "CloseInGameMenu", _CGSHPI_CloseInGameMenu);
    // Dev::InterceptProc("CTrackMania", "TerminateGame", _OnExit);
    // Dev::InterceptProc("CTrackMania", "BackToMainMenu", _OnExit);
}

bool _OnExit(CMwStack &in stack) {
    print("got OnExit intercept");
    if (scrubberMgr !is null) {
        scrubberMgr.ResetAll();
    }
    return true;
}

bool g_BlockNextSpawnPlayer;
bool _SpawnPlayer(CMwStack &in stack) {
    if (g_BlockNextSpawnPlayer) {
        warn("Blocking spawn player");
        g_BlockNextSpawnPlayer = false;
        return false;
    }
    // warn("SpawnPlayer");
    return true;
}
bool _CGSHPI_CloseInGameMenu(CMwStack &in stack) {
    auto result = CGameScriptHandlerPlaygroundInterface::EInGameMenuResult(stack.CurrentEnum(0));
    bool isExiting = result == CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit;
    // having ghosts in the paused state can crash the game when exiting a map
    if (isExiting && scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.ResetAll();
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
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }

    if (ps !is null) {
        // auto gm = cast<CGameGhostMgrScript>(nod);
        auto ghost = cast<CGameGhostScript>(stack.CurrentNod(1));
        if (ghost !is null)
            Cache::CheckForNameToAddSoon(ghost.Nickname, ghost.Result.Time);
    }

    return true;
}

bool _Ghost_AddWaypointSynced(CMwStack &in stack) {
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    return true;
}

bool _Ghost_Remove(CMwStack &in stack) {
    // having ghosts in the paused state can crash the game when removing a ghost
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    return true;
}

bool _Ghost_RemoveAll(CMwStack &in stack) {
    // having ghosts in the paused state can crash the game when removing a ghost
    if (scrubberMgr !is null && !scrubberMgr.unpausedFlag) {
        scrubberMgr.DoUnpause();
        startnew(CoroutineFunc(scrubberMgr.DoPause));
    }
    return true;
}

bool g_BlockNextGhostsSetTimeReset;
bool g_BlockNextGhostsSetTimeAny;
int lastSetStartTime = 5000;
bool _Ghosts_SetStartTime(CMwStack &in stack, CMwNod@ nod) {
    auto ghostStartTime = stack.CurrentInt(0);
    if (g_BlockNextGhostsSetTimeReset && int(ghostStartTime) < 0) {
        warn("blocking ghost SetStartTime reset");
        g_BlockNextGhostsSetTimeReset = false;
        return false;
    }
    if (g_BlockNextGhostsSetTimeAny) {
        warn("blocking ghost SetStartTime any");
        g_BlockNextGhostsSetTimeAny = false;
        return false;
    }

    lastSetStartTime = ghostStartTime;

    if (lastSetStartTime < 0) {
        auto ps = cast<CSmArenaRulesMode>(nod);
        lastSetStartTime = ps.Now;
    }
    // trace('ghost set start time: ' + lastSetStartTime);
    return true;
}

MwId lastSpectatedGhostInstanceId = MwId(uint(-1));
uint lastSpectatedGhostRaceTime = 0;

bool _Spectator_SetForcedTarget_Ghost(CMwStack &in stack) {
    lastSpectatedGhostInstanceId = stack.CurrentId(0);
    auto mgr = GhostClipsMgr::Get(GetApp());
    auto ghost = mgr is null ? null : GhostClipsMgr::GetGhostFromInstanceId(mgr, lastSpectatedGhostInstanceId.Value);
    lastSpectatedGhostRaceTime = (ghost is null) ? 0 : ghost.GhostModel.RaceTime;

    if (ghost !is null) {
        trace('SetForcedTarget_Ghost: ' + (ghost is null ? "null" : string(ghost.GhostModel.GhostNickname)) + " / InstanceId: " + lastSpectatedGhostInstanceId.Value + " / RaceTime: " + lastSpectatedGhostRaceTime);
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
    warn("SetForcedTarget_Clear");
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
}

// ! clip pausing and unpausing moved to GhostClips.as


uint GetCurrentlySpecdGhostInstanceId(CSmArenaRulesMode@ ps) {
    if (ps is null) return 0x0FF00000;
    auto currInstIdOffset = GetOffset("CGamePlaygroundUIConfig", "SpectatorCamAutoLatitude") - 0x14;
    uint instId = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset);
    // 0 none, 1 all players, 2 all map, 3 clan, ? entity, ? landmark, 6 ghost
    uint specFlag = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset - 0x4);
    if (specFlag != 6) {
        log_trace('spec target type == ' + specFlag + ' (not ghost)');
        return 0x0FF00000;
    }
    return instId;
}
