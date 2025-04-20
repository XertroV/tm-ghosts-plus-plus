// ! This only controls visuals for moving items. Not surfaces/physics.
// Copied from E++

const uint16 O_GAMESSCENE_TIME = GetOffset("ISceneVis", "ScenePhy") - 0xC; // offset at 0xD04, ScenePhy at 0xD10

namespace KinematicsControl {
    MemPatcher kinematicsControlPatch("89 91 04 0D 00 00 8B 05 ?? ?? ?? ?? 48 89 7C 24 28 4C 89 7C 24 20 85 C0 74 2D 8B FD 8B F0", {0}, {"90 90 90 90 90 90"});

    bool IsApplied {
        get {
            return kinematicsControlPatch.IsApplied;
        }
        set {
            kinematicsControlPatch.IsApplied = value;
        }
    }

    void SetKinematicsTime(CGameCtnApp@ app, uint newSceneTime) {
        if (app is null || app.GameScene is null) return;
        Dev::SetOffset(app.GameScene, O_GAMESSCENE_TIME, newSceneTime);
    }
}
