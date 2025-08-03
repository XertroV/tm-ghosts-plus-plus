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
    Std = 0, Bold = 1, Large = 2, Larger = 3, Mono = 4
}

[Setting category="Scrubber Size / Pos" name="Font Size"]
Font S_FontSize = Font::Large;

[Setting category="Scrubber Size / Pos" name="Show the advanced tools above the scrubber"]
bool S_ForceShowAdvOnTop = false;

[Setting category="Scrubber Size / Pos" name="Always show advanced tools"]
bool S_AlwaysShowAdv = false;

[Setting category="Scrubber Size / Pos" name="After hover hide delay" min=0 max=10000 description="When driving, the scrubber will auto-disappear after this many miliseconds."]
uint S_HoverHideDelay = 2500;

[Setting category="Scrubber Size / Pos" name="Never hide the scrubber" description="Overrides hover hide delay"]
bool S_NeverHideScrubber = false;




bool g_ThrowOnDoPause = false;



UI::Font@ GetCurrFont() {
    if (S_FontSize == Font::Std) return g_fontStd;
    if (S_FontSize == Font::Bold) return g_fontBold;
    if (S_FontSize == Font::Large) return g_fontLarge;
    if (S_FontSize == Font::Larger) return g_fontLarger;
    if (S_FontSize == Font::Mono) return g_fontMono;
    return g_fontStd;
}

float GetCurrFontSize() {
    if (S_FontSize == Font::Std) return 16.;
    if (S_FontSize == Font::Bold) return 16.;
    if (S_FontSize == Font::Large) return 20.;
    if (S_FontSize == Font::Larger) return 26.;
    if (S_FontSize == Font::Mono) return 16.;
    return 16.;
}


bool IsPauseMenuOpen() {
    auto net = GetApp().Network;
    try {
        return net.PlaygroundClientScriptAPI.IsInGameMenuDisplayed;
    } catch {}
    return false;
}


namespace ScrubberWindow {
    vec2 screen;
    vec2 screenScaled;
    vec2 spacing;
    // frame padding
    vec2 fp;
    vec2 pos;
    vec2 size;
    float ySize;

    const int WindowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize;

    // pushes font, updates variables for screen stuff
    void BeforeRender() {
        UI::PushFont(GetCurrFont());

        screen = vec2(Draw::GetWidth(), Draw::GetHeight());
        screenScaled = screen / UI::GetScale();
        spacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
        fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        ySize = (UI::GetFrameHeightWithSpacing() + spacing.y + fp.y) / UI::GetScale();
        pos = (screenScaled - vec2(S_XWidth * screenScaled.x, ySize)) * vec2(S_ScrubberCenterX ? 0.5 : S_XPosRel, S_YPosRel);
        size = screenScaled * vec2(S_XWidth, 0);
        size.y = ySize;
    }

    void SetUpWindow() {
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
    }

    void AfterWindowEnd() {
        UI::PopStyleColor(5);
        UI::PopFont();
    }
}


void DrawInputsForVisId(uint targetVisId) {
    CSceneVehicleVis@[] viss = VehicleState::GetAllVis(GetApp().GameScene);
    CSceneVehicleVis@ found;
    for (uint i = 0; i < viss.Length; i++) {
        auto vis = viss[i];
        auto visId = Dev::GetOffsetUint32(vis, 0);
        if (visId == targetVisId) {
            @found = vis;
            break;
        }
    }
    if (found !is null) {
        auto inputsSize = vec2(S_InputsHeight * 2, S_InputsHeight) * ScrubberWindow::screen.y;
        auto inputsPos = (ScrubberWindow::screen - inputsSize) * vec2(S_InputsPosX, S_InputsPosY);
        inputsPos += inputsSize;
        nvg::Translate(inputsPos);
        Inputs::DrawInputs(found.AsyncState, inputsSize);
        nvg::ResetTransform();
    }
}


