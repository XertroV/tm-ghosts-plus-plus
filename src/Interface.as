const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuTitle = "\\$dd5" + Icons::HandPointerO + "\\$z " + PluginName;

const int TABLE_FLAGS = UI::TableFlags::SizingStretchProp | UI::TableFlags::RowBg;

PBTab@ g_PBTab = PBTab();
NearTime@ g_NearTimeTab = NearTime();
AroundRank@ g_AroundRankTab = AroundRank();
Intervals@ g_IntervalsTab = Intervals();
FavoritesTab@ g_Favorites = FavoritesTab();
PlayersTab@ g_Players = PlayersTab();
SavedTab@ g_Saved = SavedTab();
MedalsTab@ g_Medals = MedalsTab();
LeaderboardTab@ g_LeaderboardTab = LeaderboardTab();
LoadGhostsTab@ g_LoadGhostTab = LoadGhostsTab();
SaveGhostsTab@ g_SaveGhostTab = SaveGhostsTab();
DebugGhostsTab@ g_DebugTab = DebugGhostsTab();
DebugCacheTab@ g_DebugCacheTab = DebugCacheTab();
DebugClipsTab@ g_DebugClips = DebugClipsTab();
ScrubberDebugTab@ g_ScrubDebug = ScrubberDebugTab();
UrlTab@ g_UrlTab = UrlTab();

Tab@[]@ tabs = {g_PBTab, g_NearTimeTab, g_AroundRankTab, g_IntervalsTab, g_Favorites, g_LoadGhostTab, g_SaveGhostTab, g_Saved, g_Players, g_Medals, g_DebugTab, g_DebugClips, g_ScrubDebug, g_UrlTab, g_LeaderboardTab};

/** Render function called every frame intended for `UI`.
*/
void RenderInterface() {
    if (!GameVersionSafe) return;
    if (!permissionsOkay) return;
    if (!g_Initialized) return;
    if (!S_ShowWindow) return;
    if (!S_EnableInEditor && GetApp().Editor !is null) return;
    // only show a window outside the map in dev mode
#if DEV
#else
    if (GetApp().PlaygroundScript is null) return;
#endif

    if (!Cache::hasDoneInit) startnew(Cache::Initialize);
    UI::SetNextWindowSize(600, 300, UI::Cond::Appearing);
    if (UI::Begin(MenuTitle, S_ShowWindow)) {
        if (GetApp().PlaygroundScript is null) {
            UI::Text("Please load a map in Solo mode");
#if SIG_DEVELOPER
            UI::BeginTabBar("save or load ghosts");
            g_DebugTab.Draw();
            g_DebugCacheTab.Draw();
            g_Favorites.Draw();
            g_Players.Draw();
            UI::EndTabBar();
#endif
        } else if (!Cache::IsInitialized) {
            UI::Text("Loading...");
        } else {
            // if (UI::BeginChild("main-lhs", vec2(300., 0))) {
            //     UI::AlignTextToFramePadding();
            //     UI::Text("Current Ghosts:");
            //     UI::Indent();
            //     g_SaveGhostTab.DrawInner();
            //     UI::Unindent();
            // }
            // UI::EndChild();
            // UI::SameLine();
            if (UI::BeginChild("main-rhs")) {
            UI::BeginTabBar("save or load ghosts");
            g_SaveGhostTab.Draw();
            g_LoadGhostTab.Draw();
#if SIG_DEVELOPER
            g_DebugTab.Draw();
            g_ScrubDebug.Draw();
            g_DebugClips.Draw();
            g_DebugCacheTab.Draw();
#else
            // g_LoadGhostTab.DrawInner();
#endif
            UI::EndTabBar();
            }
            UI::EndChild();
        }
    }
    UI::End();
}

class Tab {
    string Name;

    Tab(const string &in name) {
        Name = name;
    }

    void Draw() {
        if (UI::BeginTabItem(Name)) {
            UI::BeginChild("tab-child-" + Name);
            DrawInner();
            UI::EndChild();
            UI::EndTabItem();
        }
    }

