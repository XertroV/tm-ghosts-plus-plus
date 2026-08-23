// ! From Autohide Opponents (cut down for just ghost visibility stuff)

/**
 * offsets for special user profile and user profile wrapper
 *
 * 2023-03-28: {rootMapM.Offset + 0x48, 0, 0x20, 0xA8}, {.., .., 0x18, 0x98}
 * 2023-04-28: {rootMapM.Offset + 0x48, 0, 0x28, 0xA8}, {.., .., 0x20, 0x98}
 *
 * For special interface UI
 *
 * 2023-03-28: app.Network, 0x158, (Names: 0x28, UI: 0x1c, 0x3c, 0x40)
 *
 */

// This is the most fragile technique in the plugin: a raw pointer walk with only
// RootMap's reflected offset to anchor it. The revision history above is what breaking
// looks like -- it has needed re-deriving three times. Hence the "ghost-visibility"
// capability, whose probe checks the walk still lands on a CGameUserProfile.

// user profile
uint GhostVisOffset = 0xA8;

// updated 2024-04-28: +0x8.
uint SpecialUserProfileOffset = 0x28;

/**
 * Unguarded walk. Returns null rather than throwing when any link is missing, so the
 * capability probe can call it to decide whether the walk is still valid. Everything
 * else should use GetSpecialUserProfile().
 */
CGameUserProfile@ GetSpecialUserProfile_Unchecked(CGameCtnApp@ app) {
    if (app is null) return null;
    auto appTy = Reflection::GetType("CTrackMania");
    if (appTy is null) return null;
    auto rootMapM = appTy.GetMember("RootMap");
    if (rootMapM is null) return null;
    // orig 0x3a0 = 0x358 + 0x48
    auto off1 = rootMapM.Offset + 0x48;
    int[] offsets = {off1, 0, SpecialUserProfileOffset, GhostVisOffset};
    auto fakeNod1 = Dev::GetOffsetNod(app, offsets[0]);
    if (fakeNod1 is null) return null;
    auto fakeNod2 = Dev::GetOffsetNod(fakeNod1, offsets[1]);
    if (fakeNod2 is null) return null;
    auto nod3 = Dev::GetOffsetNod(fakeNod2, offsets[2]);
    return cast<CGameUserProfile>(nod3);
}

CGameUserProfile@ GetSpecialUserProfile(CGameCtnApp@ app) {
    Compat::Require("ghost-visibility");
    return GetSpecialUserProfile_Unchecked(app);
}

// Special User Profile

bool GetGhostVisibility() {
    Compat::Require("ghost-visibility");
    auto profile = GetSpecialUserProfile_Unchecked(GetApp());
    if (profile is null) return false;
    return Dev::GetOffsetUint32(profile, GhostVisOffset) == 1;
}