double maxTime = 0.;
double maxTimePre = 0.;
uint lastHover;
bool showAdvanced = false;
uint oneTimeLog = 0;
uint lastDraw_StartTime = 0;

void DrawScrubber() {
    // check visibility before branching for GPS scrubbing
    if (!S_ScrubberWhenOverlayOff && !UI::IsOverlayShown()) return;
    if (!S_ScrubberWhenUIOff && !UI::IsGameUIVisible()) return;
    // we'll need to refer to a bunch of things in the app
    auto app = GetApp();
    // curr pg first -- required for normal and gps scrubbing
    auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
    if (cp is null) return;
    // don't show any scrubber if we're in a menu
    if (IsPauseMenuOpen()) return;

    // if we are in an active GPS clip, we want to show the special GPS scrubber (reduced features)
    if (GPSScrubbing::Active) {
        // trace("GPS Scrubber Active");
        GPSScrubbing::DrawScrubber();
        return;
    }
    // if we're not in a GPS clip, we can proceed with the normal scrubber
    // ... which only works in solo
    auto ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    if (ps is null) return;

    if (S_AutoUnlockTimelineSolo) CheckUpdateAutoUnlockTimelineSolo(ps, app.Editor);

    bool isSpectating = IsSpectatingGhost();

    auto player = cp.Players.Length > 0 ? cast<CSmPlayer>(cp.Players[0]) : null;
    auto playerStartTime = player !is null ? player.StartTime : 0;
    // don't show during finish sequence
    if (ps.UIManager.UIAll.UISequence == CGamePlaygroundUIConfig::EUISequence::Finish) return;
    if (UI::CurrentActionMap() == "MenuInputsMap") return;

    ScrubberWindow::BeforeRender();

    if (S_NeverHideScrubber || scrubberMgr.isScrubbing || (
        // check that we are hovering the scrubber area BUT we are not interacting with another imgui element
        int(app.InputPort.MouseVisibility) == 0 // 0 = Auto; 1 = ForceHidden; 2 = ForceShow
        && Within(UI::GetMousePos() / UI::GetScale(), vec4(ScrubberWindow::pos, ScrubberWindow::size))
    )) {
        lastHover = Time::Now;
    }

    bool showBeforeStart = S_ShowScrubberBeforeStart && (
        (int(ps.StartTime) - ps.Now) > 0
        || uint(playerStartTime) > ps.Now
    );
    bool showScrubber = isSpectating || showBeforeStart || (Time::Now - lastHover) < S_HoverHideDelay;
    auto @mgr = GhostClipsMgr::Get(app);
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
                DrawInputsForVisId(ghostVisId);
#endif
            }
        }
    }

    bool drawAdvOnTop = S_ForceShowAdvOnTop || (ScrubberWindow::pos.y + (ScrubberWindow::ySize * 2.) / UI::GetScale() > ScrubberWindow::screen.y);
    if (drawAdvOnTop && ShowAdvancedTools()) ScrubberWindow::pos.y -= (ScrubberWindow::ySize - (ScrubberWindow::spacing.y + ScrubberWindow::fp.y) / UI::GetScale());

    ScrubberWindow::SetUpWindow();

    if (UI::Begin("scrubber", ScrubberWindow::WindowFlags)) {
        bool ghostsNotVisible = !GetGhostVisibility();

        // if (oneTimeLog < 2) {
        //     warn("OTL: scrubber pauseAt: " + scrubberMgr.pauseAt);
        //     oneTimeLog++;
        // }

        double startTime = Math::Max(playerStartTime, lastGhostsStartOrSpawnTime);
        lastDraw_StartTime = uint(startTime);
        // need double precision everywhere here to avoid last digit flicker (ps.Now is often in the millions)
        double t = (double(ps.Now) - startTime) + double(scrubberMgr.subSecondOffset);
        // auto setProg = UI::ProgressBar(t, vec2(-1, 0), Text::Format("%.2f %%", t * 100));
        auto btnWidth = Math::Lerp(40., 50., Math::Clamp(Math::InvLerp(1920., 3440., ScrubberWindow::screen.x), 0., 1.))
            * (GetCurrFontSize() / 16.) * UI::GetScale();
        auto btnWidthFull = btnWidth + ScrubberWindow::spacing.x;
        float setProg = scrubberMgr.pauseAt;
        // if the scrubber is in the reset position, just use the current time.
        // this can happen when spectating ghosts + unlock timeline at the same time.
        if (scrubberMgr.pauseAt == 0.0) setProg = MaxD(t, -2000.0);
        if (Math::Abs(t - setProg) > 2.0) {
            log_debug('t and setprog differet at init: ' + vec2(t, setProg).ToString() + "; " + ps.Now + ", " + playerStartTime + ", " + lastGhostsStartOrSpawnTime);
            // setProg = t;
        }

        if (ShowAdvancedTools() && drawAdvOnTop) {
            setProg = DrawAdvancedScrubberExtras(ps, btnWidth, isSpectating, setProg);
        }

        bool clickTogglePause = false;


#if DEV
        nvg::StrokeWidth(4.0);
        // DrawDebugRect(UI::GetWindowPos() + UI::GetCursorPos(), vec2(btnWidth, GetCurrFontSize() + fp.y * 2.), c_red);
        nvg::StrokeWidth(2.0);
#endif
        bool expand = UI::Button(Icons::Expand + "##scrubber-expand", vec2(btnWidth, 0));
        UI::SameLine();
        clickTogglePause = DrawPlayPauseButton(btnWidth) || clickTogglePause;
        UI::SameLine();

        auto nbBtns = 4;

        if (lastLoadedGhostRaceTime == 0 && mgr.Ghosts.Length > 0) {
            lastLoadedGhostRaceTime = mgr.Ghosts[0].GhostModel.RaceTime;
        }

        float scrubberWidth = (UI::GetCursorPos().x + UI::GetContentRegionAvail().x - btnWidthFull * nbBtns - ScrubberWindow::spacing.x);
#if DEV
        nvg::StrokeWidth(4.0);
        // DrawDebugRect(UI::GetWindowPos() + UI::GetCursorPos(), vec2(scrubberWidth, GetCurrFontSize() + fp.y * 2.), c_red);
        nvg::StrokeWidth(2.0);
#endif
        UI::SetNextItemWidth(scrubberWidth / UI::GetScale());
        UpdateMaxScrubberTime(ps);
        string labelTime = Time::Format(int64(Math::Max(t, setProg) + lastSetGhostOffset));
        if (t < 0) labelTime = "-" + labelTime;
        auto fmtString = labelTime + " / " + Time::Format(int64(maxTime + lastSetGhostOffset))
            + (ghostsNotVisible ? " (Ghosts Off)" : "")
            ;
        float minTime = Math::Min(0.0, float(int(ps.Now)) - float(playerStartTime) - 10.0);
        minTime = Math::Max(minTime, -1600.0); // we don't expect the player to have a curr time < -1.5s since that is the start delay.
        auto progBefore = setProg;
        setProg = UI::SliderFloat("##ghost-scrub", setProg, minTime, Math::Max(maxTime, t), fmtString, UI::SliderFlags::NoInput);
        bool startedScrub = UI::IsItemClicked();
        clickTogglePause = (UI::IsItemHovered() && !scrubberMgr.isScrubbing && UI::IsMouseClicked(UI::MouseButton::Right)) || clickTogglePause;
        // if we hold left shift while scrubbing, it'll go slower:
        if (progBefore != setProg && scrubberMgr.isScrubbing && UI::IsKeyDown(UI::Key::LeftShift)) {
            setProg = (setProg - progBefore) * 0.1 + progBefore;
        }

        UI::SameLine();
        bool changeCurrSpeed = UI::Button(currSpeedLabel + "##scrubber-next-speed", vec2(btnWidth, 0));
        bool currSpeedBw = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
        // bool currSpeedCtx = UI::IsItemHovered() && UI::IsMouseDown(UI::MouseButton::Middle);

        UI::SameLine();

        // bool clickCamera = UI::Button(Icons::Camera + "##scrubber-toggle-cam", vec2(btnWidth, 0));
        UI::BeginDisabled(S_AlwaysShowAdv);
        bool toggleAdv = UI::Button(Icons::Cogs + "##scrubber-toggle-adv", vec2(btnWidth, 0));
        UI::EndDisabled();

#if DEV
        // dev label below
        UI::PushFont(g_fontMono);
        UI::Text("[DEV] lsgrt:" + lastSpectatedGhostRaceTime
            + ", llgrt:" + lastLoadedGhostRaceTime
            + ", lsst:" + lastSetStartTime
            + ", lgsost:" + lastGhostsStartOrSpawnTime
            + ", startTime: " + int64(startTime)
            + ", mtp:" + maxTimePre
            + ", pauseAt: " + scrubberMgr.pauseAt
            + ", setProg: " + setProg
            + ", ps.Now: " + ps.Now
            + ", isScb'g: " + scrubberMgr.isScrubbing
            );
        // g_ThrowOnDoPause = UI::Checkbox("Throw on DoPause", g_ThrowOnDoPause);
        UI::PopFont();
#endif

        bool shouldSoftenEngineSounds = scrubberMgr.IsPaused || scrubberMgr.playbackSpeed <= 0.5 || scrubberMgr.isScrubbing;
        if (shouldSoftenEngineSounds && S_SoftenEngineSounds) {
            if (EngineSounds::Apply()) EngineSounds::SetEngineSoundVdB_SpawnCoro_Debounced((Math::Clamp(scrubberMgr.playbackSpeed, 0.1, 0.8) - 0.1));
        } else {
            EngineSounds::Unapply();
        }

        if (toggleAdv) {
            showAdvanced = !showAdvanced;
        }
        if (ShowAdvancedTools()) {
            if (!drawAdvOnTop)
                setProg = DrawAdvancedScrubberExtras(ps, btnWidth, isSpectating, setProg);
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
        // } else if (dragDelta.y > 0) {
        //     float dragY = Math::Clamp(dragDelta.y, -100., 100.);
        //     print('' + dragY);
        //     float sign = dragY >= 0 ? 1.0 : -1.0;
        //     dragY = Math::Max(1, Math::Abs(dragY));
        //     auto dyl = sign * Math::Pow(Math::Log(dragY) / Math::Log(100.), 10.);
        //     scrubberMgr.SetPlaybackSpeed(dyl, !scrubberMgr.IsPaused);
        if (clickTogglePause && !scrubberMgr.isScrubbing) {
            // makes pausing smoother
            // t += 10 * scrubberMgr.playbackSpeed;
            scrubberMgr.TogglePause(scrubberMgr.pauseAt + 5.0 * scrubberMgr.playbackSpeed);
        } else if (lastSetStartTime < 0 && !scrubberMgr.isScrubbing) {
            // do nothing b/c auto time, but update pauseAt so scrubber shows time correctly
            scrubberMgr.pauseAt = t;
        } else if (((t*setProg == 0. && t != setProg) || (t > 0.)) && Math::Abs(t - setProg) > 0.01f) {
            // check if we have a new setProg; or t/setProg is 0
            log_debug('t and setProg different: ' + vec2(t, setProg).ToString() + "; " + ps.Now + ", " + playerStartTime + ", " + lastGhostsStartOrSpawnTime);
            scrubberMgr.SetProgress(setProg, scrubberMgr.isScrubbing);
            t = setProg;
        }
        if (changeCurrSpeed || currSpeedBw) {
            scrubberMgr.CyclePlaybackSpeed(currSpeedBw);
        }

        // update hover with actual window size to cover advanced being open

        auto wpos = UI::GetWindowPos();
        auto wsize = UI::GetWindowSize();
        if (Within(UI::GetMousePos(), vec4(wpos, wsize))) {
#if DEV
            DrawDebugRect(wpos, wsize, c_red);
            DrawDebugCircle(UI::GetMousePos(), vec2(10.), c_green);
#endif
            lastHover = Time::Now;
        }
    }
    UI::End();
    ScrubberWindow::AfterWindowEnd();
}