    void DrawInner() {
        throw("overload me");
    }

    void OnMapChange() {
        // overload me
        // reset times and things
    }
}

class SaveGhostsTab : Tab {
    SaveGhostsTab() {
        super("Curr Ghosts");
    }

    uint[] saving;

    void DrawInner() override {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        if (mgr.Ghosts.Length == 0) {
            UI::Text("No ghosts loaded.");
            return;
        }

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.3, .3, .3, .3));
        auto nbCols = 6;
        if (UI::BeginTable("save-ghosts", nbCols, TABLE_FLAGS)) {

            UI::TableSetupColumn("Ix", UI::TableColumnFlags::WidthFixed, 30.);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 70.);
            UI::TableSetupColumn("Spectate", UI::TableColumnFlags::WidthFixed, 32.);
            UI::TableSetupColumn("Save", UI::TableColumnFlags::WidthFixed, 32.);
            UI::TableSetupColumn("Unload", UI::TableColumnFlags::WidthFixed, 32.);

            UI::ListClipper clip(mgr.Ghosts.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < Math::Min(clip.DisplayEnd, mgr.Ghosts.Length); i++) {
                    UI::PushID(i);
                    auto item = mgr.Ghosts[i];
                    auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
                    DrawSaveGhost(mgr.Ghosts[i], i, id);
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
        UI::PopStyleColor();
#if DEV
        // auto bufOffset = Reflection::GetType("NGameGhostClips_SMgr").GetMember("Ghosts").Offset + 0x10;
        // auto bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
        // auto bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
        // auto bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);

        // for (uint i = 0; i < bufCapacity; i++) {
        //     auto u1 = Dev::ReadUInt32(bufPtr + i * 4);
        //     auto u2 = Dev::ReadUInt32(bufPtr + bufCapacity * 4 + i * 4);
        //     auto u3 = Dev::ReadUInt32(bufPtr + bufCapacity * 8 + i * 4);
        //     UI::Text(
        //         Text::Format("%2d. ", i) +
        //         Text::Format("%08x    ", u1) +
        //         Text::Format("%08x    ", u2) +
        //         Text::Format("%08x    ", u3)
        //     );
        // }
#endif
    }

    void DrawSaveGhost(NGameGhostClips_SClipPlayerGhost@ gc, uint i, uint id) {
        auto gm = gc.GhostModel;
        auto clip = gc.Clip;
        auto rt = Time::Format(gm.RaceTime);

        UI::TableNextRow();

        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        UI::Text(Text::Format("%02d. ", i+1)); // + Text::Format("%08x", id));
#if SIG_DEVELOPER
        AddSimpleTooltip("InstanceId: " + Text::Format("0x%08x", id));
#endif

        UI::TableNextColumn();
        UI::Text(ColoredString(gm.GhostNickname));

        UI::TableNextColumn();
        UI::Text(rt);

        UI::TableNextColumn();
        bool clicked = UI::Button(Icons::Eye + "##" + i);
        AddSimpleTooltip("Spectate");
        if (clicked) startnew(CoroutineFuncUserdataInt64(SpectateGhost), int64(i));

        UI::TableNextColumn();
        UI::BeginDisabled(saving.Find(id) >= 0);
        clicked = UI::Button(Icons::FloppyO + "##" + i);
        AddSimpleTooltip("Save " + gm.GhostNickname + "'s " + rt + " ghost for later.");
        if (clicked) SaveGhost(gm, id);
        UI::EndDisabled();

        UI::TableNextColumn();
        clicked = UI::Button(Icons::Times + "##" + i);
        AddSimpleTooltip("Unload ghost");
        if (clicked) UnloadGhost(i);
    }

    void SpectateGhost(int64 _i) {
        uint i = uint(_i);
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) throw("null playground script");
        auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);

        if (S_SetGhostAlphaTo1) ps.Ghosts_SetMaxAlpha(S_GhostOpacitySolo);
        g_SaveGhostTab.StartWatchGhostsLoopLoop();

        // auto cmap = GetApp().Network.ClientManiaAppPlayground;
        // if (cmap is null) throw("null cmap");
        auto mgr = GhostClipsMgr::Get(GetApp());
        auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
        auto g = mgr.Ghosts[i].GhostModel;

        // SendEvent_TMGame_Record_Spectate(LoginToWSID(g.GhostLogin));
        Update_ML_SetSpectateID(LoginToWSID(g.GhostLogin));

        auto ghostPlayTime = int(ps.Now) - lastSetStartTime;
        // if we choose a ghost that has already finished, restart ghosts
        if (int(g.RaceTime) < ghostPlayTime) {
            Call_Ghosts_SetStartTime(ps, ps.Now); // was ps.Now
        }
        g_BlockNextGhostsSetTimeAny = true;

        log_info("spectating ghost with instance id: " + id);
        //cast<CSmPlayer>(cp.Players[0]).;
        ps.UnspawnPlayer(cast<CSmScriptPlayer>(cast<CSmPlayer>(cp.Players[0]).ScriptAPI));
        ps.UIManager.UIAll.ForceSpectator = true;
        // normally 1 but this works and prevents ghost scrubber doing annoying things
        ps.UIManager.UIAll.SpectatorForceCameraType = 3;
        ps.UIManager.UIAll.Spectator_SetForcedTarget_Ghost(MwId(id));
        // ps.UIManager.UIAll.UISequence = CGamePlaygroundUIConfig::EUISequence::EndRound;

        if (scrubberMgr !is null && !scrubberMgr.IsStdPlayback)
            EngineSounds::SetEngineSoundVdBFromSettings_SpawnCoro();
    }

    void StartWatchGhostsLoopLoop() {
        startnew(CoroutineFunc(this.WatchGhostsToLoopThem)); // .WithRunContext(Meta::RunContext::NetworkAfterMainLoop);
    }

    bool watchLoopActive = false;
    void WatchGhostsToLoopThem() {
        if (watchLoopActive) return;
        watchLoopActive = true;
        // main ghost watch loop
        while (IsSpectatingGhost() && watchLoopActive) {
            // curr loaded max time
            // uint maxTime = GhostClipsMgr::GetMaxGhostDuration(GetApp());
            // auto g = GhostClipsMgr::GetGhostFromInstanceId()
            // CSmArenaRulesMode@ ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);

            // while PS exists and now < finish time of longest ghost
            while (IsSpectatingGhost() && int(GetApp().PlaygroundScript.Now) < (int(lastSpectatedGhostRaceTime) + lastSetStartTime - 20)) {
                yield();
            }
            if (!IsSpectatingGhost()) break;
            // TODO: this might set ghosts paused in wrong context
            try {
                if (scrubberMgr !is null && !scrubberMgr.IsPaused) {
                    if (!scrubberMgr.IsStdPlayback) {
                        scrubberMgr.DoUnpause();
                        trace('DoPause soon because !IsStdPlayback');
                        startnew(CoroutineFunc(scrubberMgr.DoPause));
                        EngineSounds::SetEngineSoundVdBFromSettings_SpawnCoro();
                    }
                    scrubberMgr.SetProgress(0.001);
                }
            } catch {
                // can get a null ptr exception here (from mlhook, but from this code) if we reload the plugin and the loop is active
                // warn("Got weird exception (null ptr?): " + getExceptionInfo());
            }
            yield();
        }
        watchLoopActive = false;
        g_BlockNextGhostsSetTimeAny = false;
    }

    void UnloadGhost(uint i) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) throw("null playground script");
        auto mgr = GhostClipsMgr::Get(GetApp());
        auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
        Update_ML_SetGhostUnloaded(LoginToWSID(mgr.Ghosts[i].GhostModel.GhostLogin));
        log_info("unloading ghost with instance id: " + id);
        ps.GhostMgr.Ghost_Remove(MwId(id));
        auto ix = saving.Find(id);
        if (ix >= 0) saving.RemoveAt(ix);
    }

    void SaveGhost(CGameCtnGhost@ gm, uint id) {
        saving.InsertLast(id);
        // we could upload the ghost like archivist, but it's easier to just get the current LB ghost
        // GetApp().PlaygroundScript.ScoreMgr.Map_GetPlayerListRecordList()
        startnew(CoroutineFuncUserdata(RunSaveGhost), ref(array<string> = {gm.GhostLogin, gm.Validate_ChallengeUid.GetName(), gm.GhostNickname, tostring(id)}));
    }

    void RunSaveGhost(ref@ r) {
        auto args = cast<string[]>(r);
        auto login = args[0];
        auto uid = args[1];
        auto nickname = args[2];
        auto id = Text::ParseUInt(args[3]);
        auto recs = Core::GetMapPlayerListRecordList({LoginToWSID(login)}, uid);
        if (recs is null) {
            NotifyWarning("Failed to get ghost download link: " + string::Join({nickname, login, uid}, " / "));
            return;
        }
        auto rec = recs[0];
        Cache::AddRecord(rec, login, nickname);
        // don't remove from the saving list b/c it'll get reset on map change
        // auto ix = saving.Find(id);
        // if (ix >= 0) saving.RemoveAt(ix);
    }

    void OnMapChange() override {
        saving.RemoveRange(0, saving.Length);
    }
}

