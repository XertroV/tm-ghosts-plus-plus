// When near the end of a replay, the camera can unpleasantly skip to a thumbnail/spectator view
// Function that updates camera iso4 at 0x578 in system cameras:
// E8 ?? ?? ?? ?? 8B F0 85 C0  74 ?? 8B 43 08

namespace CameraPolish {
    iso4 lastLoc;
    vec2 lastFov;

    const string Pattern_CameraUpdatePosCall = "E8 ?? ?? ?? ?? 8B F0 85 C0  74 ?? 8B 43 08";
    FunctionHookHelperAsync@ Hook_CameraUpdatePos = FunctionHookHelperAsync(Pattern_CameraUpdatePosCall, 0x0, 0, "CameraPolish::_OnCameraUpdatePos", Dev::PushRegisters::Basic, true);

    void _OnCameraUpdatePos(uint64 rdx) {
        // quickest way to check if we want to bail is playground script
        auto app = GetApp();
        auto pg = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (pg is null) return;

        // rdx = SysCameras + 0x578
        if (scrubberMgr is null || !IsSpectatingGhost(pg)) return;
        if (rdx < 0x0FFFFFFF) {
            warn_every_60_s("Very low pointer value: " + Text::FormatPointer(rdx));
            return;
        }

        auto mgr = GhostClipsMgr::Get(app);
        if (pg is null || mgr is null) return;
        auto ghost = GhostClipsMgr::GetGhostFromInstanceId(mgr, GetCurrentlySpecdGhostInstanceId(pg));
        auto entId = Ghosts_PP::GetGhostVisEntityId(ghost);
        // if there's no ghost, we want to keep the last camera pos.
        if (entId == 0x0FF00000) {
            // only set the camera if we have sensible values.
            if (Math::Abs(lastLoc.tx * lastLoc.ty * lastLoc.tz) > 0.0001) {
                Dev::Write(rdx, lastLoc);
                Dev::Write(rdx + 0x30, lastFov);
            }
        } else if (entId & 0x04000000 != 0) {
            // if we have a ghost, update the camera pos.
            lastLoc = Dev::ReadIso4(rdx);
            lastFov = Dev::ReadVec2(rdx + 0x30);
        } else {
            warn_every_60_s("CameraPolish: entId is not valid: " + FmtHexUint32(entId));
        }
    }
}
