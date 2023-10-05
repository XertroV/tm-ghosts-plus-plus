[Setting category="Scrubber Size / Pos" name="Show when UI off"]
bool S_ScrubberWhenUIOff = true;

[Setting category="Scrubber Size / Pos" name="Show when Overlay off"]
bool S_ScrubberWhenOverlayOff = true;

[Setting category="Scrubber Size / Pos" name="Center Scrubber (X)"]
bool S_ScrubberCenterX = true;

[Setting category="Scrubber Size / Pos" name="X position (relative to screen)" min=0 max=1]
float S_XPosRel = 0.25;

[Setting category="Scrubber Size / Pos" name="Y position (relative to screen)" min=0 max=1]
float S_YPosRel = 0.94;

[Setting category="Scrubber Size / Pos" name="Width (relative to screen)" min=0 max=1]
float S_XWidth = 0.5;

float maxTime = 0.;
uint lastHover;

void DrawScrubber() {
    if (!S_ScrubberWhenOverlayOff && !UI::IsOverlayShown()) return;
    if (!S_ScrubberWhenUIOff && !UI::IsGameUIVisible()) return;
    bool isSpectating = IsSpectatingGhost();
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) return;


    vec2 screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    auto spacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
    auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
    auto ySize = UI::GetFrameHeightWithSpacing() + spacing.y + fp.y;;
    vec2 pos = (screen - vec2(S_XWidth * screen.x, ySize)) * vec2(S_ScrubberCenterX ? 0.5 : S_XPosRel, S_YPosRel);
    vec2 size = screen * vec2(S_XWidth, 0);
    size.y = ySize;

    if (Within(UI::GetMousePos(), vec4(pos, size))) {
        lastHover = Time::Now;
    }

    bool showScrubber = isSpectating || (int(ps.StartTime) - ps.Now) > 0 || (Time::Now - lastHover) < 5000;
    if (!showScrubber) return;

    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
    if (UI::Begin("scrubber", UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize)) {
        double t = double(ps.Now - lastSetStartTime) + scrubberMgr.subSecondOffset;
        // auto setProg = UI::ProgressBar(t, vec2(-1, 0), Text::Format("%.2f %%", t * 100));
        auto btnWidth = Math::Lerp(40., 50., Math::Clamp(Math::InvLerp(1920, 3440, screen.x), 0., 1.));
        auto btnWidthFull = btnWidth + spacing.x;

        bool expand = UI::Button(Icons::Expand + "##scrubber-expand", vec2(btnWidth, 0));
        UI::SameLine();
        // Backward <<
        bool exit = UI::Button(Icons::Reply + "##scrubber-back", vec2(btnWidth, 0));
        UI::SameLine();
        bool reset = UI::Button(Icons::Refresh + "##scrubber-toggle", vec2(btnWidth, 0));
        UI::SameLine();
        bool stepBack = UI::Button(scrubberMgr.IsPaused ? Icons::StepBackward : Icons::Backward + "##scrubber-step-back", vec2(btnWidth, 0));
        UI::SameLine();

        auto nbBtns = 8;

        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() - btnWidthFull * nbBtns);
        maxTime = 0;
        maxTime = Math::Max(maxTime, lastSpectatedGhostRaceTime);
        maxTime = Math::Max(maxTime, scrubberMgr.pauseAt);
        maxTime = Math::Max(maxTime, lastLoadedGhostRaceTime);
        string labelTime = Time::Format(Math::Abs(t));
        if (t < 0) labelTime = "-" + labelTime;
        auto setProg = UI::SliderFloat("##ghost-scrub", scrubberMgr.pauseAt, 0, Math::Max(maxTime, t),  labelTime + " / " + Time::Format(maxTime));

        bool clickTogglePause = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);

        UI::SameLine();
        bool stepFwd = UI::Button((scrubberMgr.IsPaused ? Icons::StepForward : Icons::Forward) + "##scrubber-step-fwd", vec2(btnWidth, 0));
        UI::SameLine();
        bool changeCurrSpeed = UI::Button(currSpeedLabel + "##scrubber-next-speed", vec2(btnWidth, 0));
        bool currSpeedBw = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
        // bool currSpeedCtx = UI::IsItemHovered() && UI::IsMouseDown(UI::MouseButton::Middle);

        // if (UI::BeginPopupContextItem("curr speed")) {
        //     UI::SetNextItemWidth(100.);
        //     scrubberMgr.SetPlaybackSpeed(
        //         UI::InputFloat("Playback Speed", scrubberMgr.playbackSpeed, .1),
        //         !scrubberMgr.IsPaused
        //     );
        //     UI::EndPopup();
        // }

        // auto dragDelta = UI::GetMouseDragDelta(UI::MouseButton::Left, 10);
        // trace(dragDelta.ToString());
        vec2 dragDelta;

        UI::SameLine();
        clickTogglePause = UI::Button((scrubberMgr.IsPaused ? Icons::Play : Icons::Pause) + "##scrubber-toggle", vec2(btnWidth, 0)) || clickTogglePause;
        UI::SameLine();
        bool clickCamera = UI::Button(Icons::Camera + "##scrubber-toggle-cam", vec2(btnWidth, 0));

        if (expand) {
            S_ShowWindow = !S_ShowWindow;
        }
        if (clickCamera) {
            auto cam = ps.UIManager.UIAll.SpectatorForceCameraType;
            auto newCam = cam;
            if (cam == 0) newCam = 2;
            if (cam == 1) newCam = 2;
            if (cam == 2) newCam = 3;
            if (cam >= 3) newCam = 0;
            ps.UIManager.UIAll.SpectatorForceCameraType = newCam;
        }
        if (exit) {
            scrubberMgr.SetPlayback();
            ExitSpectatingGhostAndCleanUp();
        }
        if (reset) setProg = 0;
        if (stepBack || stepFwd) {
            if (scrubberMgr.IsPaused) {
                float progDelta = 10.0 * Math::Abs(scrubberMgr.playbackSpeed);
                // auto newT = t + progDelta * (stepBack ? -1. : 1.);
                // trace('newT: ' + newT + '; t: ' + t + "; diff: " + (newT - t) + ' pauseat: ' + scrubberMgr.pauseAt);
                scrubberMgr.SetPaused(scrubberMgr.pauseAt + progDelta * (stepBack ? -1. : 1.), true);
            } else {
                scrubberMgr.SetProgress(scrubberMgr.pauseAt + 5000.0 * Math::Abs(scrubberMgr.playbackSpeed) * (stepBack ? -1. : 1.));
            }
        } else if (dragDelta.y > 0) {
            float dragY = Math::Clamp(dragDelta.y, -100, 100);
            print('' + dragY);
            float sign = dragY >= 0 ? 1.0 : -1.0;
            dragY = Math::Max(1, Math::Abs(dragY));
            auto dyl = sign * Math::Pow(Math::Log(dragY) / Math::Log(100.), 10.);
            scrubberMgr.SetPlaybackSpeed(dyl, !scrubberMgr.IsPaused);
        } else if (clickTogglePause) {
            // makes pausing smoother
            // t += 10 * scrubberMgr.playbackSpeed;
            scrubberMgr.TogglePause(scrubberMgr.pauseAt + 10 * scrubberMgr.playbackSpeed);
        } else if (t > 0. && Math::Abs(t - setProg) / t * 1000. >= 1.0) {
            // trace('t and setProg different: ' + vec2(t, setProg).ToString());
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
    if (Math::Abs(scrubberMgr.playbackSpeed) < 0.1)
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
    double pauseAt = 0;
    float playbackSpeed = 1.0;
    float subSecondOffset = 0.0;

    ScrubberMgr() {
        auto ps = GetApp().PlaygroundScript;
        if (ps is null) return;
        auto mgr = GhostClipsMgr::Get(GetApp());
        pauseAt = ps.Now - GhostClipsMgr::GetCurrentGhostTime(mgr);
    }

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

    void TogglePause(double setProg) {
        pauseAt = setProg;
        if (IsPaused) {
            mode = playbackSpeed == 1.0 ? ScrubberMode::Playback : ScrubberMode::CustomSpeed;
            if (IsStdPlayback) DoUnpause();
        } else {
            SetPaused(setProg, true);
        }
    }

    void SetProgress(double setProg) {
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

    // this flag is for Update() -- it should not advance car positions if unpausedFlag == true. We start with it true as it's only false when paused or custom speed
    bool unpausedFlag = true;
    void DoUnpause() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        GhostClipsMgr::UnpauseClipPlayers(mgr, pauseAt / 1000., float(GhostClipsMgr::GetMaxGhostDuration(mgr)) / 1000.);
        unpausedFlag = true;
    }
    void DoPause() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        GhostClipsMgr::PauseClipPlayers(mgr, pauseAt / 1000.);
        unpausedFlag = false;
    }

    void SetPaused(double pgGhostProgTime, bool setMode = false) {
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
        auto m = cast<CTrackMania>(GetApp()).Network;

        // if () {
        //     // having ghosts in the paused state can crash the game when exiting map
        //     ResetAll();
        //     return;
        // }
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
                pauseAt = double(td.x) * 1000.;
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



// getting around playground time limits
// On CGameCtnMediaBlockEntity:

/*

0x38: buffer of entities?
0x58: ptr: CPlugEntRecordData
0x60: float: startOffset
0x68: string: ghost name

0xF8: string: skin options

0x14C: float: currently viewing

*/
bool Within(vec2 &in pos, vec4 &in rect) {
    return pos.x >= rect.x && pos.x < (rect.x + rect.z)
        && pos.y >= rect.y && pos.y < (rect.y + rect.w);
}