class LoadGhostsTab : Tab {
    LoadGhostsTab() {
        super("Load Ghosts");
    }

    void DrawInner() override {
        UI::BeginTabBar("ghosts++ load tabs");
        g_Favorites.Draw();
        g_Players.Draw();
        g_Saved.Draw();
        g_Medals.Draw();
        g_LeaderboardTab.Draw();
        g_UrlTab.Draw();
        // g_PBTab.Draw();
        // g_NearTimeTab.Draw();
        // g_AroundRankTab.Draw();
        // g_IntervalsTab.Draw();
        UI::EndTabBar();
    }
}


class PlayersTab : Tab {

    PlayersTab() {
        super("Players");
    }

    string m_PlayerFilter = "";
    string[] loading;

    Json::Value@[]@ get_DefaultList() {
        return Cache::LoginsArr;
    }

    bool loadingWsid = false;
    void DrawInner() override {
        bool changed;
        UI::BeginDisabled(loadingWsid);
        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() * .5);
        m_PlayerFilter = UI::InputText("Filter", m_PlayerFilter, changed);
        if (m_PlayerFilter.Length == 36 && IsWSID(m_PlayerFilter)) {
            UI::SameLine();
            if (UI::Button(Icons::Plus+"##add-wsid")) {
                startnew(CoroutineFuncUserdataString(this.AddWSID), m_PlayerFilter);
            }
        }
        UI::EndDisabled();
        UI::SameLine();
        if (UI::Button("Reset##playersfilter")) {
            m_PlayerFilter = "";
            changed = true;
        }
        if (changed) {
            startnew(CoroutineFunc(UpdatePlayerFilter));
        }

