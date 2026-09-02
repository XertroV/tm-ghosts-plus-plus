
#if DEV
// DEV-only test hook (never in release builds): parse a replay's ghost inputs
// without ImGui access. Loads the replay into the race's DataFileMgr (the
// ghost is not added to the race) and opens the Ghost Inputs window on its
// first ghost. Path is relative to the Replays folder, URL-encoded.
HttpResponse@ HandleDevParseReplay(const string &in type, const string &in route, dictionary@ headers, MemoryBuffer@ body) {
    if (type != "GET") return HttpResponse(405, "Must be a GET request.");
    auto path = Net::UrlDecode(route.Replace("/dev/parse_replay/", ""));
    if (path.Length == 0 || path.Contains("../")) return HttpResponse(400, "bad replay path");
    startnew(_DevParseReplayCoro, path);
    return HttpResponse(200, "ok: parse_replay " + path);
}

void _ReleaseTaskSafe(ClearTask@ task) {
    if (task is null) return;
    try {
        task.Release();
    } catch {
        warn("[dev] parse_replay: task release threw: " + getExceptionInfo());
    }
}

void _DevParseReplayCoro(const string &in path) {
    yield(); // let the HTTP response flush before the parse starts
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) {
        warn("[dev] parse_replay: no playground script");
        return;
    }
    auto dfm = ps.DataFileMgr;
    // path convention is relative-to-Replays or user-dir "Replays/..." — try both
    string[] variants = {path, "Replays/" + path};
    CGameCtnGhost@ ghost;
    ClearTask@ keptTask; // successful load's task; ownership passes to the loader
    for (uint v = 0; v < variants.Length && ghost is null; v++) {
        ClearTask@ taskHolder = null;
        try {
            auto task = dfm.Replay_Load(variants[v]);
            // keep the task alive ourselves: releasing it can free its ghost,
            // so ownership passes to the loader on success
            @taskHolder = ClearTask(task, dfm);
            while (task.IsProcessing) yield();
            if (task.HasFailed || !task.HasSucceeded) {
                warn("[dev] parse_replay: Replay_Load('" + variants[v] + "') failed: " + task.ErrorCode + ", " + task.ErrorDescription);
            } else if (task.Ghosts.Length == 0) {
                warn("[dev] parse_replay: no ghosts in replay ('" + variants[v] + "')");
            } else {
                // task.Ghosts is CGameGhostScript[]; unwrap to the CGameCtnGhost
                @ghost = GetCtnGhost(task.Ghosts[0]);
                if (ghost is null) warn("[dev] parse_replay: ghost had no CGameCtnGhost model ('" + variants[v] + "')");
            }
        } catch {
            warn("[dev] parse_replay: '" + variants[v] + "' threw: " + getExceptionInfo());
        }
        if (ghost is null) {
            _ReleaseTaskSafe(taskHolder);
        } else {
            @keptTask = taskHolder;
        }
    }
    if (ghost is null) {
        warn("[dev] parse_replay: no usable ghost found");
        return;
    }
    g_SaveGhostTab.ShowInputs(ghost, GhostInputsSource::DevDataFileMgr, keptTask);
}
#endif
