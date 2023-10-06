const string SETFOCUSEDRECORD_SCRIPT_TXT = """
 #Const C_PageUID "SetFocusedRecord"
 #Include "TextLib" as TL

 #Const C_RecordStatus_Loading 0
 #Const C_RecordStatus_Loaded 1
 #Const C_RecordStatus_Followed 2

Void MLHookLog(Text _Msg) {
    SendCustomEvent("MLHook_LogMe_" ^ C_PageUID, [_Msg]);
}

Void CheckIncoming() {
    declare Text[][] MLHook_Inbound_SetFocusedRecord for ClientUI = [];
    foreach (Event in MLHook_Inbound_SetFocusedRecord) {
        MLHookLog("Inbound: " ^ TL::Join(", ", Event));
        if (Event.count < 2) continue;
        if (Event[0] == "SetSpectating") {
            declare Text TMGame_Record_SpectatorTargetAccountId for ClientUI = "";
            TMGame_Record_SpectatorTargetAccountId = Event[1];
        } else if (Event[0] == "SetGhostLoading") {
            declare Integer[Text] TMGame_Record_RecordsStatus for ClientUI = [];
            declare Integer TMGame_Record_RecordsStatusUpdate for ClientUI = 0;
            TMGame_Record_RecordsStatus[Event[1]] = C_RecordStatus_Loading;
            TMGame_Record_RecordsStatusUpdate += 1;
        } else if (Event[0] == "SetGhostLoaded") {
            declare Integer[Text] TMGame_Record_RecordsStatus for ClientUI = [];
            declare Integer TMGame_Record_RecordsStatusUpdate for ClientUI = 0;
            TMGame_Record_RecordsStatus[Event[1]] = C_RecordStatus_Loaded;
            TMGame_Record_RecordsStatusUpdate += 1;
        } else if (Event[0] == "SetGhostUnloaded") {
            declare Integer[Text] TMGame_Record_RecordsStatus for ClientUI = [];
            declare Integer TMGame_Record_RecordsStatusUpdate for ClientUI = 0;
            TMGame_Record_RecordsStatus.removekey(Event[1]);
            TMGame_Record_RecordsStatusUpdate += 1;
        }
    }
    MLHook_Inbound_SetFocusedRecord = [];
}

main() {
    declare Boolean ShouldRun = TL::EndsWith("_Local", Playground.ServerInfo.ModeName);
    while (ShouldRun) {
        CheckIncoming();
        yield;
    }
}
// declare Text TMGame_Record_SpectatorTargetAccountId for ClientUI = "";
""".Replace('_"_"_"_', '"""');