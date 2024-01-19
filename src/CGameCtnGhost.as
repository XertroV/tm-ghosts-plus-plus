const uint16 O_CTNGHOST_PRESTIGE = GetOffset("CGameCtnGhost", "LightTrailColor") - 0x10;
const uint16 O_CTNGHOST_SKINPACKDESC = GetOffset("CGameCtnGhost", "ModelIdentAuthor") + 0x20;

string CGameCtnGhost_GetPrestigeOpts(CGameCtnGhost@ g) {
    if (g is null) return "";
    if (!LooksLikeString(g, O_CTNGHOST_PRESTIGE)) return "";
    return Dev::GetOffsetString(g, O_CTNGHOST_PRESTIGE);
}

CSystemPackDesc@ CGameCtnGhost_GetSkin(CGameCtnGhost@ g) {
    if (!LooksLikePtr(g, O_CTNGHOST_SKINPACKDESC)) return null;
    auto nod = Dev::GetOffsetNod(g, O_CTNGHOST_SKINPACKDESC);
    if (nod !is null) return cast<CSystemPackDesc>(nod);
    return null;
}


bool LooksLikePtr(CMwNod@ nod, uint offset) {
    auto ptr = Dev::GetOffsetUint64(nod, offset);
    return ptr > 0xFFFFFFFFFF && ptr < 0x0000030FFEEDDCC
        && ptr & 0xF == 0;
}

bool LooksLikeString(CMwNod@ nod, uint offset) {
    auto strPtr = Dev::GetOffsetUint64(nod, offset);
    auto strLen = Dev::GetOffsetUint32(nod, offset + 0xC);
    return (strPtr == 0 && strLen == 0
        || (strLen < 12)
        || (strLen >= 12 && strLen < 128
            && strPtr > 0xFFFFFFFFFF && strPtr < 0x0000030FFEEDDCC)
        );
}
