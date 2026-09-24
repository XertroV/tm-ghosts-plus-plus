// Bit reader that reads directly from the ghost's input buffer in game memory.
// Changed architecture due to https://github.com/anjo76/angelscript/issues/91.
class GhostBitReader {
    uint64 basePtr;
    int Length;   // bits
    int Position;

    GhostBitReader(uint64 _basePtr, int numBits) {
        basePtr = _basePtr;
        Length = numBits;
        Position = 0;
    }

    uint8 ReadBit() {
        if (Position >= Length) {
            return 0;
        }
        auto result = (Dev::ReadUInt8(basePtr + (Position >> 3)) & (1 << (Position & 7))) != 0;
        Position++;
        return result ? 1 : 0;
    }

    uint64 ReadNumber(int bits) {
        uint64 res = 0;
        for (int i = 0; i < bits; i++) {
            res |= ReadBit() << i;
        }
        return res;
    }

    int8 ReadSByte() {
        return int8(ReadNumber(8));
    }

    uint8 ReadByte() {
        return uint8(ReadNumber(8));
    }

    uint16 ReadUInt16() {
        return uint16(ReadNumber(16));
    }
}

GhostBitReader@ GetRawGhostInputDataReader(CGameCtnGhost@ ghost) {
    if (ghost is null) throw("GetRawGhostInputDataReader: null ghost");
    auto g = DGameCtnGhost(ghost);
    auto inputs = g.Inputs.GetPlayerInput(0);
    auto dataPtr = inputs.GetUint64(0x10);
    if (dataPtr == 0) throw("ghost has no input data pointer");
    auto data = DGameCtnGhost_PlayerInputData(dataPtr);
    auto ptr = data.BytesPtr;
    uint len = data.BytesLen;
    if (ptr == 0 || len == 0 || len > 4 * 1024 * 1024) {
        throw("ghost input data buffer looks invalid (ptr/len)");
    }
    return GhostBitReader(ptr, int(len) * 8);
}
    // dev_trace("GetRawGhostInputData");
enum EStart {
    NotStarted, Character, Vehicle, VehicleMix
}

// namespace Ghosts_PP {
//     shared interface IInputChange {
//         int32 get_Tick();
//         uint64 get_States();
//         uint16 get_MouseAccuX();
//         uint16 get_MouseAccuY();
//         int8 get_Steer();
//         bool get_Gas();
//         bool get_Brake();
//         bool get_Horn();
//         uint8 get_CharacterStates();
//         int64 get_Time();
//         bool get_FreeLook();
//         bool get_ActionSlot1();
//         bool get_ActionSlot2();
//         bool get_ActionSlot3();
//         bool get_ActionSlot4();
//         bool get_ActionSlot5();
//         bool get_ActionSlot6();
//         bool get_ActionSlot7();
//         bool get_ActionSlot8();
//         bool get_ActionSlot9();
//         bool get_ActionSlot0();
//         bool get_Respawn();
//         bool get_SecondaryRespawn();
//         string ToString();
//     }


//     shared class CheckpointIxTime {
//         uint32 CheckpointIndex;
//         int64 Time;

//         CheckpointIxTime(uint ix, int64 t) {
//             CheckpointIndex = ix;
//             Time = t;
//         }
//     }
// }

class TmInputChange : Ghosts_PP::IInputChange {
    int tick;
    uint64 states;
    uint16 mouseAccuX;
    uint16 mouseAccuY;
    int8 steer;
    bool gas;
    bool brake;
    bool horn;
    uint8 characterStates;

    TmInputChange(int tick, uint64 states, uint16 mouseAccuX, uint16 mouseAccuY, int8 steer, bool gas, bool brake, bool horn, uint8 characterStates) {
        this.tick = tick;
        this.states = states;
        this.mouseAccuX = mouseAccuX;
        this.mouseAccuY = mouseAccuY;
        this.steer = steer;
        this.gas = gas;
        this.brake = brake;
        this.horn = horn;
        this.characterStates = characterStates;
    }

    int32 get_Tick() { return tick; }
    uint64 get_States() { return states; }
    uint16 get_MouseAccuX() { return mouseAccuX; }
    uint16 get_MouseAccuY() { return mouseAccuY; }
    int16 get_MouseX() { return int16(mouseAccuX); }
    int16 get_MouseY() { return int16(mouseAccuY); }
    int8 get_Steer() { return steer; }
    bool get_Gas() { return gas; }
    bool get_Brake() { return brake; }
    bool get_Horn() { return horn; }
    uint8 get_CharacterStates() { return characterStates; }

