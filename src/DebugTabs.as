
class DebugClipsTab : Tab {
    DebugClipsTab() {
        super("[D] Clips");
    }

    void DrawInner() override {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        auto clip1 = cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x20));
        uint64 clip1Ptr = Dev::GetOffsetUint64(mgr, 0x20);
        auto clip2 = cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x40));
        uint64 clip2Ptr = Dev::GetOffsetUint64(mgr, 0x40);
        auto debug1 = GetGhostClipPlayerDebugValues(clip1);
        auto debug2 = GetGhostClipPlayerDebugValues(clip2);

        DrawClip("clip1", clip1, clip1Ptr, debug1);
        UI::Separator();
        DrawClip("clip2", clip2, clip2Ptr, debug2);
    }

    void DrawClip(const string &in name, CGameCtnMediaClipPlayer@ clip, uint64 ptr, string[]@ debugVals) {
        UI::Text(name);
        UI::Indent();
        UI::Text("ptr: " + Text::FormatPointer(ptr));
        if (UI::IsItemClicked()) {
            IO::SetClipboard(Text::FormatPointer(ptr));
            Notify("Copied: " + Text::FormatPointer(ptr));
        }
        UI::Text("Debug vals: " + string::Join(debugVals, ", "));
        if (UI::Button("Pause " + name)) {
            SetGhostClipPlayerPaused(clip, 3.0);
        }
        if (UI::Button("Unpause " + name)) {
            SetGhostClipPlayerUnpaused(clip, 3.0, float(GhostClipsMgr::GetMaxGhostDuration(GetApp())) / 1000.);
        }
        UI::Unindent();
    }
}
class DebugGhostsTab : Tab {
    DebugGhostsTab() {
        super("[D] Ghosts");
    }

    void DrawInner() override {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        // UI::Text(GetReplaySpeed_Debug());
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
        super("[D] Cache");
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
        UI::Separator();
        DrawValLabel(lastSetStartTime, "lastSetStartTime");
        DrawValLabel(lastSpectatedGhostInstanceId.Value, "lastSpectatedGhostInstanceId.Value");
        DrawValLabel(lastSpectatedGhostRaceTime, "lastSpectatedGhostRaceTime");

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
void DrawValLabel(float v, const string &in l) {
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
