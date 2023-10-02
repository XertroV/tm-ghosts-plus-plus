NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
    if (app.GameScene is null) return null;
    auto nod = Dev::GetOffsetNod(app.GameScene, 0x120);
    if (nod is null) return null;
    return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
}

namespace GhostClipsMgr {
    NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
        return GetGhostClipsMgr(app);
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
}
