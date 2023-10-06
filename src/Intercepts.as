void SetupIntercepts() {
    Dev::InterceptProc("CSmArenaRulesMode", "Ghosts_SetStartTime", _Ghosts_SetStartTime);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_Add", _Ghost_Add);
    Dev::InterceptProc("CGameGhostMgrScript", "Ghost_Remove", _Ghost_Remove);
    Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Ghost", _Spectator_SetForcedTarget_Ghost);
    Dev::InterceptProc("CGameScriptHandlerPlaygroundInterface", "CloseInGameMenu", _CGSHPI_CloseInGameMenu);
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

    // an attempt to get the end of ghosts to load faster than normal -- didn't work
    // auto ps = GetApp().PlaygroundScript;
    // if (ps !is null) {
    //     auto gm = cast<CGameGhostMgrScript>(nod);
    //     auto ghost = cast<CGameGhostScript>(stack.CurrentNod(1));
    //     auto ghostLayer = stack.CurrentBool(0);
    //     if (ghost !is null) {
    //         lastLoadedGhostRaceTime = ghost.Result.Time;
    //         trace('Ghost_Add: ' + (ghost is null ? "null" : string(ghost.Nickname)) + " / RaceTime: " + lastLoadedGhostRaceTime);
    //         ghostAddSkipIntercept = true;
    //         auto instId = gm.Ghost_Add(ghost, ghostLayer, ghost.Result.Time - 60000);
    //         // gm.Ghost_Remove(instId);
    //         ghostAddSkipIntercept = false;
    //     }
    // }

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

int lastSetStartTime = 5000;
bool _Ghosts_SetStartTime(CMwStack &in stack, CMwNod@ nod) {
    lastSetStartTime = stack.CurrentInt(0);
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
