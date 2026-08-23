// ! This only controls visuals for moving items. Not surfaces/physics.
// Copied from E++

const uint16 O_GAMESSCENE_TIME = GetOffsetSafe("ISceneVis", "ScenePhy") - 0xC; // offset at 0xD04, ScenePhy at 0xD10

namespace KinematicsControl {
    // Named so the "kinematics-control" capability probe can check it still matches this
    // build before the patch is ever applied.
    const string Pattern_KinematicsWrite = "89 91 04 0D 00 00 8B 05 ?? ?? ?? ?? 48 89 7C 24 28 4C 89 7C 24 20 85 C0 74 2D 8B FD 8B F0";

    MemPatcher kinematicsControlPatch(Pattern_KinematicsWrite, {0}, {"90 90 90 90 90 90"});

    bool IsApplied {
        get {
            return kinematicsControlPatch.IsApplied;
        }
        set {
            // Applying is gated on the probe; un-applying never is, so that a patch which
            // is already in place can always be removed (on unload, for instance).
            if (value && !Compat::Available("kinematics-control")) return;
            kinematicsControlPatch.IsApplied = value;
        }
    }

    void SetKinematicsTime(CGameCtnApp@ app, uint newSceneTime) {
        if (app is null || app.GameScene is null) return;
        if (!Compat::Available("scene-time")) return;
        Dev::SetOffset(app.GameScene, O_GAMESSCENE_TIME, newSceneTime);
    }
}