    // InputQuant_* inverses. Steer is a signed byte; gas/brake are 0 or 1.
    float get_SteerF() { return float(steer) / 127.0f; }
    float get_GasF() { return gas ? 1.0f : 0.0f; }
    float get_BrakeF() { return brake ? 1.0f : 0.0f; }
    // Character / generic path: four InputQuant_Ternary codes packed in one byte.
    float get_CharF0() { return _TernaryToFloat(characterStates & 3); }
    float get_CharF1() { return _TernaryToFloat((characterStates >> 2) & 3); }
    float get_CharF2() { return _TernaryToFloat((characterStates >> 4) & 3); }
    float get_CharF3() { return _TernaryToFloat((characterStates >> 6) & 3); }

    int64 get_Time() { return tick * 10; }
    uint get_InputType() { return uint(states) & 0xF; }
    // Packed state word. See research/tm2020/2026-09-25-GhostInputEncoding.md.
    bool get_FreeLook() { return (states & (1 << 4)) != 0; }
    bool get_StrafeLeft() { return (states & (1 << 7)) != 0; }
    bool get_Hop() { return (states & (1 << 10)) != 0; }
    bool get_GiveUp() { return (states & (1 << 11)) != 0; }
    // AK2 -> slot 6, AK4 -> slot 8.
    bool get_ActionSlot1() { return (states & (1 << 12)) != 0; }
    bool get_ActionSlot2() { return (states & (1 << 13)) != 0; }
    bool get_ActionSlot3() { return (states & (1 << 14)) != 0; }
    bool get_ActionSlot4() { return (states & (1 << 15)) != 0; }
    bool get_ActionSlot5() { return (states & (1 << 16)) != 0; }
    bool get_ActionSlot6() { return (states & (1 << 17)) != 0; }
    bool get_ActionSlot7() { return (states & (1 << 18)) != 0; }
    bool get_ActionSlot8() { return (states & (1 << 19)) != 0; }
    bool get_ActionSlot9() { return (states & (1 << 20)) != 0; }
    bool get_ActionSlot0() { return (states & (1 << 21)) != 0; }
    bool get_RearView() { return (states & (1 << 24)) != 0; }
    bool get_Respawn() { return (states & (uint64(1) << 31)) != 0; }
    bool get_SecondaryRespawn() { return (states & (uint64(1) << 33)) != 0; }
    bool get_ActionLatch() { return SecondaryRespawn; }

    float _TernaryToFloat(uint code) {
        if (code == 1) return 1.0f;
        if (code == 3) return -1.0f;
        return 0.0f;
    }

    string _repr;
    string ToString() {
        if (_repr.Length == 0) {
            _repr = "TmInputChange(tick=" + tick + ", time="+Time::Format(Time)+", states=" + states + ", mouseAccuX=" + mouseAccuX + ", mouseAccuY=" + mouseAccuY;
            _repr += ", steer=" + steer + ", gas=" + gas + ", brake=" + brake + ", horn=" + horn + ", freeLook=" + FreeLook;
            _repr += ", as1=" + ActionSlot1 + ", as2=" + ActionSlot2 + ", as3=" + ActionSlot3 + ", as4=" + ActionSlot4 + ", as5=" + ActionSlot5 + ", as6=" + ActionSlot6 + ", as7=" + ActionSlot7 + ", as8=" + ActionSlot8 + ", as9=" + ActionSlot9 + ", as0=" + ActionSlot0;
            _repr += ", respawn=" + Respawn + ", secondaryRespawn=" + SecondaryRespawn + ")";
        }
        return _repr;
    }
}


namespace Ghosts_PP {
    IInputChange@[]@ GetGhostInputData(CGameCtnGhost@ ghost) {
        auto data = GetProcessedGhostInputData(ghost);
        IInputChange@[] ret = array<IInputChange@>(data.Length);
        for (uint i = 0; i < data.Length; i++) {
            ret.InsertLast(data[i]);
        }
        return ret;
    }

