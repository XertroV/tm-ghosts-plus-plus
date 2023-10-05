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
