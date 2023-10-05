void SetupIntercepts() {
    Dev::InterceptProc("CSmArenaRulesMode", "Ghosts_SetStartTime", _Ghosts_SetStartTime);
    Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Ghost", _Spectator_SetForcedTarget_Ghost);
}


uint lastSetStartTime;
bool _Ghosts_SetStartTime(CMwStack &in stack) {
    lastSetStartTime = stack.CurrentInt(0);
    // trace('ghost set start time: ' + lastSetStartTime);
    return true;
}

MwId lastSpectatedGhostInstanceId = MwId(-1);
uint lastSpectatedGhostRaceTime = 60000;

bool _Spectator_SetForcedTarget_Ghost(CMwStack &in stack) {
    lastSpectatedGhostInstanceId = stack.CurrentId(0);
    auto mgr = GhostClipsMgr::Get(GetApp());
    auto ghost = mgr is null ? null : GhostClipsMgr::GetGhostFromInstanceId(mgr, lastSpectatedGhostInstanceId.Value);
    lastSpectatedGhostRaceTime = (ghost is null)  ? 60000 : ghost.GhostModel.RaceTime;
    if (ghost !is null) {
        trace('SetForcedTarget_Ghost: ' + (ghost is null ? "null" : string(ghost.GhostModel.GhostNickname)) + " / InstanceId: " + lastSpectatedGhostInstanceId.Value + " / RaceTime: " + lastSpectatedGhostRaceTime);
    }
    return true;
}


// update values set by intercepts
void SetCurrentGhostValues() {
    auto app = cast<CTrackMania>(GetApp());
    auto ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
    if (ps is null) return;
    if (!ps.UIManager.UIAll.ForceSpectator) return;
    trace('Setting current ghost values (if non null)');
    auto currInstIdOffset = GetOffset("CGamePlaygroundUIConfig", "SpectatorCamAutoLatitude") - 0x14;
    uint instId = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset);
    // 0 none, 1 all players, 2 all map, 3 clan, ? entity, ? landmark, 6 ghost
    uint specFlag = Dev::GetOffsetUint32(ps.UIManager.UIAll, currInstIdOffset - 0x4);
    if (specFlag != 6) {
        trace('spec target type == ' + specFlag + ' (not ghost)');
        return;
    }
    trace('current spectating instId: ' + instId);

    // if (instId == 0) return;
    auto mgr = GhostClipsMgr::Get(GetApp());
    auto ghost = GhostClipsMgr::GetGhostFromInstanceId(mgr, instId);
    if (ghost !is null) {
        lastSpectatedGhostInstanceId = instId;
        lastSpectatedGhostRaceTime = ghost.GhostModel.RaceTime;
        lastSetStartTime = GhostClipsMgr::GetCurrentGhostTime(mgr);
        trace('Set current ghost values: ' + lastSetStartTime + ' / ' + lastSpectatedGhostRaceTime + ' / ' + Text::Format("%08x", instId));
    }
}

// ! clip pausing and unpausing moved to GhostClips.as
