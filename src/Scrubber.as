[Setting category="Size / Pos" name="Center Scrubber (X)"]
bool S_ScrubberCenterX = true;

[Setting category="Size / Pos" name="X position (relative to screen)" min=0 max=1]
float S_XPosRel = 0.25;

[Setting category="Size / Pos" name="Y position (relative to screen)" min=0 max=1]
float S_YPosRel = 0.94;

[Setting category="Size / Pos" name="Width (relative to screen)" min=0 max=1]
float S_XWidth = 0.5;

void DrawScrubber() {
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) return;
    vec2 screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    auto spacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
    auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
    auto ySize = UI::GetFrameHeightWithSpacing() + spacing.y + fp.y;;
    vec2 pos = (screen - vec2(S_XWidth * screen.x, ySize)) * vec2(S_ScrubberCenterX ? 0.5 : S_XPosRel, S_YPosRel);
    vec2 size = screen * vec2(S_XWidth, 0);
    size.y = ySize;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
    if (UI::Begin("scrubber", UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize)) {
        float t = float(ps.Now - lastSetStartTime - 1) + scrubberMgr.subSecondOffset;
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
        auto setProg = UI::SliderFloat("##ghost-scrub", scrubberMgr.pauseAt, 0, lastSpectatedGhostRaceTime, "%9.0f / " + lastSpectatedGhostRaceTime);

        bool clickTogglePause = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);

        UI::SameLine();
        bool stepFwd = UI::Button(Icons::StepForward + "##scrubber-step-fwd", vec2(50, 0));
        UI::SameLine();
        bool changeCurrSpeed = UI::Button(currSpeedLabel + "##scrubber-next-speed", vec2(50, 0));
        bool currSpeedBw = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
        UI::SameLine();
        clickTogglePause = UI::Button((scrubberMgr.IsPaused ? Icons::Play : Icons::Pause) + "##scrubber-toggle", vec2(50, 0)) || clickTogglePause;


        if (exit) {
            scrubberMgr.SetPlayback();
            ExitSpectatingGhostAndCleanUp();
        }
        if (reset) setProg = 0;
        if (stepBack || stepFwd) {
            float progDelta = 10.0 * Math::Abs(scrubberMgr.playbackSpeed);
            float newT = t + progDelta * (stepBack ? -1. : 1.);
            // trace('newT: ' + newT + '; t: ' + t + "; diff: " + (newT - t) + ' pauseat: ' + scrubberMgr.pauseAt);
            scrubberMgr.SetPaused(scrubberMgr.pauseAt + progDelta * (stepBack ? -1. : 1.), true);
        } else if (clickTogglePause) {
            // makes pausing smoother
            // t += 10 * scrubberMgr.playbackSpeed;
            scrubberMgr.TogglePause(scrubberMgr.pauseAt + 10 * scrubberMgr.playbackSpeed);
        } else if (setProg != t) {
            scrubberMgr.SetProgress(setProg);
            t = setProg;
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
    float pauseAt = 0;
    float playbackSpeed = 1.0;
    float subSecondOffset = 0.0;

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

    void ResetAll() {
        scrubberMgr.ForceUnpause();
        scrubberMgr.SetPlayback();
    }

    void ForceUnpause() {
        if (!IsPaused) return;
        TogglePause(pauseAt);
    }

    void TogglePause(float setProg) {
        pauseAt = setProg;
        if (IsPaused) {
            mode = playbackSpeed == 1.0 ? ScrubberMode::Playback : ScrubberMode::CustomSpeed;
            if (IsStdPlayback) DoUnpause();
        } else {
            SetPaused(setProg, true);
        }
    }

    void SetProgress(float setProg) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        pauseAt = setProg;
        auto newStartTime = ps.Now - pauseAt;
        if (ps !is null) {
            ps.Ghosts_SetStartTime(newStartTime);
        }
        if (!IsStdPlayback) {
            auto mgr = GhostClipsMgr::Get(GetApp());
            GhostClipsMgr::PauseClipPlayers(mgr, setProg / 1000.);
        }
        subSecondOffset = pauseAt > 0
                        ? pauseAt - Math::Floor(pauseAt)
                        : Math::Ceil(pauseAt) - pauseAt;
    }

    void SetPlayback() {
        _pbSpeed = PlaybackSpeeds::x1;
        UpdatePlaybackSpeed();
    }

    // this flag is for Update() -- it should not advance car positions if unpausedFlag == true;
    bool unpausedFlag = false;
    void DoUnpause() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        GhostClipsMgr::UnpauseClipPlayers(mgr, pauseAt / 1000., float(GhostClipsMgr::GetMaxGhostDuration(mgr)) / 1000.);
        unpausedFlag = true;
    }
    void DoPause() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        GhostClipsMgr::PauseClipPlayers(mgr, pauseAt / 1000.);
        unpausedFlag = false;
    }

    void SetPaused(float pgGhostProgTime, bool setMode = false) {
        pauseAt = pgGhostProgTime;
        if (setMode) {
            mode = ScrubberMode::Paused;
            DoPause();
        }
    }

    void SetPlaybackSpeed(float custSpeed, bool setMode = false) {
        playbackSpeed = custSpeed;
        // UpdatePBSpeedEnum();
        if (setMode) {
            bool wasPlayback = IsStdPlayback;
            mode = custSpeed == 1.0 ? ScrubberMode::Playback : ScrubberMode::CustomSpeed;
            // check if we changed modes
            if (wasPlayback != IsStdPlayback) {
                auto mgr = GhostClipsMgr::Get(GetApp());
                if (wasPlayback) DoPause();
                else DoUnpause();
            }
        }
    }

    PlaybackSpeeds _pbSpeed = PlaybackSpeeds::x1;

    void CyclePlaybackSpeed(bool backwards = false) {
        _pbSpeed = PlaybackSpeeds((int(_pbSpeed) + int(PlaybackSpeeds::LAST) + (backwards ? -1 : 1)) % int(PlaybackSpeeds::LAST));
        UpdatePlaybackSpeed();
    }

    void UpdatePlaybackSpeed() {
        if (_pbSpeed == PlaybackSpeeds::x2) SetPlaybackSpeed(2.0, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_01) SetPlaybackSpeed(0.01, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_1) SetPlaybackSpeed(0.1, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_5) SetPlaybackSpeed(0.5, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x1) SetPlaybackSpeed(1.0, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::nx2) SetPlaybackSpeed(-2.0, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::nx0_01) SetPlaybackSpeed(-0.01, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::nx0_1) SetPlaybackSpeed(-0.1, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::nx0_5) SetPlaybackSpeed(-0.5, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::nx1) SetPlaybackSpeed(-1.0, !IsPaused);
        else SetPlaybackSpeed(1.0, !IsPaused);
    }

    void Update() {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return;
        if (!IsSpectatingGhost() && !unpausedFlag) {
            ResetAll();
            return;
        }
        if (IsPaused) {
            // auto setStart = ps.Now - pauseAt;
            // ps.Ghosts_SetStartTime(setStart);
            ps.Ghosts_SetStartTime(ps.Now - pauseAt);
        } else if (!unpausedFlag && IsCustPlayback) {
            auto mgr = GhostClipsMgr::Get(GetApp());
            auto td = GhostClipsMgr::AdvanceClipPlayersByDelta(mgr, playbackSpeed);
            if (td.x < 0) {
                pauseAt = ps.Now;
                GhostClipsMgr::PauseClipPlayers(mgr, 0.0);
            } else {
                pauseAt = td.x * 1000.;
                subSecondOffset = pauseAt - Math::Floor(pauseAt);
            }
            ps.Ghosts_SetStartTime(ps.Now - pauseAt);
        } else {
            pauseAt = ps.Now - lastSetStartTime;
        }
    }
}

ScrubberMgr scrubberMgr;

enum PlaybackSpeeds {
    x2 = 0, x1 = 1, x0_5, x0_1, x0_01,
    nx0_01, nx0_1, nx0_5, nx1, nx2,
    LAST,
}

void ML_PG_Callback(ref@ r) {
    if (scrubberMgr is null) return;
    if (GetApp().PlaygroundScript is null) return;
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
        DrawValLabel(scrubberMgr.subSecondOffset, "scrubberMgr.subSecondOffset");
        DrawValLabel(scrubberMgr.unpausedFlag, "scrubberMgr.unpausedFlag");
        UI::Columns(1);
    }
}