    IInputChange@[]@ GetGhostInputDataAsync(CGameCtnGhost@ ghost, int budgetMs) {
        GhostInputsParser parser(ghost);
        parser.ParseAllAsync(budgetMs);
        IInputChange@[] ret = array<IInputChange@>(parser.inputs.Length);
        auto @data = parser.inputs;
        for (uint i = 0; i < data.Length; i++) {
            ret.InsertLast(data[i]);
        }
        return ret;
    }

    CheckpointIxTime@[]@ GetGhostCheckpoints(CGameCtnGhost@ ghost) {
        CheckpointIxTime@[] ret;
        auto g = DGameCtnGhost(ghost);
        auto cps = g.Checkpoints;
        for (uint i = 0; i < cps.Length; i++) {
            auto cp = cps.GetCP(i);
            ret.InsertLast(CheckpointIxTime(uint(cp.cpIndex), int64(cp.cpTime)));
        }
        return ret;
    }
}

// Bits 27–33 are one tick. The encoder compares the next sample with them clear,
// so a respawn pulse must not stay set on later rows.
uint64 GhostInputWithoutPulse(uint64 states) {
    return states & ~(uint64(0x7F) << 27);
}

class ReferencedGhost {
    CGameCtnGhost@ ghost;
    ReferencedGhost(CGameCtnGhost@ ghost_) {
        if (Reflection::GetRefCount(ghost_) < 1) throw("ghost has no ref count");
        ghost_.MwAddRef();
        @this.ghost = ghost_;
    }

    ~ReferencedGhost() {
        Release();
    }

    void Release() {
        if (ghost !is null) {
            ghost.MwRelease();
            @ghost = null;
        }
    }
}

// Incremental parser. Runs in chunks so we can yield.
// a ~208k-tick ghost takes >2s to parse.
class GhostInputsParser {
    ReferencedGhost@ rGhost;
    GhostBitReader@ buf;
    int ticks;   // total ticks in the recording
    int tickIx;  // next tick to parse
    TmInputChange@[] inputs;

    EStart started = EStart::NotStarted;
    bool sameChar = false;
    bool sameVech = false;
    // Carried sample. Each tick is a diff against this (the encoder's previous sample).
    uint64 curStates = 0;
    uint16 curMouseX = 0;
    uint16 curMouseY = 0;
    int8 curSteer = 0;
    bool curGas = false;
    bool curBrake = false;
    bool curHorn = false;
    uint8 curChar = 0;

    GhostInputsParser(CGameCtnGhost@ ghost) {
        @rGhost = ReferencedGhost(ghost);
        @buf = GetRawGhostInputDataReader(ghost);
        ticks = DGameCtnGhost(ghost).Inputs.GetPlayerInput(0).ticks;
        if (ticks < 0 || uint(ticks) > 4 * 1024 * 1024) {
            throw("ghost input tick count looks invalid (" + ticks + ")");
        }
    }

    ~GhostInputsParser() {
        if (rGhost !is null) {
            rGhost.Release();
            @rGhost = null;
        }
    }

    bool get_Done() { return tickIx >= ticks; }
    int get_TicksParsed() { return tickIx; }
    int get_TicksTotal() { return ticks; }

    // Synchronous: Parses without yielding
    void ParseAll() {
        while (!Done) ParseTick();
    }

    // Asynchronous: Parses all in chunks, yielding every budgetMs.
    void ParseAllAsync(int budgetMs) {
        while (!Done) {
            if (ParseChunk(budgetMs)) break;
            yield();
        }
    }

    // Asynchronous: Parses for up to budgetMs. Returns true when done.
    bool ParseChunk(int budgetMs) {
        int sliceStart = Time::Now;
        while (!Done) {
            ParseTick();
            if ((tickIx & 255) == 0 && Time::Now - sliceStart >= budgetMs) break;
        }
        return Done;
    }

