const string CAudioSourceEngine_SetVolumeDB_Pattern = "F3 0F 11 3F F3 0F 11 83 ?? 00 00 00 F3 0F 11 73 ?? E9 ?? ?? ?? ?? 48 8B 03 48 8D 7B ?? BA 00 30 01 10";

namespace EngineSounds {
    uint64 setVolumePtr;
    string setVolumeOrigBytes;
    bool applied;

    bool Apply() {
        if (applied) return false;
        setVolumePtr = Dev::FindPattern(CAudioSourceEngine_SetVolumeDB_Pattern);
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

    void SetEngineSoundVolumeDB(float volumeDb) {
        volumeDb = Math::Clamp(volumeDb, -60., 0.);
        auto app = GetApp();
        auto audio = app.AudioPort;
        CAudioSourceEngine@ engineSource = null;
        for (uint i = 0; i < audio.Sources.Length; i++) {
            if ((@engineSource = cast<CAudioSourceEngine>(audio.Sources[i])) !is null) {
                engineSource.VolumedB = volumeDb;
            }
        }
    }
}
