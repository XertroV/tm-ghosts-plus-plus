bool permissionsOkay = false;
ResetHook@ resetHook = ResetHook();
SpectateHook@ spectateHook = SpectateHook();
ToggleHook@ toggleHook = ToggleHook();
const string SetFocusedRecord_PageUID = "SetFocusedRecord";

UI::Font@ g_fontStd;
UI::Font@ g_fontBold;
UI::Font@ g_fontLarge;
UI::Font@ g_fontLarger;

void Main() {
    trace('ghosts++ checking permissions');
    CheckRequiredPermissions();
    trace('checked permissions');
    CheckAndSetGameVersionSafe();
    if (!KnownSafe) {
        while (!GameVersionSafe) yield();
        // initialization problems when GameVersionSafe is false in a map
        while (GetApp().RootMap !is null) yield();
    }
    // startnew(WindowFocusCoro);
    startnew(MapCoro);
    startnew(ClearTaskCoro);
    startnew(SetupIntercepts);
    startnew(InitGP);
    startnew(LoadFonts);
    trace('started coros');
    trace('checking spec');
    if (GetApp().PlaygroundScript !is null) {
        trace('in playground! getting current values');
        // get current spec'd ghost id and update values
        SetCurrentGhostValues();
        if (IsSpectatingGhost()) {
            trace("starting watch loop on init because we're spectating a ghost");
            g_SaveGhostTab.StartWatchGhostsLoopLoop();
        }
        @g_GhostFinder = GhostFinder();
    }

#if FALSE
    startnew(RunGhostTest);
#endif
}

void LoadFonts() {
    @g_fontStd = UI::LoadFont("DroidSans.ttf", 16., -1, -1, true, true, true);
    @g_fontBold = UI::LoadFont("DroidSans-bold.ttf");
    @g_fontLarge = UI::LoadFont("DroidSans.ttf", 20.);
    @g_fontLarger = UI::LoadFont("DroidSans.ttf", 26.);
}

void InitGP() {
    yield();
    yield();
    yield();
    auto app = GetApp();
    while (app.PlaygroundScript is null) yield();
    trace('registering callback & hook');
    MLHook::RegisterPlaygroundMLExecutionPointCallback(ML_PG_Callback);
    MLHook::RegisterMLHook(resetHook, "RaceMenuEvent_NextMap", true);
    MLHook::RegisterMLHook(resetHook, "RaceMenuEvent_Exit", true);

    // MLHook::RegisterMLHook(spectateHook, "TMGame_Record_SpectateGhost", true);
    // MLHook::RegisterMLHook(spectateHook, "TMGame_Record_Spectate", true);
    // MLHook::RegisterMLHook(toggleHook, "TMGame_Record_ToggleGhost", true);
    // MLHook::RegisterMLHook(toggleHook, "TMGame_Record_TogglePB", true);
    // MLHook::InjectManialinkToPlayground(SetFocusedRecord_PageUID, SETFOCUSEDRECORD_SCRIPT_TXT, true);

    SetCurrentGhostValues();
    startnew(WatchAndRemoveFadeOut);
    g_SaveGhostTab.StartWatchGhostsLoopLoop();
    trace('init done');
    g_Initialized = true;
}

bool g_Initialized = false;

void Unload() {
    trace('unloading ghosts++ #1 paused');
    // if (scrubberPaused) GhostClipsMgr::UnpauseClipPlayers(GhostClipsMgr::Get(GetApp()), 0., 60.0);
    if (scrubberMgr !is null)
        scrubberMgr.ResetAll();
    trace('unloading ghosts++ #2 mlhook');
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
    trace('unloading ghosts++ #3 done');
    EngineSounds::Unapply();
}
void OnDestroyed() { Unload(); }
void OnDisabled() { Unload(); }

// check for permissions and
void CheckRequiredPermissions() {
    permissionsOkay = Permissions::ViewRecords() && Permissions::PlayRecords();
    if (!permissionsOkay) {
        NotifyWarning("Your edition of the game does not support playing against record ghosts.\n\nThis plugin won't work, sorry :(.");
        while(true) { sleep(10000); } // do nothing forever
    }
}

// void WindowFocusCoro() {
//     while (true) {
//         yield();
//         if (UI::IsWindowFocused())
//     }
// }

string s_currMap = "";

void MapCoro() {
    s_currMap = CurrentMap;
    while(true) {
        sleep(273); // no need to check that frequently. 273 seems primeish
        if (s_currMap != CurrentMap) {
            s_currMap = CurrentMap;
            startnew(OnMapChange);
        }
    }
}

