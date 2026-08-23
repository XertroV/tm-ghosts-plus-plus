// Diagnostic for re-deriving CGameCtnGhost field offsets after a game update.
//
// The generated accessors in ReadCtnGhostInputs.as carry hardcoded deltas from reflected
// anchor members to the checkpoint / input / entity-record buffers. Those deltas are only
// valid for the struct layout they were generated against, and CGameCtnGhost changed size
// between then (0x330) and build 2026-02-02_17_51 (0x340).
//
// Guessing new deltas is not viable: a wrong offset yields a pointer into unrelated
// memory, and reading it can hit an unmapped page, which kills the game outright rather
// than raising a catchable error. So this finds them empirically instead.
//
// What makes that safe: reading *inside* the ghost object is always fine -- it is mapped,
// and the reflected size bounds it. This walks that window looking for the engine's
// standard buffer shape, a {pointer, length, capacity} triple, and reports where they sit
// relative to the anchors. Candidate pointers are range-checked but never dereferenced.

#if DEV
namespace GhostDiag {
    // A count of input ticks or checkpoints in a real ghost. Wide enough for a very long
    // run, tight enough to reject coincidental integers.
    const uint PLAUSIBLE_MAX_LEN = 1000000;

    void LogAnchor(const string &in name) {
        auto m = Compat::FindMember("CGameCtnGhost", name);
        if (m is null) {
            log_info("  anchor " + name + ": MISSING");
        } else {
            log_info("  anchor " + name + " @ +0x" + Text::Format("%03x", m.Offset));
        }
    }

    // Offset of a named member, or -1. Used to express findings as anchor-relative deltas,
    // which is the form the source actually needs.
    int AnchorOffset(const string &in name) {
        auto m = Compat::FindMember("CGameCtnGhost", name);
        return m is null ? -1 : int(m.Offset);
    }

    string DeltaFrom(const string &in anchor, uint offset) {
        int a = AnchorOffset(anchor);
        if (a < 0) return "";
        int d = int(offset) - a;
        string sign = d < 0 ? "-" : "+";
        return "  [" + anchor + " " + sign + " 0x" + Text::Format("%x", d < 0 ? -d : d) + "]";
    }

    void DumpGhostStruct(CGameCtnGhost@ ghost) {
        if (ghost is null) {
            NotifyWarning("No ghost to dump -- load or spectate one first.");
            return;
        }
        uint size = Compat::SizeOf("CGameCtnGhost");
        if (size == 0) {
            NotifyWarning("Reflection did not report a size for CGameCtnGhost.");
            return;
        }
        uint64 base = Dev_GetPointerForNod(ghost);
        if (Dev_PointerLooksBad(base)) {
            NotifyWarning("Ghost pointer looks unusable: " + Text::FormatPointer(base));
            return;
        }

        log_info("=== CGameCtnGhost layout dump ===");
        log_info("  game build: " + GetGameExeVersion());
        log_info("  base: " + Text::FormatPointer(base)
            + "  reflected size: 0x" + Text::Format("%x", size)
            + "  (verified against 0x" + Text::Format("%x", DGAMECTNGHOST_VERIFIED_SIZE) + ")");
        log_info("  nickname: " + ghost.GhostNickname + "  racetime: " + ghost.RaceTime);

        LogAnchor("NbRespawns");
        LogAnchor("Validate_GameModeCustomData");
        LogAnchor("Validate_ExtraTool_Info");
        LogAnchor("LightTrailColor");
        LogAnchor("ModelIdentAuthor");

        log_info("  --- buffer-shaped candidates {ptr, len, cap} ---");
        uint found = 0;
        for (uint o = 0; o + 0x10 <= size; o += 0x8) {
            uint64 p = Dev::ReadUInt64(base + o);
            uint len = Dev::ReadUInt32(base + o + 0x8);
            uint cap = Dev::ReadUInt32(base + o + 0xC);
            // Deliberately not dereferencing p -- range check only.
            if (Dev_PointerLooksBad(p)) continue;
            if (len == 0 || len > PLAUSIBLE_MAX_LEN) continue;
            if (cap < len || cap > PLAUSIBLE_MAX_LEN * 2) continue;
            found++;
            log_info("  +0x" + Text::Format("%03x", o)
                + "  ptr=" + Text::FormatPointer(p)
                + "  len=" + len
                + "  cap=" + cap
                + DeltaFrom("NbRespawns", o)
                + DeltaFrom("Validate_GameModeCustomData", o)
                + DeltaFrom("Validate_ExtraTool_Info", o));
        }
        log_info("  " + found + " candidate(s). Checkpoint counts are small (3-50); input "
            + "buffers are larger. Compare len against the ghost's real checkpoint count.");
        DumpInputInnerStructs(ghost);
        log_info("=== end dump ===");
        UI::ShowNotification("Ghost layout dumped to the Openplanet log.");
    }

