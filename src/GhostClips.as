NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
    if (app.GameScene is null) return null;
    auto nod = Dev::GetOffsetNod(app.GameScene, 0x120);
    if (nod is null) return null;
    return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
}

namespace GhostClipsMgr {
    const uint16 GhostsOffset = GetOffset("NGameGhostClips_SMgr", "Ghosts");
    const uint16 GhostInstIdsOffset = GhostsOffset + 0x10;

    NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
        return GetGhostClipsMgr(app);
    }

    uint GetMaxGhostDuration(CGameCtnApp@ app) {
        return GetMaxGhostDuration(GhostClipsMgr::Get(app));
    }
    uint GetMaxGhostDuration(NGameGhostClips_SMgr@ mgr) {
        uint maxTime = 0;
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            maxTime = Math::Max(mgr.Ghosts[i].GhostModel.RaceTime, maxTime);
        }
        return maxTime;
    }

    NGameGhostClips_SClipPlayerGhost@ Find(NGameGhostClips_SMgr@ mgr, uint32 entUid) {
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            auto @pghost = mgr.Ghosts[i];
            if (Dev::GetOffsetUint32(pghost, 0x0) == entUid) {
                return pghost;
            }
        }
        return null;
    }

    NGameGhostClips_SClipPlayerGhost@ Find(NGameGhostClips_SMgr@ mgr, const string &in loginOrName) {
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            auto @pghost = mgr.Ghosts[i];
            if (pghost.GhostModel.GhostLogin == loginOrName || pghost.GhostModel.GhostNickname == loginOrName) {
                return pghost;
            }
        }
        return null;
    }

    uint GetInstanceIdAtIx(NGameGhostClips_SMgr@ mgr, uint ix) {
        if (mgr is null) return uint(-1);
        auto bufOffset = GhostInstIdsOffset;
        auto bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
        auto nextIdOrSomething = Dev::GetOffsetUint32(mgr, bufOffset + 0x8);
        auto bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
        auto bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);

        if (bufLen == 0 || bufCapacity == 0) return uint(-1);

        // A bunch of trial and error to figure this out >.<
        if (bufLen <= ix) return uint(-1);
        if (bufPtr == 0 or bufPtr % 8 != 0) return uint(-1);
        auto slot = Dev::ReadUInt32(bufPtr + (bufCapacity*4) + ix * 4);
        auto msb = Dev::ReadUInt32(bufPtr + slot * 4) & 0xFF000000;
        return msb + slot;

        // auto lsb = Dev::ReadUInt32(bufPtr + slot * 4) & 0x00FFFFFF;
        // if (lsb >= bufCapacity) {
        //     warn('lsb outside expected range: ' + lsb + " should be < " + bufCapacity);
        // }
        // auto msb = Dev::ReadUInt32(bufPtr + (bufCapacity*4*2) + slot * 4) & 0xFF000000;
        // trace('msb: ' + msb);
    }

    NGameGhostClips_SClipPlayerGhost@ GetGhostFromInstanceId(NGameGhostClips_SMgr@ mgr, uint instanceId) {
        auto lsb = instanceId & 0x00FFFFFF;
        auto bufOffset = GhostInstIdsOffset;
        // auto bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
        // auto nextIdOrSomething = Dev::GetOffsetUint32(mgr, bufOffset + 0x8);
        // auto bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
        auto bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);
        if (lsb > bufCapacity) {
            warn('unexpectedly high ghost instance ID');
            return null;
        }
        for (uint i = 0; i < bufCapacity; i++) {
            if (GetInstanceIdAtIx(mgr, i) == instanceId) {
                return mgr.Ghosts[i];
            }
        }
        return null;
    }

    // this is the result of the last call to Ghosts_SetStartTime
    uint GetCurrentGhostTime(NGameGhostClips_SMgr@ mgr) {
        if (mgr.Ghosts.Length == 0) return uint(-1);
        auto clipPlayer = GetMainClipPlayer(mgr);
        if (clipPlayer is null) {
            @clipPlayer = GetPBClipPlayer(mgr);
        }
        if (clipPlayer is null) {
            warn("no loaded ghosts");
            return uint(-1);
        }
        // this nod is 0x350 bytes large => memory will always be allocated
        return Dev::GetOffsetUint32(clipPlayer, 0x320);
    }

    void PauseClipPlayers(NGameGhostClips_SMgr@ mgr, float currTime) {
        SetGhostClipPlayerPaused(GetMainClipPlayer(mgr), currTime);
        SetGhostClipPlayerPaused(GetPBClipPlayer(mgr), currTime);
    }

    void UnpauseClipPlayers(NGameGhostClips_SMgr@ mgr, float currTime, float totalTime) {
        SetGhostClipPlayerUnpaused(GetMainClipPlayer(mgr), currTime, totalTime);
        SetGhostClipPlayerUnpaused(GetPBClipPlayer(mgr), currTime, totalTime);
    }
    // if total time is not provided, then the current values are used.
    void UnpauseClipPlayers(NGameGhostClips_SMgr@ mgr, float currTime) {
        auto tmp = GetMainClipPlayer(mgr);
        if (tmp is null) @tmp = GetPBClipPlayer(mgr);
        if (tmp is null) return;
        auto totalTime = ClipPlayer_GetTotalTime(tmp);
        SetGhostClipPlayerUnpaused(GetMainClipPlayer(mgr), currTime, totalTime);
        SetGhostClipPlayerUnpaused(GetPBClipPlayer(mgr), currTime, totalTime);
    }

    // all ghosts but 1 PB ghost, null if there are no ghosts
    CGameCtnMediaClipPlayer@ GetMainClipPlayer(NGameGhostClips_SMgr@ mgr) {
        return cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x20));
    }

    // One ghost only, always PB (PBs can also be in the other clip player tho too). Can be null if you unload PB ghosts
    CGameCtnMediaClipPlayer@ GetPBClipPlayer(NGameGhostClips_SMgr@ mgr) {
        return cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x40));
    }

    vec2 AdvanceClipPlayersByDelta(NGameGhostClips_SMgr@ mgr, float playbackSpeed = 1.0) {
        auto ret = ClipPlayer_AdvanceByDelta(GetPBClipPlayer(mgr), playbackSpeed);
        auto mainClip = GetMainClipPlayer(mgr);
        if (mainClip !is null) {
            ret = ClipPlayer_AdvanceByDelta(mainClip, playbackSpeed);
        }
        return ret;
    }
}

// Utils for CGameCtnMediaClipPlayer

float ClipPlayer_GetCurrSeconds(CGameCtnMediaClipPlayer@ player) {
    return Dev::GetOffsetFloat(player, 0x1AC);
}

void ClipPlayer_SetCurrSeconds(CGameCtnMediaClipPlayer@ player, float t) {
    Dev::SetOffset(player, 0x1AC, t);
}

float ClipPlayer_GetFrameDelta(CGameCtnMediaClipPlayer@ player) {
    return Dev::GetOffsetFloat(player, 0x310);
}

float ClipPlayer_GetTotalTime(CGameCtnMediaClipPlayer@ player) {
    return Dev::GetOffsetFloat(player, 0x338);
}

// returns vec2(time, delta)
vec2 ClipPlayer_AdvanceByDelta(CGameCtnMediaClipPlayer@ player, float playbackSpeed = 1.0) {
    if (player is null) return vec2();
    auto d = ClipPlayer_GetFrameDelta(player) * playbackSpeed;
    auto t = ClipPlayer_GetCurrSeconds(player) + d;
    ClipPlayer_SetCurrSeconds(player, t);
    return vec2(t, d);
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
