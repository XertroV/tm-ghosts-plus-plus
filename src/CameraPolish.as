// When near the end of a replay, the camera can unpleasantly skip to a thumbnail/spectator view
// Function that updates camera iso4 at 0x578 in system cameras:
// E8 ?? ?? ?? ?? 8B F0 85 C0 74 ?? 8B 43 08

namespace CameraPolish {
    iso4 lastLoc;
    vec2 lastFov;

    /**
     * How long the camera may be held at its last position after the ghost's entity
     * disappears.
     *
     * The hold exists to cover the brief gap at the end of a run, where the camera would
     * otherwise snap to a thumbnail view. It used to have no limit, so once a run ended
     * the camera froze at that position indefinitely -- looking, from the outside, like
     * being dumped into a stationary free camera somewhere on the map with nothing
     * playing. Past this window the game gets its camera back.
     */
    const uint MAX_HOLD_AFTER_GHOST_GONE_MS = 1500;
    uint lastGhostEntitySeenAt = 0;

    const string Pattern_CameraUpdatePosCall = "E8 ?? ?? ?? ?? 8B F0 85 C0 74 ?? 8B 43 08";
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
            // Hold the last position, but only briefly -- see MAX_HOLD_AFTER_GHOST_GONE_MS.
            // Holding indefinitely leaves the camera frozen wherever the run ended.
            if (lastGhostEntitySeenAt == 0) return;
            if (lastGhostEntitySeenAt + MAX_HOLD_AFTER_GHOST_GONE_MS < Time::Now) return;
            // only set the camera if we have sensible values.
            if (Math::Abs(lastLoc.tx * lastLoc.ty * lastLoc.tz) > 0.0001) {
                Dev::Write(rdx, lastLoc);
                Dev::Write(rdx + 0x30, lastFov);
            }
        } else if (entId & 0x04000000 != 0) {
            // if we have a ghost, update the camera pos.
            lastGhostEntitySeenAt = Time::Now;
            lastLoc = Dev::ReadIso4(rdx);
            lastFov = Dev::ReadVec2(rdx + 0x30);
        } else {
            warn_every_60_s("CameraPolish: entId is not valid: " + FmtHexUint32(entId));
        }
    }
}
