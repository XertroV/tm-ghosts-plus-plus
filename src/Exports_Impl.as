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

    // PB ghost that respawns at CPs with you; returns -1 if null issue or not found
    int GetLaunchedCpGhostIx(NGameGhostClips_SMgr@ mgr) {
        if (mgr is null) return -1;
        auto pbClip = GhostClipsMgr::GetPBClipPlayer(mgr);
        if (pbClip is null || pbClip.Clip is null) return -1;
        auto clip = pbClip.Clip;
        if (clip.Tracks.Length == 0) return -1;

        // this track will let us identify the ghost.
        auto pbTrack = clip.Tracks[0];

        auto nbGhosts = mgr.Ghosts.Length;
        for (uint i = 0; i < nbGhosts; i++) {
            auto ghost = mgr.Ghosts[i];
            auto track = ghost.Clip.Tracks[0];
            if (track is pbTrack) {
                return int(i);
            }
        }
        return -1;
    }

    // PB ghost that respawns at CPs with you; returns -1 if null issue or not found
    int GetLaunchedCpGhostInstanceId(NGameGhostClips_SMgr@ mgr) {
        auto ix = GetLaunchedCpGhostIx(mgr);
        if (ix > -1) return int(GhostClipsMgr::GetInstanceIdAtIx(mgr, ix));
        return -1;
    }

    // PB ghost that respawns at CPs with you
    NGameGhostClips_SClipPlayerGhost@ GetLaunchedCpGhost(NGameGhostClips_SMgr@ mgr) {
        auto ix = GetLaunchedCpGhostIx(mgr);
        if (ix <= -1) return null;
        return mgr.Ghosts[ix];
    }
}
