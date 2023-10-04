void DrawScrubber() {
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) return;
    vec2 screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    vec2 pos = screen * vec2(0.1, 0.87);
    vec2 size = screen * vec2(0.3, 0);
    auto spacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
    auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
    size.y = UI::GetFrameHeightWithSpacing() + spacing.y + fp.y;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
    if (UI::Begin("scrubber", UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize)) {
        float t = ps.Now - lastSetStartTime;
        // auto setProg = UI::ProgressBar(t, vec2(-1, 0), Text::Format("%.2f %%", t * 100));
        auto btnWidth = 50.;
        auto btnWidthFull = btnWidth + spacing.x;

        // Backward <<
        bool exit = UI::Button(Icons::Reply + "##scrubber-back", vec2(50, 0));
        UI::SameLine();
        bool reset = UI::Button(Icons::Refresh + "##scrubber-toggle", vec2(50, 0));
        UI::SameLine();
        bool stepBack = UI::Button(Icons::StepBackward + "##scrubber-step-back", vec2(50, 0));
        UI::SameLine();

        auto nbBtns = 5;

        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() - btnWidthFull * nbBtns);
        auto setProg = UI::SliderFloat("##ghost-scrub", t, 0, lastSpectatedGhostRaceTime, "%9.0f / " + lastSpectatedGhostRaceTime);

        bool rClicked = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);

        UI::SameLine();
        bool stepFwd = UI::Button(Icons::StepForward + "##scrubber-step-fwd", vec2(50, 0));
        UI::SameLine();
        rClicked = UI::Button((scrubberPaused ? Icons::Play : Icons::Pause) + "##scrubber-toggle", vec2(50, 0)) || rClicked;

        auto mgr = GhostClipsMgr::Get(GetApp());

        if (exit) {
            ExitSpectatingGhostAndCleanUp();
            rClicked = scrubberPaused;
        }
        if (reset) setProg = 0;
        if (stepBack || stepFwd) {
            rClicked = !scrubberPaused;
            setProg = t + 10 * (stepBack ? -1 : 1);
        }
        if (setProg != t) {
            trace('t / s ' + t + ' / ' + setProg);
            auto newStartTime = ps.Now - setProg;
            // newStartTime = newStartTime - newStartTime % 10 + 10;
            scrubberPauseAt = setProg;
            if (ps !is null) {
                ps.Ghosts_SetStartTime(newStartTime);
            }
            if (scrubberPaused) {
                GhostClipsMgr::PauseClipPlayers(mgr, float(t) / 1000.);
            }
        }
        if (rClicked) {
            // makes pausing smoother
            t += 10;
            scrubberPaused = !scrubberPaused;
            scrubberPauseAt = t;
            if (scrubberPaused) {
                GhostClipsMgr::PauseClipPlayers(mgr, float(t) / 1000.);
            } else {
                GhostClipsMgr::UnpauseClipPlayers(mgr, float(t) / 1000., float(GhostClipsMgr::GetMaxGhostDuration(mgr)) / 1000.);
            }
        }
    }
    UI::End();
}


bool scrubberPaused = false;
uint scrubberPauseAt = 0;

// todo: fix removing callbacks for pg exec
void ML_PG_Callback(ref@ r) {
    if (scrubberPaused) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return;
        auto setStart = ps.Now - scrubberPauseAt;
        ps.Ghosts_SetStartTime(setStart);
    }
}
