[Setting category="Scrubber Size / Pos" name="Show when UI off"]
bool S_ScrubberWhenUIOff = true;

[Setting category="Scrubber Size / Pos" name="Show when Overlay off"]
bool S_ScrubberWhenOverlayOff = true;

[Setting category="Scrubber Size / Pos" name="Center Scrubber (X axis; \\$f80Overrides X Position\\$z)"]
bool S_ScrubberCenterX = true;

[Setting category="Scrubber Size / Pos" name="X position (relative to screen)" min=0 max=1]
float S_XPosRel = 0.25;

[Setting category="Scrubber Size / Pos" name="Y position (relative to screen)" min=0 max=1]
float S_YPosRel = 0.94;

[Setting category="Scrubber Size / Pos" name="Width (relative to screen)" min=0 max=1]
float S_XWidth = 0.65;

[Setting category="Scrubber Size / Pos" name="Background Alpha" min=0 max=1]
float S_ScrubberBgAlpha = 1.0;

[Setting category="Scrubber Size / Pos" name="Text Color" color]
vec4 S_TextColor = vec4(1);

enum Font {
    Std = 0, Bold = 1, Large = 2, Larger = 3
}

[Setting category="Scrubber Size / Pos" name="Font Size"]
Font S_FontSize = Font::Large;

[Setting category="Scrubber Size / Pos" name="Show the advanced tools above the scrubber"]
bool S_ForceShowAdvOnTop = false;

[Setting category="Scrubber Size / Pos" name="After hover hide delay" min=0 max=10000 description="When driving, the scrubber will auto-disappear after this many miliseconds."]
uint S_HoverHideDelay = 2500;

[Setting category="Scrubber Size / Pos" name="Never hide the scrubber" description="Overrides hover hide delay"]
bool S_NeverHideScrubber = false;




UI::Font@ GetCurrFont() {
    if (S_FontSize == Font::Std) return g_fontStd;
    if (S_FontSize == Font::Bold) return g_fontBold;
    if (S_FontSize == Font::Large) return g_fontLarge;
    if (S_FontSize == Font::Larger) return g_fontLarger;
    return g_fontStd;
}

float GetCurrFontSize() {
    if (S_FontSize == Font::Std) return 16.;
    if (S_FontSize == Font::Bold) return 16.;
    if (S_FontSize == Font::Large) return 20.;
    if (S_FontSize == Font::Larger) return 26.;
    return 16.;
}



float maxTime = 0.;
uint lastHover;
bool showAdvanced = false;

