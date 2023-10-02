namespace Core {
    // Do not keep handles to these objects around
    CNadeoServicesMap@ GetMapFromUid(const string &in mapUid) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto userId = app.MenuManager.MenuCustom_CurrentManiaApp.UserMgr.Users[0].Id;
        auto resp = app.MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr.Map_NadeoServices_GetFromUid(userId, mapUid);
        WaitAndClearTaskLater(resp, app.MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr);
        if (resp.HasFailed || !resp.HasSucceeded) {
            log_warn('GetMapFromUid failed: ' + resp.ErrorCode + ", " + resp.ErrorType + ", " + resp.ErrorDescription);
            return null;
        }
        return resp.Map;
    }

    // uses playground script because we only care about local
    array<CMapRecord@>@ GetMapPlayerListRecordList(string[]@ wsids, const string &in mapUid) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto scoreMgr = ps.ScoreMgr;
        auto userMgr = ps.UserMgr;
        MwFastBuffer<wstring> wsidsBuf;
        for (uint i = 0; i < wsids.Length; i++) {
            wsidsBuf.Add(wsids[i]);
        }
        auto resp = scoreMgr.Map_GetPlayerListRecordList(userMgr.MainUser.Id, wsidsBuf, mapUid, "PersonalBest", "", "", "");
        WaitAndClearTaskLater(resp, scoreMgr);
        if (resp.HasFailed || !resp.HasSucceeded) {
            log_warn('GetMapPlayerListRecordList failed: ' + resp.ErrorCode + ", " + resp.ErrorType + ", " + resp.ErrorDescription);
            return null;
        }
        auto x = resp.MapRecordList;
        CMapRecord@[] ret;
        for (uint i = 0; i < resp.MapRecordList.Length; i++) {
            ret.InsertLast(resp.MapRecordList[i]);
        }
        return ret;
    }

    void LoadGhostFromUrl(const string &in filename, const string &in url) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfm = ps.DataFileMgr;
        auto gm = ps.GhostMgr;
        auto task = dfm.Ghost_Download(filename, url);
        WaitAndClearTaskLater(task, dfm);
        if (task.HasFailed || !task.HasSucceeded) {
            log_warn('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription);
            return null;
        }
        gm.Ghost_Add(task.Ghost, true);
    }

    void LoadGhost(const string &in filename, bool onlyFirst = false) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfm = ps.DataFileMgr;
        auto gm = ps.GhostMgr;
        auto task = dfm.Replay_Load(filename);
        WaitAndClearTaskLater(task, dfm);
        if (task.HasFailed || !task.HasSucceeded) {
            log_warn('Replay_Load failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription);
            return null;
        }
        for (uint i = 0; i < task.Ghosts.Length; i++) {
            gm.Ghost_Add(task.Ghosts[i], true);
            if (onlyFirst) break;
        }
    }
}
