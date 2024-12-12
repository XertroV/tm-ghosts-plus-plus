uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}

uint16 GetOffset(CMwNod@ nod, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::TypeOf(nod);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}






// copied from E++ for dev structs



// 88""Yb    db    Yb        dP     88""Yb 88   88 888888 888888 888888 88""Yb
// 88__dP   dPYb    Yb  db  dP      88__dP 88   88 88__   88__   88__   88__dP
// 88"Yb   dP__Yb    YbdPYbdP       88""Yb Y8   8P 88""   88""   88""   88"Yb
// 88  Yb dP"'""Yb    YP  YP        88oodP `YbodP' 88     88     888888 88  Yb


// A class to safely access raw buffers
class RawBuffer {
    // location in memory of the buffer struct (ptr, len, cap)
    protected uint64 ptr;
    protected uint size;
    protected bool structBehindPtr = false;

    RawBuffer(CMwNod@ nod, uint16 offset, uint structSize = 0x8, bool structBehindPointer = false) {
        _Setup(Dev_GetPointerForNod(nod) + offset, structSize, structBehindPointer);
    }
    RawBuffer(uint64 bufPtr, uint structSize = 0x8, bool structBehindPointer = false) {
        _Setup(bufPtr, structSize, structBehindPointer);
    }

    private void _Setup(uint64 bufPtr, uint structSize, bool structBehindPtr) {
        if (Dev_PointerLooksBad(bufPtr)) throw("Bad buffer pointer: " + Text::FormatPointer(bufPtr));
        this.ptr = bufPtr;
        size = structSize;
        this.structBehindPtr = structBehindPtr;
    }

    uint64 get_Ptr() { return ptr; }
    uint64 get_ElSize() { return size; }
    bool get_StructBehindPtr() { return structBehindPtr; }

    uint get_Length() {
        return Dev::ReadUInt32(ptr + 0x8);
    }
    uint get_Reserved() {
        return Dev::ReadUInt32(ptr + 0xC);
    }

    RawBufferElem@ opIndex(uint i) {
        if (i >= Length) throw("RawBufferElem out of range!");
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        uint elStartOffset = i * size;
        if (structBehindPtr) {
            ptr2 = ptr2 + i * 0x8;
            ptr2 = Dev::ReadUInt64(ptr2);
            elStartOffset = 0;
        }
        return RawBufferElem(ptr2 + elStartOffset, size);
    }
}

// Can be the elements of a raw buffer, or arbitrary struct
class RawBufferElem {
    protected uint64 ptr;
    protected uint size;
    RawBufferElem(uint64 ptr, uint size) {
        this.ptr = ptr;
        this.size = size;
    }

    uint64 get_Ptr() { return ptr; }
    uint64 get_ElSize() { return size; }

    void CheckOffset(uint o, uint len) {
        if (o+len > size) throw("index out of range: " + o + " + " + len);
    }
    uint64 opIndex(uint i) {
        uint o = i * 0x8;
        CheckOffset(o, 8);
        return ptr + o;
    }

    RawBuffer@ GetBuffer(uint o, uint size, bool behindPointer = false) {
        CheckOffset(o, 16);
        return RawBuffer(ptr + o, size, behindPointer);
    }

    string GetString(uint o) {
        CheckOffset(o, 16);
        auto nod = Dev_GetNodFromPointer(ptr + o);
        return Dev::GetOffsetString(nod, 0);
    }
    void SetString(uint o, const string &in val) {
        CheckOffset(o, 16);
        auto nod = Dev_GetNodFromPointer(ptr + o);
        Dev::SetOffset(nod, 0, val);
    }