void OnMapChange() {
    lastSpectatedGhostRaceTime = 0;
    lastLoadedGhostRaceTime = 0;
    maxTime = 0.;
    if (s_currMap.Length > 0) {
        @g_GhostFinder = GhostFinder();
    }
    if (tabs is null) return;
    for (uint i = 0; i < tabs.Length; i++) {
        tabs[i].OnMapChange();
    }
    if (scrubberMgr is null) return;
    scrubberMgr.ResetAll();
    EngineSounds::Unapply();
}


void WatchAndRemoveFadeOut() {
    auto app = GetApp();
    while (true) {
        yield();
        while (app.PlaygroundScript is null) yield();
        while (app.Network.ClientManiaAppPlayground is null || app.Network.ClientManiaAppPlayground.UILayers.Length < 5) yield();
        sleep(1000);
        if (app.Network.ClientManiaAppPlayground is null) continue;
        for (uint i = 0; i < app.Network.ClientManiaAppPlayground.UILayers.Length; i++) {
            auto layer = app.Network.ClientManiaAppPlayground.UILayers[i];
            auto qf = cast<CGameManialinkQuad>(layer.LocalPage.GetFirstChild("quad-fade"));
            if (qf !is null) {
                qf.Size = vec2(0, 0);
                // log_trace("!! SET SIZE ON QUAD FADE");
            }
        }
        string uid = app.RootMap.EdChallengeId;
        while (app.RootMap !is null && uid == app.RootMap.EdChallengeId) yield();
    }
}


uint lastRefresh = 0;
const uint disableTime = 3000;
void Render() {
    if (!GameVersionSafe) return;
    if (!permissionsOkay) return;
    if (!g_Initialized) return;
    if (!S_EnableInEditor && GetApp().Editor !is null) return;
    if (S_DrawLetterboxBars) UpdateDrawLetterboxBars();
    // if (!S_ShowWindow) return;
    DrawScrubber();
    RenderLoadingGhostsMsg();
    return;
}

void RenderMenu() {
    if (!GameVersionSafe) return;
    if (!permissionsOkay) return;
    if (!g_Initialized) return;
    if (UI::MenuItem("\\$888" + Icons::HandPointerO + "\\$z " + PluginName, "", S_ShowWindow)) {
        S_ShowWindow = !S_ShowWindow;
    }
}

string get_CurrentMap() {
    auto map = GetApp().RootMap;
    if (map is null) return "";
    return map.MapInfo.MapUid;
}

// /**
// TMGame_Record_SpectateGhost
// TMGame_Record_ToggleGhost
// TMGame_Record_TogglePB
//  */
// void ToggleGhost(const string &in playerId) {
//     if (!permissionsOkay) return;
//     // trace('toggled ghost for ' + playerId);
//     MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {playerId});
//     bool enabled = false;
//     toggleCache.Get(playerId, enabled);
//     toggleCache[playerId] = !enabled;
// }

// void ToggleSpectator() {
//     if (!permissionsOkay) return;
//     auto pids = UpdateMapRecords();
//     if (lastRecordPid == "" || int(pids.Length) < g_numGhosts) {
//         NotifyWarning("\n>> Toggle ghosts first at least once. <<\n");
//     } else {
//         MLHook::Queue_SH_SendCustomEvent("TMGame_Record_SpectateGhost", {pids[g_numGhosts - 1]});
//     }
// }


/*
UI STUFF
*/

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifySuccess(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, vec4(.4, .7, .1, .3), 12000);
    trace("Notified: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 12000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.7, .4, .1, .3), 12000);
}


bool IsSpectatingGhost() {
    auto ps = GetApp().PlaygroundScript;
    if (ps is null || ps.UIManager is null) return false;
    return ps.UIManager.UIAll.ForceSpectator;
}

double lastExitPauseAt;
void ExitSpectatingGhost() {
    if (scrubberMgr !is null) lastExitPauseAt = scrubberMgr.pauseAt;
    auto ps = GetApp().PlaygroundScript;
    if (ps is null || ps.UIManager is null) return;
    SendEvent_TMGame_Record_Spectate_None();
    // Update_ML_SetSpectateID("");
}

void SendEvent_TMGame_Record_Spectate_None() {
    SendEvent_TMGame_Record_Spectate("");
}

void SendEvent_TMGame_Record_Spectate(const string &in wsid) {
    MLHook::Queue_PG_SendCustomEvent("TMGame_Record_Spectate", {wsid});
}

void SendEvent_TMGame_Record_Toggle(const string &in wsid) {
    MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {wsid});
}