void DrawScrubber() {
    if (!S_ScrubberWhenOverlayOff && !UI::IsOverlayShown()) return;
    if (!S_ScrubberWhenUIOff && !UI::IsGameUIVisible()) return;
    bool isSpectating = IsSpectatingGhost();
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) return;

    UI::PushFont(GetCurrFont());

    vec2 screen = vec2(Draw::GetWidth(), Draw::GetHeight()) / UI::GetScale();
    auto spacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
    auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
    auto ySize = (UI::GetFrameHeightWithSpacing() + spacing.y + fp.y) / UI::GetScale();
    vec2 pos = (screen - vec2(S_XWidth * screen.x, ySize)) * vec2(S_ScrubberCenterX ? 0.5 : S_XPosRel, S_YPosRel);
    vec2 size = screen * vec2(S_XWidth, 0);
    size.y = ySize;

    if (S_NeverHideScrubber || Within(UI::GetMousePos() / UI::GetScale(), vec4(pos, size))) {
        lastHover = Time::Now;
    }

    bool showScrubber = isSpectating || (int(ps.StartTime) - ps.Now) > 0 || (Time::Now - lastHover) < S_HoverHideDelay;
    auto @mgr = GhostClipsMgr::Get(GetApp());
    showScrubber = showScrubber && scrubberMgr !is null;
    showScrubber = showScrubber && mgr !is null;
    if (!showScrubber) {
        UI::PopFont();
        return;
    }

    auto nbGhosts = mgr.Ghosts.Length;

    bool showInputs = isSpectating && S_ShowInputsWhileSpectatingGhosts
        && (UI::IsGameUIVisible() || S_ShowInputsWhenUIHidden)
        && (!S_HideInputsIfOnlyGhost || nbGhosts > 1)
        && nbGhosts > 0 && ps !is null;
    if (showInputs) {
        auto instId = GetCurrentlySpecdGhostInstanceId(ps);
        auto g = GhostClipsMgr::GetGhostFromInstanceId(mgr, instId);
        if (g !is null) {
            auto ghostVisId = Dev::GetOffsetUint32(g, 0x0);
            if (ghostVisId < 0x0F000000 && ghostVisId & 0x04000000 != 0) {
#if DEPENDENCY_DASHBOARD && ENABLE_NEW_DASHBOARD
                if (Meta::GetPluginFromID("Dashboard").Enabled) {
                    Dashboard::InformCurrentEntityId(ghostVisId);
                }
#else
                CSceneVehicleVis@[] viss = VehicleState::GetAllVis(GetApp().GameScene);
                CSceneVehicleVis@ found;
                for (uint i = 0; i < viss.Length; i++) {
                    auto vis = viss[i];
                    auto visId = Dev::GetOffsetUint32(vis, 0);
                    if (visId == ghostVisId) {
                        @found = vis;
                        break;
                    }
                }
                if (found !is null) {
                    auto inputsSize = vec2(S_InputsHeight * 2, S_InputsHeight) * screen.y;
                    auto inputsPos = (screen - inputsSize) * vec2(S_InputsPosX, S_InputsPosY);
                    inputsPos += inputsSize;
                    nvg::Translate(inputsPos);
                    Inputs::DrawInputs(found.AsyncState, inputsSize);
                    nvg::ResetTransform();
                }
#endif
            }
        }
    }

    bool drawAdvOnTop = S_ForceShowAdvOnTop || (pos.y + (ySize * 2.) / UI::GetScale() > screen.y);
    if (drawAdvOnTop && showAdvanced) pos.y -= (ySize - (spacing.y + fp.y) / UI::GetScale());

    auto bgCol = UI::GetStyleColor(UI::Col::WindowBg);
    auto frameBgCol = UI::GetStyleColor(UI::Col::FrameBg);
    auto frameABgCol = UI::GetStyleColor(UI::Col::FrameBgActive);
    auto frameHBgCol = UI::GetStyleColor(UI::Col::FrameBgHovered);
    bgCol.w *= S_ScrubberBgAlpha;
    frameBgCol.w *= S_ScrubberBgAlpha;
    frameHBgCol.w *= S_ScrubberBgAlpha;
    frameABgCol.w *= S_ScrubberBgAlpha;
    UI::PushStyleColor(UI::Col::WindowBg, bgCol);
    UI::PushStyleColor(UI::Col::Text, S_TextColor);
    UI::PushStyleColor(UI::Col::FrameBg, frameBgCol);
    UI::PushStyleColor(UI::Col::FrameBgActive, frameABgCol);
    UI::PushStyleColor(UI::Col::FrameBgHovered, frameHBgCol);
    UI::SetNextWindowSize(int(size.x), 0 /*int(size.y)*/, UI::Cond::Always);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
    if (UI::Begin("scrubber", UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize)) {
        double t = double(ps.Now - lastSetStartTime) + scrubberMgr.subSecondOffset;
        // auto setProg = UI::ProgressBar(t, vec2(-1, 0), Text::Format("%.2f %%", t * 100));
        auto btnWidth = Math::Lerp(40., 50., Math::Clamp(Math::InvLerp(1920., 3440., screen.x), 0., 1.))
            * (GetCurrFontSize() / 16.) * UI::GetScale();
        auto btnWidthFull = btnWidth + spacing.x;
        if (showAdvanced && drawAdvOnTop) {
            DrawAdvancedScrubberExtras(ps, btnWidth);
        }

        bool expand = UI::Button(Icons::Expand + "##scrubber-expand", vec2(btnWidth, 0));
        UI::SameLine();
        // Backward <<
        UI::BeginDisabled(!isSpectating);
        bool exit = UI::Button(Icons::Reply + "##scrubber-back", vec2(btnWidth, 0));
        UI::EndDisabled();
        UI::SameLine();
        bool reset = UI::Button(Icons::Refresh + "##scrubber-toggle", vec2(btnWidth, 0));
        UI::SameLine();
        bool stepBack = UI::Button(scrubberMgr.IsPaused ? Icons::StepBackward : Icons::Backward + "##scrubber-step-back", vec2(btnWidth, 0));
        UI::SameLine();

        auto nbBtns = 8;

        if (lastLoadedGhostRaceTime == 0 && mgr.Ghosts.Length > 0) {
            lastLoadedGhostRaceTime = mgr.Ghosts[0].GhostModel.RaceTime;
        }

        UI::SetNextItemWidth((UI::GetWindowContentRegionWidth() - btnWidthFull * nbBtns) / UI::GetScale());
        maxTime = 0;
        maxTime = Math::Max(maxTime, lastSpectatedGhostRaceTime);
        maxTime = Math::Max(maxTime, scrubberMgr.pauseAt);
        maxTime = Math::Max(maxTime, lastLoadedGhostRaceTime);
        maxTime = Math::Min(maxTime, ps.Now);
        string labelTime = Time::Format(int64(Math::Abs(t) + lastSetGhostOffset));
        if (t < 0) labelTime = "-" + labelTime;
        auto setProg = UI::SliderFloat("##ghost-scrub", scrubberMgr.pauseAt, 0, Math::Max(maxTime, t),  labelTime + " / " + Time::Format(int64(maxTime + lastSetGhostOffset)));
        bool startedScrub = UI::IsItemClicked();
        bool clickTogglePause = UI::IsItemHovered() && !scrubberMgr.isScrubbing && UI::IsMouseClicked(UI::MouseButton::Right);

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
        // bool clickCamera = UI::Button(Icons::Camera + "##scrubber-toggle-cam", vec2(btnWidth, 0));
        bool toggleAdv = UI::Button(Icons::Cogs + "##scrubber-toggle-adv", vec2(btnWidth, 0));

        bool shouldSoftenEngineSounds = scrubberMgr.IsPaused || scrubberMgr.playbackSpeed < 0.5 || scrubberMgr.isScrubbing;
        if (shouldSoftenEngineSounds) {
            if (EngineSounds::Apply()) EngineSounds::SetEngineSoundVolumeDB(S_EngineSoundsDB);
        } else {
            EngineSounds::Unapply();
        }

        if (toggleAdv) {
            showAdvanced = !showAdvanced;
        }
        if (showAdvanced) {
            if (!drawAdvOnTop)
                DrawAdvancedScrubberExtras(ps, btnWidth);
            else if (toggleAdv) {
                // draw an empty line when we toggle to avoid flash
                UI::AlignTextToFramePadding();
                UI::Text("");
            }
        }

        if (startedScrub) {
            scrubberMgr.StartScrubWatcher();
        }

        if (expand) {
            if (S_ShowWindow && !UI::IsOverlayShown()) {
                UI::ShowOverlay();
            } else {
                S_ShowWindow = !S_ShowWindow;
                if (S_ShowWindow && !UI::IsOverlayShown()) {
                    UI::ShowOverlay();
                }
            }
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
        // } else if (dragDelta.y > 0) {
        //     float dragY = Math::Clamp(dragDelta.y, -100., 100.);
        //     print('' + dragY);
        //     float sign = dragY >= 0 ? 1.0 : -1.0;
        //     dragY = Math::Max(1, Math::Abs(dragY));
        //     auto dyl = sign * Math::Pow(Math::Log(dragY) / Math::Log(100.), 10.);
        //     scrubberMgr.SetPlaybackSpeed(dyl, !scrubberMgr.IsPaused);
        } else if (clickTogglePause) {
            // makes pausing smoother
            // t += 10 * scrubberMgr.playbackSpeed;
            scrubberMgr.TogglePause(scrubberMgr.pauseAt + 10 * scrubberMgr.playbackSpeed);
        } else if ((t == 0. && t != setProg) || (t > 0. && Math::Abs(t - setProg) / t * 1000. >= 1.0)) {
            // trace('t and setProg different: ' + vec2(t, setProg).ToString());
            scrubberMgr.SetProgress(setProg);
            t = setProg;
        }
        if (changeCurrSpeed || currSpeedBw) {
            scrubberMgr.CyclePlaybackSpeed(currSpeedBw);
        }
    }
    UI::End();
    UI::PopStyleColor(5);

    UI::PopFont();
}