    CMwNod@ GetNod(uint o) {
        return Dev_GetNodFromPointer(GetUint64(o));
    }
    void SetNod(uint o, CMwNod@ nod) {
        CheckOffset(o, 8);
        Dev::SetOffset(Dev_GetNodFromPointer(ptr), o, nod);
    }
    uint64 GetUint64(uint o) {
        CheckOffset(o, 8);
        return Dev::ReadUInt64(ptr + o);
    }
    void SetUint64(uint o, uint64 value) {
        CheckOffset(o, 8);
        Dev::Write(ptr + o, value);
    }
    string GetMwIdValue(uint o) {
        CheckOffset(o, 4);
        return GetMwIdName(Dev::ReadUInt32(ptr + o));
    }
    void SetMwIdValue(uint o, const string &in value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, GetMwId(value));
    }
    uint32 GetUint32(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadUInt32(ptr + o);
    }
    void SetUint32(uint o, uint value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, value);
    }
    uint16 GetUint16(uint o) {
        CheckOffset(o, 2);
        return Dev::ReadUInt16(ptr + o);
    }
    uint8 GetUint8(uint o) {
        CheckOffset(o, 1);
        return Dev::ReadUInt8(ptr + o);
    }
    void SetUint8(uint o, uint8 value) {
        CheckOffset(o, 1);
        Dev::Write(ptr + o, value);
    }
    bool GetBool(uint o) {
        CheckOffset(o, 1);
        return Dev::ReadUInt8(ptr + o) != 0;
    }
    void SetBool(uint o, bool value) {
        CheckOffset(o, 1);
        Dev::Write(ptr + o, uint8(value ? 1 : 0));
    }
    float GetFloat(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadFloat(ptr + o);
    }
    void SetFloat(uint o, float value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, value);
    }
    int32 GetInt32(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadInt32(ptr + o);
    }
    void SetInt32(uint o, int value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, value);
    }
    nat3 GetNat3(uint o) {
        CheckOffset(o, 12);
        return Dev::ReadNat3(ptr + o);
    }
    void SetNat3(uint o, const nat3 &in value) {
        CheckOffset(o, 12);
        Dev::Write(ptr + o, value);
    }
    int3 GetInt3(uint o) {
        CheckOffset(o, 12);
        return Dev::ReadInt3(ptr + o);
    }
    void SetInt3(uint o, const int3 &in value) {
        CheckOffset(o, 12);
        Dev::Write(ptr + o, value);
    }
    vec2 GetVec2(uint o) {
        CheckOffset(o, 8);
        return Dev::ReadVec2(ptr + o);
    }
    void SetVec2(uint o, vec2 value) {
        CheckOffset(o, 8);
        Dev::Write(ptr + o, value);
    }
    vec3 GetVec3(uint o) {
        CheckOffset(o, 12);
        return Dev::ReadVec3(ptr + o);
    }
    void SetVec3(uint o, vec3 value) {
        CheckOffset(o, 12);
        Dev::Write(ptr + o, value);
    }
    vec4 GetVec4(uint o) {
        CheckOffset(o, 16);
        return Dev::ReadVec4(ptr + o);
    }
    void SetVec4(uint o, const vec4 &in value) {
        CheckOffset(o, 16);
        Dev::Write(ptr + o, value);
    }
    mat3 GetMat3(uint o) {
        CheckOffset(o, 36);
        return mat3(Dev::ReadVec3(ptr + o), Dev::ReadVec3(ptr + o + 12), Dev::ReadVec3(ptr + o + 24));
    }
    iso4 GetIso4(uint o) {
        CheckOffset(o, 48);
        return Dev::ReadIso4(ptr + o);
        // return iso4(Dev::ReadVec3(ptr + o), Dev::ReadVec3(ptr + o + 12), Dev::ReadVec3(ptr + o + 24), Dev::ReadVec3(ptr + o + 36));
        // return iso4(mat4(vec4(Dev::ReadVec3(ptr + o), 0), vec4(Dev::ReadVec3(ptr + o + 12), 0), vec4(Dev::ReadVec3(ptr + o + 24), 0), vec4(Dev::ReadVec3(ptr + o + 36), 0)));
    }
    mat4 GetMat4(uint o) {
        CheckOffset(o, 64);
        return mat4(Dev::ReadVec4(ptr + o), Dev::ReadVec4(ptr + o + 16), Dev::ReadVec4(ptr + o + 32), Dev::ReadVec4(ptr + o + 48));
    }
    void SetMat3(uint o, const mat3 &in value) {
        CheckOffset(o, 36);
        Dev::Write(ptr + o, vec4(value.xx, value.xy, value.xz, value.yx));
        Dev::Write(ptr + o + 16, vec4(value.yy, value.yz, value.zx, value.zy));
        Dev::Write(ptr + o + 32, value.zz);
    }
    void SetIso4(uint o, const iso4 &in value) {
        CheckOffset(o, 48);
        Dev::Write(ptr + o, value);
        // Dev::Write(ptr + o, vec4(value.xx, value.xy, value.xz, value.yx));
        // Dev::Write(ptr + o + 16, vec4(value.yy, value.yz, value.zx, value.zy));
        // Dev::Write(ptr + o + 32, vec4(value.zz, value.tx, value.ty, value.tz));
    }
    void SetMat4(uint o, const mat4 &in value) {
        CheckOffset(o, 64);
        Dev::Write(ptr + o, vec4(value.xx, value.xy, value.xz, value.xw));
        Dev::Write(ptr + o + 16, vec4(value.yx, value.yy, value.yz, value.yw));
        Dev::Write(ptr + o + 32, vec4(value.zx, value.zy, value.zz, value.zw));
        Dev::Write(ptr + o + 48, vec4(value.tx, value.ty, value.tz, value.tw));
    }

    // void DrawResearchView() {
    //     UI::PushFont(g_MonoFont);
    //     g_RV_RenderAs = DrawComboRV_ValueRenderTypes("Render Values##"+ptr, g_RV_RenderAs);

    //     auto nbSegments = size / RV_SEGMENT_SIZE;
    //     for (uint i = 0; i < nbSegments; i++) {
    //         DrawSegment(i);
    //     }
    //     auto remainder = size - (nbSegments * RV_SEGMENT_SIZE);
    //     if (remainder >= RV_SEGMENT_SIZE) throw("Error caclulating remainder size");
    //     DrawSegment(nbSegments, remainder);

    //     UI::PopFont();
    // }

    // void DrawSegment(uint n, int limit = -1) {
    //     if (limit == 0) return;
    //     limit = limit < 0 ? RV_SEGMENT_SIZE : limit;
    //     auto segPtr = ptr + RV_SEGMENT_SIZE * n;
    //     UI::AlignTextToFramePadding();
    //     UI::Text("\\$888" + Text::Format("0x%03x  ", n * RV_SEGMENT_SIZE));
    //     if (UI::IsItemClicked()) {
    //         SetClipboard(Text::FormatPointer(segPtr));
    //     }
    //     UI::SameLine();
    //     string mem;
    //     for (int o = 0; o < RV_SEGMENT_SIZE; o += 4) {
    //         mem = o >= limit ? "__ __ __ __" : Dev::Read(segPtr + o, Math::Min(limit, 4));
    //         UI::Text(mem);
    //         UI::SameLine();
    //         if (o % 8 != 0) {
    //             UI::Dummy(vec2(10, 0));
    //         }
    //         UI::SameLine();
    //     }
    //     DrawRawValues(segPtr, limit);
    //     UI::Dummy(vec2());
    // }

    // void DrawRawValues(uint64 segPtr, int bytesToRead) {
    //     switch (g_RV_RenderAs) {
    //         case RV_ValueRenderTypes::Float: DrawRawValuesFloat(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint32: DrawRawValuesUint32(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint32D: DrawRawValuesUint32D(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint64: DrawRawValuesUint64(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint16: DrawRawValuesUint16(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint16D: DrawRawValuesUint16D(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint8: DrawRawValuesUint8(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Uint8D: DrawRawValuesUint8D(segPtr, bytesToRead); return;
    //         // case RV_ValueRenderTypes::Int32: DrawRawValuesInt32(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Int32D: DrawRawValuesInt32D(segPtr, bytesToRead); return;
    //         // case RV_ValueRenderTypes::Int16: DrawRawValuesInt16(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Int16D: DrawRawValuesInt16D(segPtr, bytesToRead); return;
    //         // case RV_ValueRenderTypes::Int8: DrawRawValuesInt8(segPtr, bytesToRead); return;
    //         case RV_ValueRenderTypes::Int8D: DrawRawValuesInt8D(segPtr, bytesToRead); return;
    //         default: {}
    //     }
    //     UI::Text("no impl: " + tostring(g_RV_RenderAs));
    // }

    // void DrawRawValuesFloat(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 4) {
    //         _DrawRawValueFloat(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint32(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 4) {
    //         _DrawRawValueUint32(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint32D(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 4) {
    //         _DrawRawValueUint32D(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint64(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 8) {
    //         _DrawRawValueUint64(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint16(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 2) {
    //         _DrawRawValueUint16(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint16D(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 2) {
    //         _DrawRawValueUint16D(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint8(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 1) {
    //         _DrawRawValueUint8(segPtr + i);
    //     }
    // }
    // void DrawRawValuesUint8D(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 1) {
    //         _DrawRawValueUint8D(segPtr + i);
    //     }
    // }
    // void DrawRawValuesInt32(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 4) {
    //         _DrawRawValueInt32(segPtr + i);
    //     }
    // }
    // void DrawRawValuesInt32D(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 4) {
    //         _DrawRawValueInt32D(segPtr + i);
    //     }
    // }
    // void DrawRawValuesInt16(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 2) {
    //         _DrawRawValueInt16(segPtr + i);
    //     }
    // }
    // void DrawRawValuesInt16D(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 2) {
    //         _DrawRawValueInt16D(segPtr + i);
    //     }
    // }
    // void DrawRawValuesInt8(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 1) {
    //         _DrawRawValueInt8(segPtr + i);
    //     }
    // }
    // void DrawRawValuesInt8D(uint64 segPtr, int bytesToRead) {
    //     for (int i = 0; i < bytesToRead; i += 1) {
    //         _DrawRawValueInt8D(segPtr + i);
    //     }
    // }

    // void _DrawRawValueFloat(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadFloat(valPtr)));
    // }
    // void _DrawRawValueUint32(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt32(valPtr)));
    // }
    // void _DrawRawValueUint32D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadUInt32(valPtr)));
    // }
    // void _DrawRawValueUint16(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt16(valPtr)));
    // }
    // void _DrawRawValueUint16D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadUInt16(valPtr)));
    // }
    // void _DrawRawValueUint8(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt8(valPtr)));
    // }
    // void _DrawRawValueUint8D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadUInt8(valPtr)));
    // }
    // void _DrawRawValueInt32(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt32(valPtr)));
    // }
    // void _DrawRawValueInt32D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadInt32(valPtr)));
    // }
    // void _DrawRawValueInt16(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt16(valPtr)));
    // }
    // void _DrawRawValueInt16D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadInt16(valPtr)));
    // }
    // void _DrawRawValueInt8(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt8(valPtr)));
    // }
    // void _DrawRawValueInt8D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadInt8(valPtr)));
    // }
    // void _DrawRawValueUint64(uint64 valPtr) {
    //     RV_CopiableValue(Text::FormatPointer(Dev::ReadUInt64(valPtr)));
    // }

    // bool RV_CopiableValue(const string &in value) {
    //     auto ret = CopiableValue(value);
    //     if (UI::IsItemHovered()) {
    //         if (UI::IsMouseClicked(UI::MouseButton::Middle)) {
    //             g_RV_RenderAs = RV_ValueRenderTypes((int(g_RV_RenderAs) - 1) % RV_ValueRenderTypes::LAST);
    //         }
    //         if (UI::IsMouseClicked(UI::MouseButton::Right)) {
    //             g_RV_RenderAs = RV_ValueRenderTypes((int(g_RV_RenderAs) + 1) % RV_ValueRenderTypes::LAST);
    //         }
    //         // auto scrollDelta = Math::Clamp(g_ScrollThisFrame.x, -1, 1);
    //         // g_RV_RenderAs = RV_ValueRenderTypes(Math::Clamp(int(g_RV_RenderAs) + scrollDelta, 0, RV_ValueRenderTypes::LAST - 1));
    //     }
    //     UI::SameLine();
    //     return ret;
    // }
}


