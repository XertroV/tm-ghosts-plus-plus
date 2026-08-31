#if DEV
string UiSequenceName(int seq) {
    // CGamePlaygroundUIConfig::EUISequence declaration order
    if (seq == 0) return "None";
    if (seq == 1) return "Playing";
    if (seq == 2) return "Intro";
    if (seq == 3) return "Outro";
    if (seq == 4) return "Podium";
    if (seq == 5) return "CustomMTClip";
    if (seq == 6) return "EndRound";
    if (seq == 7) return "PlayersPresentation";
    if (seq == 8) return "UIInteraction";
    if (seq == 9) return "RollingBackgroundIntro";
    if (seq == 10) return "CustomMTClip_WithUIInteraction";
    if (seq == 11) return "Finish";
    return "seq_" + seq;
}

Json::Value@ BuildWatchDebugState() {
    auto o = Json::Object();
    auto app = GetApp();
    auto ps = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    o["hasPlaygroundScript"] = ps !is null;
    o["isSpectating"] = IsSpectatingGhost();
    o["watchLoopActive"] = g_SaveGhostTab !is null && g_SaveGhostTab.watchLoopActive;
    o["lastSpectatedGhostRaceTime"] = lastSpectatedGhostRaceTime;
    o["lastLoadedGhostRaceTime"] = lastLoadedGhostRaceTime;
    o["lastSetStartTime"] = lastSetStartTime;
    o["lastGhostsStartOrSpawnTime"] = lastGhostsStartOrSpawnTime;
    o["mostRecentGhostTimeMax"] = MostRecentGhostTimeMax();
    o["lastSpectatedGhostInstanceId"] = Text::Format("#%08x", lastSpectatedGhostInstanceId.Value);
    o["blockAllSetTimeNow"] = g_BlockAllGhostsSetTimeNow;
    o["blockNextSetTimeAny"] = g_BlockNextGhostsSetTimeAny;
    o["allowWindowActive"] = Time::Now <= allowSetStartTimeNow_BeforeEq;
    o["allowWindowMs"] = int(allowSetStartTimeNow_BeforeEq) - int(Time::Now);
    o["timerUnlocked"] = IsTimerUnlocked(ps);
    if (ps !is null && ps.UIManager !is null && ps.UIManager.UIAll !is null) {
        o["now"] = int(ps.Now);
        o["psStartTime"] = int(ps.StartTime);
        o["forceSpectator"] = ps.UIManager.UIAll.ForceSpectator;
        int seq = int(ps.UIManager.UIAll.UISequence);
        o["uiSequence"] = seq;
        o["uiSequenceName"] = UiSequenceName(seq);
        int deadline = int(lastSpectatedGhostRaceTime) + lastSetStartTime + 50;
        o["loopDeadline"] = deadline;
        o["loopWaitRemaining"] = deadline - int(ps.Now);
        o["ghostPlayTime"] = int(ps.Now) - lastSetStartTime;
        o["specInstanceId"] = Text::Format("#%08x", GetCurrentlySpecdGhostInstanceId(ps));
    }
    if (scrubberMgr !is null) {
        o["scrubberMode"] = int(scrubberMgr.mode);
        o["isPaused"] = scrubberMgr.IsPaused;
        o["isStdPlayback"] = scrubberMgr.IsStdPlayback;
        o["isScrubbing"] = scrubberMgr.isScrubbing;
        o["pauseAt"] = scrubberMgr.pauseAt;
        o["playbackSpeed"] = scrubberMgr.playbackSpeed;
        o["unpausedFlag"] = scrubberMgr.unpausedFlag;
    } else {
        o["scrubberNull"] = true;
    }
    auto mgr = GhostClipsMgr::Get(app);
    if (mgr !is null) {
        o["ghostCount"] = mgr.Ghosts.Length;
        auto ghosts = Json::Array();
        uint n = mgr.Ghosts.Length;
        if (n > 16) n = 16;
        for (uint i = 0; i < n; i++) {
            auto g = mgr.Ghosts[i].GhostModel;
            auto gj = Json::Object();
            gj["ix"] = i;
            gj["nickname"] = string(g.GhostNickname);
            gj["raceTime"] = int(g.RaceTime);
            ghosts.Add(gj);
        }
        o["ghosts"] = ghosts;
        auto mainClip = GhostClipsMgr::GetMainClipPlayer(mgr);
        if (mainClip !is null) {
            float clipCurr = ClipPlayer_GetCurrSeconds(mainClip);
            float clipCurr2 = ClipPlayer_GetCurrSeconds2(mainClip);
            float clipCurr3 = ClipPlayer_GetCurrSeconds3(mainClip);
            uint clipStart = ClipPlayer_GetStartTime(mainClip);
            o["clipCurr"] = clipCurr;
            o["clipCurr2"] = clipCurr2;
            o["clipCurr3"] = clipCurr3;
            o["clipTotal"] = ClipPlayer_GetTotalTime(mainClip);
            o["clipPaused"] = ClipPlayer_GetTotalTime(mainClip) < 0.0;
            o["clipStart"] = clipStart;
            o["clipFrameDeltaMs"] = ClipPlayer_GetFrameDelta(mainClip) * 1000.0;
            o["clipDoDeltaAdvance"] = Dev::GetOffsetUint32(mainClip, O_GHOSTCLIPPLAYER_DO_DELTA_ADVANCE);
            o["clipAtEnd"] = ClipPlayer_GetTotalTime(mainClip) > 0.0
                && clipCurr + 0.05 >= ClipPlayer_GetTotalTime(mainClip);
            int playMs = ps !is null ? int(ps.Now) - lastSetStartTime : 0;
            int clipMs = int(clipCurr * 1000.0);
            o["startDeltaMs"] = lastSetStartTime - int(clipStart);
            o["playVsClipMs"] = playMs - clipMs;
            o["clip12Ms"] = int((clipCurr - clipCurr2) * 1000.0);
            o["clip13Ms"] = int((clipCurr - clipCurr3) * 1000.0);
            if (scrubberMgr !is null) {
                o["pauseVsPlayMs"] = int(scrubberMgr.pauseAt) - playMs;
                o["pauseVsClipMs"] = int(scrubberMgr.pauseAt) - clipMs;
            }
        }
    }
    return o;
}
#endif