int m_NewGhostOffset = 0;
uint lastSetGhostOffset = 0;
bool m_UseAltCam = false;
bool m_KeepGhostsWhenOffsetting = true;

void DrawAdvancedScrubberExtras(CSmArenaRulesMode@ ps, float btnWidth) {
    bool clickCamera = UI::Button(Icons::Camera + "##scrubber-toggle-cam", vec2(btnWidth, 0));
    bool rmbCamera = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
    AddSimpleTooltip("While spectating, cycle between cimenatic cam, free cam, and the player camera.");
    UI::SameLine();
    bool clickCycleCams = UI::Button(CurrCamLabel() + "##scrubber-spec-cam", vec2(btnWidth, 0));
    AddSimpleTooltip("Force the camera you spectate ghosts with (1, 2, 3) -- does not override mediatracker.");
    if (UI::BeginPopupContextItem("ctx-ghost-cams")) {
        if (UI::MenuItem("None", "", S_SpecCamera == ScrubberSpecCamera::None)) S_SpecCamera = ScrubberSpecCamera::None;
        if (UI::MenuItem("Cam1", "", S_SpecCamera == ScrubberSpecCamera::Cam1)) S_SpecCamera = ScrubberSpecCamera::Cam1;
        if (UI::MenuItem("Cam2", "", S_SpecCamera == ScrubberSpecCamera::Cam2)) S_SpecCamera = ScrubberSpecCamera::Cam2;
        if (UI::MenuItem("Cam3", "", S_SpecCamera == ScrubberSpecCamera::Cam3)) S_SpecCamera = ScrubberSpecCamera::Cam3;
        if (UI::MenuItem("BW", "", S_SpecCamera == ScrubberSpecCamera::BW)) S_SpecCamera = ScrubberSpecCamera::BW;
        UI::EndPopup();
    }
    UI::BeginDisabled(S_SpecCamera == ScrubberSpecCamera::None);
    // UI::SameLine();
    // m_UseAltCam = UI::Checkbox("Alt", m_UseAltCam);
    UI::EndDisabled();
    UI::SameLine();
    UI::Dummy(vec2(10, 0));
    UI::SameLine();
    UI::AlignTextToFramePadding();
    UI::Text("Set Ghosts Offset");
    AddSimpleTooltip("This can be used to exceed the usual limits on ghosts.");
    UI::SameLine();
    UI::SetNextItemWidth(btnWidth * 3.0);
    m_NewGhostOffset = UI::InputInt("##set-ghost-offset", m_NewGhostOffset, lastLoadedGhostRaceTime == 0 ? 10000 : Math::Min(lastLoadedGhostRaceTime / 10, 60000));
    m_NewGhostOffset = Math::Clamp(m_NewGhostOffset, 0, lastLoadedGhostRaceTime == 0 ? 9999999 : (lastLoadedGhostRaceTime * 2));
    UI::SameLine();
    bool clickSetOffset = UI::Button("Set Offset: " + Time::Format(m_NewGhostOffset));
    UI::SameLine();
    m_KeepGhostsWhenOffsetting = UI::Checkbox("Keep Existing?", m_KeepGhostsWhenOffsetting);
    UI::SameLine();
    UI::Dummy(vec2(10, 0));

    if (clickCycleCams) {
        S_SpecCamera =
            S_SpecCamera == ScrubberSpecCamera::None ? ScrubberSpecCamera::Cam1
            : S_SpecCamera == ScrubberSpecCamera::Cam1 ? ScrubberSpecCamera::Cam2
            : S_SpecCamera == ScrubberSpecCamera::Cam2 ? ScrubberSpecCamera::Cam3
            : S_SpecCamera == ScrubberSpecCamera::Cam3 ? ScrubberSpecCamera::BW
            : ScrubberSpecCamera::None
            ;
    } else if (clickCamera || rmbCamera) {
        bool fwd = !rmbCamera;
        auto cam = ps.UIManager.UIAll.SpectatorForceCameraType;
        auto newCam = cam;
        // we use 0x3 instead of 0x1 b/c it's the same but avoids ghost scrubber blocking our calls to Ghosts_SetStartTime
        if (cam == 0) newCam = fwd ? 2 : 3;
        if (cam == 1) newCam = fwd ? 0 : 2;
        if (cam == 2) newCam = fwd ? 3 : 0; // cam7 / free
        if (cam >= 3) newCam = fwd ? 0 : 2;
        ps.UIManager.UIAll.SpectatorForceCameraType = newCam;
        if (newCam == 2) {
            auto gt = GetApp().CurrentPlayground.GameTerminals[0];
            SetDrivableCamFlag(gt, false);
        }
    } else if (clickSetOffset) {
        startnew(UpdateGhostsSetOffsets);
    }
}