        UI::Separator();

        auto players = (m_PlayerFilter.Length > 0) ? filteredPlayers : DefaultList;

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.3, .3, .3, .3));
        if (UI::BeginTable("players", 3, TABLE_FLAGS)) {
            UI::TableSetupColumn("Fav Player", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Find Ghost", UI::TableColumnFlags::WidthFixed, 100.);

            UI::ListClipper clip(players.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    if (i >= int(players.Length)) break;
                    auto j = players[i];
                    if (j.GetType() !=  Json::Type::Object) {
                        warn('not obj: ' + Json::Write(j));
                        @j = Json::Object();
                        j['key'] = 'unknown';
                        j['names'] = Json::Object();
                        j['names']['< UNK ERROR >'] = 1;
                    }
                    auto jNames = j['names'];
                    if (jNames.GetType() != Json::Type::Object) break;
                    // trace('j: ' + Json::Write(j));
                    auto names = jNames.GetKeys();
                    string namesStr = string::Join(names, ", ");
                    string login = j['key'];

                    UI::PushID(i);
                    UI::TableNextRow();
                    UI::TableNextColumn();
                    Cache::DrawPlayerFavButton(login);

                    UI::TableNextColumn();
                    UI::AlignTextToFramePadding();
                    UI::Text((i + 1) + ". " + namesStr);

                    UI::TableNextColumn();
                    UI::BeginDisabled(loading.Find(login) >= 0);
                    if (UI::Button("Find Ghost##" + i)) {
                        OnClickFindGhost(j);
                    }
                    UI::EndDisabled();
                    UI::PopID();
                }
            }

            UI::EndTable();
        }

        UI::PopStyleColor(1);
    }

    void AddWSID(const string &in wsid) {
        string login;
        try {
            login = WSIDToLogin(wsid);
        } catch {
            NotifyError("Invalid WSID: " + wsid);
            return;
        }
        loadingWsid = true;
        auto name = NadeoServices::GetDisplayNameAsync(wsid);
        Cache::AddLogin(wsid, login, name);
        NotifySuccess("Added player to player cache: " + name);
        loadingWsid = false;
        m_PlayerFilter = name;
        startnew(CoroutineFunc(UpdatePlayerFilter));
    }

    void OnClickFindGhost(Json::Value@ j) {
        loading.InsertLast(string(j['key']));
        startnew(CoroutineFuncUserdata(this.FindAndLoadGhost), j);
    }

    // find an load a ghost from a player json
    void FindAndLoadGhost(ref@ r) {
        auto j = cast <Json::Value>(r);
        string login = j['key'];
        trace(Json::Write(j));
        string wsid = j['wsid'];
        auto names = j['names'].GetKeys();

        Update_ML_SetGhostLoading(wsid);
        Core::LoadGhostOfPlayer(wsid, s_currMap, string::Join(names, ", "));
        Update_ML_SetGhostLoaded(wsid);
        // no need to refind someones ghost (is there?)
        // auto ix = loading.Find(login);
        // if (ix >= 0) loading.RemoveAt(ix);
    }

    Json::Value@[] filteredPlayers;
    void UpdatePlayerFilter() {
        filteredPlayers.RemoveRange(0, filteredPlayers.Length);
        Cache::GetPlayersFromNameFilter(m_PlayerFilter, filteredPlayers);
    }

    void OnMapChange() override {
        loading.RemoveRange(0, loading.Length);
    }

    void OnPlayerAdded() {
        UpdatePlayerFilter();
    }
}



