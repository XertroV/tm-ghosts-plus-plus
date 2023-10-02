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

Tab@[] tabs = {g_PBTab, g_NearTimeTab, g_AroundRankTab, g_IntervalsTab, g_Favorites, g_LoadGhostTab, g_SaveGhostTab, g_Saved, g_Players, g_Medals, g_DebugTab};

/** Render function called every frame intended for `UI`.
*/
void RenderInterface() {
    if (!S_ShowWindow) return;
    if (!Cache::hasDoneInit) startnew(Cache::Initialize);

    UI::SetNextWindowSize(400, 300, UI::Cond::Appearing);
    if (UI::Begin(MenuTitle, S_ShowWindow)) {
        if (!Cache::IsInitialized) {
            UI::Text("Loading...");
        } else {
            UI::BeginTabBar("save or load ghosts");
            g_SaveGhostTab.Draw();
            g_LoadGhostTab.Draw();
#if SIG_DEVELOPER
            g_DebugTab.Draw();
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

    void DrawInner() override {
        auto mgr = GhostClipsMgr::Get(GetApp());
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            DrawSaveGhost(mgr.Ghosts[i], i);
        }
    }

    void DrawSaveGhost(NGameGhostClips_SClipPlayerGhost@ gc, uint i) {
        auto gm = gc.GhostModel;
        auto rt = Time::Format(gm.RaceTime);
        UI::AlignTextToFramePadding();
        UI::Text(gm.GhostNickname + " -- "+rt+"");
        UI::SameLine();
        bool clicked = UI::Button(Icons::FloppyO + "##" + i);
        AddSimpleTooltip("Save " + gm.GhostNickname + "'s " + rt + " ghost for later.");
        if (clicked) {
            SaveGhost(gm);
        }
    }

    void SaveGhost(CGameCtnGhost@ gm) {
        // we could upload the ghost like archivist, but it's easier to just get the current LB ghost
        // GetApp().PlaygroundScript.ScoreMgr.Map_GetPlayerListRecordList()
        startnew(CoroutineFuncUserdata(RunSaveGhost), {gm.GhostLogin, gm.Validate_ChallengeUid, gm.GhostNickname});
    }

    void RunSaveGhost(ref@ r) {
        auto args = cast<string[]>(r);
        auto login = args[0];
        auto uid = args[1];
        auto nickname = args[2];
        auto recs = Core::GetMapPlayerListRecordList({LoginToWSID(login)}, uid);
        if (recs is null) {
            NotifyWarning("Failed to get ghost download link: " + string::Join({nickname, login, uid}, " / "));
            return;
        }
        auto rec = recs[0];
        Cache::AddRecord(rec);
        NotifySuccess("Saved ghost: ")
    }
}

class DebugGhostsTab : Tab {
    DebugGhostsTab() {
        super("Debug Ghosts");
    }

    void DrawInner() override {
        auto mgr = GhostClipsMgr::Get(GetApp());
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            DrawDebugGhost(mgr.Ghosts[i], i);
        }
    }

    void DrawDebugGhost(NGameGhostClips_SClipPlayerGhost@ gc, uint i) {
        auto gm = gc.GhostModel;
        auto zcc = gc.GhostZoneCountryCache;
        if (UI::TreeNode(gm.GhostNickname + "( "+Time::Format(gm.RaceTime)+" )" + "##" + i, UI::TreeNodeFlags::None)) {
            if (UI::TreeNode("GhostZoneCountryCache##" + i, UI::TreeNodeFlags::DefaultOpen)) {
                UI::Columns(2);
                DrawValLabel(zcc.Description, "Description");
                DrawValLabel(zcc.IdName, "IdName");
                DrawValLabel(tostring(zcc.IsGroup), "IsGroup");
                DrawValLabel(zcc.Name, "Name");
                DrawValLabel(zcc.Login, "Login");
                DrawValLabel(zcc.Path, "Path");
                UI::Columns(1);
                UI::TreePop();
            }
            if (UI::TreeNode("Model##" + i, UI::TreeNodeFlags::DefaultOpen)) {
                UI::Columns(2);
                DrawValLabel(gm.Size, "Size");
                DrawValLabel(gm.Duration, "Duration");
                DrawValLabel(gm.RaceTime, "RaceTime");
                DrawValLabel(gm.NbRespawns, "NbRespawns");
                DrawValLabel(gm.StuntsScore, "StuntsScore");
                DrawValLabel(gm.ModelIdentAuthor.GetName(), "ModelIdentAuthor");
                DrawValLabel(gm.ModelIdentName.GetName(), "ModelIdentName");
                DrawValLabel(gm.GhostAvatarName, "GhostAvatarName");
                DrawValLabel(gm.GhostCountryPath, "GhostCountryPath");
                DrawValLabel(gm.GhostLogin, "GhostLogin");
                DrawValLabel(gm.GhostNickname, "GhostNickname");
                DrawValLabel(gm.GhostTrigram, "GhostTrigram");
                DrawValLabel(gm.LightTrailColor.ToString(), "LightTrailColor");
                DrawValLabel(tostring(gm.m_GhostNameLogoType), "m_GhostNameLogoType");
                DrawValLabel(gm.Validate_ChallengeUid.GetName(), "Validate_ChallengeUid");
                DrawValLabel(gm.Validate_CpuKind, "Validate_CpuKind");
                DrawValLabel(gm.Validate_ExeChecksum, "Validate_ExeChecksum");
                DrawValLabel(gm.Validate_ExeVersion, "Validate_ExeVersion");
                DrawValLabel(gm.Validate_ExtraTool_Info, "Validate_ExtraTool_Info");
                DrawValLabel(gm.Validate_GameMode, "Validate_GameMode");
                DrawValLabel(gm.Validate_GameModeCustomData, "Validate_GameModeCustomData");
                DrawValLabel(gm.Validate_OsKind, "Validate_OsKind");
                DrawValLabel(gm.Validate_ScopeId, "Validate_ScopeId");
                DrawValLabel(gm.Validate_ScopeType, "Validate_ScopeType");
                DrawValLabel(gm.Validate_TitleId, "Validate_TitleId");
                UI::Columns(1);
                UI::TreePop();
            }

            UI::TreePop();
        }

    }
    void DrawValLabel(const string &in v, const string &in l) {
        UI::Text(l + ": ");
        UI::NextColumn();
        UI::Text(v);
        UI::NextColumn();
    }

    void DrawValLabel(uint v, const string &in l) {
        DrawValLabel(tostring(v), l);
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
        super("Favorites");
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

    void DrawInner() override {
        UI::Text("Players");
    }

    void OnMapChange() override {
    }
}
class SavedTab : Tab {
    SavedTab() {
        super("Favorites");
    }

    void DrawInner() override {
        UI::Text("Favs");
    }

    void OnMapChange() override {
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
        super("Intervals");
    }

    void DrawInner() override {
        UI::Text(Name + "...");
    }
}
