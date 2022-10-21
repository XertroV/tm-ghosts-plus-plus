
NadeoApi@ api;
bool permissionsOkay = false;

void Main() {
    CheckRequiredPermissions();
    @api = NadeoApi();
    MLHook::RequireVersionApi('0.3.1');
    startnew(MapCoro);
}

// check for permissions and
void CheckRequiredPermissions() {
    permissionsOkay = Permissions::ViewRecords() && Permissions::PlayRecords();
    if (!permissionsOkay) {
        NotifyWarn("Your edition of the game does not support playing against record ghosts.\n\nThis plugin won't work, sorry :(.");
        while(true) { sleep(10000); } // do nothing forever
    }
}

string s_currMap = "";

void MapCoro() {
    while(true) {
        sleep(273); // no need to check that frequently. 273 seems primeish
        if (s_currMap != CurrentMap) {
            s_currMap = CurrentMap;
            ResetToggleCache();
        }
    }
}

dictionary toggleCache;
void ResetToggleCache() {
    toggleCache.DeleteAll();
    records = Json::Value();
    lastRecordPid = "";
}

[Setting hidden]
bool g_windowVisible = false;
int g_numGhosts = 20;
int g_ghostRankOffset = 0;

// returns e.g., "the top X ghosts" or "ghosts ranked 5 to 56";
const string GenGhostRankString() {
    if (g_ghostRankOffset == 0)
        return "the top " + g_numGhosts + " ghosts";
    int startRank = g_ghostRankOffset + 1;
    if (g_numGhosts == 1) {
        return "the ghost ranked " + startRank;
    }
    int endRank = startRank + g_numGhosts - 1;
    return "ghosts ranked " + startRank + " to " + endRank;
}


uint lastRefresh = 0;
const uint disableTime = 3000;
void RenderInterface() {
    if (!permissionsOkay) return;
    if (!g_windowVisible) return;
    if (UI::Begin("Too Many Ghosts", g_windowVisible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse)) {
        auto grString = GenGhostRankString();
        g_numGhosts = UI::SliderInt("Number of Ghosts", g_numGhosts, 1, 100);
        g_ghostRankOffset = UI::InputInt("Start at rank", g_ghostRankOffset + 1) - 1;
        if (MDisabledButton(lastRefresh + disableTime > Time::Now, "Toggle " + grString + ".")) {
            lastRefresh = Time::Now;
            startnew(ToggleTopGhosts);
        }
        if (MDisabledButton(lastRefresh + disableTime > Time::Now, "Show " + grString + ".")) {
            lastRefresh = Time::Now;
            startnew(ShowTopGhosts);
        }
        if (MDisabledButton(lastRefresh + disableTime > Time::Now, "Hide " + grString + ".")) {
            lastRefresh = Time::Now;
            startnew(HideTopGhosts);
        }
        if (MDisabledButton(lastRefresh + disableTime > Time::Now, "Hide all enabled ghosts.")) {
            lastRefresh = Time::Now;
            startnew(HideAllGhosts);
        }
        AddSimpleTooltip("Useful if you reduce the number of ghosts and there are some left over.");
        int lastRank = g_ghostRankOffset + g_numGhosts;
        if (MDisabledButton(lastRefresh + disableTime > Time::Now, "Spectate ghost at rank " + lastRank + (g_numGhosts > 1 ? "\n(the last of " + grString + ")" : ""))) {
            lastRefresh = Time::Now;
            startnew(ToggleSpectator);
        }
    }
    UI::End();
}

