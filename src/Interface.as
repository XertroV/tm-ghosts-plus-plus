const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuTitle = "\\$dd5" + Icons::HandPointerO + "\\$z " + PluginName;


PBTab g_PBTab;
NearTime g_NearTimeTab;
AroundRank g_AroundRankTab;
Intervals g_IntervalsTab;
FavoritesTab g_Favorites;
PlayersTab g_Players;
SavedTab g_Saved;
MedalsTab g_Medals;
LoadGhostsTab g_LoadGhostTab;
SaveGhostsTab g_SaveGhostTab;
DebugGhostsTab g_DebugTab;
DebugCacheTab g_DebugCacheTab;

Tab@[] tabs = {g_PBTab, g_NearTimeTab, g_AroundRankTab, g_IntervalsTab, g_Favorites, g_LoadGhostTab, g_SaveGhostTab, g_Saved, g_Players, g_Medals, g_DebugTab};

/** Render function called every frame intended for `UI`.
*/
void RenderInterface() {
    if (!S_ShowWindow) return;
    if (!Cache::hasDoneInit) startnew(Cache::Initialize);


    UI::SetNextWindowSize(500, 300, UI::Cond::Appearing);
    if (UI::Begin(MenuTitle, S_ShowWindow)) {
        if (GetApp().PlaygroundScript is null) {
            UI::Text("Please load a map in Solo mode");
        } else if (!Cache::IsInitialized) {
            UI::Text("Loading...");
        } else {
            UI::BeginTabBar("save or load ghosts");
            g_SaveGhostTab.Draw();
            g_LoadGhostTab.Draw();
#if SIG_DEVELOPER
            g_DebugTab.Draw();
            g_DebugCacheTab.Draw();
#endif
            UI::EndTabBar();
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
        super("Save Ghosts");
    }

    uint[] saving;

    void DrawInner() override {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        if (mgr.Ghosts.Length == 0) {
            UI::Text("No ghosts loaded.");
            return;
        }

        if (UI::BeginTable("save-ghosts", 5, UI::TableFlags::SizingStretchProp)) {

            UI::TableSetupColumn("Ix", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 80.);
            UI::TableSetupColumn("Save", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Unload", UI::TableColumnFlags::WidthFixed, 40.);

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
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        }
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
        //         Text::Format("%08x", u3)
        //     );
        // }
    }

    void DrawSaveGhost(NGameGhostClips_SClipPlayerGhost@ gc, uint i, uint id) {
        auto gm = gc.GhostModel;
        auto clip = gc.Clip;
        auto rt = Time::Format(gm.RaceTime);

        UI::TableNextRow();

        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        UI::Text(Text::Format("%02d. ", i)); // + Text::Format("%08x", id));

        UI::TableNextColumn();
        UI::Text(gm.GhostNickname);

        UI::TableNextColumn();
        UI::Text(rt);

        UI::TableNextColumn();
        UI::BeginDisabled(saving.Find(id) >= 0);
        bool clicked = UI::Button(Icons::FloppyO + "##" + i);
        AddSimpleTooltip("Save " + gm.GhostNickname + "'s " + rt + " ghost for later.");
        if (clicked) SaveGhost(gm, id);
        UI::EndDisabled();

        UI::TableNextColumn();
        clicked = UI::Button(Icons::Times + "##" + i);
        AddSimpleTooltip("Unload ghost");
        if (clicked) UnloadGhost(i);
    }

    void UnloadGhost(uint i) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) throw("null playground script");
        auto mgr = GhostClipsMgr::Get(GetApp());
        auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
        log_info("unloading ghost with instance id: " + id);
        ps.GhostMgr.Ghost_Remove(MwId(id));
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
        auto ix = saving.Find(id);
        if (ix >= 0) saving.RemoveAt(ix);
    }
}

class LoadGhostsTab : Tab {
    LoadGhostsTab() {
        super("Load Ghosts");
    }

    void DrawInner() override {
        UI::BeginTabBar("ghost picker tabs");
        g_Favorites.Draw();
        g_Players.Draw();
        g_Saved.Draw();
        g_PBTab.Draw();
        g_NearTimeTab.Draw();
        g_AroundRankTab.Draw();
        g_IntervalsTab.Draw();
        UI::EndTabBar();
    }
}

class FavoritesTab : Tab {

    FavoritesTab() {
        super("Favs");
    }

    void DrawInner() override {
        UI::Text("Favs");
    }

    void OnMapChange() override {
    }
}
class PlayersTab : Tab {

    PlayersTab() {
        super("Players");
    }

    string m_PlayerFilter = "";
    string[] loading;

    void DrawInner() override {
        bool changed;
        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() * .5);
        m_PlayerFilter = UI::InputText("Filter", m_PlayerFilter, changed);
        UI::SameLine();
        if (UI::Button("Reset##playersfilter")) {
            m_PlayerFilter = "";
            changed = true;
        }
        if (changed) {
            startnew(CoroutineFunc(UpdatePlayerFilter));
        }

        UI::Separator();

        auto players = (m_PlayerFilter.Length > 0) ? filteredPlayers : Cache::LoginsArr;

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.3, .3, .3, .3));

        if (UI::BeginTable("players", 3, UI::TableFlags::SizingStretchProp | UI::TableFlags::RowBg)) {
            UI::TableSetupColumn("Fav Player", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Find Ghost", UI::TableColumnFlags::WidthFixed, 100.);

            UI::ListClipper clip(players.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    if (i >= players.Length) break;
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
                    UI::Text(i + ". " + namesStr);

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

    void OnClickFindGhost(Json::Value@ j) {
        loading.InsertLast(string(j['key']));
        startnew(CoroutineFuncUserdata(this.FindAndLoadGhost), j);
    }

    void FindAndLoadGhost(ref@ r) {
        auto j = cast <Json::Value>(r);
        string login = j['key'];
        string wsid = j['wsid'];
        auto names = j['names'].GetKeys();
        Core::LoadGhostOfPlayer(wsid, s_currMap, string::Join(names, ", "));
        auto ix = loading.Find(login);
        if (ix >= 0) loading.RemoveAt(ix);
    }

    Json::Value@[] filteredPlayers;
    void UpdatePlayerFilter() {
        filteredPlayers.RemoveRange(0, filteredPlayers.Length);
        Cache::GetPlayersFromNameFilter(m_PlayerFilter, filteredPlayers);
    }

    void OnMapChange() override {
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

        if (UI::BeginTable("saved ghosts", 5, UI::TableFlags::SizingStretchProp)) {
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
                    UI::Text(Text::Format("%02d.", i));
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
    }

    string[] loading;
    void LoadGhost(ref@ r) {
        auto j = cast<Json::Value>(r);
        string key = j['key'];
        string name = j['name'];
        string time = Time::Format(int(j['time']));
        loading.InsertLast(key);
        Notify("Loading ghost: " + name + " / " + time);
        Cache::LoadGhost(key);
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
    MedalsTab() {
        super("Medals");
    }

    void DrawInner() override {
        UI::Text("Near medal times");
    }

    void OnMapChange() override {
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