class FavoritesTab : PlayersTab {
    FavoritesTab() {
        super();
        Name = "Favs";
        startnew(CoroutineFunc(this.InitSoon));
    }

    void OnMapChange() override {
        PlayersTab::OnMapChange();
        if (S_AutoloadFavoritedPlayers) startnew(CoroutineFunc(AutoloadFavoritePlayers));
    }

    void InitSoon() {
        sleep(100);
        while (!Cache::IsInitialized) yield();
        UpdatePlayerFilter();
    }

    array<Json::Value@>@ get_DefaultList() override property {
        return filteredPlayers;
    }

    void UpdatePlayerFilter() override {
        filteredPlayers.RemoveRange(0, filteredPlayers.Length);
        Cache::GetFavoritesFromNameFilter(m_PlayerFilter, filteredPlayers);
    }

    void OnFavAdded() {
        UpdatePlayerFilter();
    }

    void AutoloadFavoritePlayers() {
        auto app = GetApp();
        if (app.RootMap is null) return;
        sleep(200);
        if (app.RootMap is null) return;
        if (app.PlaygroundScript is null) return;
        auto net = app.Network;
        while (net.ClientManiaAppPlayground is null) {
            // trace('waiting for cmap');
            yield();
        }
        while (net.ClientManiaAppPlayground.UILayers.Length < 10) {
            // trace('waiting for cmap.UILayers.Len >= 10');
            yield();
        }
        if (app.RootMap is null) return;

        Json::Value@[] @favs = {};
        Cache::GetFavoritesFromNameFilter("", favs);
        auto nbToLoad = Math::Min(favs.Length, 10);
        for (uint i = 0; i < nbToLoad; i++) {
            OnClickFindGhost(Cache::GetLogin(favs[i]['key']));
        }
    }
}