void RenderMenu() {
    if (!permissionsOkay) return;
    if (UI::MenuItem("\\$888" + Icons::SnapchatGhost + "\\$z Too Many Ghosts", "", g_windowVisible)) {
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
int lastOffset = -1;
Json::Value records = Json::Value(); // null

array<string> UpdateMapRecords() {
    if (!permissionsOkay) return array<string>();
    if (records.GetType() != Json::Type::Array || int(records.Length) < g_numGhosts || lastOffset != g_ghostRankOffset) {
        lastOffset = g_ghostRankOffset;
        Json::Value mapRecords = api.GetMapRecords("Personal_Best", CurrentMap, true, g_numGhosts, g_ghostRankOffset);
        // trace(Json::Write(records));
        auto tops = mapRecords['tops'];
        if (tops.GetType() != Json::Type::Array) {
            warn('api did not return an array for records; instead got: ' + Json::Write(mapRecords));
            NotifyWarn("API did not return map records.");
            return array<string>();
        }
        records = tops[0]['top'];
    }
    array<string> pids = {};
    if (records.GetType() == Json::Type::Array) {
        for (uint i = 0; i < records.Length; i++) {
            auto item = records[i];
            pids.InsertLast(item['accountId']);
        }
    }
    lastRecordPid = pids[pids.Length - 1];
    return pids;
}

void ToggleTopGhosts() {
    array<string> pids = UpdateMapRecords();
    Notify("Toggling " + pids.Length + " ghosts...");
    yield();
    for (uint i = 0; i < pids.Length; i++) {
        auto playerId = pids[i];
        ToggleGhost(playerId);
        yield();
    }
}

void _ShowTopGhosts(bool hideInstead = false) {
    array<string> pids = UpdateMapRecords();
    Notify((hideInstead ? "Hiding " : "Showing ") + pids.Length + " ghosts...");
    yield();
    for (uint i = 0; i < pids.Length; i++) {
        auto playerId = pids[i];
        bool enabled = false;
        toggleCache.Get(playerId, enabled);
        if (enabled == hideInstead) {
            ToggleGhost(playerId);
            yield();
        }
    }
}

void ShowTopGhosts() {
    _ShowTopGhosts(false);
}

void HideTopGhosts() {
    _ShowTopGhosts(true);
}

void HideAllGhosts() {
    auto pids = toggleCache.GetKeys();
    for (uint i = 0; i < pids.Length; i++) {
        auto pid = pids[i];
        if (bool(toggleCache[pid])) {
            ToggleGhost(pid);
            yield();
        }
    }
}

void ToggleGhost(const string &in playerId) {
    if (!permissionsOkay) return;
    // trace('toggled ghost for ' + playerId);
    MLHook::Queue_SH_SendCustomEvent("TMxSM_Race_Record_ToggleGhost", {playerId});
    bool enabled = false;
    toggleCache.Get(playerId, enabled);
    toggleCache[playerId] = !enabled;
}

void ToggleSpectator() {
    if (!permissionsOkay) return;
    auto pids = UpdateMapRecords();
    if (lastRecordPid == "" || int(pids.Length) < g_numGhosts) {
        NotifyWarn("\n>> Toggle ghosts first at least once. <<\n");
    } else {
        MLHook::Queue_SH_SendCustomEvent("TMxSM_Race_Record_SpectateGhost", {pids[g_numGhosts - 1]});
    }
}


/*
API
api stuff -- copied from COTD_HUD
*/

void log_trace(const string &in msg) {
    trace(msg);
}

class NadeoApi {
    string liveSvcUrl;

    NadeoApi() {
        NadeoServices::AddAudience("NadeoLiveServices");
        liveSvcUrl = NadeoServices::BaseURL();
    }

    void AssertGoodPath(const string &in path) {
        if (path.Length <= 0 || !path.StartsWith("/")) {
            throw("API Paths should start with '/'!");
        }
    }

    const string LengthAndOffset(uint length, uint offset) {
        return "length=" + length + "&offset=" + offset;
    }

    /* LIVE SERVICES API CALLS */

    Json::Value CallLiveApiPath(const string &in path) {
        AssertGoodPath(path);
        return FetchLiveEndpoint(liveSvcUrl + path);
    }

    /* see COTD_HUD/example/getMapRecords.json */
    Json::Value GetMapRecords(const string &in seasonUid, const string &in mapUid, bool onlyWorld = true, uint length=5, uint offset=0) {
        // Personal_Best
        string qParams = onlyWorld ? "?onlyWorld=true" : "";
        if (onlyWorld) qParams += "&" + LengthAndOffset(length, offset);
        return CallLiveApiPath("/api/token/leaderboard/group/" + seasonUid + "/map/" + mapUid + "/top" + qParams);
    }
}

Json::Value FetchLiveEndpoint(const string &in route) {
    log_trace("[FetchLiveEndpoint] Requesting: " + route);
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) { yield(); }
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}

/*
UI STUFF
*/

void Notify(const string &in msg) {
    // UI::ShowNotification("Too Many Ghosts", msg, vec4(.1, .8, .5, .3));
    UI::ShowNotification("Too Many Ghosts", msg, vec4(.2, .8, .5, .3));
}

void NotifyWarn(const string &in msg) {
    UI::ShowNotification("Too Many Ghosts", msg, vec4(1, .5, .1, .5), 10000);
}
