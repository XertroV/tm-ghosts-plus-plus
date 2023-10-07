string WSIDToLogin(const string &in wsid) {
    try {
        auto hex = string::Join(wsid.Split("-"), "");
        auto buf = HexToBuffer(hex);
        return buf.ReadToBase64(buf.GetSize(), true);
    } catch {
        warn("WSID failed to convert: " + wsid);
        return wsid;
    }
}

MemoryBuffer@ HexToBuffer(const string &in hex) {
    MemoryBuffer@ buf = MemoryBuffer();
    for (int i = 0; i < hex.Length; i += 2) {
        buf.Write(Hex2ToUint8(hex.SubStr(i, 2)));
    }
    buf.Seek(0);
    return buf;
}

uint8 Hex2ToUint8(const string &in hex) {
    return HexPairToUint8(hex[0], hex[1]);
}

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

uint8 HexPairToUint8(uint8 c1, uint8 c2) {
    return HexCharToUint8(c1) << 4 | HexCharToUint8(c2);
}

// values output in range 0 to 15 inclusive
uint8 HexCharToUint8(uint8 char) {
    if (char < 0x30 || (char > 0x39 && char < 0x61) || char > 0x66) throw('char out of range: ' + char);
    if (char < 0x40) return char - 0x30;
    return char - 0x61 + 10;
}
