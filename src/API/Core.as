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
        auto resp = scoreMgr.Map_GetPlayerListRecordList(userMgr.Users[0].Id, wsidsBuf, mapUid, "PersonalBest", "", "TimeAttack", "");
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
        LoadingGhosts_New(1);
        auto recs = GetMapPlayerListRecordList({wsid}, uid);
        if (recs is null || recs.Length == 0) {
            NotifyWarning("Could not load ghost of " + (name.Length > 0 ? name : wsid) + ". (It might not exist.)");
            LoadingGhosts_GhostError(1);
        } else {
            auto rec = recs[0];
            LoadGhostFromUrl(rec.FileName, rec.ReplayUrl);
        }
        LoadingGhosts_LodingDone();
    }

    void LoadGhostOfPlayers(string[]@ wsids, const string &in uid) {
        LoadingGhosts_New(wsids.Length);
        log_trace('Getting ghosts for ' + wsids.Length + ' players');
        auto recs = GetMapPlayerListRecordList(wsids, uid);
        if (recs is null || recs.Length == 0) {
            NotifyWarning("Could not load ghosts for " + string::Join(wsids, ', '));
            LoadingGhosts_GhostError(wsids.Length);
        } else {
            log_trace('Found ' + recs.Length + ' ghosts for ' + wsids.Length + ' players');
            LoadGhostsAsync(recs);
        }
        LoadingGhosts_LodingDone();
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

    // increments done counter
    void LoadGhostFromUrl(const string &in filename, const string &in url) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfm = ps.DataFileMgr;
        auto gm = ps.GhostMgr;
        auto task = dfm.Ghost_Download(filename, url);
        WaitAndClearTaskLater(task, dfm);
        if (task.HasFailed || !task.HasSucceeded) {
            log_warn('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription);
            LoadingGhosts_GhostError(1);
            return;
        }
        auto instId = gm.Ghost_Add(task.Ghost, S_UseGhostLayer);
        print('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value));
        LoadingGhosts_GhostDone(1);
    }

    void LoadGhost_Replay(const string &in filename, bool onlyFirst = false) {
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
            auto instId = gm.Ghost_Add(task.Ghosts[i], S_UseGhostLayer);
            print('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value));
            if (onlyFirst) break;
        }
    }
}

int LoadingGhosts_Loading = 0;
int LoadingGhosts_NbTotal = 0;
int LoadingGhosts_NbDone = 0;
int LoadingGhosts_NbError = 0;

void LoadingGhosts_New(uint nbGhosts) {
    LoadingGhosts_Loading++;
    LoadingGhosts_NbTotal += nbGhosts;
}
void LoadingGhosts_GhostDone(uint nbGhosts) {
    LoadingGhosts_NbDone += nbGhosts;
}
void LoadingGhosts_GhostError(uint nbGhosts) {
    LoadingGhosts_NbError += nbGhosts;
    LoadingGhosts_NbTotal -= nbGhosts;
}
void LoadingGhosts_LodingDone() {
    startnew(_LoadingDoneCoro);
}

void _LoadingDoneCoro() {
    yield();
    LoadingGhosts_Loading--;
    if (LoadingGhosts_Loading == 0) {
        LoadingGhosts_NbDone = 0;
        LoadingGhosts_NbError = 0;
        LoadingGhosts_NbTotal = 0;
    } else if (LoadingGhosts_Loading < 0) {
        warn_every_60_s('calculated negative number of ghost loading coros!');
    }
}

uint lastRenderLoadingInProg = 0;
nat3 lastRenderLoadingCounts;
void RenderLoadingGhostsMsg() {
    if (LoadingGhosts_Loading > 0) {
        lastRenderLoadingInProg = Time::Now;
        lastRenderLoadingCounts = nat3(LoadingGhosts_NbDone, LoadingGhosts_NbTotal, LoadingGhosts_NbError);
    }
    if (LoadingGhosts_Loading <= 0 && Time::Now > lastRenderLoadingInProg + 500) return;

    auto screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    auto pos = screen * vec2(.5, .2);

    string _loadingStr = "Loading: " + lastRenderLoadingCounts.x + " / " + lastRenderLoadingCounts.y;
    if (lastRenderLoadingCounts.z > 0) {
        _loadingStr += " (Failed: "+lastRenderLoadingCounts.z+")";
    }
    float fs = 0.03 * screen.y;

    nvg::Reset();
    nvg::BeginPath();

    nvg::FontFace(Inputs::g_NvgFontBold);
    nvg::FontSize(fs);
    nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);

    DrawTextWithStroke(pos, _loadingStr, vec4(1), fs / 10.);
}
