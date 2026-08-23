// Per-checkpoint split times for loaded ghosts, and comparison between them.
//
// Deliberately does not use Ghosts_PP::GetGhostCheckpoints(). That builds an array of
// CheckpointIxTime, which is a *shared* class, and appending an object bound to a shared
// type to an array is the operation that crashes the game in the input parser. Until that
// is understood, nothing new is built on the same pattern -- these are plain classes.
//
// The checkpoint buffer offset is measured, not assumed: NbRespawns + 0x8, confirmed by
// the ghost struct dump on build 2026-02-02_17_51 (len=5 on a 4-checkpoint map: four
// checkpoints plus the finish).

/** One checkpoint crossing. Plain class -- see the note above. */
class GhostSplit {
    int cpIndex;
    int time;
    GhostSplit(int cpIndex, int time) {
        this.cpIndex = cpIndex;
        this.time = time;
    }
}

/** Splits for one ghost, with the identity needed to label and compare it. */
class GhostSplits {
    string nickname;
    string login;
    int raceTime;
    uint instanceId;
    GhostSplit@[] splits;

    GhostSplits(const string &in nickname, const string &in login, int raceTime, uint instanceId) {
        this.nickname = nickname;
        this.login = login;
        this.raceTime = raceTime;
        this.instanceId = instanceId;
    }

    /** Cumulative time at a checkpoint index, or -1 if this ghost has no such split. */
    int TimeAt(uint ix) {
        if (ix >= splits.Length) return -1;
        return splits[ix].time;
    }
}

// A run has a checkpoint per lap-gate plus the finish; anything past this is a misread
// rather than a real ghost.
const uint MAX_GHOST_CHECKPOINTS = 512;

/**
 * Reads a ghost's checkpoint times.
 *
 * Walks raw game structures, so it is called on demand and cached -- never per frame.
 */
GhostSplits@ ReadGhostSplits(NGameGhostClips_SClipPlayerGhost@ clipGhost, uint instanceId) {
    if (clipGhost is null) return null;
    auto gm = clipGhost.GhostModel;
    if (gm is null) return null;
    Compat::Require("ghost-checkpoints");

    auto res = GhostSplits(gm.GhostNickname, gm.GhostLogin, int(gm.RaceTime), instanceId);
    auto cps = DGameCtnGhost(gm).Checkpoints;
    uint n = cps.Length;
    if (n == 0 || n > MAX_GHOST_CHECKPOINTS) return res;
    for (uint i = 0; i < n; i++) {
        auto cp = cps.GetCP(i);
        res.splits.InsertLast(GhostSplit(cp.cpIndex, cp.cpTime));
    }
    return res;
}

/**
 * Splits for every currently loaded ghost.
 *
 * Returns an empty array rather than throwing when the capability is unavailable, so UI
 * code can simply show nothing.
 */
GhostSplits@[]@ ReadAllGhostSplits() {
    GhostSplits@[] all;
    if (!Compat::Available("ghost-checkpoints")) return all;
    auto mgr = GhostClipsMgr::Get(GetApp());
    if (mgr is null) return all;
    for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        try {
            auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
            auto gs = ReadGhostSplits(mgr.Ghosts[i], id);
            if (gs !is null) all.InsertLast(gs);
        } catch {
            log_warn("reading splits for ghost " + i + " failed: " + getExceptionInfo());
        }
    }
    return all;
}
