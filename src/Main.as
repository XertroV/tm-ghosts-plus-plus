
CotdApi@ api = null;

void Main() {
    @api = CotdApi();
    MLHook::RequireVersionApi('0.2.0');
    startnew(InitCoro);
}

void InitCoro() {
    IO::FileSource refreshCode("RefreshRecords.Script.txt");
    string manialinkScript = refreshCode.ReadToEnd();
    MLHook::InjectManialinkToPlayground("Hook_RefreshRecords", manialinkScript, true);
}


bool g_windowVisible = false;
uint lastRefresh = 0;
void RenderInterface() {
    if (!g_windowVisible) return;
    if (UI::Begin("Refresh Records Demo", g_windowVisible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse)) {
        if (MDisabledButton(lastRefresh + 5000 > Time::Now, "Refresh Records")) {
            lastRefresh = Time::Now;
            MLHook::Queue_MessageManialinkPlayground("RefreshRecords", "Hook_RefreshRecords");
        }
        if (MDisabledButton(lastRefresh + 5000 > Time::Now, "Toggle top 100 ghosts")) {
            lastRefresh = Time::Now;
            startnew(ToggleTopGhosts);
        }
        if (MDisabledButton(lastRefresh + 5000 > Time::Now, "Spectate ghost at rank 100 (the last of the top 100)")) {
            lastRefresh = Time::Now;
            startnew(ToggleSpectator);
        }
    }
    UI::End();
}

void RenderMenu() {
    if (UI::MenuItem("\\$2f8" + Icons::ListAlt + "\\$z Refresh Records", "", g_windowVisible)) {
        g_windowVisible = !g_windowVisible;
    }
}

CTrackMania@ get_app() {
    return cast<CTrackMania>(GetApp());
}

CGameManiaAppPlayground@ get_cmap() {
    return app.Network.ClientManiaAppPlayground;
}

string get_CurrentMap() {
    auto map = GetApp().RootMap;
    if (map is null) return "";
    return map.MapInfo.MapUid;
}

string lastRecordPid;

void ToggleTopGhosts() {
    auto top = api.GetMapRecords("Personal_Best", CurrentMap, true, 100);
    print(Json::Write(top));
    auto tops = top['tops'];
    if (tops.GetType() != Json::Type::Array) {
        warn('api did not return an array for records');
        return;
    }
    auto records = tops[0]['top'];
    string[] pids = {};
    for (uint i = 0; i < records.Length; i++) {
        auto item = records[i];
        pids.InsertLast(item['accountId']);
    }
    UI::ShowNotification("Top 100 Record Ghosts", "Toggling " + pids.Length + " ghosts...", vec4(.1, .8, .5, .3));
    yield();
    for (uint i = 0; i < pids.Length; i++) {
        auto item = pids[i];
        MLHook::Queue_SH_SendCustomEvent("TMxSM_Race_Record_ToggleGhost", {item});
        trace('toggled ghost for ' + item);
        yield();
    }
    lastRecordPid = pids[pids.Length - 1];
    // MLHook::Queue_SH_SendCustomEvent("TMxSM_Race_Record_SpectateGhost", {lastRecordPid});
}

void ToggleSpectator() {
    if (lastRecordPid == "") {
        UI::ShowNotification("ghosts", "\ntoggle the top 100 ghosts first at least once.\n");
    } else {
        MLHook::Queue_SH_SendCustomEvent("TMxSM_Race_Record_SpectateGhost", {lastRecordPid});
    }
}