void UpdateGhostsSetOffsets() {
    auto app = GetApp();
    CSmArenaRulesMode@ ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    dictionary seenGhosts;
    auto mgr = GhostClipsMgr::Get(app);
    uint[] instanceIds;
    uint spectatingId = GetCurrentlySpecdGhostInstanceId(ps);
    string spectating;
    for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        auto gm = mgr.Ghosts[i].GhostModel;
        seenGhosts[gm.GhostNickname + "|" + gm.RaceTime] = true;
        auto _id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
        instanceIds.InsertLast(_id);
        if (spectatingId == _id) {
            spectating = gm.GhostNickname + "|" + gm.RaceTime;
        }
    }
    CGameGhostScript@[] ghosts;
    auto cmap = GetApp().Network.ClientManiaAppPlayground;
    for (uint i = 0; i < cmap.DataFileMgr.Ghosts.Length; i++) {
        ghosts.InsertLast(cmap.DataFileMgr.Ghosts[i]);
    }
    for (uint i = 0; i < ps.DataFileMgr.Ghosts.Length; i++) {
        ghosts.InsertLast(ps.DataFileMgr.Ghosts[i]);
    }

    scrubberMgr.ForceUnpause();
    scrubberMgr.SetPlayback();

    for (uint i = 0; i < ghosts.Length; i++) {
        auto g = ghosts[i];
        auto key = string(g.Nickname) + "|" + g.Result.Time;
        bool spectateThisGhost = spectating == key;
        if (spectateThisGhost || seenGhosts.Exists(key)) {
            // this can be quite expensive time-wise
            auto _id = ps.GhostMgr.Ghost_Add(g, S_UseGhostLayer, int(m_NewGhostOffset) * -1);
        }
        if (spectateThisGhost) {
            g_SaveGhostTab.SpectateGhost(mgr.Ghosts.Length - 1);
        }
        yield();
        yield();
        if (GetApp().PlaygroundScript is null) return;
    }
    if (!m_KeepGhostsWhenOffsetting) {
        for (uint i = 0; i < instanceIds.Length; i++) {
            ps.GhostMgr.Ghost_Remove(MwId(instanceIds[i]));
            yield();
            yield();
            if (GetApp().PlaygroundScript is null) return;
        }
    }
    lastSetGhostOffset = m_NewGhostOffset;
}