void ExitSpectatingGhostAndCleanUp() {
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    auto cp = GetApp().CurrentPlayground;
    if (ps is null || ps.UIManager is null || cp is null) return;
    if (spectateHook.lastLoadWsid.Length > 0)
        SendEvent_TMGame_Record_Spectate(spectateHook.lastLoadWsid);
    spectateHook.lastLoadWsid = "";
    // return;
    // auto speccing = GetCurrentlySpecdGhostInstanceId(ps);
    // speccing =
    // auto mgr = GhostClipsMgr::Get(GetApp());
    // auto g = GhostClipsMgr::GetGhostFromInstanceId(mgr, speccing);
    // string wsid = g is null ? "" : LoginToWSID(g.GhostModel.GhostLogin);
    // SendEvent_TMGame_Record_Spectate(wsid);
    // lastSpectatedGhostInstanceId
    ExitSpectatingGhost();
    Call_Ghosts_SetStartTime(ps, -1);
    ps.UIManager.UIAll.UISequence = CGamePlaygroundUIConfig::EUISequence::Playing;
    ps.UIManager.UIAll.ForceSpectator = false;
    ps.UIManager.UIAll.SpectatorForceCameraType = 15;
    ps.UIManager.UIAll.Spectator_SetForcedTarget_Clear();
    ps.SpawnPlayer(cast<CSmScriptPlayer>(cast<CSmPlayer>(cp.Players[0]).ScriptAPI), 0, 0, GetDefaultMapSpawn(ps), ps.Now);
    // yield();
    // ps.SpawnPlayer(cast<CSmScriptPlayer>(cast<CSmPlayer>(cp.Players[0]).ScriptAPI), 0, 0, GetDefaultMapSpawn(ps), ps.Now);
    // ps.RespawnPlayer(cast<CSmScriptPlayer>(cast<CSmPlayer>(cp.Players[0]).ScriptAPI));
}


// From Titles/Trackmania/Scripts/Libs/Nadeo/TMGame/Modes/Map.Script.txt, Void LoadMap()
CGameScriptMapSpawn@ GetDefaultMapSpawn(CSmArenaRulesMode@ ps) {
    bool spawnIsMultilap = false;
    CGameScriptMapSpawn@ spawn;
    for (uint i = 0; i < ps.MapLandmarks.Length; i++) {
        auto lm = ps.MapLandmarks[i];
        bool isMultilap = lm.Tag == "StartFinish";
        if (!(lm.Tag == "Spawn" || isMultilap)) continue;
        if (isMultilap) {
            if (lm.PlayerSpawn !is null && lm.Waypoint !is null && lm.Waypoint.IsMultiLap) {
                spawnIsMultilap = true;
                @spawn = lm.PlayerSpawn;
            }
        } else if (spawn is null || spawnIsMultilap) {
            spawnIsMultilap = false;
            @spawn = lm.PlayerSpawn;
        }
    }
    return spawn;
}

uint UNLOCK_TIMER_AMOUNT = 0x2000000;

bool IsTimerUnlocked(CSmArenaRulesMode@ ps) {
    return ps.Now >= UNLOCK_TIMER_AMOUNT;
}

void UnlockPlaygroundTimer(CSmArenaRulesMode @ps) {
    if (IsTimerUnlocked(ps)) return;
    auto app = GetApp();
    // check a bunch of things that should be false only when in solo
    auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
    if (ps is null || cp is null) return;
    if (app.Editor !is null || app.PlaygroundScript is null) return;
    auto ghostTime = ps.Now - Math::Max(0, lastSetStartTime);
    uint newNow = ps.Now + UNLOCK_TIMER_AMOUNT;
    Dev::SetOffset(cp, GetOffset(cp, "PredictionSmooth") + 0x14, newNow);
    ps.StartTime += UNLOCK_TIMER_AMOUNT;
    Call_Ghosts_SetStartTime(ps, newNow - ghostTime);
}


void CheckUnlockTimelinePrompt(uint ghostRaceTime) {
    if (S_SuppressUnlockTimelinePrompt) return;
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) return;
    if (IsTimerUnlocked(ps)) return;
    if (ghostRaceTime < 90000) return;
    if (ghostRaceTime < ps.Now + 30000) return;
    g_ShowUnlockTimerPrompt = true;
}


/** Called whenever a key is pressed on the keyboard. See the documentation for the [`VirtualKey` enum](https://openplanet.dev/docs/api/global/VirtualKey).
*/
UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    // if (down && key == VirtualKey::Escape && IsSpectatingGhost()) {
    //     ExitSpectatingGhost();
    //     if (scrubberMgr !is null) scrubberMgr.ResetAll();
    //     // GetApp().Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Resume);
    //     return UI::InputBlocking::Block;
    // }
    return UI::InputBlocking::DoNothing;
}

/** Called whenever the mouse wheel is scrolled. `x` and `y` are the scroll delta values.
*/
UI::InputBlocking OnMouseWheel(int x, int y) {
    pendingScroll = vec2(x, y);
    return UI::InputBlocking::DoNothing;
}

vec2 pendingScroll = vec2();

void RenderEarly() {
    pendingScroll = vec2();

    DrawUnlockTimelinePromptWindow();
}