bool DrawPlayPauseButton(float btnWidth) {
    return UI::Button((scrubberMgr.IsPaused ? Icons::Play : Icons::Pause) + "##scrubber-toggle", vec2(btnWidth, 0));
}

bool DrawResetButton(float btnWidth) {
    return UI::Button(Icons::Refresh + "##scrubber-toggle", vec2(btnWidth, 0));
}

int m_NewGhostOffset = 0;
uint lastSetGhostOffset = 0;
bool m_UseAltCam = false;
bool m_KeepGhostsWhenOffsetting = true;

float DrawAdvancedScrubberExtras(CSmArenaRulesMode@ ps, float btnWidth, bool isSpectating, float setProg) {
    // 0: cinematic?, 1: normal, 2: freecam
    auto forcedCamType = ps.UIManager.UIAll.SpectatorForceCameraType;

    UI::BeginDisabled(!isSpectating);
    bool exit = UI::Button(Icons::Reply + "##scrubber-back", vec2(btnWidth, 0));
    UI::EndDisabled();
    UI::SameLine();
    bool reset = DrawResetButton(btnWidth);
    UI::SameLine();
    bool stepBack = UI::Button(scrubberMgr.IsPaused ? Icons::StepBackward : Icons::Backward + "##scrubber-step-back", vec2(btnWidth, 0));
    UI::SameLine();
    bool stepFwd = UI::Button((scrubberMgr.IsPaused ? Icons::StepForward : Icons::Forward) + "##scrubber-step-fwd", vec2(btnWidth, 0));
    UI::SameLine();
    bool clickCamera = UI::Button(ScrubCameraModeIcon(forcedCamType) + "##scrubber-toggle-cam", vec2(btnWidth, 0));
    bool rmbCamera = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
    AddSimpleTooltip("While spectating, cycle between cinematic cam, free cam, and the player camera.");
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
    DrawUnlockTimelineButton(ps);
    // UI::SameLine();
    // S_AutoUnlockTimelineSolo = UI::Checkbox("Auto-Unlock", S_AutoUnlockTimelineSolo);
    // AddSimpleTooltip("Automatically unlock the timeline when you load a map.\n\n\\$iNote: 'unlock timeline' button is disabled while you are driving.");
    UI::SameLine();
    DrawGhostOpacityControls();

    bool clickSetOffset = false;
    if (!S_HideSetOffset) {
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
        clickSetOffset = UI::Button("Set Offset: " + Time::Format(m_NewGhostOffset));
        UI::SameLine();
        m_KeepGhostsWhenOffsetting = UI::Checkbox("Keep Existing?", m_KeepGhostsWhenOffsetting);
        UI::SameLine();
        UI::Dummy(vec2(10, 0));
    }
    // UI::SameLine();

    if (exit) {
        scrubberMgr.SetPlayback();
        ExitSpectatingGhostAndCleanUp();
    }
    if (reset) setProg = 0.0001;
    if (stepBack || stepFwd) {
        if (scrubberMgr.IsPaused) {
            float progDelta = 10.0 * Math::Abs(scrubberMgr.playbackSpeed);
            // auto newT = t + progDelta * (stepBack ? -1. : 1.);
            // trace('newT: ' + newT + '; t: ' + t + "; diff: " + (newT - t) + ' pauseat: ' + scrubberMgr.pauseAt);
            scrubberMgr.SetPaused(scrubberMgr.pauseAt + progDelta * (stepBack ? -1. : 1.), true);
        } else {
            scrubberMgr.SetProgress(scrubberMgr.pauseAt + 5000.0 * Math::Abs(scrubberMgr.playbackSpeed) * (stepBack ? -1. : 1.));
        }
    }
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
        auto newCam = forcedCamType;
        // we use 0x3 instead of 0x1 b/c it's the same but avoids ghost scrubber blocking our calls to Ghosts_SetStartTime
        if (forcedCamType == 0) newCam = fwd ? 2 : 3; // cinematic
        if (forcedCamType == 1) newCam = fwd ? 0 : 2; // normal
        if (forcedCamType == 2) newCam = fwd ? 3 : 0; // cam7 / free
        if (forcedCamType >= 3) newCam = fwd ? 0 : 2; // normal (3) or unknown ( gt 3 )
        ps.UIManager.UIAll.SpectatorForceCameraType = lastSetForcedCamera = newCam;
        if (newCam == 2) {
            auto gt = GetApp().CurrentPlayground.GameTerminals[0];
            SetDrivableCamFlag(gt, false);
        }
    } else if (clickSetOffset) {
        startnew(UpdateGhostsSetOffsets);
    }

    return setProg;
}

