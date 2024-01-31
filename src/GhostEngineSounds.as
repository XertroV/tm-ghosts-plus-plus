const string CAudioSourceEngine_SetVolumeDB_Pattern = "F3 0F 11 3F F3 0F 11 83 ?? 00 00 00 F3 0F 11 73 ?? E9 ?? ?? ?? ?? 48 8B 03 48 8D 7B ?? BA 00 30 01 10";

namespace EngineSounds {
    uint64 setVolumePtr;
    string setVolumeOrigBytes;
    bool applied;

    bool Apply() {
        if (applied) return true;
        if (setVolumePtr == 0) setVolumePtr = Dev::FindPattern(CAudioSourceEngine_SetVolumeDB_Pattern);
        if (setVolumePtr == 0) return false;
        setVolumeOrigBytes = Dev::Patch(setVolumePtr, "90 90 90 90");
        applied = true;
        return applied;
    }

    void Unapply() {
        if (!applied) return;
        if (setVolumePtr == 0) throw("setVolumePtr == 0");
        Dev::Patch(setVolumePtr, setVolumeOrigBytes);
        applied = false;
    }

    void SetEngineSoundVolumeDB(double volumeDb) {
        auto volumeDbF = Math::Clamp(float(volumeDb), -60., 0.);
        auto app = GetApp();
        auto audio = app.AudioPort;
        CAudioSourceEngine@ engineSource = null;
        for (uint i = 0; i < audio.Sources.Length; i++) {
            if ((@engineSource = cast<CAudioSourceEngine>(audio.Sources[i])) !is null) {
                engineSource.VolumedB = volumeDbF;
            }
        }
    }

    void SetEngineSoundVdBFromSettings_SpawnCoro() {
        startnew(CoroutineFuncUserdataDouble(EngineSounds::SetEngineSoundVolumeDB), S_EngineSoundsDB);
    }

    uint lastSetEngineSounds = 0;
    void SetEngineSoundVdB_SpawnCoro_Debounced(float lerp_t) {
        if (lastSetEngineSounds + 100 < Time::Now) {
            double setDb = Math::Lerp(S_EngineSoundsDB, 0.0, Math::Clamp(lerp_t * lerp_t, 0.0, 1.0));
            lastSetEngineSounds = Time::Now;
            startnew(CoroutineFuncUserdataDouble(EngineSounds::SetEngineSoundVolumeDB), setDb);
        }
    }
}
