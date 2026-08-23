class BittableMemoryBuffer {
    MemoryBuffer@ buf;
    uint8[] data;
    int Position;
    int Length;

    BittableMemoryBuffer(MemoryBuffer@ buf) {
        @this.buf = buf;
        buf.Seek(0);
        auto LenBytes = buf.GetSize();
        Length = LenBytes * 8;
        data.Reserve(LenBytes);
        for (uint i = 0; i < LenBytes; i++) {
            data.InsertLast(buf.ReadUInt8());
        }
    }

    uint8 ReadBit() {
        if (Position >= Length) {
            return 0;
        }
        auto result = (data[Position / 8] & (1 << (Position % 8))) != 0;
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

    uint8 Read2Bit() {
        return uint8(ReadNumber(2));
    }

    int8 ReadSByte() {
        return int8(ReadNumber(8));
    }

    uint8 ReadByte() {
        return uint8(ReadNumber(8));
    }

    int16 ReadInt16()
    {
        return int16(ReadNumber(16));
    }

    uint16 ReadUInt16()
    {
        return uint16(ReadNumber(16));
    }

    int32 ReadInt32()
    {
        return int32(ReadNumber(32));
    }
}

/**
 * Upper bound on a ghost's input data. Inputs are compact -- even a very long run is a
 * few hundred KB -- so anything past this is a misread, not a real ghost.
 */
const uint MAX_GHOST_INPUT_BYTES = 32 * 1024 * 1024;

// Ticks run at roughly 100Hz, so this allows a run of about 27 hours -- far past anything
// real, which is the point: reject garbage without second-guessing long runs.
const uint MAX_GHOST_INPUT_TICKS = 10000000;
// Observed 12 on build 2026-02-02_17_51. Kept loose so a format bump does not read as
// corruption.
const int MAX_GHOST_INPUT_VERSION = 1000;

/**
 * Can this ghost's inputs be read at all? Safe to call every frame from UI code.
 *
 * Plenty of ghosts carry no recorded inputs -- leaderboard and medal ghosts especially --
 * and their input struct is left unpopulated. Checking up front lets the button disable
 * itself instead of the click taking the game down.
 */
/**
 * Sanity-checks a PlayerInput record before its pointers are followed.
 *
 * A ghost that never recorded inputs still has the struct; its contents are simply not
 * meaningful. Following an InputData pointer read out of such a record is how the game
 * gets taken down, since an unmapped read is not catchable. The tick count and format
 * version are the two fields cheap enough to check and specific enough to be worth it: on
 * a real record they are a positive tick count roughly proportional to run length, and a
 * small version number. Measured reference on build 2026-02-02_17_51: ticks=2539,
 * version=12 for a 23.818s run.
 *
 * Bounds are deliberately loose. The goal is to reject obvious garbage, not to pin down
 * values from a single observed ghost.
 */
bool InputRecordLooksReal(DGameCtnGhost_PlayerInput@ pi) {
    if (pi is null) return false;
    if (pi.ticks <= 0 || uint(pi.ticks) > MAX_GHOST_INPUT_TICKS) return false;
    if (pi.version <= 0 || pi.version > MAX_GHOST_INPUT_VERSION) return false;
    return true;
}

bool GhostHasInputData(CGameCtnGhost@ ghost) {
    if (ghost is null) return false;
    // Never walk these structures when the layout check has failed: a read through a
    // stale offset can hit unmapped memory, which is not a catchable error.
    if (!Compat::Available("ghost-inputs")) return false;
    try {
        auto inputBufs = DGameCtnGhost(ghost).Inputs;
        if (inputBufs.Length == 0) return false;
        auto pi = inputBufs.GetPlayerInput(0);
        if (!InputRecordLooksReal(pi)) return false;
        auto data = pi.InputData;
        return !Dev_PointerLooksBad(data.BytesPtr, false)
            && data.BytesLen > 0
            && data.BytesLen <= MAX_GHOST_INPUT_BYTES;
    } catch {
        return false;
    }
}

MemoryBuffer@ GetRawGhostInputData(CGameCtnGhost@ ghost) {
    // dev_trace("GetRawGhostInputData");
    Compat::Require("ghost-inputs");
    auto g = DGameCtnGhost(ghost);
    // dev_trace("DGameCtnGhost");
    auto inputBufs = g.Inputs;
    if (inputBufs.Length == 0) throw("this ghost has no recorded inputs");
    auto inputs = inputBufs.GetPlayerInput(0);
    // dev_trace("DGameCtnGhost_PlayerInput");
    if (!InputRecordLooksReal(inputs)) {
        throw("this ghost's input record is not populated (ticks=" + inputs.ticks +
              ", version=" + inputs.version + ")");
    }
    auto data = inputs.InputData;
    // dev_trace("DGameCtnGhost_PlayerInputData");
    auto ptr = data.BytesPtr;
    uint len = data.BytesLen;
    // Trace level: free in normal use, and the only evidence of where a stackless crash
    // happened when someone raises the log level to report one.
    log_trace("[inputread] InputData=" + Text::FormatPointer(Dev_GetPointerForNod(ghost))
        + " BytesPtr=" + Text::FormatPointer(ptr) + " BytesLen=" + len
        + " ticks=" + inputs.ticks + " version=" + inputs.version);
    // Both of these come straight out of game memory. Reading them unchecked is what
    // crashes the game: an unmapped pointer, or a garbage length that walks the read loop
    // clean off the end of the heap. Neither is recoverable once it happens.
    if (len == 0) throw("this ghost has no recorded inputs (empty input buffer)");
    if (Dev_PointerLooksBad(ptr, false)) {
        throw("ghost input data pointer is not usable: " + Text::FormatPointer(ptr));
    }
    if (len > MAX_GHOST_INPUT_BYTES) {
        throw("ghost input data length looks wrong (" + len + " bytes) -- refusing to read it");
    }
    auto buf = MemoryBuffer(len);
    // dev_trace('getting buffer of data; len=' + len + '; ptr=' + Text::FormatPointer(ptr));
    uint offset = 0;
    uint64 tmp64;
    // while (offset < len) {
    //     tmp64 = Dev::ReadUInt64(ptr + offset);
    //     buf.Write(tmp64);
    //     if (offset < 100) dev_trace("Read bytes: " + Text::FormatPointer(tmp64));
    //     offset += 8;
    // }
    // One byte first, on its own, so the log distinguishes "BytesPtr is not readable at
    // all" from "it is readable but the buffer is shorter than BytesLen claims". Those
    // need different fixes and look identical from a crash with no stack.
    log_trace("[inputread] reading first byte at " + Text::FormatPointer(ptr));
    uint8 firstByte = Dev::ReadUInt8(ptr);
    log_trace("[inputread] first byte ok: " + firstByte + " -- reading remaining "
        + (len - 1) + " bytes");
    buf.Write(firstByte);
    offset = 1;
    while (offset < len) {
        buf.Write(Dev::ReadUInt8(ptr + offset));
        offset++;
    }
    log_trace("[inputread] copied " + offset + " bytes without faulting");
    buf.Seek(0);
    if (buf.GetSize() != len) {
        warn("Expected " + len + " bytes, but got " + buf.GetSize());
    }
    return buf;
}

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

/**
 * Parsed input state for one tick.
 *
 * Deliberately does NOT implement Ghosts_PP::IInputChange. That interface is `shared`,
 * and shared types live in a module Openplanet compiles separately from this plugin's
 * own. Storing instances of a class bound to it into a local array crashed the game --
 * construction succeeded, the very first InsertLast did not, with no exception and no
 * stack. Traced to the exact statement:
 *
 *   t0: TmInputChange constructed
 *   (dies before "t0: appended")
 *
 * The interface still exists for other plugins; TmInputChangeExport below adapts to it at
 * the export boundary, which is the only place the cross-module type belongs. Internal
 * code has no reason to pay for the ABI.
 */
class TmInputChange {
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
    int8 get_Steer() { return steer; }
    bool get_Gas() { return gas; }
    bool get_Brake() { return brake; }
    bool get_Horn() { return horn; }
    uint8 get_CharacterStates() { return characterStates; }

    int64 get_Time() { return tick * 10; }
    bool get_FreeLook() { return states & 8192 != 0; }
    bool get_ActionSlot1() { return states & (1 << 14) != 0; }
    bool get_ActionSlot2() { return states & (1 << 15) != 0; }
    bool get_ActionSlot3() { return states & (1 << 16) != 0; }
    bool get_ActionSlot4() { return states & (1 << 17) != 0; }
    bool get_ActionSlot5() { return states & (1 << 18) != 0; }
    bool get_ActionSlot6() { return states & (1 << 19) != 0; }
    bool get_ActionSlot7() { return states & (1 << 20) != 0; }
    bool get_ActionSlot8() { return states & (1 << 21) != 0; }
    bool get_ActionSlot9() { return states & (1 << 22) != 0; }
    bool get_ActionSlot0() { return states & (1 << 23) != 0; }
    bool get_Respawn() { return states & (1 << 31) != 0; }
    bool get_SecondaryRespawn() { return states & (1 << 33) != 0; }

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
    /**
     * Adapts a parsed TmInputChange to the shared cross-plugin interface.
     *
     * Kept separate from TmInputChange so the shared type is only ever instantiated here,
     * at the export boundary, and never in the parse loop -- see the note on TmInputChange.
     */
    class TmInputChangeExport : IInputChange {
        private TmInputChange@ c;
        TmInputChangeExport(TmInputChange@ c) { @this.c = c; }

        int32 get_Tick() { return c.Tick; }
        uint64 get_States() { return c.States; }
        uint16 get_MouseAccuX() { return c.MouseAccuX; }
        uint16 get_MouseAccuY() { return c.MouseAccuY; }
        int8 get_Steer() { return c.Steer; }
        bool get_Gas() { return c.Gas; }
        bool get_Brake() { return c.Brake; }
        bool get_Horn() { return c.Horn; }
        uint8 get_CharacterStates() { return c.CharacterStates; }
        int64 get_Time() { return c.Time; }
        bool get_FreeLook() { return c.FreeLook; }
        bool get_ActionSlot1() { return c.ActionSlot1; }
        bool get_ActionSlot2() { return c.ActionSlot2; }
        bool get_ActionSlot3() { return c.ActionSlot3; }
        bool get_ActionSlot4() { return c.ActionSlot4; }
        bool get_ActionSlot5() { return c.ActionSlot5; }
        bool get_ActionSlot6() { return c.ActionSlot6; }
        bool get_ActionSlot7() { return c.ActionSlot7; }
        bool get_ActionSlot8() { return c.ActionSlot8; }
        bool get_ActionSlot9() { return c.ActionSlot9; }
        bool get_ActionSlot0() { return c.ActionSlot0; }
        bool get_Respawn() { return c.Respawn; }
        bool get_SecondaryRespawn() { return c.SecondaryRespawn; }
        string ToString() { return c.ToString(); }
    }

    IInputChange@[]@ GetGhostInputData(CGameCtnGhost@ ghost) {
        IInputChange@[] ret;
        auto data = GetProcessedGhostInputData(ghost);
        for (uint i = 0; i < data.Length; i++) {
            ret.InsertLast(TmInputChangeExport(data[i]));
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

// Traced unconditionally: every failure in this path so far has been a hard crash with no
// exception and no stack, so the last line written is the only evidence of where it died.
void InputTrace(const string &in msg) {
    log_trace("[inputread] " + msg);
}

TmInputChange@[]@ GetProcessedGhostInputData(CGameCtnGhost@ ghost) {
    // dev_trace("GetProcessedGhostInputData");
    auto buf = BittableMemoryBuffer(GetRawGhostInputData(ghost));
    InputTrace("bit buffer built: " + buf.Length + " bits");
    auto ticks = DGameCtnGhost(ghost).Inputs.GetPlayerInput(0).ticks;
    InputTrace("re-read ticks: " + ticks + " -- entering parse loop");
    TmInputChange@[] res;

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
        // Progress tracing. Nothing in this loop touches raw memory, so it should not be
        // able to fault -- but it demonstrably does not reach the end. Knowing *which*
        // iteration it dies on separates "the first one is malformed" from "it runs off
        // the end of the bit buffer near the finish".
        if (i < 4 || i % 250 == 0) {
            InputTrace("tick " + i + "/" + ticks + " bitpos=" + buf.Position
                + "/" + buf.Length + " changes=" + res.Length);
        }
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
                started = EStart(states & 3);
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
            auto change = TmInputChange(i, states, mouseAccuX, mouseAccuY, steer, gas, brake, horn, characterStates);
            // dev_trace('Got input change: ' + change.ToString());
            res.InsertLast(change);
        }
    }

    InputTrace("parse loop done: " + res.Length + " input changes");
    return res;
}

const uint16 O_CTN_GHOST_CHECKPOINTS_BUF = GetOffsetSafe("CGameCtnGhost", "NbRespawns") + 0x8;
const uint16 O_CTN_GHOST_PLAYER_INPUTS_BUF = GetOffsetSafe("CGameCtnGhost", "Validate_GameModeCustomData") + (0x1A0 - 0x188);


/// ! This file is generated in editor++: codegen/Game/CGameCtnGhost.xtoml !
/// ! Do not edit this file manually !

/**
 * The CGameCtnGhost layout these offsets have been *measured* against.
 *
 * This is load-bearing, not documentation. Every hardcoded delta in this file assumes a
 * particular field layout, and reading through a stale one is not survivable: an unmapped
 * read takes the game down without raising a catchable exception. The "ghost-inputs" and
 * "ghost-telemetry" probes compare this against the size the game reports and disable
 * those features when they disagree, rather than reading anyway.
 *
 * Measured on build 2026-02-02_17_51 (struct size 0x340) with the ghost struct dump in
 * GhostStructDump.as, against a 4-checkpoint map:
 *
 *   +0x038 len=5  = NbRespawns + 0x8                  checkpoints (4 CPs + finish)
 *   +0x1a8 len=1  = Validate_GameModeCustomData + 0x18 player inputs
 *   +0x2f8 len=1  = Validate_ExtraTool_Info + 0xc8     entity records
 *   PlayerInput:     version +0x08, ticks +0x0C, InputData +0x10
 *   PlayerInputData: BytesPtr +0x18, BytesLen +0x20 (repeated at +0x28)
 *
 * Only the entity-record delta had moved from the values generated against the older
 * 0x330 layout; everything else measured identical.
 */
const uint DGAMECTNGHOST_VERIFIED_SIZE = 0x340;

class DGameCtnGhost : RawBufferElem {
	DGameCtnGhost(RawBufferElem@ el) {
		if (el.ElSize != DGAMECTNGHOST_VERIFIED_SIZE) throw("invalid size for DGameCtnGhost");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnGhost(uint64 ptr) {
		super(ptr, DGAMECTNGHOST_VERIFIED_SIZE);
	}
	DGameCtnGhost(CGameCtnGhost@ nod) {
		if (nod is null) throw("not a CGameCtnGhost");
		super(Dev_GetPointerForNod(nod), DGAMECTNGHOST_VERIFIED_SIZE);
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
