void CleanupGhostScript(CGameGhostScript@ gs) {
    if (gs is null) return;
    Dev::SetOffset(gs, 0x20, uint64(0));
    gs.MwAddRef();
    gs.MwRelease();
}

CGameGhostScript@ CreateGhostScript(CGameCtnGhost@ g) {
    auto gs = CGameGhostScript();
    auto gPtr = Dev_GetPointerForNod(g);
    Dev::SetOffset(gs, 0x18, uint(-1));
    Dev::SetOffset(gs, 0x1C, uint(0));
    Dev::SetOffset(gs, 0x20, gPtr);
    // CTmRaceResultNod goes here, but keeping it null is fine for ghost upload.
    // The struct shrank from 0x58 to 0x38 (CGameGhostScript, per the reflection dump in
    // OpenplanetNext.json); zeroing out to 0x50 was writing 0x20 bytes past the end and
    // corrupting the heap (crash on 'Save ghost for later', issue #39). Only fields that
    // still exist are zeroed now.
    Dev::SetOffset(gs, 0x28, uint64(0));
    Dev::SetOffset(gs, 0x30, uint64(0));

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
