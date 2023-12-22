namespace Ghosts_PP {
    void Call_Ghosts_SetStartTime(CSmArenaRulesMode@ ps, uint startTime) {
        ::Call_Ghosts_SetStartTime(ps, startTime);
    }

    // unfortunately can't make these const b/c things like `.RaceTime` are non-const
    // require app so GetApp() must be used.
    array<CGameCtnGhost@>@ GetCurrentGhosts(CGameCtnApp@ app) {
        auto mgr = GhostClipsMgr::Get(app);
        if (mgr is null) return null;
        array<CGameCtnGhost@> ghosts;
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            ghosts.InsertLast(mgr.Ghosts[i].GhostModel);
        }
        return ghosts;
    }

    bool IsSpectatingGhost() {
        return ::IsSpectatingGhost();
    }
    uint GetSpectatingGhostInstanceId(CGameCtnApp@ app) {
        return GetCurrentlySpecdGhostInstanceId(cast<CSmArenaRulesMode>(app.PlaygroundScript));
    }
    NGameGhostClips_SClipPlayerGhost@ GetGhostFromInstanceId(CGameCtnApp@ app, uint instanceId) {
        auto mgr = GhostClipsMgr::Get(app);
        if (mgr is null) return null;
        return GhostClipsMgr::GetGhostFromInstanceId(mgr, instanceId);
    }
    uint GetGhostVisEntityId(NGameGhostClips_SClipPlayerGhost@ g) {
        if (g is null) return 0x0FF00000;
        return Dev::GetOffsetUint32(g, 0x0);
    }
}
