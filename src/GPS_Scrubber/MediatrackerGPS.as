FunctionHookHelper@ Hook_UpdateMediatrackerClipCurrentTime = FunctionHookHelper(
    "F3 0F ?? ?? F3 0F ?? ?? E8 ?? ?? ?? ?? 0F 2F", 8, 0, "After_UpdateMTClipCurrTime", Dev::PushRegisters::SSE, true
);

string _debug_AfterUpdateMTClipCurrTime_ClipDebug = "";
void After_UpdateMTClipCurrTime(CMwNod@ rbx) {
    if (!GPSScrubbing::Active) return;
    if (GPSScrubbing::ShouldSetClipPlayerTime()) {
        if (rbx is null) warn("rbx null");
        auto clipPlayer = cast<CGameCtnMediaClipPlayer>(rbx);
        if (clipPlayer is null) warn("clipPlayer null");
        _debug_AfterUpdateMTClipCurrTime_ClipDebug = string::Join(GetGhostClipPlayerDebugValues(clipPlayer), " ");
        ClipPlayer_SetCurrSeconds3(clipPlayer, GPSScrubbing::TakeClipPlayerTimeToSet());
    }
}


[Setting category="GPS Scrubber" name="Enable scrubber when watching GPS?"]
bool S_EnableGPSScrubbing = true;

void OnUpdatedGpsScrubbingSetting() {
    Hook_UpdateMediatrackerClipCurrentTime.SetApplied(S_EnableGPSScrubbing);
    if (!S_EnableGPSScrubbing) {
        GPSScrubbing::_SetActiveClip(null);
    }
}

namespace GPSScrubbing {
    CGameCtnMediaClip@ _activeClip;
    bool _lastActiveClipWasGPS;
    float _activeClipDuration;

    void _SetActiveClip(CGameCtnMediaClip@ clip) {
        if (clip is _activeClip) return;
        // update active clip with ref counting
        if (_activeClip !is null) _activeClip.MwRelease();
        @_activeClip = clip;
        if (_activeClip !is null) _activeClip.MwAddRef();
        // update other cached data
        _lastActiveClipWasGPS = CanFindGPSInClip(_activeClip);
        _activeClipDuration = Clip_GetDuration(_activeClip);
#if DEV
        trace("Active clip: " + (_lastActiveClipWasGPS ? "GPS" : "No GPS") + " | " + _activeClipDuration + "ms");
#endif
    }

    bool get_Active() {
        if (!S_EnableGPSScrubbing) return false;
        auto app = GetApp();
        if (!CheckMapHasGPS(app.RootMap)) return false;
        if (!IsPlayerDriving()) return false;
        auto clipPlayer = GetCurrPgMediaClipPlayer(app);
        if (clipPlayer is null) return false;
        auto clip = clipPlayer.Clip;
        if (clip is null) return false;
        if (ClipPlayer_GetTimeSpeed3(clipPlayer) == 0.0) {
            _SetActiveClip(null);
            return false;
        }
        if (clip is _activeClip) return _lastActiveClipWasGPS;
        _SetActiveClip(clip);
        return _lastActiveClipWasGPS;
    }

    CGameCtnMediaClipPlayer@ GetCurrPgMediaClipPlayer(CGameCtnApp@ app) {
        if (app.CurrentPlayground is null) return null;
        if (app.CurrentPlayground.GameTerminals.Length < 1) return null;
        return app.CurrentPlayground.GameTerminals[0].MediaClipPlayer;
    }

    bool _hasClipTimeToSet = false;
    float _clipTimeToSet = 0;

    bool ShouldSetClipPlayerTime() {
        return _hasClipTimeToSet;
    }

    float TakeClipPlayerTimeToSet() {
        _hasClipTimeToSet = false;
        return _clipTimeToSet;
    }

    void RequestSetClipPlayerTime(float time) {
        _hasClipTimeToSet = true;
        _clipTimeToSet = time;
    }

    float ActiveClipDuration {
        get {
            return _activeClipDuration;
        }
    }

    float Clip_GetDuration(CGameCtnMediaClip@ clip) {
        if (clip is null) return 0;
        float maxEnd = 0;
        for (uint i = 0; i < _activeClip.Tracks.Length; i++) {
            auto track = _activeClip.Tracks[i];
            if (track is null || track.Blocks.Length == 0) continue;
            maxEnd = Math::Max(track.Blocks[track.Blocks.Length - 1].End, maxEnd);
        }
        return maxEnd;
    }