    void ParseTick() {
        int i = tickIx;
        bool different = false;
        bool sameState = buf.ReadBit() == 1;

        if (!sameState) {
            bool onlyHorn = buf.ReadBit() > 0;
            // Ghost samples use a 34-bit state word. 33 bits desyncs the analog
            // block so the gas bit lands in the steer sign (always left).
            uint64 states = onlyHorn ? buf.ReadNumber(2) : buf.ReadNumber(34);

            if (started == EStart::NotStarted) {
                // uint() first: the AngelScript bytecode optimizer fuses Enum(u64expr)
                // into an 8-byte write that corrupts the adjacent local (the Inputs crash)
                started = EStart(uint(states) & 3);
                if (started == EStart::VehicleMix) started = EStart::Vehicle;
            }

            if (onlyHorn) {
                // dwButtons bit 0 then bit 1 → packed bits 5 and 6. Drop the previous pulse.
                curStates = (GhostInputWithoutPulse(curStates) & ~uint64(0x60)) | (states << 5);
            } else {
                curStates = states;
            }
            // Horn is dwButtons bits 0 and 1 (packed 5 and 6). The onlyHorn shortcut writes both.
            curHorn = (curStates & (0x3 << 5)) != 0;
            different = true;
        } else {
            curStates = GhostInputWithoutPulse(curStates);
        }

        bool sameMouse = buf.ReadBit() > 0;
        if (!sameMouse) {
            curMouseX = buf.ReadUInt16();
            curMouseY = buf.ReadUInt16();
            different = true;
        }

        switch (started) {
            case EStart::Character: {
                sameChar = buf.ReadBit() > 0;
                if (!sameChar) {
                    curChar = buf.ReadByte();
                    different = true;
                }
                break;
            }
            case EStart::Vehicle: {
                sameVech = buf.ReadBit() > 0;
                if (!sameVech) {
                    curSteer = buf.ReadSByte();
                    curGas = buf.ReadBit() > 0;
                    curBrake = buf.ReadBit() > 0;
                    different = true;
                }
                break;
            }
        }

        if (different) {
            inputs.InsertLast(TmInputChange(i, curStates, curMouseX, curMouseY, curSteer, curGas, curBrake, curHorn, curChar));
        }
        tickIx = i + 1;
    }
}

TmInputChange@[]@ GetProcessedGhostInputData(CGameCtnGhost@ ghost) {
    // dev_trace("GetProcessedGhostInputData");
    GhostInputsParser parser(ghost);
    parser.ParseAll();
    return parser.inputs;
}

#if DEV
// Diagnostic variant of the parse that builds the result as the shared interface type.
Ghosts_PP::IInputChange@[]@ GetProcessedGhostInputDataIIC(CGameCtnGhost@ ghost) {
    auto buf = GetRawGhostInputDataReader(ghost);
    Ghosts_PP::IInputChange@[] res;
    auto ticks = DGameCtnGhost(ghost).Inputs.GetPlayerInput(0).ticks;
    if (ticks < 0 || uint(ticks) > 4 * 1024 * 1024) {
        throw("ghost input tick count looks invalid (" + ticks + ")");
    }
    EStart started = EStart::NotStarted;
    bool different = false;
    uint64 states;
    uint16 mouseAccuX;
    uint16 mouseAccuY;
    int8 steer;
    bool gas;
    bool brake;
    bool horn;
    uint8 characterStates;
    bool sameChar = false;
    bool sameVech = false;

    for (int i = 0; i < ticks; i++) {
        different = false;
        bool sameState = buf.ReadBit() == 1;
        bool onlyHorn = false;
        states = 0;
        mouseAccuX = 0;
        mouseAccuY = 0;
        steer = 0;
        gas = false;
        brake = false;
        horn = false;
        characterStates = 0;
        if (!sameState) {
            onlyHorn = buf.ReadBit() > 0;
            states = onlyHorn ? buf.ReadNumber(2) : buf.ReadNumber(34);
            if (started == EStart::NotStarted) {
                // uint() first: the AngelScript bytecode optimizer fuses Enum(u64expr)
                // into an 8-byte write that corrupts the adjacent local (the Inputs crash)
                started = EStart(uint(states) & 3);
                if (started == EStart::VehicleMix) {
                    started = EStart::Vehicle;
                    horn = states & 64 != 0;
                }
            } else if (started == EStart::Vehicle) {
                horn = onlyHorn ? (states & 2 != 0) : (states & 64 != 0);
            }
            different = true;
        }
        bool sameMouse = buf.ReadBit() > 0;
        if (!sameMouse) {
            mouseAccuX = buf.ReadUInt16();
            mouseAccuY = buf.ReadUInt16();
            different = true;
        }
        switch (started) {
            case EStart::Character: {
                sameChar = buf.ReadBit() > 0;
                if (!sameChar) {
                    characterStates = buf.ReadByte();
                    different = true;
                }
                break;
            }
            case EStart::Vehicle: {
                sameVech = buf.ReadBit() > 0;
                if (!sameVech) {
                    steer = buf.ReadSByte();
                    gas = buf.ReadBit() > 0;
                    brake = buf.ReadBit() > 0;
                    different = true;
                }
                break;
            }
        }
        if (different) {
            if (res.Length == 0) trace("[INPUTS-DBG] V2: first change constructed, inserting");
            res.InsertLast(TmInputChange(i, states, mouseAccuX, mouseAccuY, steer, gas, brake, horn, characterStates));
            if (res.Length == 1) trace("[INPUTS-DBG] V2: first insert returned ok");
        }
    }
    trace("[INPUTS-DBG] V2 parse done: ticks = " + ticks + " changes = " + res.Length);
    return res;
}
#endif

