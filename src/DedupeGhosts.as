// Removes duplicate ghosts from the clips manager.
//
// Why here and not in the Ghost_Add intercept: the duplicate personal-best ghosts never
// reach that intercept. Other intercepts on the same class fire normally, and the log
// shows no Ghost_Add activity at all for them, so the game is putting these ghosts into
// the clips system directly rather than through CGameGhostMgrScript. There is no script
// call to intercept, which leaves inspecting the result and correcting it.
//
// Runs on a timer rather than per frame: reaching the clips manager goes through raw
// pointer reads, and per-frame raw memory access is what crashed the game once already.

[Setting category="Ghosts" name="Keep the checkpoint-respawn PB ghost when deduplicating" description="Off by default. When your personal best is loaded twice, the copy kept is the plain one, which spectates and scrubs smoothly. Turn this on to keep the ghost that respawns at checkpoints with you instead -- it stays in sync with your own respawns, which makes it stutter when spectated."]
bool S_DedupeKeepCpGhost = false;

namespace DedupeGhosts {
    // Long enough that map load and any burst of ghost loading has settled, short enough
    // that a duplicate is gone before it is worth complaining about.
    const uint CHECK_INTERVAL_MS = 2000;

    void Coro() {
        while (true) {
            sleep(CHECK_INTERVAL_MS);
            if (!S_PreventDuplicateGhosts) continue;
            if (GetApp().PlaygroundScript is null) continue;
            try {
                RemoveDuplicates();
            } catch {
                log_warn("ghost dedupe pass failed: " + getExceptionInfo());
            }
        }
    }

    /**
     * One pass: group loaded ghosts by login+time and unload all but one of each group.
     *
     * Which one survives matters. The game's own PB ghost is the one that respawns at
     * checkpoints with you, so it is kept in preference to a copy loaded from a
     * leaderboard; otherwise the lowest index wins.
     */
    void RemoveDuplicates() {
        auto app = GetApp();
        auto ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (ps is null || ps.GhostMgr is null) return;
        auto mgr = GhostClipsMgr::Get(app);
        if (mgr is null || mgr.Ghosts.Length < 2) return;

        int pbIx = Ghosts_PP::GetLaunchedCpGhostIx(mgr);

        // The ghost currently being watched is never a candidate for removal.
        //
        // Without this, picking a record in the game's own records UI could focus one copy
        // of a duplicated run and have the next dedupe pass delete that exact copy a second
        // later -- leaving the camera detached with no ghost visible, and only recoverable
        // by spectating something else. Duplicates are a cosmetic annoyance; deleting what
        // someone is watching is not.
        uint specId = uint(-1);
        if (IsSpectatingGhost()) specId = GetCurrentlySpecdGhostInstanceId(ps);

        string[] keys;
        int[] keepIx;
        uint[] removeIds;

        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            auto gm = mgr.Ghosts[i].GhostModel;
            if (gm is null) continue;
            // Identity is login + time. Nickname cannot be used: the game's PB ghost is
            // named "$...Personal best" rather than the player's name, which is why it
            // never matched a leaderboard copy of the same run.
            if (gm.GhostLogin.Length == 0) continue;
            string key = gm.GhostLogin + "|" + gm.RaceTime;

            int at = keys.Find(key);
            if (at < 0) {
                keys.InsertLast(key);
                keepIx.InsertLast(int(i));
                continue;
            }

            // Duplicate. Decide which of the two to drop.
            //
            // Prefer to keep the plain playback copy. The launched-CP PB ghost is the one
            // the game keeps in sync with your own checkpoint respawns, and that sync
            // makes it stutter and wobble when spectated or scrubbed -- an ordinary
            // loaded ghost just replays its recording smoothly.
            //
            // S_DedupeKeepCpGhost flips this for anyone who would rather keep the ghost
            // that respawns with them than the one that spectates cleanly.
            uint loser = i;
            bool keepingCpGhost = (keepIx[at] == pbIx);
            bool thisIsCpGhost = (int(i) == pbIx);
            if (S_DedupeKeepCpGhost ? thisIsCpGhost : (keepingCpGhost && !thisIsCpGhost)) {
                loser = uint(keepIx[at]);
                keepIx[at] = int(i);
            }

            auto loserId = GhostClipsMgr::GetInstanceIdAtIx(mgr, loser);
            // If the copy we would drop is the one being watched, drop the other instead.
            if (specId != uint(-1) && loserId == specId) {
                uint other = (loser == i) ? uint(keepIx[at]) : i;
                auto otherId = GhostClipsMgr::GetInstanceIdAtIx(mgr, other);
                if (otherId == specId) continue; // both resolve to it: leave well alone
                keepIx[at] = int(loser);
                loser = other;
                loserId = otherId;
            }
            removeIds.InsertLast(loserId);
            log_info("dedupe: removing duplicate ghost \"" + mgr.Ghosts[loser].GhostModel.GhostNickname
                + "\" " + Time::Format(mgr.Ghosts[loser].GhostModel.RaceTime)
                + " (login " + mgr.Ghosts[loser].GhostModel.GhostLogin + ", instance "
                + Text::Format("#%08x", loserId) + ")");
        }

        // Removed after the scan, so indices are not invalidated mid-walk.
        for (uint i = 0; i < removeIds.Length; i++) {
            ps.GhostMgr.Ghost_Remove(MwId(removeIds[i]));
        }
        if (removeIds.Length > 0) {
            NotifyWarning("Removed " + removeIds.Length + " duplicate ghost"
                + (removeIds.Length == 1 ? "" : "s") + ".");
        }
    }
}
