void SetupIntercepts() {
    Dev::InterceptProc("CSmArenaRulesMode", "Ghosts_SetStartTime", _Ghosts_SetStartTime);
    Dev::InterceptProc("CGamePlaygroundUIConfig", "Spectator_SetForcedTarget_Ghost", _Spectator_SetForcedTarget_Ghost);
}


uint lastSetStartTime;
bool _Ghosts_SetStartTime(CMwStack &in stack) {
    lastSetStartTime = stack.CurrentInt(0);
    trace('ghost set start time: ' + lastSetStartTime);
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


// 0x1ac - float time
// 0x1b0 - some scaling thing? 1.0 normally
// 0x310, delta?
// 0x314, ?
// 0x318 - time speed
// 0x324 - flag 2?
  // set to 0 (1 does motion interpolation or something)
// 0x328 - flag? (test rdx,rdx)
// 0x330 - test
// --- both above pass then
// 0x338 - total len
// 0x33c - time speed
// 0x340 - time float
// 0x348 - flag 1? (nonzero)
  // set to 1? (invis if not f2 also 1)
  // hides other ghosts?
// 0x364 - apply custom time?
// set 0x1b0 to -1?

// load tiem speed, mov to xmm2, mulss x2 x0, mulss x2 0x1b0 (scaling), addss 0x340 (time)


// set 338 to -100
// set 324 to 0
// set 348 to 1
// set 1ac to set the position of the ghost
// set 33c > 0


string[] GetGhostClipPlayerDebugValues(CGameCtnMediaClipPlayer@ player) {
    if (player is null) return {"not found"};
    float totalTime = Dev::GetOffsetFloat(player, 0x338);
    float curTime = Dev::GetOffsetFloat(player, 0x1AC);
    uint8 doMotionInterp = Dev::GetOffsetUint8(player, 0x324);
    uint8 otherGhostsVisible = Dev::GetOffsetUint8(player, 0x348);
    float timeSpeed_33C = Dev::GetOffsetFloat(player, 0x33C);
    float timeSpeed_318 = Dev::GetOffsetFloat(player, 0x318);
    float timeSpeed_1B0 = Dev::GetOffsetFloat(player, 0x1B0);
    return {tostring(totalTime), tostring(curTime), tostring(doMotionInterp), tostring(otherGhostsVisible), "1B0: " + timeSpeed_1B0, "318: " + timeSpeed_318, "33C: " + timeSpeed_33C};
}

void SetGhostClipPlayerPaused(CGameCtnMediaClipPlayer@ player, float timestamp) {
    if (player is null) return;
    Dev::SetOffset(player, 0x1AC, timestamp);
    Dev::SetOffset(player, 0x338, float(-100.0));
    Dev::SetOffset(player, 0x324, uint8(0));
    Dev::SetOffset(player, 0x348, uint8(1));
    Dev::SetOffset(player, 0x33C, float(1.0));
}

void SetGhostClipPlayerUnpaused(CGameCtnMediaClipPlayer@ player, float timestamp, float totalTime) {
    if (player is null) return;
    Dev::SetOffset(player, 0x1AC, timestamp);
    Dev::SetOffset(player, 0x338, float(totalTime));
    Dev::SetOffset(player, 0x324, uint8(1));
    Dev::SetOffset(player, 0x348, uint8(1));
    Dev::SetOffset(player, 0x33C, uint32(0));
}