string CurrCamLabel() {
    return tostring(S_SpecCamera);
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

enum ScrubberSpecCamera {
    None = 0x0, Cam1 = 0x12, Cam2 = 0x13, Cam3 = 0x14, BW = 0x15
}

[Setting category="Camera" name="Force Ghost Camera"]
ScrubberSpecCamera S_SpecCamera = ScrubberSpecCamera::None;


class ScrubberMgr {
    ScrubberMode mode = ScrubberMode::Playback;
    // measured in seconds since ghost start
    double pauseAt = 0;
    float playbackSpeed = 1.0;
    float subSecondOffset = 0.0;

    ScrubberMgr() {
        auto app = GetApp();
        if (app is null) return;
        auto ps = app.PlaygroundScript;
        if (ps is null) return;
        auto mgr = GhostClipsMgr::Get(app);
        if (mgr is null) return;
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
        m_NewGhostOffset = 0;
        lastSetGhostOffset = 0;
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
            Call_Ghosts_SetStartTime(ps, int(newStartTime));
        }
        if (!IsStdPlayback || !unpausedFlag) {
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
        auto app = cast<CTrackMania>(GetApp());
        auto ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (ps is null) return;

        // check for the quit trackmania dialog, if present, reset
        auto nbActiveMenus = app.ActiveMenus.Length;
        if (nbActiveMenus > 0) {
            auto currFrame = app.ActiveMenus[nbActiveMenus - 1].CurrentFrame;
            if (currFrame !is null && currFrame.IdName == "DialogConfirmClose") {
                ResetAll();
            }
        }

        if (IsSpectatingGhost() && S_SpecCamera != ScrubberSpecCamera::None) {
            GameCamera().ActiveCam = uint(S_SpecCamera);
            // GameCamera().AltCam = m_UseAltCam;
        }

        auto mgr = GhostClipsMgr::Get(GetApp());
        // auto specId = GetCurrentlySpecdGhostInstanceId(ps);
        // auto ghost = GhostClipsMgr::GetGhostFromInstanceId(mgr, specId);
        // only set in some branches
        auto newStartTime = ps.Now - int(pauseAt);
        // if (ghost.GhostModel.RaceTime - 100 < int(pauseAt)) {
        //     log_trace('flicker range');
        //     newStartTime -= 100;
        // }
        if (IsPaused) {
            Call_Ghosts_SetStartTime(ps, newStartTime);
        } else if (!unpausedFlag && !isScrubbing && IsCustPlayback) {
            auto td = GhostClipsMgr::AdvanceClipPlayersByDelta(mgr, playbackSpeed);
            if (td.x < 0) {
                pauseAt = ps.Now;
                GhostClipsMgr::PauseClipPlayers(mgr, 0.0);
            } else {
                pauseAt = double(td.x) * 1000.;
                subSecondOffset = pauseAt - Math::Floor(pauseAt);
            }
            Call_Ghosts_SetStartTime(ps, newStartTime);
        } else {
            pauseAt = ps.Now - lastSetStartTime;
        }
    }

    bool isScrubbing = false;
    bool isScrubbingShouldUnpause = false;
    void StartScrubWatcher() {
        if (IsPaused) return;
        isScrubbing = true;
        isScrubbingShouldUnpause = IsStdPlayback;
        if (isScrubbingShouldUnpause)
            DoPause();
        startnew(CoroutineFunc(this.ScrubWatcher));
    }

    protected void ScrubWatcher() {
        while (UI::IsMouseDown(UI::MouseButton::Left)) yield();
        if (isScrubbingShouldUnpause)
            DoUnpause();
        isScrubbing = false;
    }
}

ScrubberMgr@ scrubberMgr = ScrubberMgr();

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
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        UI::Columns(2);
        DrawValLabel(tostring(scrubberMgr.mode), "scrubberMgr.mode");
        DrawValLabel(scrubberMgr.pauseAt, "scrubberMgr.pauseAt");
        DrawValLabel(scrubberMgr.playbackSpeed, "scrubberMgr.playbackSpeed");
        DrawValLabel(scrubberMgr.subSecondOffset, "scrubberMgr.subSecondOffset");
        DrawValLabel(scrubberMgr.unpausedFlag, "scrubberMgr.unpausedFlag");
        DrawValLabel(lastSpectatedGhostRaceTime, "lastSpectatedGhostRaceTime");
        DrawValLabel(lastLoadedGhostRaceTime, "lastLoadedGhostRaceTime");
        if (ps !is null)
            DrawValLabel(ps.Now, "ps.Now");
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
