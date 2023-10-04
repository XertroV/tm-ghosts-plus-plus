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
        if (mgr.Ghosts.Length == 0) return -1;
        auto clipPlayer = cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, GhostsOffset - 0x30));
        if (clipPlayer is null) {
            @clipPlayer = cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, GhostsOffset - 0x10));
        }
        if (clipPlayer is null) {
            warn("unexpected clip player null");
            return -1;
        }
        // this nod is 0x350 bytes large => memory will always be allocated
        return Dev::GetOffsetUint32(clipPlayer, 0x320);
    }

    void PauseClipPlayers(NGameGhostClips_SMgr@ mgr, float currTime) {
        SetGhostClipPlayerPaused(cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x20)), currTime);
        SetGhostClipPlayerPaused(cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x40)), currTime);
    }

    void UnpauseClipPlayers(NGameGhostClips_SMgr@ mgr, float currTime, float totalTime) {
        SetGhostClipPlayerUnpaused(cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x20)), currTime, totalTime);
        SetGhostClipPlayerUnpaused(cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x40)), currTime, totalTime);
    }
}
