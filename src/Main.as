bool permissionsOkay = false;
ResetHook@ resetHook = ResetHook();
SpectateHook@ spectateHook = SpectateHook();
ToggleHook@ toggleHook = ToggleHook();
const string SetFocusedRecord_PageUID = "SetFocusedRecord";

UI::Font@ g_fontStd;
UI::Font@ g_fontBold;
UI::Font@ g_fontLarge;
UI::Font@ g_fontLarger;
UI::Font@ g_fontMono;

void Main() {
    startnew(CheckMLFeedEnabled);
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
    startnew(Loop_BeforeScripts).WithRunContext(Meta::RunContext::BeforeScripts);
    startnew(MapCoro);
    startnew(ClearTaskCoro);
    startnew(SetupIntercepts);
    startnew(InitGP);
    startnew(LoadFonts);
    startnew(OnUpdatedGpsScrubbingSetting);
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

    startnew(ForceGhostAlphaLoop).WithRunContext(Meta::RunContext::AfterMainLoop);

#if FALSE
    startnew(RunGhostTest);
#endif
}

void CheckMLFeedEnabled() {
    auto mlhook = Meta::GetPluginFromID("MLHook");
    if (mlhook is null) {
        NotifyError("MLHook not found. Ghosts++ will not work.");
        return;
    }
    if (!mlhook.Enabled) {
        NotifyError("MLHook is disabled. Please enable it (toggle it on). Ghosts++ will not work otherwise.");
        return;
    }
}

// startnew(ForceGhostAlphaLoop).WithRunContext(Meta::RunContext::AfterMainLoop);
void ForceGhostAlphaLoop() {
    auto app = GetApp();
    while (true) {
        yield();
        if (!S_GhostOpacityOverrideOnline && !S_SetGhostAlphaTo1) {
            sleep(91); continue;
        }
        if (app.PlaygroundScript !is null) {
            if (S_SetGhostAlphaTo1) {
                // persists, so don't need to do this very often
                cast<CSmArenaRulesMode>(app.PlaygroundScript).Ghosts_SetMaxAlpha(S_GhostOpacitySolo);
            }
            sleep(131); continue;
        } else if (S_GhostOpacityOverrideOnline && app.CurrentPlayground !is null) {
            auto net = app.Network;
            auto si = cast<CTrackManiaNetworkServerInfo>(net.ServerInfo);
            // only enable for time attack, otherwise it affects royal, etc.
            if (!IsTimeAttackDebounced(si)) {
                sleep(91); continue;
            }
            // need to set this every frame
            auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
            if (cp is null) continue;
            if (cp.Arena is null) continue;
            if (cp.Arena.Rules is null) continue;
            CSmArenaRules_SetGhostAlpha(cp.Arena.Rules, S_GhostOpacityTimeAttack);
        }
    }
}

uint lastTaCheck = 0;
bool lastTaCheckResult = false;
bool IsTimeAttackDebounced(CTrackManiaNetworkServerInfo@ si) {
    if (lastTaCheck + 1000 > Time::Now) return lastTaCheckResult;
    lastTaCheck = Time::Now;
    lastTaCheckResult = si.CurGameModeStr == "TM_TimeAttack_Online"
        || si.CurGameModeStr == "TM_COTDQualifications_Online";
    return lastTaCheckResult;
}

void LoadFonts() {
    @g_fontStd = UI::LoadFont("DroidSans.ttf", 16., -1, -1, true, true, true);
    @g_fontBold = UI::LoadFont("DroidSans-bold.ttf");
    @g_fontLarge = UI::LoadFont("DroidSans.ttf", 20.);
    @g_fontLarger = UI::LoadFont("DroidSans.ttf", 26.);
    @g_fontMono = UI::LoadFont("DroidSansMono.ttf", 16.);
}

void InitGP() {
    yield();
    yield();
    yield();
    auto app = GetApp();
    while (app.PlaygroundScript is null) yield();
    _OnEnabledOrStart();

    // MLHook::RegisterMLHook(spectateHook, "TMGame_Record_SpectateGhost", true);
    // MLHook::RegisterMLHook(spectateHook, "TMGame_Record_Spectate", true);
    // MLHook::RegisterMLHook(toggleHook, "TMGame_Record_ToggleGhost", true);
    // MLHook::RegisterMLHook(toggleHook, "TMGame_Record_TogglePB", true);
    // MLHook::InjectManialinkToPlayground(SetFocusedRecord_PageUID, SETFOCUSEDRECORD_SCRIPT_TXT, true);

    startnew(WatchAndRemoveFadeOut);
    trace('init done');
    g_Initialized = true;
}

void _OnEnabledOrStart() {
    trace('registering callback & hook');
    MLHook::RegisterPlaygroundMLExecutionPointCallback(ML_PG_Callback);
    MLHook::RegisterMLHook(resetHook, "RaceMenuEvent_NextMap", true);
    MLHook::RegisterMLHook(resetHook, "RaceMenuEvent_Exit", true);
    SetCurrentGhostValues();
    if (IsSpectatingGhost())
        g_SaveGhostTab.StartWatchGhostsLoopLoop();
}

