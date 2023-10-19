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

// user profile
uint GhostVisOffset = 0xA8;

// updated 2024-04-28: +0x8.
uint SpecialUserProfileOffset = 0x28;


CGameUserProfile@ GetSpecialUserProfile(CGameCtnApp@ app) {
    if (!GameVersionSafe) throw("Call to unsafe dev method");
    auto appTy = Reflection::GetType("CTrackMania");
    auto rootMapM = appTy.GetMember("RootMap");
    // orig 0x3a0 = 0x358 + 0x48
    auto off1 = rootMapM.Offset + 0x48;
    int[] offsets = {off1, 0, SpecialUserProfileOffset, GhostVisOffset};
    auto fakeNod1 = Dev::GetOffsetNod(app, offsets[0]);
    auto fakeNod2 = Dev::GetOffsetNod(fakeNod1, offsets[1]);
    auto nod3 = Dev::GetOffsetNod(fakeNod2, offsets[2]);
    return cast<CGameUserProfile>(nod3);
}

// Special User Profile

bool GetGhostVisibility() {
    if (!GameVersionSafe) throw("Call to unsafe dev method");
    return Dev::GetOffsetUint32(GetSpecialUserProfile(GetApp()), GhostVisOffset) == 1;
}