bool ShowAdvancedTools() {
    return showAdvanced || S_AlwaysShowAdv;
}

string ScrubCameraModeIcon(int forcedCamType) {
    if (forcedCamType == 0) return Icons::VideoCamera;
    if (forcedCamType == 2) return Icons::Arrows;
    return Icons::Camera;
}

uint lastSetForcedCamera = 1;

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
    if (Math::Abs(scrubberMgr.playbackSpeed) < 0.5)
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
    // measured in ms since ghost start
    double pauseAt = 0;
    float playbackSpeed = 1.0;
    float subSecondOffset = 0.0;

    ScrubberMgr() {
        startnew(CoroutineFunc(this.InitScrubberMgr));
    }

    void InitScrubberMgr() {
        auto app = GetApp();
        if (app is null) return;
        auto ps = app.PlaygroundScript;
        if (ps is null) return;
        auto mgr = GhostClipsMgr::Get(app);
        if (mgr is null) return;
        auto lastGhostStartTime = GhostClipsMgr::GetCurrentGhostTime(mgr);
        if (lastGhostStartTime > 0) pauseAt = ps.Now - lastGhostStartTime;
        log_debug("ScubberMgr init pauseAt: " + pauseAt);
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
        // trace("Scrubber: ResetAll");
        m_NewGhostOffset = 0;
        lastSetGhostOffset = 0;
        pauseAt = 0;
        isScrubbing = false;
        isScrubbingShouldUnpause = false;
        _pbSpeed = PlaybackSpeeds::x1;
        SetPlaybackSpeed(1.0, true);
        if (IsPaused) TogglePause(0);
        ForceUnpause();
        SetProgress(-1);
        DoUnpause();
        // warn("Reset, playback speed: " + Text::Format("%.7f", playbackSpeed));
        NoFlashCar::IsApplied = false;
        KinematicsControl::IsApplied = false;
        CameraPolish::Hook_CameraUpdatePos.Unapply();
    }

    void ForceUnpause() {
        if (!IsPaused) return;
        TogglePause(pauseAt);
    }

    void TogglePause(double setProg) {
        trace("TogglePause: " + setProg);
        pauseAt = setProg;
        if (IsPaused) {
            mode = playbackSpeed == 1.0 ? ScrubberMode::Playback : ScrubberMode::CustomSpeed;
            if (IsStdPlayback) DoUnpause();
        } else {
            SetPaused(setProg, true);
        }
    }

    void SetProgress(double setProg, bool allowEasing = false) {
        // trace("SetProgress: " + setProg);
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        // disable easing for long ghosts (bad experience)
        allowEasing = allowEasing && MaxTime < 300. * 1000.;
        // Either A: update pauseAt directly, or B: smoothly approach it
        // A: pauseAt = setProg;
        // B:
        if (allowEasing && S_ApplyScrubEasing) {
            auto diff = setProg - pauseAt;
            diff = diff < 0.0 ? -diff : diff;
            // milliseconds
            if (diff > 0.01) {
                auto decay = S_ScrubEasingDecay;
                if (setProg <= 0.0) decay *= 4.0;
                pauseAt = SmoothFollow(pauseAt, setProg, g_DT_sec, decay);
            } else {
                pauseAt = setProg;
            }
        } else {
            pauseAt = setProg;
        }

        // setting to -1 will sync to player
        auto newStartTime = setProg >= 0.0 ? ps.Now - pauseAt : -1.0; // pauseAt == 0.0 ? -1.0;
        if (pauseAt < 0.0) pauseAt = 0.0;
        if (ps !is null) {
            Call_Ghosts_SetStartTime(ps, int(newStartTime));
        }
        if (!IsStdPlayback || !unpausedFlag) {
            log_debug("pause via setprog: " + IsStdPlayback + ", " + unpausedFlag);
            auto mgr = GhostClipsMgr::Get(GetApp());
            if (mgr !is null) GhostClipsMgr::PauseClipPlayers(mgr, pauseAt / 1000.);
            else log_debug("ScrubberMgr::SetProgress: mgr is null !?");
        } else {
            // auto mgr = GhostClipsMgr::Get(GetApp());
            // GhostClipsMgr::UnpauseClipPlayers(mgr, pauseAt / 1000.);
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
        log_debug("DoUnpause");
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        GhostClipsMgr::UnpauseClipPlayers(mgr, pauseAt / 1000., float(GhostClipsMgr::GetMaxGhostDuration(mgr)) / 1000.);
        unpausedFlag = true;
    }
    void DoPause() {
        log_debug("DoPause");
        // if (g_ThrowOnDoPause) throw("g_ThrowOnDoPause");
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        GhostClipsMgr::PauseClipPlayers(mgr, pauseAt / 1000.);
        unpausedFlag = false;
    }

    void SetPaused(double pgGhostProgTime, bool setMode = false) {
        log_debug("SetPaused: " + pgGhostProgTime);
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
        else if (_pbSpeed == PlaybackSpeeds::x4) SetPlaybackSpeed(4.0, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_01) SetPlaybackSpeed(0.01, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_1) SetPlaybackSpeed(0.1, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_3) SetPlaybackSpeed(0.3, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_5) SetPlaybackSpeed(0.5, !IsPaused);
        else if (_pbSpeed == PlaybackSpeeds::x0_7) SetPlaybackSpeed(0.7, !IsPaused);
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

        bool isSpectating = IsSpectatingGhost();
        if (isSpectating && S_SpecCamera != ScrubberSpecCamera::None) {
            GameCamera().ActiveCam = uint(S_SpecCamera);
            // GameCamera().AltCam = m_UseAltCam;
        }

        if (!isSpectating) {
            lastSetForcedCamera = 1;
            lastSpectatedGhostInstanceId.Value = uint(-1);
        }


        auto mgr = GhostClipsMgr::Get(app);
        // auto specId = GetCurrentlySpecdGhostInstanceId(ps);
        // auto ghost = GhostClipsMgr::GetGhostFromInstanceId(mgr, specId);
        // only set in some branches
        auto newStartTime = ps.Now - int(pauseAt);

        // if we're spectating a ghost, update kinematics time
        KinematicsControl::IsApplied = isSpectating;
        if (isSpectating) {
            auto currDur = ps.Now - newStartTime;
            if (currDur > 0) {
                KinematicsControl::SetKinematicsTime(app, currDur);
            }
        }

        // the patch needs to be async otherwise the function won't be found (since we are running out of MLHook context)
        CameraPolish::Hook_CameraUpdatePos.SetAppliedSoon(isSpectating);
        NoFlashCar::IsApplied = (pauseAt > 50.0) && (IsPaused || (!unpausedFlag)); //  && 0.0 < playbackSpeed && playbackSpeed < 0.4

        if (IsPaused || isScrubbing) {
            Call_Ghosts_SetStartTime(ps, newStartTime);
        } else if (!unpausedFlag && !isScrubbing && IsCustPlayback) {
            auto td = GhostClipsMgr::AdvanceClipPlayersByDelta(mgr, playbackSpeed);
            if (td.x < 0) {
                pauseAt = 0.0;
                DoPause();
                log_debug("td.x < 0: setting pause to ps.Now: " + pauseAt);
            } else {
                pauseAt = double(td.x) * 1000.;
                subSecondOffset = pauseAt - Math::Floor(pauseAt);
                log_debug("td.x >= 0: setting pause to: " + pauseAt);
            }
            Call_Ghosts_SetStartTime(ps, newStartTime);
        } else {
            if (lastGhostsStartOrSpawnTime > 0 && lastSetStartTime > 0) {
                pauseAt = ps.Now - Math::Min(ps.Now, lastGhostsStartOrSpawnTime);
                if (false) {
                    log_debug("lastGhostsStartOrSpawnTime: " + lastGhostsStartOrSpawnTime);
                    log_debug("lastSetStartTime: " + lastSetStartTime);
                    log_debug("setting pause at at end of scrubber update loop: " + pauseAt);
                }
            }
        }
    }

    bool isScrubbing = false;
    bool isScrubbingShouldUnpause = false;
    // enable smooth scrubbing
    void StartScrubWatcher() {
        // if (IsPaused) return;
        isScrubbing = true;
        isScrubbingShouldUnpause = IsStdPlayback;
        if (isScrubbingShouldUnpause) DoPause();
        startnew(CoroutineFunc(this.ScrubWatcher));
    }

    protected void ScrubWatcher() {
        while (UI::IsMouseDown(UI::MouseButton::Left)) yield();
        if (isScrubbingShouldUnpause)
            DoUnpause();
        isScrubbing = false;
    }

    // returns units in milliseconds
    float get_MaxTime() {
        return maxTime;
    }
}

