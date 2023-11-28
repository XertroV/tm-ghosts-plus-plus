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

class ToggleHook : MLHook::HookMLEventsByType {
    ToggleHook() {
        super("TMGame_Record_ToggleGhost");
        startnew(CoroutineFunc(this.ClearDebounce)).WithRunContext(Meta::RunContext::BeforeScripts);
    }

    dictionary debounceToggles;
    void ClearDebounce() {
        while (true) {
            yield();
            debounceToggles.DeleteAll();
        }
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        log_debug('got event: ' + event.type);
        if (event.type.EndsWith("PB")) {
            OnTogglePB();
        } else {
            startnew(CoroutineFuncUserdataString(OnToggleGhost), event.data[0]);
        }
    }

    void OnTogglePB() {

    }

    void OnToggleGhost(const string &in wsid) {
        if (debounceToggles.Exists(wsid)) return;
        debounceToggles[wsid] = true;
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;

        if (!ghostWsidsLoaded.Exists(wsid)) {
            // then we are adding it
            // Update_ML_SetGhostLoading(wsid);
            // log_debug("DEBUG toggling ghost loading: " + wsid);
            yield();
            startnew(Update_ML_SyncAll);
            return;
        }
        log_debug("DEBUG on toggle ghost: " + wsid);
        // we want to find the fastest ghost with this WSID so we can remove all instances of it
        int bestTime = -1;
        int[] bestIds;
        string login = WSIDToLogin(wsid);
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            auto g = mgr.Ghosts[i].GhostModel;
            if (g.GhostLogin != login) continue;
            if (bestTime < 0 || int(g.RaceTime) < bestTime) {
                bestIds.RemoveRange(0, bestIds.Length);
                bestIds.InsertLast(GhostClipsMgr::GetInstanceIdAtIx(mgr, i));
            } else if (int(g.RaceTime) == bestTime) {
                bestIds.InsertLast(GhostClipsMgr::GetInstanceIdAtIx(mgr, i));
            }
        }
        // now remove all ghosts at these ixs but do it backwards
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        for (int i = bestIds.Length - 1; i >= 0; i--) {
            ps.GhostMgr.Ghost_Remove(bestIds[i]);
        }
        Update_ML_SetGhostUnloaded(wsid);
        yield();
        startnew(Update_ML_SyncAll);
    }

    /**
     * research re finding ghost offset
     * from CPlugEntRecordData (0x911f000): 0x40,0x10
     *
     */
}

class SpectateHook : MLHook::HookMLEventsByType {
    SpectateHook() {
        super("TMGame_Record_Spectate");
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        print("TMGame_Record_Spectate: " + event.data[0]);
        startnew(CoroutineFuncUserdata(this.AfterSpectate), event);
    }

    uint lastLoadSpectate = Time::Now;
    string lastLoadWsid = "";
    void AfterSpectate(ref@ r) {
        if (g_SaveGhostTab is null) warn("AfterSpectate got null g_SaveGhostTab?!");
        else g_SaveGhostTab.StartWatchGhostsLoopLoop();

        return;

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
                // we want to unspectate this player, but not load a ghost.
                if (LoginToWSID(g.GhostModel.GhostLogin) == wsid) {
                    // sleep(100);
                    // ExitSpectatingGhost();
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
        // sleep(100);

        // this abadons the load + spectate ghost request on ML size; we then want to re-spectate the ghost
        auto currSpec = GetCurrentlySpecdGhostInstanceId(ps);
        if (IsSpectatingGhost()) {
            // g_BlockNextGhostsSetTimeReset = true;
            g_BlockNextGhostsSetTimeAny = true;
            g_BlockNextClearForcedTarget = true;
        }
        // ExitSpectatingGhost();


        // while (GetApp().PlaygroundScript !is null && mgr.Ghosts.Length == nbGhosts) yield();
        // Cache::LoadGhostsForWsids({wsid}, CurrentMap);
        // ghost was added
        auto mgr2 = GhostClipsMgr::Get(GetApp());
        auto ps2 = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (mgr2 is null || ps2 is null) return;

        // return;
        // if (scrubberMgr !is null) {
        //     scrubberMgr.ResetAll();
        // }

        for (uint i = nbGhosts; i < mgr2.Ghosts.Length; i++) {
            if (mgr2.Ghosts[i].GhostModel.GhostNickname.StartsWith("$")) continue;
            if (wsid == LoginToWSID(mgr2.Ghosts[i].GhostModel.GhostLogin)) {
                g_SaveGhostTab.SpectateGhost(i);
                return;
            }
        }
        // test from 0 now instead of nbGhosts
        for (uint i = 0; i < mgr2.Ghosts.Length; i++) {
            if (mgr2.Ghosts[i].GhostModel.GhostNickname.StartsWith("$")) continue;
            if (wsid == LoginToWSID(mgr2.Ghosts[i].GhostModel.GhostLogin)) {
                g_SaveGhostTab.SpectateGhost(i);
                return;
            }
        }

        g_AllowNextForceGhostDespiteNowBlock = true;

        // otherwise keep current spec
        // startnew(CoroutineFuncUserdataUint64(this.FindAndSpec), uint64(currSpec));
    }

    // disabled / unused
    void FindAndSpec(uint64 instId64) {
        return;
        // yield();
        // yield();
        // yield();
        yield();
        auto id = uint(instId64);
        print("find inst id: " + id);
        if (id == 0x0FF00000) return;
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        // scrubberMgr.SetProgress(lastExitPauseAt);
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            if (GhostClipsMgr::GetInstanceIdAtIx(mgr, i) == id) {
                g_SaveGhostTab.SpectateGhost(i);
                print('inst id found at ix: ' + i);
                return;
            }
        }
        print('inst id not found');
    }
}

// disable this for now,
void Update_ML_SetSpectateID(const string &in wsid) {
    // MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetSpectating", wsid});
}

dictionary ghostWsidsLoading;
dictionary ghostWsidsLoaded;

void Update_ML_SetGhostLoading(const string &in wsid) {
    if (ghostWsidsLoaded.Exists(wsid)) ghostWsidsLoaded.Delete(wsid);
    ghostWsidsLoading[wsid] = true;
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostLoading", wsid});
}

void Update_ML_SetGhostLoaded(const string &in wsid) {
    if (ghostWsidsLoading.Exists(wsid)) ghostWsidsLoading.Delete(wsid);
    ghostWsidsLoaded[wsid] = true;
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostLoaded", wsid});
}

void Update_ML_SetGhostUnloaded(const string &in wsid) {
    if (ghostWsidsLoaded.Exists(wsid)) ghostWsidsLoaded.Delete(wsid);
    MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostUnloaded", wsid});
}

void Update_ML_SyncAll() {
    ghostWsidsLoaded.DeleteAll();
    auto mgr = GhostClipsMgr::Get(GetApp());
    if (mgr is null) return;
    for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        auto g = mgr.Ghosts[i].GhostModel;
        if (g.GhostNickname.StartsWith("$")) continue;
        auto wsid = LoginToWSID(g.GhostLogin);
        ghostWsidsLoaded[wsid] = true;
    }
    auto wsids = ghostWsidsLoaded.GetKeys();
    for (uint i = 0; i < wsids.Length; i++) {
        Update_ML_SetGhostLoaded(wsids[i]);
    }
}
