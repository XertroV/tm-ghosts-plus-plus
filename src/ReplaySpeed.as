//=0x180 0x000001cabb678820 - NGameItem_SMgr
//

// void SetReplaySpeed(float timeSpeed) {
//     auto scene = GetApp().GameScene;
//     if (scene is null) return;
//     auto itemMgr = Dev::GetOffsetNod(scene, 0x180);
//     if (itemMgr is null) return;
//     auto n2 = Dev_GetOffsetNodSafer(itemMgr, 0x38);
//     if (n2 is null) throw('n2 null');
//     auto n3 = Dev_GetOffsetNodSafer(n2, 0x5A8);
//     if (n3 is null) throw('n3 null');
//     auto n4 = Dev_GetOffsetNodSafer(n3, 0x378);
//     if (n4 is null) throw('n4 null');
//     Dev::SetOffset(n4, 0x56C, timeSpeed);
// }

// string GetReplaySpeed_Debug() {
//     auto scene = GetApp().GameScene;
//     if (scene is null) return "null scene";
//     auto itemMgr = Dev::GetOffsetNod(scene, 0x180);
//     if (itemMgr is null) return "null item mgr";
//     auto n2 = Dev_GetOffsetNodSafer(itemMgr, 0x38);
//     if (n2 is null) return 'n2 null';
//     auto n3 = Dev_GetOffsetNodSafer(n2, 0x5A8);
//     if (n3 is null) return 'n3 null';
//     auto n4 = Dev_GetOffsetNodSafer(n3, 0x378);
//     if (n4 is null) return 'n4 null';
//     // Dev::SetOffset(n4, 0x56C, timeSpeed);
//     return tostring(Dev::GetOffsetFloat(n4, 0x56C));
// }

//=0x1A0 0x000001cabb6787a0 - NSceneKinematicVis_SMgr
// b8, 5a8, 378, 56c

CMwNod@ Dev_GetOffsetNodSafer(CMwNod@ nod, uint16 offset) {
    uint64 ptr = Dev::GetOffsetUint64(nod, offset);
    if (ptr > 0 && ptr % 8 == 0) {
        return Dev::GetOffsetNod(nod, offset);
    }
    return null;
}