    /**
     * Walks one level down from the PlayerInputs buffer.
     *
     * The top-level buffer offset measured correct, so the crash when reading inputs is
     * further in: the field offsets *inside* DGameCtnGhost_PlayerInput (0x18 bytes) and
     * DGameCtnGhost_PlayerInputData (0x30 bytes), which are generated the same way and
     * equally unverified.
     *
     * Each element read is bounded by the element size the buffer itself declares, and no
     * candidate pointer is dereferenced without a range check first.
     */
    void DumpInputInnerStructs(CGameCtnGhost@ ghost) {
        if (ghost is null) return;
        uint64 base = Dev_GetPointerForNod(ghost);
        if (Dev_PointerLooksBad(base)) return;

        uint16 o = O_CTN_GHOST_PLAYER_INPUTS_BUF;
        uint64 elems = Dev::ReadUInt64(base + o);
        uint len = Dev::ReadUInt32(base + o + 0x8);
        log_info("  --- PlayerInputs buffer @ +0x" + Text::Format("%03x", o)
            + "  elems=" + Text::FormatPointer(elems) + "  len=" + len + " ---");
        if (len == 0 || Dev_PointerLooksBad(elems)) {
            log_info("  nothing usable to walk into.");
            return;
        }

        // Element 0, 0x18 bytes: source expects startOffset@0x4, version@0x8, ticks@0xC,
        // and an InputData pointer at 0x10.
        log_info("  PlayerInput[0] @ " + Text::FormatPointer(elems) + " (0x18 bytes):");
        uint64 inputDataPtr = 0;
        for (uint i = 0; i < 0x18; i += 0x8) {
            uint64 q = Dev::ReadUInt64(elems + i);
            uint lo = Dev::ReadUInt32(elems + i);
            uint hi = Dev::ReadUInt32(elems + i + 0x4);
            bool looksPtr = !Dev_PointerLooksBad(q);
            log_info("    +0x" + Text::Format("%02x", i)
                + "  u64=" + Text::FormatPointer(q)
                + "  u32=" + lo + ", " + hi
                + (looksPtr ? "   <-- pointer-shaped" : ""));
            if (looksPtr && inputDataPtr == 0) inputDataPtr = q;
        }

        if (inputDataPtr == 0) {
            log_info("  no pointer-shaped field found in PlayerInput[0].");
            return;
        }

        // InputData, 0x30 bytes: source expects BytesPtr@0x18 and BytesLen@0x20.
        log_info("  PlayerInputData @ " + Text::FormatPointer(inputDataPtr) + " (0x30 bytes):");
        for (uint i = 0; i < 0x30; i += 0x8) {
            uint64 q = Dev::ReadUInt64(inputDataPtr + i);
            uint lo = Dev::ReadUInt32(inputDataPtr + i);
            uint hi = Dev::ReadUInt32(inputDataPtr + i + 0x4);
            bool looksPtr = !Dev_PointerLooksBad(q);
            // A byte buffer for a ~24s run is on the order of KB.
            bool plausibleLen = lo > 0 && lo < 4000000;
            log_info("    +0x" + Text::Format("%02x", i)
                + "  u64=" + Text::FormatPointer(q)
                + "  u32=" + lo + ", " + hi
                + (looksPtr ? "   <-- pointer-shaped" : (plausibleLen ? "   <-- length-shaped" : "")));
        }
        log_info("  Expect a pointer-shaped field immediately followed by a length-shaped "
            + "one: that pair is {BytesPtr, BytesLen}.");
    }

    // Dumps the ghost currently being spectated, or the first loaded one.
    void DumpCurrentGhost() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null || mgr.Ghosts.Length == 0) {
            NotifyWarning("No ghosts loaded -- load one first.");
            return;
        }
        DumpGhostStruct(mgr.Ghosts[0].GhostModel);
    }
}
#endif
