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
        SetEngineSoundVolumeDB(0.0);
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
        auto wheelSurf = GetSoundSurf_CommonCarWheels();
        if (wheelSurf !is null) {
            // by default, defaultWheelSurfVolume = -9.;
            // do this to maintain compatibility with the game tho
            if (defaultWheelSurfVolume < -999.0) defaultWheelSurfVolume = wheelSurf.VolumedB;
            wheelSurf.VolumedB = volumeDb + defaultWheelSurfVolume;
        }

        auto boostSound = GetSound_SpecialBoostLoop();
        if (boostSound !is null) {
            if (defaultSpecialBoostVolume < -999.0) defaultSpecialBoostVolume = boostSound.VolumedB;
            boostSound.VolumedB = volumeDb + defaultSpecialBoostVolume;
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

    float defaultWheelSurfVolume = -999.9;
    float defaultSpecialBoostVolume = -999.9;

    CPlugSoundSurface@ GetSoundSurf_CommonCarWheels() {
        auto wheelSurfFid = Fids::GetGame("GameData/Vehicles/Cars/CommonMedia/Audio/WheelSurface.SoundSurface.Gbx");
        if (wheelSurfFid is null) throw("GetSoundSurf_CommonCarWheels: wheelSurfFid is null");
        auto wheelSurf = cast<CPlugSoundSurface>(Fids::Preload(wheelSurfFid));
        if (wheelSurf is null) throw("GetSoundSurf_CommonCarWheels: wheelSurf is null");
        return wheelSurf;
    }

    // CPlugSound at GameData/Vehicles/Cars/CommonMedia/Audio/SpecialBoost_Loop.Sound.gbx
    CPlugSound@ GetSound_SpecialBoostLoop() {
        auto boostSoundFid = Fids::GetGame("GameData/Vehicles/Cars/CommonMedia/Audio/SpecialBoost_Loop.Sound.Gbx");
        if (boostSoundFid is null) throw("GetSound_SpecialBoostLoop: boostSoundFid is null");
        auto boostSound = cast<CPlugSound>(Fids::Preload(boostSoundFid));
        if (boostSound is null) throw("GetSound_SpecialBoostLoop: boostSound is null");
        return boostSound;
    }

    // could also do whoosh sound, wind, mb some other impact sounds?
}
