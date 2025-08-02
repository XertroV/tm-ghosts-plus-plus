bool g_ShowUnlockTimerPrompt = false;


void DrawUnlockTimelinePromptWindow() {
    if (!g_ShowUnlockTimerPrompt) return;

    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (IsTimerUnlocked(ps)) {
        g_ShowUnlockTimerPrompt = false;
        return;
    }

    if (UI::Begin("G++ Timeline Unlock", g_ShowUnlockTimerPrompt)) {
        UI::TextWrapped("You can unlock the timeline to skip forward in a ghost. \\$f80Experimental.\n\n\\$iNote: The button is disabled while you are driving. Spectate a ghost to enable the unlock button.\n");
        if (IsTimerUnlocked(ps)) {
            if (UI::Button("Close Window")) {
                g_ShowUnlockTimerPrompt = false;
            }
        } else {
            if (DrawUnlockTimelineButton(ps)) {
                g_ShowUnlockTimerPrompt = false;
            }
        }
        // UI::Separator();
        // S_AutoUnlockTimelineSolo = UI::Checkbox("Automatically unlock the timeline in Solo", S_AutoUnlockTimelineSolo);
        UI::Separator();
        S_SuppressUnlockTimelinePrompt = UI::Checkbox("Don't remind me again?", S_SuppressUnlockTimelinePrompt);
    }
    UI::End();
}

bool DrawUnlockTimelineButton(CSmArenaRulesMode@ ps) {
    // disable while player is driving to avoid changing race duration.
    UI::BeginDisabled(IsTimerUnlocked(ps) || IsPlayerDriving());
    auto ret = UI::Button("Unlock Timeline");
    if (ret) {
        UnlockPlaygroundTimer(ps);
    }
    UI::EndDisabled();
    return ret;
}

void CheckUpdateAutoUnlockTimelineSolo(CSmArenaRulesMode@ ps, CGameCtnEditor@ editor) {
    if (!S_AutoUnlockTimelineSolo) return;
    if (ps is null) return;
    if (editor !is null) return;
    if (IsTimerUnlocked(ps)) return;
    if (ps.UIManager.UIAll.UISequence == 0) return; // Seq == None
    if (ps.UIManager.UIAll.UISequence == CGamePlaygroundUIConfig::EUISequence::Finish) return;
    if (ps.UIManager.UIAll.UISequence == CGamePlaygroundUIConfig::EUISequence::UIInteraction) return;
    if (ps.UIManager.UIAll.UISequence == CGamePlaygroundUIConfig::EUISequence::EndRound) return;
    if (IsPlayerDriving()) return;
    if (!IsSpectatingGhost(ps)) return;
    if (int(ps.Now) < 0) return;
    if (ps.Now < 3500) return;
    // log_info("[PRE ] Auto-unlocking timeline; ps.Now: " + ps.Now + "; ps.StartTime: " + ps.StartTime + "; ps.UIManager.UIAll.UISequence: " + ps.UIManager.UIAll.UISequence);
    log_info("Auto-unlocking timeline; ps.Now: " + ps.Now + "; ps.StartTime: " + ps.StartTime + "; ps.UIManager.UIAll.UISequence: " + ps.UIManager.UIAll.UISequence);
    UnlockPlaygroundTimer(ps);
    startnew(ManuallyAdvanceScrubberAfterAutoUnlock);
#if DEV
    // UI::ShowNotification("Timeline unlocked!", "The timeline has been unlocked automatically.");
#endif
}

bool _MASAAU_Running = false;
void ManuallyAdvanceScrubberAfterAutoUnlock() {
    if (_MASAAU_Running) return;
    _MASAAU_Running = true;
    // wait a few frames for stuff to happen
    yield(5);

    // set _MASAAU_Running false before maybe returning
    _MASAAU_Running = false;
    if (scrubberMgr is null) return;
    _MASAAU_Running = true;

    // wait for scrubber to show that it's working
    double startProg = scrubberMgr.pauseAt;
    double prog = 0.0;
    scrubberMgr.SetProgress(prog);
    uint i = 0;
    for (; i < 100; i++) {
        yield();
        if (scrubberMgr is null) return;
        if (scrubberMgr.pauseAt > 200.0 && scrubberMgr.pauseAt > prog && scrubberMgr.pauseAt != startProg) {
            dev_trace("ManuallyAdvanceScrubberAfterAutoUnlock:breaking since pauseAt advanced: " + scrubberMgr.pauseAt);
            break;
        }
        UpdateMaxScrubberTime();
        scrubberMgr.SetProgress((prog += g_DT), false);
        if (i > 20 && prog > 1000.0) break; // don't timeout without at least 10 iters
    }
    _MASAAU_Running = false;
    dev_trace("ManuallyAdvanceScrubberAfterAutoUnlock: i=" + i + ", after auto-unlock; scrubberMgr.pauseAt: " + scrubberMgr.pauseAt + "; prog: " + prog + "; startProg: " + startProg);
}
