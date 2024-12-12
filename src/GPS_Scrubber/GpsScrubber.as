namespace GPSScrubbing {
    float _debugSetTimeTo = 10.0;
    bool _debugKeepRequestingSetTime = false;

    void DrawScrubber() {
        auto clipPlayer = GetCurrPgMediaClipPlayer(GetApp());

#if DEV
        // Draw_Debug_GpsScrubber(clipPlayer);
#endif

        ScrubberWindow::BeforeRender();
        ScrubberWindow::SetUpWindow();
        if (UI::Begin("gpsscrub", ScrubberWindow::WindowFlags)) {
            DrawGpsScrubber_Inner(clipPlayer);
        }
        UI::End();
        ScrubberWindow::AfterWindowEnd();

        // inputs maybe
        bool showInputs = S_ShowInputsWhileSpectatingGhosts
            && (UI::IsGameUIVisible() || S_ShowInputsWhenUIHidden)
            ;
        if (showInputs) {
            auto visId = GameCamera().CurrVehicleVisId;
            if (visId < 0x0F000000 && visId & 0x04000000 != 0) {
                DrawInputsForVisId(visId);
            }
        }

    }

    float _lastScrub_t = 0;
    float _lastScrub_max = 0;

    void DrawGpsScrubber_Inner(CGameCtnMediaClipPlayer@ clipPlayer) {
        double startTime = ClipPlayer_GetStartTime(clipPlayer);
        uint pgNow = Network_GetPlaygroundTime();
        double t = pgNow - startTime;
        float scrubberWidth = UI::GetContentRegionAvail().x;
        float setWidth = scrubberWidth / UI::GetScale();
        UI::SetNextItemWidth(setWidth);
        int64 maxTime = int64(ActiveClipDuration * 1000.0);
        string labelTime = Time::Format(int64(Math::Abs(t)));
        if (t < 0) labelTime = "-" + labelTime;
        auto fmtString = labelTime + " / " + Time::Format(maxTime);
        float t_ms = t;
        _lastScrub_t = t_ms;
        _lastScrub_max = maxTime;
        auto setProg = UI::SliderFloat("##scrb-gps", t_ms, 0.0, float(maxTime), fmtString, UI::SliderFlags::NoInput);
        bool startedScrub = UI::IsItemClicked();
        if (startedScrub || setProg != t_ms) {
            auto setProgUint = uint(setProg);
            if (setProgUint > pgNow) setProgUint = pgNow;
            auto newStartTime = pgNow - setProgUint;
            ClipPlayer_SetStartTime(clipPlayer, newStartTime);
            // we need to do this too to avoid glitchy/framey scrubbing while holding down a value.
            GPSScrubbing::RequestSetClipPlayerTime(setProg / 1000.0);
        }
    }

    void Draw_Debug_GpsScrubber(CGameCtnMediaClipPlayer@ clipPlayer) {
        if (UI::Begin("GPS Scrubber", UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text("-- GPS SCRUBBER WOULD BE ACTIVE --");
            UI::Text("Active: " + (Active ? "Yes" : "No"));
            UI::Text("_clipTimeToSet: " + _clipTimeToSet);
            UI::Text("_hasClipTimeToSet: " + _hasClipTimeToSet);
            UI::Text("Duration: " + ActiveClipDuration + " s");

            UI::Text("_lastScrub_t" + _lastScrub_t);
            UI::Text("_lastScrub_max" + _lastScrub_max);

            if (clipPlayer is null) {
                UI::Text("No clip player");
            } else {
                UI::Text(_debug_AfterUpdateMTClipCurrTime_ClipDebug);
                UI::Text(string::Join(GetGhostClipPlayerDebugValues(clipPlayer), " "));
                _debugSetTimeTo = UI::InputFloat("Set time to", _debugSetTimeTo, 0.25);
                _debugSetTimeTo = Math::Clamp(_debugSetTimeTo, 0.0, ActiveClipDuration);

                UI::Text("_clipTimeToSet: " + _clipTimeToSet);
                UI::Text("_hasClipTimeToSet: " + _hasClipTimeToSet);

                // if (UI::Button("Pause")) {
                //     SetGhostClipPlayerPaused(clipPlayer, _debugSetTimeTo);
                // }
                if (UI::Button("Set time")) {
                    RequestSetClipPlayerTime(_debugSetTimeTo);
                    // ClipPlayer_SetCurrSeconds(clipPlayer, _debugSetTimeTo);
                    // ClipPlayer_SetCurrSeconds2(clipPlayer, _debugSetTimeTo);
                    // ClipPlayer_SetCurrSeconds3(clipPlayer, _debugSetTimeTo);
                }
                UI::SameLine();
                _debugKeepRequestingSetTime = UI::Checkbox("Auto-set time", _debugKeepRequestingSetTime);
                if (_debugKeepRequestingSetTime) {
                    RequestSetClipPlayerTime(_debugSetTimeTo);
                }

                UI::Text(string::Join(GetGhostClipPlayerDebugValues(clipPlayer), " "));
            }
        }
        UI::End();

    }

    void Update() {
        return;
        // if (!Active) return;
        // auto clipPlayer = GetCurrPgMediaClipPlayer(GetApp());
        // if (clipPlayer is null) return;
        // auto time = TakeClipPlayerTimeToSet();
        // ClipPlayer_SetCurrSeconds(clipPlayer, time);
        // ClipPlayer_SetCurrSeconds2(clipPlayer, time);
        // ClipPlayer_SetCurrSeconds3(clipPlayer, time);
    }
}



uint Network_GetPlaygroundTime() {
    auto pcsapi = GetApp().Network.PlaygroundClientScriptAPI;
    if (pcsapi is null) return 0;
    return pcsapi.GameTime;
}