// // Research View segment size
// const uint RV_SEGMENT_SIZE = 0x10;

// enum RV_ValueRenderTypes {
//     Float = 0,
//     Uint64,
//     Uint32,
//     Uint32D,
//     Uint16,
//     Uint16D,
//     Uint8,
//     Uint8D,
//     Int32D,
//     Int16D,
//     Int8D,
//     LAST
// }

// RV_ValueRenderTypes g_RV_RenderAs = RV_ValueRenderTypes::Float;


string GetMwIdName(uint id) {
    return MwId(id).GetName();
}

uint GetMwId(const string &in name) {
    MwId id;
    id.SetName(name);
    return id.Value;
}


bool Dev_PointerLooksBad(uint64 ptr) {
    #if WINDOWS_WINE
        if (ptr < 0x1000000) return true;
    #else
        // normal windows
        if (ptr < 0x10000000000) return true;
    #endif
    if (ptr > 0x40000000000) return true;
    if (ptr % 8 != 0) return true;
    if (ptr == 0) return true;
    return false;
}

const uint64 BASE_ADDR_END = Dev::BaseAddressEnd();



namespace NodPtrs {
    void InitializeTmpPointer() {
        g_TmpPtrSpace = Dev::Allocate(0x1000, false);
        auto nod = CMwNod();
        uint64 tmp = Dev::GetOffsetUint64(nod, 0);
        Dev::SetOffset(nod, 0, g_TmpPtrSpace);
        @g_TmpSpaceAsNod = Dev::GetOffsetNod(nod, 0);
        Dev::SetOffset(nod, 0, tmp);
    }

