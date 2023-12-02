bool g_ShowUnlockTimerPrompt = false;


void DrawUnlockTimelinePromptWindow() {
    if (!g_ShowUnlockTimerPrompt) return;

    if (UI::Begin("G++ Timeline Unlock", g_ShowUnlockTimerPrompt)) {
        UI::TextWrapped("You can unlock the timeline to skip forward in a ghost. \\$f80Experimental.");
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
        S_SuppressUnlockTimelinePrompt = UI::Checkbox("Don't remind me again?", S_SuppressUnlockTimelinePrompt);
    }
    UI::End();
}

bool DrawUnlockTimelineButton(CSmArenaRulesMode@ ps) {
    UI::BeginDisabled(IsTimerUnlocked(ps));
    auto ret = UI::Button("Unlock Timeline");
    if (ret) {
        UnlockPlaygroundTimer(ps);
    }
    UI::EndDisabled();
    return ret;
}