bool SortGhosts(const Json::Value@ &in a, const Json::Value@ &in b) {
    if (a is null) return false;
    if (b is null) return true;
    return (int(a['time']) - int(b['time'])) < 0;
};


class SavedTab : Tab {
    SavedTab() {
        super("Saved");
    }

    bool cacheLoaded = false;
    bool cacheLoadStarted = false;
    Json::Value@[] ghostsForMap;

    void CheckLocalCache() {
        if (cacheLoadStarted) return;
        cacheLoadStarted = true;
        startnew(CoroutineFunc(this.LoadCache));
    }

    void LoadCache() {
        Cache::GetGhostsForMap(s_currMap, ghostsForMap);
        if (ghostsForMap.Length > 1)
            ghostsForMap.Sort(SortGhosts);
        cacheLoaded = true;
    }

    void DrawInner() override {
        CheckLocalCache();
        if (!cacheLoaded) {
            UI::Text("Loading...");
            return;
        }

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.3, .3, .3, .3));
        if (UI::BeginTable("saved ghosts", 5, TABLE_FLAGS)) {
            UI::TableSetupColumn("Ix", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 80.);
            UI::TableSetupColumn("date", UI::TableColumnFlags::WidthFixed, 80.);
            UI::TableSetupColumn("Load", UI::TableColumnFlags::WidthFixed, 50.);

            UI::ListClipper clip(ghostsForMap.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                // for (int i = 0; i < ghostsForMap.Length; i++) {
                    auto j = ghostsForMap[i];
                    string key = j['key'];
                    string name = j.Get('name', "?");
                    // string name = j['name'];
                    string time = Time::Format(j.Get('time', 0));
                    // string time = j['time'];
                    string date = j.Get('date', '?');
                    // string date = j['date'];
                    UI::PushID(i);

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::AlignTextToFramePadding();
                    UI::Text(Text::Format("%02d.", i + 1));
                    UI::TableNextColumn();
                    UI::Text(name);
                    UI::TableNextColumn();
                    UI::Text(time);
                    UI::TableNextColumn();
                    UI::Text(date);
                    UI::TableNextColumn();
                    UI::BeginDisabled(loading.Find(key) >= 0);
                    if (UI::Button("Load##"+i)) {
                        startnew(CoroutineFuncUserdata(this.LoadGhost), j);
                    }
                    UI::EndDisabled();

                    UI::PopID();
                }
            }

            UI::EndTable();
        }
        UI::PopStyleColor();
    }

    string[] loading;
    void LoadGhost(ref@ r) {
        auto j = cast<Json::Value>(r);
        string key = j['key'];
        string name = j['name'];
        // string wsid = j['wsid'];
        string time = Time::Format(int(j['time']));
        loading.InsertLast(key);
        Notify("Loading ghost: " + name + " / " + time);
        if (IsGhostLoaded(j)) {
            NotifyWarning("Ghost already loaded: " + name + " / " + time);
            sleep(1000);
        } else {
            Cache::LoadGhost(key);
        }
        auto ix = loading.Find(key);
        if (ix >= 0) loading.RemoveAt(ix);
    }

    void OnMapChange() override {
        ClearLocalCache();
    }

    void OnNewGhostSaved() {
        ClearLocalCache();
    }

    void ClearLocalCache() {
        cacheLoaded = false;
        cacheLoadStarted = false;
        ghostsForMap.RemoveRange(0, ghostsForMap.Length);
    }
}

class MedalsTab : Tab {
    int[] medals = {-1, -1, -1, -1, -1};

    MedalsTab() {
        super("Medals");
        startnew(CoroutineFunc(this.PopulateMedalTimes));
    }

    uint nbGhosts = 2;