    uint _lastMapMwIdVal = 0;
    uint _lastMapAuthorTime = 0;
    bool _lastMapHasGPSCheck = false;

    bool CheckMapHasGPS(CGameCtnChallenge@ map) {
        if (map is null) {
            _lastMapMwIdVal = 0;
            _lastMapHasGPSCheck = false;
            _SetActiveClip(null);
        } else if (map.Id.Value != _lastMapMwIdVal) {
            _lastMapMwIdVal = map.Id.Value;
            _lastMapAuthorTime = map.TMObjective_AuthorTime;
            _lastMapHasGPSCheck = _DoesMapHaveGPS(map);
        }
        return _lastMapHasGPSCheck;
    }

    bool _DoesMapHaveGPS(CGameCtnChallenge@ map) {
        if (map is null) return false;
        return CanFindInGameMTForGPS(map.ClipGroupInGame);
    }

    bool CanFindInGameMTForGPS(CGameCtnMediaClipGroup@ clipGroup) {
        if (clipGroup is null) return false;
        for (uint i = 0; i < clipGroup.Clips.Length; i++) {
            auto clip = clipGroup.Clips[i];
            if (clip is null) continue;
            if (CanFindGPSInClip(clip)) {
                return true;
            }
        }
        return false;
    }

    bool CanFindGPSInClip(CGameCtnMediaClip@ clip) {
        if (clip is null) return false;
        if (string(clip.Name).ToLower().Contains("gps")) {
            return true;
        }
        for (uint i = 0; i < clip.Tracks.Length; i++) {
            auto track = clip.Tracks[i];
            if (track is null) continue;
            //
            bool trackNameIncludesGPS = string(track.Name).ToLower().Contains("gps");
            if (trackNameIncludesGPS) {
                return true;
            }
            //
            if (CanFindGPSInTrack(clip, track)) {
                return true;
            }
        }
        return false;
    }

    bool CanFindGPSInTrack(CGameCtnMediaClip@ clip, CGameCtnMediaTrack@ track) {
        if (track is null) return false;
        for (uint i = 0; i < track.Blocks.Length; i++) {
            auto block = track.Blocks[i];
            if (block is null) continue;
            auto textBlock = cast<CGameCtnMediaBlockText>(block);
            auto entBlock = cast<CGameCtnMediaBlockEntity>(block);
            if (CanFindGPSInTextBlock(textBlock)) {
                return true;
            }
            if (CanFindGPSInEntityBlock(entBlock, clip)) {
                return true;
            }
        }
        return false;
    }

    bool CanFindGPSInTextBlock(CGameCtnMediaBlockText@ block) {
        if (block is null) return false;
        return string(block.Text).ToLower().Contains("gps");
    }

    bool CanFindGPSInEntityBlock(CGameCtnMediaBlockEntity@ block, CGameCtnMediaClip@ clip) {
        if (block is null) return false;
        // ghost nickname at 0x68
        auto nickName = Dev::GetOffsetString(block, 0x68);
        if (string(nickName).ToLower().Contains("gps")) {
            return true;
        }
        float nnAsFloat;
        if (Text::TryParseFloat(nickName, nnAsFloat)) {
            // ghost name is a float, true if <= AT + 5;
            auto ghostTimeLtEqAuthorTime = uint(nnAsFloat) <= _lastMapAuthorTime + 5000;
            if (ghostTimeLtEqAuthorTime) {
                return true;
            }
        }
        // race time at 0x7C
        auto raceTimeLtEqAuthorTime = Dev::GetOffsetUint32(block, 0x7C) <= _lastMapAuthorTime + 5000;
        if (raceTimeLtEqAuthorTime) {
            return true;
        }
        return false;
    }

    uint GetVehicleVisId(CGameCtnMediaBlockEntity@ block) {
        throw('unused');
        // 0x158 ptr -> struct (+0x4 = visId)
        // 0x160 visId+1 ??
        // 0x164 visId+2 ??
        uint64 ptr = Dev::GetOffsetUint64(block, 0x158);
        if (ptr == 0) return 0x0FF00000;
        if (ptr % 8 != 0) return 0x0FF00000;
        if (Dev_PointerLooksBad(ptr)) return 0x0FF00000;
        return Dev::ReadUInt32(ptr + 0x4);
    }
}
