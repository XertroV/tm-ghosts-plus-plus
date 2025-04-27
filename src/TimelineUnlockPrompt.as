bool g_ShowUnlockTimerPrompt = false;


void DrawUnlockTimelinePromptWindow() {
    if (!g_ShowUnlockTimerPrompt) return;

    if (UI::Begin("G++ Timeline Unlock", g_ShowUnlockTimerPrompt)) {
        UI::TextWrapped("You can unlock the timeline to skip forward in a ghost. \\$f80Experimental.\n\n\\$iNote: The button is disabled while you are driving. Spectate a ghost to enable the unlock button.\n");
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (IsTimerUnlocked(ps)) {
            if (UI::Button("Close Window")) {
                g_ShowUnlockTimerPrompt = false;
            }
        } else {
            if (DrawUnlockTimelineButton(ps)) {
                g_ShowUnlockTimerPrompt = false;
            }
        }
        UI::Separator();
        S_AutoUnlockTimelineSolo = UI::Checkbox("Automatically unlock the timeline in Solo", S_AutoUnlockTimelineSolo);
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
#if DEV
    // UI::ShowNotification("Timeline unlocked!", "The timeline has been unlocked automatically.");
#endif
}