    void DrawInner() override {
        UI::AlignTextToFramePadding();
        UI::Text("Load Medal Ghosts:");
        UI::Indent();
        UI::BeginDisabled(isLoadingGhosts);
        UI::SetNextItemWidth(100.);
        nbGhosts = Math::Clamp(UI::InputInt("Number of ghosts", nbGhosts), 1, 2);
        if (medals[4] > 0 && UI::Button(Time::Format(medals[4]) + " / Champion Medal Ghosts")) {
            LoadGhostsNear(medals[4], nbGhosts);
        }
        if (UI::Button(Time::Format(medals[3]) + " / AT Medal Ghosts")) {
            LoadGhostsNear(medals[3], nbGhosts);
        }
        if (UI::Button(Time::Format(medals[2]) + " / Gold Medal Ghosts")) {
            LoadGhostsNear(medals[2], nbGhosts);
        }
        if (UI::Button(Time::Format(medals[1]) + " / Silver Medal Ghosts")) {
            LoadGhostsNear(medals[1], nbGhosts);
        }
        if (UI::Button(Time::Format(medals[0]) + " / Bronze Medal Ghosts")) {
            LoadGhostsNear(medals[0], nbGhosts);
        }
        UI::EndDisabled();
        UI::Unindent();
    }

    void OnMapChange() override {
        if (s_currMap.Length == 0) return;
        medals[0] = medals[1] = medals[2] = medals[3] = medals[4] = -1;
        startnew(CoroutineFunc(this.PopulateMedalTimes));
    }

    void PopulateMedalTimes() {
        // give some time for other things to catch up, like CM
        while (GetApp().PlaygroundScript !is null && GetApp().PlaygroundScript.Now < 5000) yield();
        if (GetApp().PlaygroundScript is null) return;

        auto map = GetApp().RootMap;
        if (map is null) return;
        medals[0] = map.TMObjective_BronzeTime;
        medals[1] = map.TMObjective_SilverTime;
        medals[2] = map.TMObjective_GoldTime;
        medals[3] = map.TMObjective_AuthorTime;
#if DEPENDENCY_CHAMPIONMEDALS
        if (Meta::GetPluginFromID("ChampionMedals").Enabled) {
            medals[4] = ChampionMedals::GetCMTime();
            if (medals[4] < 1) {
                sleep(2500);
                medals[4] = ChampionMedals::GetCMTime();
            }
        }
#else
        medals[4] = -1;
#endif
    }
}
class LeaderboardTab : Tab {
    LeaderboardTab() {
        super("Leaderboard");
    }

    void DrawInner() override {
        if (g_GhostFinder is null) return;
        g_GhostFinder.EnsureLoaded();
        if (!g_GhostFinder.IsInitialized) {
            UI::Text("Loading...");
            return;
        }

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.3, .3, .3, .3));
        if (UI::BeginTable("leaderboard", 5, TABLE_FLAGS)) {
            UI::TableSetupColumn("Rank", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Fav", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 80.);
            // UI::TableSetupColumn("Date", UI::TableColumnFlags::WidthFixed, 80.);
            UI::TableSetupColumn("Load", UI::TableColumnFlags::WidthFixed, 50.);

            UI::ListClipper clip(g_GhostFinder.NbRecords);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    g_GhostFinder.ForLBRecord(i, LBRecordMapF(this.DrawRecordRow));
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
        UI::PopStyleColor();

    }

    void DrawRecordRow(uint rank, uint time, Json::Value@ j) {
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        UI::Text(tostring(rank) + ".");

        UI::TableNextColumn();
        Cache::DrawPlayerFavButton(j['login']);

        UI::TableNextColumn();

        string name = j['name'];
        UI::Text(name);

        UI::TableNextColumn();
        UI::Text(Time::Format(time));

        UI::TableNextColumn();
        UI::BeginDisabled(IsCurrLoadingGhost(j['accountId'])); //  || IsGhostLoaded(j)
        if (UI::Button("Load##" + rank)) {
            startnew(CoroutineFuncUserdata(this.LoadRecord), j);
        }
        UI::EndDisabled();
    }

    string[] loading;
    void LoadRecord(ref@ refJson) {
        auto j = cast<Json::Value>(refJson);
        auto wsid = j['accountId'];
        bool doNotLoad = IsCurrLoadingGhost(wsid) || IsGhostLoaded(j);
        loading.InsertLast(wsid);
        if (doNotLoad) {
            Notify("Ghost already loaded: " + string(j['name']) + " / " + Time::Format(int(j['time'])));
            sleep(1000);
        } else {
            SendEvent_TMGame_Record_Toggle(wsid);
            // Cache::LoadGhostsForWsids({wsid}, s_currMap);
        }
        RemoveFromLoading(wsid);
    }

    void RemoveFromLoading(const string &in wsid) {
        auto ix = loading.Find(wsid);
        if (ix >= 0) loading.RemoveAt(ix);
    }

    bool IsCurrLoadingGhost(const string &in wsid) {
        return loading.Find(wsid) >= 0;
    }

    void OnMapChange() override {
        loading.RemoveRange(0, loading.Length);
    }
}

