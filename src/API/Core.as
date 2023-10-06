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
        auto resp = scoreMgr.Map_GetPlayerListRecordList(userMgr.Users[0].Id, wsidsBuf, mapUid, "PersonalBest", "", "", "");
        WaitAndClearTaskLater(resp, scoreMgr);
        if (resp.HasFailed || !resp.HasSucceeded) {
            log_warn('GetMapPlayerListRecordList failed: ' + resp.ErrorCode + ", " + resp.ErrorType + ", " + resp.ErrorDescription);
            return null;
        }
        CMapRecord@[] ret;
        log_debug('GetMapPlayerListRecordList found ' + resp.MapRecordList.Length + ' records for ' + wsidsBuf.Length + ' players.');
        log_debug('wsids: ' + string::Join(wsids, ','));
        for (uint i = 0; i < resp.MapRecordList.Length; i++) {
            ret.InsertLast(resp.MapRecordList[i]);
        }
        return ret;
    }

    void LoadGhostOfPlayer(const string &in wsid, const string &in uid, const string &in name = "") {
        auto recs = GetMapPlayerListRecordList({wsid}, uid);
        if (recs is null || recs.Length == 0) {
            NotifyWarning("Could not load ghost of " + (name.Length > 0 ? name : wsid));
            return;
        }
        auto rec = recs[0];
        LoadGhostFromUrl(rec.FileName, rec.ReplayUrl);
    }

    void LoadGhostOfPlayers(string[]@ wsids, const string &in uid) {
        log_trace('Getting ghosts for ' + wsids.Length + ' players');
        auto recs = GetMapPlayerListRecordList(wsids, uid);
        if (recs is null || recs.Length == 0) {
            NotifyWarning("Could not load ghosts for " + string::Join(wsids, ', '));
            return;
        }
        log_trace('Found ' + recs.Length + ' ghosts for ' + wsids.Length + ' players');
        LoadGhostsAsync(recs);
    }

    void LoadGhostsAsync(CMapRecord@[]@ recs) {
        Meta::PluginCoroutine@[] coros;
        for (uint i = 0; i < recs.Length; i++) {
            coros.InsertLast(startnew(LoadGhostAsync, array<string> = {string(recs[i].FileName), recs[i].ReplayUrl}));
        }
        await(coros);
    }

    void LoadGhostAsync(ref@ r) {
        auto args = cast<string[]>(r);
        LoadGhostFromUrl(args[0], args[1]);
    }

    void LoadGhostFromUrl(const string &in filename, const string &in url) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfm = ps.DataFileMgr;
        auto gm = ps.GhostMgr;
        auto task = dfm.Ghost_Download(filename, url);
        WaitAndClearTaskLater(task, dfm);
        if (task.HasFailed || !task.HasSucceeded) {
            log_warn('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription);
            return;
        }
        auto instId = gm.Ghost_Add(task.Ghost, true);
        print('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value));
    }

    void LoadGhost(const string &in filename, bool onlyFirst = false) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfm = ps.DataFileMgr;
        auto gm = ps.GhostMgr;
        auto task = dfm.Replay_Load(filename);
        WaitAndClearTaskLater(task, dfm);
        if (task.HasFailed || !task.HasSucceeded) {
            log_warn('Replay_Load failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription);
            return;
        }
        for (uint i = 0; i < task.Ghosts.Length; i++) {
            auto instId = gm.Ghost_Add(task.Ghosts[i], true);
            print('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value));
            if (onlyFirst) break;
        }
    }
}