    void Unload() {
        @g_TmpSpaceAsNod = null;
        if (g_TmpPtrSpace > 0) {
            Dev::Free(g_TmpPtrSpace);
            g_TmpPtrSpace = 0;
        }
    }

    uint64 g_TmpPtrSpace = 0;
    CMwNod@ g_TmpSpaceAsNod = null;
}

CMwNod@ Dev_GetArbitraryNodAt(uint64 ptr) {
    if (NodPtrs::g_TmpPtrSpace == 0) {
        NodPtrs::InitializeTmpPointer();
    }
    if (ptr == 0) throw('null pointer passed');
    Dev::SetOffset(NodPtrs::g_TmpSpaceAsNod, 0, ptr);
    return Dev::GetOffsetNod(NodPtrs::g_TmpSpaceAsNod, 0);
}


const bool IS_MEMORY_ALWAYS_ALIGNED = true;
CMwNod@ Dev_GetNodFromPointer(uint64 ptr) {
#if WINDOWS_WINE
    print("get nod from ptr: " + Text::FormatPointer(ptr));
    if (ptr < 0x1000000 || (IS_MEMORY_ALWAYS_ALIGNED && ptr % 8 != 0) || ptr >> 48 > 0) {
        print("get nod from ptr failed: " + Text::FormatPointer(ptr));
        return null;
    }
#else
    if (ptr < 0xFFFFFFFF || (IS_MEMORY_ALWAYS_ALIGNED && ptr % 8 != 0) || ptr >> 48 > 0) {
        print("get nod from ptr failed: " + Text::FormatPointer(ptr));
        return null;
    }
#endif
    return Dev_GetArbitraryNodAt(ptr);
}