class UrlTab : Tab {
    UrlTab() {
        super("URL");
    }
    string m_URL = "";
    void DrawInner() override {
        UI::BeginDisabled(loading);
        bool pEnter;
        m_URL = UI::InputText("URL", m_URL, pEnter, UI::InputTextFlags::EnterReturnsTrue);
        UI::SameLine();
        pEnter = UI::Button("Load##url") || pEnter;
        if (pEnter) {
            startnew(CoroutineFunc(this.LoadURL));
        }
        UI::EndDisabled();
    }

    bool loading = false;
    void LoadURL() {
        loading = true;
        string url = m_URL;
        log_info("Loading ghost from URL: " + url);
        Core::LoadGhostFromUrl(url, url);
        m_URL = "";
        loading = false;
    }

    void OnMapChange() override {
        m_URL = "";
    }
}

class PBTab : Tab {
    int pbTime;

    PBTab() {
        super("Near PB");
        pbTime = -1;
    }

    void DrawInner() override {
        UI::Text("Ranks Below PB");
    }

    void OnMapChange() override {
        pbTime = PlayerPBTime;
    }
}

class NearTime : Tab {
    NearTime() {
        super("Time");
    }

    void DrawInner() override {
        UI::Text(Name + "...");
    }
}

class AroundRank : Tab {
    AroundRank() {
        super("Rank");
    }

    void DrawInner() override {
        UI::Text(Name + "...");
    }
}

class Intervals : Tab {
    Intervals() {
        super("Between");
    }

    void DrawInner() override {
        UI::Text(Name + "...");
    }
}

bool isLoadingGhosts = false;

void LoadGhostsNear(uint time, uint nbGhosts) {
    isLoadingGhosts = true;
    startnew(_LoadGhostsNear, array<uint> = {time, nbGhosts});
}

void _LoadGhostsNear(ref@ r) {
    auto args = cast<array<uint>>(r);
    auto time = args[0];
    auto nbGhosts = args[1];
    if (g_GhostFinder is null) return;
    auto wsids = g_GhostFinder.FindAroundTime(time, nbGhosts);
    for (int i = 0; i < Math::Min(wsids.Length, nbGhosts); i++) {
        SendEvent_TMGame_Record_Toggle(wsids[i]);
    }
    // Cache::LoadGhostsForWsids(wsids, s_currMap);
    isLoadingGhosts = false;
}


bool IsGhostLoaded(Json::Value@ j) {
    int time = int(j['time']);
    auto mgr = GhostClipsMgr::Get(GetApp());
    for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        auto gm = mgr.Ghosts[i].GhostModel;
        if (int(gm.RaceTime) == time) {
            string name = j['name'];
            if (gm.GhostNickname == name) {
                return true;
            }
        }
    }
    return false;
}


bool IsWSID(const string &in wsid) {
    if (wsid.Length != 36) return false;
    // check dashes assume the best (we error later in case of problem)
    if (wsid[8] != 0x2d) return false;
    if (wsid[13] != 0x2d) return false;
    if (wsid[18] != 0x2d) return false;
    if (wsid[23] != 0x2d) return false;
    return true;
}