ScrubberMgr@ scrubberMgr = ScrubberMgr();

enum PlaybackSpeeds {
    x4 = 0, x2, x1, x0_7, x0_5, x0_3, x0_1, x0_01,
    nx0_01, nx0_1, nx0_5, nx1, nx2, nx4,
    LAST,
}

void ML_PG_Callback(ref@ r) {
    if (scrubberMgr is null) return;
    if (GetApp().CurrentPlayground is null) return;
    GPSScrubbing::Update();
    if (GetApp().PlaygroundScript is null) return;
    scrubberMgr.Update();
}




double UpdateMaxScrubberTime(CSmArenaRulesMode@ ps = null, bool resetBeforeUpdate = false) {
    if (resetBeforeUpdate) {
        maxTime = 0.0;
    }
    maxTime = Math::Max(maxTime, lastSpectatedGhostRaceTime + 60);
    maxTime = Math::Max(maxTime, lastLoadedGhostRaceTime + 60);
    maxTimePre = maxTime;
    // maxTime = Math::Max(maxTime, scrubberMgr.pauseAt);
    if (ps !is null) {
        maxTime = Math::Min(maxTime, double(ps.Now));
    }
    return maxTime;
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
        DrawValLabel(lastDraw_StartTime, "lastDraw_StartTime");
        if (ps !is null)
            DrawValLabel(ps.Now, "ps.Now");
        UI::Columns(1);
    }
}

bool Within(vec2 &in pos, vec4 &in rect) {
    return pos.x >= rect.x && pos.x < (rect.x + rect.z)
        && pos.y >= rect.y && pos.y < (rect.y + rect.w);
}

double MaxD(double a, double b) {
    return a > b ? a : b;
}
