CGameScoreAndLeaderBoardManagerScript@ GetScoreMgr(CGameCtnApp@ app) {
    try {
        return app.Network.ClientManiaAppPlayground.ScoreMgr;
    } catch { return null; }
}

MwId UserId {
    get {
        auto userMgr = GetApp().Network.ClientManiaAppPlayground.UserMgr;
        if (userMgr is null || userMgr.Users.Length < 1) return MwId(256);
        return userMgr.Users[0].Id;
    }
}

int PlayerPBTime {
    get {
        auto app = GetApp();
        auto map = app.RootMap;
        if (map is null) return -1;
        auto mapInfo = map.MapInfo;
        auto scoreMgr = GetScoreMgr(app);
        if (scoreMgr is null) return -1;
        return scoreMgr.Map_GetRecord_v2(UserId, mapInfo.MapUid, "PersonalBest", "", "TimeAttack", "");
    }
}
