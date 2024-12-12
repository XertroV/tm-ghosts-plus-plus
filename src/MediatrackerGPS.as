FunctionHookHelper@ Hook_UpdateMediatrackerClipCurrentTime = FunctionHookHelper(
    "F3 0F ?? ?? F3 0F ?? ?? E8 ?? ?? ?? ?? 0F 2F", 8, 0, "After_UpdateMTClipCurrTime", Dev::PushRegisters::SSE, true
);

void After_UpdateMTClipCurrTime() {
    if (!GPSScrubbing::Active) return;
}


[Setting category="General" name="Enable scrubber when watching GPS?"]
bool S_EnableGPSScrubbing = true;

namespace GPSScrubbing {
    bool get_Active() {
        if (!S_EnableGPSScrubbing) return false;
        auto app = GetApp();
        if (!CheckMapHasGPS(app.RootMap)) return false;
        if (app.CurrentPlayground is null) return false;
        if (app.CurrentPlayground.GameTerminals.Length < 1) return false;
        auto gt = app.CurrentPlayground.GameTerminals[0];
        auto clip = gt.MediaClipPlayer;
        if (clip is null) return false;
    }


    uint _lastMapMwIdVal = 0;
    bool _lastMapHasGPSCheck = false;

    bool CheckMapHasGPS(CGameCtnChallenge@ map) {
        if (map is null) {
            _lastMapMwIdVal = 0;
            _lastMapHasGPSCheck = false;
        } else if (map.Id.Value != _lastMapMwIdVal) {
            _lastMapMwIdVal = map.Id.Value;
            _lastMapHasGPSCheck = _DoesMapHaveGPS(map);
        }
        return _lastMapHasGPSCheck;
    }

    bool _DoesMapHaveGPS(CGameCtnChallenge@ map) {
        if (map is null) return false;

    }
}