#if DEV
// One-shot diagnostic: staged VM experiments to isolate the InsertLast crash.
// V0/V0b/V1 run in any game state; V2/V3 need a loaded ghost. Remove when done.
class _DbgDummy {
    int x;
}

// Minimal reproduction of the engine bug: the optimizer retargets the 64-bit
// BAND64 into the 4-byte enum slot, and the extra 4 bytes zero canary's low
// dword. Returns 42003 when the engine is correct, 3 when the bug is present.
int _V4EnumFusionProbe() {
    uint64 big = 3;
    uint64 canary = 42;
    EStart t = EStart(big & 3);
    return int(canary) * 1000 + int(t);
}

// Same shape with the plugin's workaround (32-bit AND); must always be 42003.
int _V4WorkaroundProbe() {
    uint64 big = 3;
    uint64 canary = 42;
    EStart t = EStart(uint(big) & 3);
    return int(canary) * 1000 + int(t);
}

// InputsParseAutoTest last run 2026-09-01 (Openplanet.log 03:21:12, ghosts-pp DEV):
//   V0 ok len=1
//   V0b ok len=1
//   V1 ok len=1
//   V4a enum-fusion probe = 3 (VM BUG PRESENT)
//   V4b workaround probe = 42003 (workaround safe)
//   Replay_Load attempts 0-2 (3 path variants), then Index out of bounds at
//   variants[toggles] — loop is `toggles <= 3` on a Length-3 array, so toggles==3
//   indexes off the end. V2/V3 never ran.
/*
void InputsParseAutoTest() {
    trace("[INPUTS-DBG] auto-test coro started");
    yield();
    yield();

    // V0: unrelated plain class, handle array — VM sanity baseline
    trace("[INPUTS-DBG] V0: plain dummy class handle-array insert");
    _DbgDummy@[] v0;
    v0.InsertLast(_DbgDummy());
    trace("[INPUTS-DBG] V0 ok len=" + v0.Length);

    // V0b: TmInputChange (implements shared interface) into its own concrete-type array
    trace("[INPUTS-DBG] V0b: TmInputChange handle-array insert");
    TmInputChange@[] v0b;
    v0b.InsertLast(TmInputChange(0, 0, 0, 0, 0, false, false, false, 0));
    trace("[INPUTS-DBG] V0b ok len=" + v0b.Length);

    // V1: TmInputChange handle into shared-interface-typed array
    trace("[INPUTS-DBG] V1: IInputChange handle-array insert");
    Ghosts_PP::IInputChange@[] v1;
    v1.InsertLast(TmInputChange(0, 0, 0, 0, 0, false, false, false, 0));
    trace("[INPUTS-DBG] V1 ok len=" + v1.Length);

    // V4: direct probe for the VM bug behind the Inputs crash. The bytecode
    // optimizer fuses Enum(u64expr) into an 8-byte write that zeroes the low
    // dword of the adjacent local (here: canary). 3 = bug present, 42003 = fixed.
    int v4a = _V4EnumFusionProbe();
    trace("[INPUTS-DBG] V4a enum-fusion probe = " + v4a + (v4a == 42003 ? " (engine fixed)" : v4a == 3 ? " (VM BUG PRESENT)" : " (unexpected)"));
    int v4b = _V4WorkaroundProbe();
    trace("[INPUTS-DBG] V4b workaround probe = " + v4b + (v4b == 42003 ? " (workaround safe)" : " (UNEXPECTED: workaround unsafe)"));

    // V2/V3 need a CGameCtnGhost. Try play ghosts first, then the menu's DataFileMgr
    // (loaded via Replay_Load; the menu manager persists in any game state).
    CGameCtnGhost@ g = null;
    uint waitedMs = 0;
    uint toggles = 0;
    while (waitedMs < 180000) {
        auto mgrCheck = GhostClipsMgr::Get(GetApp());
        if (mgrCheck !is null && mgrCheck.Ghosts.Length > 0) {
            @g = mgrCheck.Ghosts[0].GhostModel;
            break;
        }
        auto maniaPlanet = cast<CGameManiaPlanet>(GetApp());
        auto menuApp = (maniaPlanet !is null && maniaPlanet.MenuManager !is null) ? maniaPlanet.MenuManager.MenuCustom_CurrentManiaApp : null;
        if (menuApp !is null && menuApp.DataFileMgr !is null) {
            auto mGhosts = menuApp.DataFileMgr.Ghosts;
            if (mGhosts.Length > 0) {
                try {
                    @g = cast<CGameCtnGhost>(Dev::GetOffsetNod(mGhosts[0], 0x20));
                } catch {
                    trace("[INPUTS-DBG] menu ghost cast threw: " + getExceptionInfo());
                }
                trace("[INPUTS-DBG] menu ghost 0 ctnghost: " + (g is null ? string("null") : string(g.GhostNickname)));
                if (g !is null) break;
            }
            if (toggles <= 3) {
                string[] variants = {
                    "Autosaves/XertroV_Winter 2026 - 05_PersonalBest_TimeAttack.Replay.Gbx",
                    "Replays/Autosaves/XertroV_Winter 2026 - 05_PersonalBest_TimeAttack.Replay.Gbx",
                    "XertroV_Winter 2026 - 05_PersonalBest_TimeAttack.Replay.Gbx"
                };
                trace("[INPUTS-DBG] Replay_Load attempt " + toggles + ": " + variants[toggles]);
                try {
                    menuApp.DataFileMgr.Replay_Load(variants[toggles]);
                } catch {
                    trace("[INPUTS-DBG] Replay_Load threw: " + getExceptionInfo());
                }
                toggles++;
            }
        }
        yield();
        waitedMs += 16;
    }
    if (g is null) {
        trace("[INPUTS-DBG] auto-test: no ghost obtained within wait window; done");
        return;
    }
    trace("[INPUTS-DBG] running parse variants on ghost (" + g.GhostNickname + ", " + g.RaceTime + ")");

    // V2: parse with shared-interface-typed result array
    trace("[INPUTS-DBG] V2: parse with IInputChange@[] result");
    try {
        auto res2 = GetProcessedGhostInputDataIIC(g);
        trace("[INPUTS-DBG] V2 ok len=" + res2.Length);
    } catch {
        trace("[INPUTS-DBG] V2 threw: " + getExceptionInfo());
    }

    // V3: original parse (TmInputChange@[]) — expected crash site, run last
    trace("[INPUTS-DBG] V3: parse with TmInputChange@[] result (original)");
    try {
        auto res3 = GetProcessedGhostInputData(g);
        trace("[INPUTS-DBG] V3 ok len=" + res3.Length);
    } catch {
        trace("[INPUTS-DBG] V3 threw: " + getExceptionInfo());
    }
    trace("[INPUTS-DBG] auto-test done");
}
*/
#endif

