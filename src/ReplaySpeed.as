CMwNod@ Dev_GetOffsetNodSafer(CMwNod@ nod, uint16 offset) {
    uint64 ptr = Dev::GetOffsetUint64(nod, offset);
    if (ptr > 0 && ptr % 8 == 0) {
        return Dev::GetOffsetNod(nod, offset);
    }
    return null;
}
