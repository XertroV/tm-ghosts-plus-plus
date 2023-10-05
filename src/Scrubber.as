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

        auto nbBtns = 6;

        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() - btnWidthFull * nbBtns);
        auto setProg = UI::SliderFloat("##ghost-scrub", t, 0, lastSpectatedGhostRaceTime, "%9.0f / " + lastSpectatedGhostRaceTime);

        bool clickTogglePause = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);

        UI::SameLine();
        bool stepFwd = UI::Button(Icons::StepForward + "##scrubber-step-fwd", vec2(50, 0));
        UI::SameLine();
        bool changeCurrSpeed = UI::Button(currSpeedLabel + "##scrubber-next-speed", vec2(50, 0));
        bool currSpeedBw = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
        UI::SameLine();
        clickTogglePause = UI::Button((scrubberMgr.IsPaused ? Icons::Play : Icons::Pause) + "##scrubber-toggle", vec2(50, 0)) || clickTogglePause;

        auto mgr = GhostClipsMgr::Get(GetApp());

        if (exit) {
            ExitSpectatingGhostAndCleanUp();
            clickTogglePause = scrubberMgr.IsPaused;
        }
        if (reset) setProg = 0;
        if (stepBack || stepFwd) {
            clickTogglePause = !scrubberMgr.IsPaused;
            setProg = t + (10 * scrubberMgr.playbackSpeed) * (stepBack ? -1 : 1);
        }
        if (setProg != t) {
            scrubberMgr.SetProgress(setProg);
            t = setProg;
        }
        if (clickTogglePause) {
            // makes pausing smoother
            t += (10 * scrubberMgr.playbackSpeed);
            scrubberMgr.TogglePause(t);
        }
        if (changeCurrSpeed || currSpeedBw) {
            scrubberMgr.CyclePlaybackSpeed(currSpeedBw);
        }
    }
    UI::End();
}

string get_currSpeedLabel() {
    if (scrubberMgr.playbackSpeed < 0.1)
        return Text::Format("%.2fx", scrubberMgr.playbackSpeed);
    return Text::Format("%.1fx", scrubberMgr.playbackSpeed);
}

enum ScrubberMode {
    Playback,
    Paused,
    CustomSpeed,
}

class ScrubberMgr {
    ScrubberMode mode = ScrubberMode::Playback;
    // measured in seconds since ghost start
    uint pauseAt = 0;
    float playbackSpeed = 1.0;

    ScrubberMgr() {}

    bool get_IsPaused() {
        return mode == ScrubberMode::Paused;
    }

    bool get_IsStdPlayback() {
        return mode == ScrubberMode::Playback;
    }

    bool get_IsCustPlayback() {
        return mode == ScrubberMode::CustomSpeed || playbackSpeed != 1.0;
    }

    void TogglePause(uint setProg) {
        pauseAt = setProg;
        if (IsPaused) {
            mode = playbackSpeed == 1.0 ? ScrubberMode::Playback : ScrubberMode::CustomSpeed;
            if (IsStdPlayback) DoUnpause();
        } else {
            SetPaused(setProg, true);
        }
    }

    void SetProgress(uint setProg) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        // auto t = ps.Now - lastSetStartTime;
        // trace('t / s ' + t + ' / ' + setProg);
        auto newStartTime = ps.Now - setProg;
        pauseAt = setProg;
        if (ps !is null) {
            ps.Ghosts_SetStartTime(newStartTime);
        }
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (IsPaused) {
            GhostClipsMgr::PauseClipPlayers(mgr, float(setProg) / 1000.);
        } else {
            GhostClipsMgr::UnpauseClipPlayers(mgr, float(setProg) / 1000.);
        }
    }

    void SetPlayback(bool setMode = false) {
        SetPlaybackSpeed(1.0, setMode);
        if (setMode) {
            if (IsPaused) DoUnpause();
            mode = ScrubberMode::Playback;
        }
    }

    void DoUnpause() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        GhostClipsMgr::UnpauseClipPlayers(mgr, float(pauseAt) / 1000., float(GhostClipsMgr::GetMaxGhostDuration(mgr)) / 1000.);
    }

    void SetPaused(uint pgGhostProgTime, bool setMode = false) {
        pauseAt = pgGhostProgTime;
        if (setMode) {
            mode = ScrubberMode::Paused;
            auto mgr = GhostClipsMgr::Get(GetApp());
            GhostClipsMgr::PauseClipPlayers(mgr, float(pauseAt) / 1000.);
        }
    }

    void SetPlaybackSpeed(float custSpeed, bool setMode = false) {
        playbackSpeed = custSpeed;
        if (setMode) {
            bool wasPlayback = IsStdPlayback;
            mode = custSpeed == 1.0 ? ScrubberMode::Playback : ScrubberMode::CustomSpeed;
            // check if we changed modes
            if (wasPlayback != IsStdPlayback) {
                auto mgr = GhostClipsMgr::Get(GetApp());
                if (wasPlayback)
                    GhostClipsMgr::PauseClipPlayers(mgr, float(pauseAt) / 1000.);
                else
                    GhostClipsMgr::UnpauseClipPlayers(mgr, float(pauseAt) / 1000., float(GhostClipsMgr::GetMaxGhostDuration(mgr)) / 1000.);
            }
        }
    }

    PlaybackSpeeds _pbSpeed = PlaybackSpeeds::x1;

    void CyclePlaybackSpeed(bool backwards = false) {
        _pbSpeed = PlaybackSpeeds((int(_pbSpeed) + int(PlaybackSpeeds::LAST) + (backwards ? -1 : 1)) % int(PlaybackSpeeds::LAST));

        if (_pbSpeed == PlaybackSpeeds::x2) SetPlaybackSpeed(2.0, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_01) SetPlaybackSpeed(0.01, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_1) SetPlaybackSpeed(0.1, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_5) SetPlaybackSpeed(0.5, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x1) SetPlaybackSpeed(1.0, !IsPaused);
        else SetPlaybackSpeed(1.0, !IsPaused);
    }

    void Update() {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return;
        if (scrubberMgr.IsPaused) {
            // auto setStart = ps.Now - pauseAt;
            // ps.Ghosts_SetStartTime(setStart);
            ps.Ghosts_SetStartTime(ps.Now - pauseAt);
        } else if (scrubberMgr.IsCustPlayback) {
            auto mgr = GhostClipsMgr::Get(GetApp());
            auto td = GhostClipsMgr::AdvanceClipPlayersByDelta(mgr, scrubberMgr.playbackSpeed);
            pauseAt = uint(td.x * 1000.);
            ps.Ghosts_SetStartTime(ps.Now - pauseAt);
        } else {
            pauseAt = ps.Now - lastSetStartTime;
        }
    }
}

ScrubberMgr scrubberMgr;

enum PlaybackSpeeds {
    x2 = 0, x1 = 1, x0_5, x0_1, x0_01,
    LAST,
}

void ML_PG_Callback(ref@ r) {
    scrubberMgr.Update();
}












class ScrubberDebugTab : Tab {
    ScrubberDebugTab() {
        super("[D] Scrubber");
    }

    void DrawInner() override {
        UI::Columns(2);
        DrawValLabel(tostring(scrubberMgr.mode), "scrubberMgr.mode");
        DrawValLabel(scrubberMgr.pauseAt, "scrubberMgr.pauseAt");
        DrawValLabel(scrubberMgr.playbackSpeed, "scrubberMgr.playbackSpeed");
        UI::Columns(1);
    }
}
