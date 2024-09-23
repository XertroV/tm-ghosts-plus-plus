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
        for (int i = 0; i < LenBytes; i++) {
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
        for (uint i = 0; i < bits; i++) {
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

MemoryBuffer@ GetRawGhostInputData(CGameCtnGhost@ ghost) {
    // dev_trace("GetRawGhostInputData");
    auto g = DGameCtnGhost(ghost);
    // dev_trace("DGameCtnGhost");
    auto inputs = g.Inputs.GetPlayerInput(0);
    // dev_trace("DGameCtnGhost_PlayerInput");
    auto data = inputs.InputData;
    // dev_trace("DGameCtnGhost_PlayerInputData");
    auto buf = MemoryBuffer(data.BytesLen);
    auto ptr = data.BytesPtr;
    uint len = data.BytesLen;
    // dev_trace('getting buffer of data; len=' + len + '; ptr=' + Text::FormatPointer(ptr));
    uint offset = 0;
    uint64 tmp64;
    // while (offset < len) {
    //     tmp64 = Dev::ReadUInt64(ptr + offset);
    //     buf.Write(tmp64);
    //     if (offset < 100) dev_trace("Read bytes: " + Text::FormatPointer(tmp64));
    //     offset += 8;
    // }
    while (offset < len) {
        buf.Write(Dev::ReadUInt8(ptr + offset));
        offset++;
    }
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
    IInputChange@[]@ GetGhostInputData(CGameCtnGhost@ ghost) {
        IInputChange@[] ret;
        auto data = GetProcessedGhostInputData(ghost);
        for (int i = 0; i < data.Length; i++) {
            ret.InsertLast(data[i]);
        }
        return ret;
    }

    CheckpointIxTime@[]@ GetGhostCheckpoints(CGameCtnGhost@ ghost) {
        CheckpointIxTime@[] ret;
        auto g = DGameCtnGhost(ghost);
        auto cps = g.Checkpoints;
        for (int i = 0; i < cps.Length; i++) {
            auto cp = cps.GetCP(i);
            ret.InsertLast(CheckpointIxTime(uint(cp.cpIndex), int64(cp.cpTime)));
        }
        return ret;
    }
}

TmInputChange@[]@ GetProcessedGhostInputData(CGameCtnGhost@ ghost) {
    // dev_trace("GetProcessedGhostInputData");
    auto buf = BittableMemoryBuffer(GetRawGhostInputData(ghost));
    // dev_trace("[GetProcessedGhostInputData] got buffer");
    auto ticks = DGameCtnGhost(ghost).Inputs.GetPlayerInput(0).ticks;
    // dev_trace("[GetProcessedGhostInputData] got ticks=" + ticks);
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
        // dev_trace("[GetProcessedGhostInputData] processing tick " + i);
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

    return res;
}

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
