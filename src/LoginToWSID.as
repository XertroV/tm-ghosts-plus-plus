
string LoginToWSID(const string &in login) {
    try {
        auto buf = MemoryBuffer();
        buf.WriteFromBase64(login, true);
        auto hex = BufferToHex(buf);
        return hex.SubStr(0, 8)
            + "-" + hex.SubStr(8, 4)
            + "-" + hex.SubStr(12, 4)
            + "-" + hex.SubStr(16, 4)
            + "-" + hex.SubStr(20)
            ;
    } catch {
        warn("Login failed to convert: " + login);
        return login;
    }
}

string BufferToHex(MemoryBuffer@ buf) {
    buf.Seek(0);
    auto size = buf.GetSize();
    string ret;
    for (uint i = 0; i < size; i++) {
        ret += Uint8ToHex(buf.ReadUInt8());
    }
    return ret;
}

string Uint8ToHex(uint8 val) {
    return Uint4ToHex(val >> 4) + Uint4ToHex(val & 0xF);
}

string Uint4ToHex(uint8 val) {
    if (val > 0xF) throw('val out of range: ' + val);
    string ret = " ";
    if (val < 10) {
        ret[0] = val + 0x30;
    } else {
        // 0x61 = a
        ret[0] = val - 10 + 0x61;
    }
    return ret;
}
