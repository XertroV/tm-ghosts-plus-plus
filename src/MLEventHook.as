class ResetHook : MLHook::HookMLEventsByType {
    ResetHook() {
        super("RaceMenuEvent_NextMap");
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        if (scrubberMgr !is null) {
            scrubberMgr.ResetAll();
        }
    }
}

class SpectateHook : MLHook::HookMLEventsByType {
    SpectateHook() {
        super("TMGame_Record_Spectate");
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        startnew(CoroutineFuncUserdata(this.AfterSpectate), event);
    }

    uint lastLoadSpectate = Time::Now;
    string lastLoadWsid = "";
    void AfterSpectate(ref@ r) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return;

        auto mgr = GhostClipsMgr::Get(GetApp());
        auto nbGhosts = mgr.Ghosts.Length;

        auto event = cast<MLHook::PendingEvent>(r);
        if (event.data.Length < 1) return;
        string wsid = event.data[0];
        if (wsid.Length != 36) return;

        if (IsSpectatingGhost()) {
            auto currSpecId = GetCurrentlySpecdGhostInstanceId(ps);
            NGameGhostClips_SClipPlayerGhost@ g = GhostClipsMgr::GetGhostFromInstanceId(mgr, currSpecId);
            if (g !is null) {
                if (LoginToWSID(g.GhostModel.GhostLogin) == wsid) {
                    // we want to unspectate this player, but not load a ghost.
                    sleep(100);
                    ExitSpectatingGhost();
                    if (scrubberMgr !is null) scrubberMgr.ResetAll();
                    return;
                }
            }
        }

        @mgr = null;

        if (Time::Now - lastLoadSpectate <= 100 && lastLoadWsid == wsid) return;

        lastLoadSpectate = Time::Now;
        lastLoadWsid = wsid;

        // since we got a request to spectate a ghost, we want to undo that and manage it ourselves
        // wait a bit to give ML time to process request
        sleep(100);

        // this abadons the load + spectate ghost request on ML size
        ExitSpectatingGhost();
        // while (GetApp().PlaygroundScript !is null && mgr.Ghosts.Length == nbGhosts) yield();
        Cache::LoadGhostsForWsids({wsid}, CurrentMap);
        // ghost was added
        auto mgr2 = GhostClipsMgr::Get(GetApp());
        auto ps2 = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (mgr2 is null || ps2 is null) return;

        if (scrubberMgr !is null) {
            scrubberMgr.ResetAll();
            // scrubberMgr.SetProgress(0);
            // scrubberMgr.SetPlayback();
        }

        for (uint i = nbGhosts; i < mgr2.Ghosts.Length; i++) {
            if (wsid == LoginToWSID(mgr2.Ghosts[i].GhostModel.GhostLogin)) {
                g_SaveGhostTab.SpectateGhost(i);
                return;
            }
        }
        // test from 0 now instead of nbGhosts
        for (uint i = 0; i < mgr2.Ghosts.Length; i++) {
            if (wsid == LoginToWSID(mgr2.Ghosts[i].GhostModel.GhostLogin)) {
                g_SaveGhostTab.SpectateGhost(i);
                return;
            }
        }
    }
}

void Update_ML_SetSpectateID(const string &in wsid) {
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetSpectating", wsid});
}

void Update_ML_SetGhostLoading(const string &in wsid) {
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostLoading", wsid});
}

void Update_ML_SetGhostLoaded(const string &in wsid) {
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostLoaded", wsid});
}

void Update_ML_SetGhostUnloaded(const string &in wsid) {
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostUnloaded", wsid});
}