bool g_Initialized = false;

void Unload() {
    // nothing to do if game version is not safe, moreover, we might accidentally call unsafe stuff if we do it in this situation
    if (GameVersionSafe) {
        trace('unloading ghosts++ #1 paused');
        // if (scrubberPaused) GhostClipsMgr::UnpauseClipPlayers(GhostClipsMgr::Get(GetApp()), 0., 60.0);
        if (scrubberMgr !is null)
            scrubberMgr.ResetAll();
        trace('unloading ghosts++ #2 mlhook');
        MLHook::UnregisterMLHooksAndRemoveInjectedML();
        trace('unloading ghosts++ #3 done');
        EngineSounds::Unapply();
        CheckUnhookAllRegisteredHooks();
    }
}
void OnDestroyed() {
    NodPtrs::Unload();
    NoFlashCar::IsApplied = false;
    KinematicsControl::IsApplied = false;
    CameraPolish::Hook_CameraUpdatePos.Stop();
    Unload();
}
void OnDisabled() { Unload(); }

void OnEnabled() {
    _OnEnabledOrStart();
}

/** Called when a setting in the settings panel was changed.
*/
void OnSettingsChanged() {
    OnUpdatedGpsScrubbingSetting();
}

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

float g_DT = 20;
float g_DT_sec = 0.02;
void Update(float dt) {
    g_DT_sec = (g_DT = dt) * 0.001;
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


bool IsSpectatingGhost(CGamePlaygroundScript@ ps = null) {
    if (ps is null) {
        @ps = GetApp().PlaygroundScript;
        if (ps is null) return false;
    }
    if (ps.UIManager is null) return false;
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
    if (ps is null) return false;
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
    if (int(ps.StartTime) >= 0) {
        // don't increase this more than once.
        if (ps.StartTime < UNLOCK_TIMER_AMOUNT) {
            ps.StartTime += UNLOCK_TIMER_AMOUNT;
        }
        // Call_Ghosts_SetStartTime(ps, newNow - ghostTime);
        setGhostStartTimeNextFrame = newNow - ghostTime;
        startnew(SetGhostStartTimeNextFrameAfterUnlock);
    }
}

bool IsPlayerDriving() {
    auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (cp is null) return false;
    if (cp.GameTerminals.Length == 0) return false;
    auto gt = cp.GameTerminals[0];
    if (gt.UISequence_Current == SGamePlaygroundUIConfig::EUISequence::Finish) return true;
    if (gt.UISequence_Current != SGamePlaygroundUIConfig::EUISequence::Playing) return false;
    if (gt.GUIPlayer is null || gt.ControlledPlayer is null) return false;
    return gt.GUIPlayer.User.Id.Value == gt.ControlledPlayer.User.Id.Value;
}

int setGhostStartTimeNextFrame = 0;
void SetGhostStartTimeNextFrameAfterUnlock() {
    yield();
    Call_Ghosts_SetStartTime(cast<CSmArenaRulesMode>(GetApp().PlaygroundScript), setGhostStartTimeNextFrame);
    // trace('set ghosts start time to: ' + setGhostStartTimeNextFrame);
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


void Loop_BeforeScripts() {
    // if app.BackToMainMenu() is called, it can crash the game if ghosts are paused. (Not always, but sometimes)
    // This happens in the game's main loop, but plugins call BackToMainMenu during render.
    // Check here whether an BackToMainMenu was called and if so, unpause.
    auto app = cast<CGameManiaPlanet>(GetApp());
    while (true) {
        if (scrubberMgr !is null && IsBackToMenuRequested(app)) {
            log_warn("Unpausing ghosts because IsBackToMenuRequested(app) == true");
            scrubberMgr.ResetAll();
            while (IsBackToMenuRequested(app)) yield();
        }
        yield();
    }
}

uint16 O_GAMECTNAPP_BACKTOMENUCALLED = GetOffset("CGameCtnApp", "Editor") - (0x7D8 - 0x7B4);

bool IsBackToMenuRequested(CGameManiaPlanet@ app) {
    // 0x7B4 is 1 after BackToMainMenu is called.
    // 0x7B8 is never 1; 0x7BC is 1 after it starts going back to menu.
    return Dev::GetOffsetUint32(app, O_GAMECTNAPP_BACKTOMENUCALLED) > 0;

    // auto ret = Dev::GetOffsetUint32(app, 0x7B8) > 0
    // || Dev::GetOffsetUint32(app, 0x7B4) > 0
    // || Dev::GetOffsetUint32(app, 0x7BC) > 0;
    // if (ret) {
    //     log_warn("0x7B4: " + Dev::GetOffsetUint32(app, 0x7B4));
    //     log_warn("0x7B8: " + Dev::GetOffsetUint32(app, 0x7B8));
    //     log_warn("0x7BC: " + Dev::GetOffsetUint32(app, 0x7BC));
    // }
    // return ret;
}