const uint16 O_CTN_GHOST_CHECKPOINTS_BUF = GetOffset("CGameCtnGhost", "NbRespawns") + 0x8;
const uint16 O_CTN_GHOST_PLAYER_INPUTS_BUF = GetOffset("CGameCtnGhost", "Validate_GameModeCustomData") + (0x1A0 - 0x188);


/// ! This file is generated in editor++: codegen/Game/CGameCtnGhost.xtoml !
/// ! Do not edit this file manually !

class DGameCtnGhost : RawBufferElem {
	DGameCtnGhost(RawBufferElem@ el) {
		if (el.ElSize != 0x330) throw("invalid size for DGameCtnGhost");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnGhost(uint64 ptr) {
		super(ptr, 0x330);
	}
	DGameCtnGhost(CGameCtnGhost@ nod) {
		if (nod is null) throw("not a CGameCtnGhost");
		super(Dev_GetPointerForNod(nod), 0x330);
	}
	CGameCtnGhost@ get_Nod() {
		return cast<CGameCtnGhost>(Dev_GetNodFromPointer(ptr));
	}

	DGameCtnGhost_CPs@ get_Checkpoints() { return DGameCtnGhost_CPs(this.GetBuffer(O_CTN_GHOST_CHECKPOINTS_BUF, 0x8, false)); }
	DGameCtnGhost_PlayerInputs@ get_Inputs() { return DGameCtnGhost_PlayerInputs(this.GetBuffer(O_CTN_GHOST_PLAYER_INPUTS_BUF, 0x18, false)); }
}

class DGameCtnGhost_CPs : RawBuffer {
	DGameCtnGhost_CPs(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DGameCtnGhost_CP@ GetCP(uint i) {
		return DGameCtnGhost_CP(this[i]);
	}
}


class DGameCtnGhost_PlayerInputs : RawBuffer {
	DGameCtnGhost_PlayerInputs(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DGameCtnGhost_PlayerInput@ GetPlayerInput(uint i) {
		return DGameCtnGhost_PlayerInput(this[i]);
	}
}

// might be bigger, unsure
class DGameCtnGhost_PlayerInput : RawBufferElem {
	DGameCtnGhost_PlayerInput(RawBufferElem@ el) {
		if (el.ElSize != 0x18) throw("invalid size for DGameCtnGhost_PlayerInput");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnGhost_PlayerInput(uint64 ptr) {
		super(ptr, 0x18);
	}

	uint get_u01() { return (this.GetUint32(0x0)); }
	void set_u01(uint value) { this.SetUint32(0x0, value); }
	int get_startOffset() { return (this.GetInt32(0x4)); }
	void set_startOffset(int value) { this.SetInt32(0x4, value); }
	int get_version() { return (this.GetInt32(0x8)); }
	void set_version(int value) { this.SetInt32(0x8, value); }
	int get_ticks() { return (this.GetInt32(0xC)); }
	void set_ticks(int value) { this.SetInt32(0xC, value); }
	DGameCtnGhost_PlayerInputData@ get_InputData() { return DGameCtnGhost_PlayerInputData(this.GetUint64(0x10)); }
}


// could be bigger
class DGameCtnGhost_PlayerInputData : RawBufferElem {
	DGameCtnGhost_PlayerInputData(RawBufferElem@ el) {
		if (el.ElSize != 0x30) throw("invalid size for DGameCtnGhost_PlayerInputData");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnGhost_PlayerInputData(uint64 ptr) {
		super(ptr, 0x30);
	}

	uint64 get_BytesPtr() { return (this.GetUint64(0x18)); }
	uint get_BytesLen() { return (this.GetUint32(0x20)); }
	DGameCtnGhost_InputData_Bytes@ get_Bytes() { return DGameCtnGhost_InputData_Bytes(this.GetBuffer(0x18, 0x1, false)); }
}

class DGameCtnGhost_InputData_Bytes : RawBuffer {
	DGameCtnGhost_InputData_Bytes(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DGameCtnGhost_InputData_Byte@ GetByte(uint i) {
		return DGameCtnGhost_InputData_Byte(this[i]);
	}
}

class DGameCtnGhost_CP : RawBufferElem {
	DGameCtnGhost_CP(RawBufferElem@ el) {
		if (el.ElSize != 0x8) throw("invalid size for DGameCtnGhost_CP");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnGhost_CP(uint64 ptr) {
		super(ptr, 0x8);
	}

	int get_cpIndex() { return (this.GetInt32(0x0)); }
	int get_cpTime() { return (this.GetInt32(0x4)); }
}


class DGameCtnGhost_InputData_Byte : RawBufferElem {
	DGameCtnGhost_InputData_Byte(RawBufferElem@ el) {
		if (el.ElSize != 0x1) throw("invalid size for DGameCtnGhost_InputData_Byte");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnGhost_InputData_Byte(uint64 ptr) {
		super(ptr, 0x1);
	}

	uint8 get_v() { return (this.GetUint8(0x0)); }
}

void dev_trace(const string &in msg) {
#if DEV
    trace(msg);
#endif
}
