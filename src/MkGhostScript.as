void CleanupGhostScript(CGameGhostScript@ gs) {
    if (gs is null) return;
    Dev::SetOffset(gs, 0x20, uint64(0));
    gs.MwAddRef();
    gs.MwRelease();
}

CGameGhostScript@ CreateGhostScript(CGameCtnGhost@ g) {
    // Fabricates a CGameGhostScript wrapping an existing ghost, purely so it can be
    // handed to DataFileMgr::Ghost_Upload. Every offset below is hardcoded, so the
    // capability probe checks the struct is still big enough to hold them.
    Compat::Require("ghost-save");
    uint structSize = Compat::SizeOf("CGameGhostScript");

    auto gs = CGameGhostScript();
    auto gPtr = Dev_GetPointerForNod(g);
    Dev::SetOffset(gs, 0x18, uint(-1));
    Dev::SetOffset(gs, 0x1C, uint(0));
    Dev::SetOffset(gs, 0x20, gPtr);
    // CTmRaceResultNod goes here, but keeping it null is fine for ghost upload.
    //
    // Upstream zeroed a fixed list of fields out to 0x50, assuming this struct was 0x58
    // bytes. It is 0x38 on current builds, so four of those writes landed past the end of
    // the object and corrupted the heap -- the cause of the crash on "Save ghost for
    // later" (upstream #39). Zero only the fields that actually exist.
    for (uint16 o = 0x28; uint(o) + 8 <= structSize; o += 8) {
        Dev::SetOffset(gs, o, uint64(0));
    }

#if DEV
    // auto ptr = Text::FormatPointer(Dev_GetPointerForNod(gs));
    // print(ptr);
    // IO::SetClipboard(ptr);
    // UI::ShowNotification("Copied: " + ptr);
#endif
    return gs;
}


/*

    size: 0x58

    0x18: MwId, 0x1C: junk
    0x20: CGameCtnGhost
    0x28: CTmRaceResultNod
    0x30: 0
    0x38: unused 0x58d00a;
    0x40: 0
    0x48: unused 0xf92064;
    0x50: 0
*/
