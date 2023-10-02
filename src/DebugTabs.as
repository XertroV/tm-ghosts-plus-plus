
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
        auto clip = gc.Clip;
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
            if (UI::TreeNode("CGameCtnMediaClip##" + i, UI::TreeNodeFlags::DefaultOpen)) {
                UI::Columns(2);
                DrawValLabel(clip.LocalPlayerClipEntIndex, "LocalPlayerClipEntIndex");
                DrawValLabel(clip.Compat_IntroRelativeToBlock, "Compat_IntroRelativeToBlock");
                DrawValLabel(clip.IdName, "IdName");
                DrawValLabel(clip.Name, "Name");
                DrawValLabel(clip.StopOnRespawn, "StopOnRespawn");
                DrawValLabel(clip.StopWhenLeave, "StopWhenLeave");
                DrawValLabel(clip.StopWhenRespawn, "StopWhenRespawn");
                DrawValLabel(clip.TriggersBeforeRaceStart, "TriggersBeforeRaceStart");
                DrawValLabel(clip.Tracks.Length, "Tracks.Length");
                UI::Columns(1);
                if (UI::Button("Explore Clip##"+i)) {
                    ExploreNod("Clip", clip);
                }
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
}
class DebugCacheTab : Tab {
    DebugCacheTab() {
        super("Debug Cache");
    }

    void DrawInner() override {
        UI::Columns(2);
        DrawValLabel(Cache::isLoading, "isLoading");
        DrawValLabel(Cache::hasDoneInit, "hasDoneInit");
        DrawValLabel(Cache::IsInitialized, "IsInitialized");
        DrawValLabel(Cache::GhostsArr.Length, "GhostsArr.Length");
        DrawValLabel(Cache::LoginsArr.Length, "LoginsArr.Length");
        DrawValLabel(Cache::FavoritesArr.Length, "FavoritesArr.Length");
        DrawValLabel(Cache::MapsArr.Length, "MapsArr.Length");
        UI::Columns(1);
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
void DrawValLabel(bool v, const string &in l) {
    DrawValLabel(tostring(v), l);
}



uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (nod is null) throw('nod was null');
    auto tmpNod = CMwNod();
    uint64 tmp = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, nod);
    uint64 ptr = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, tmp);
    return ptr;
}
