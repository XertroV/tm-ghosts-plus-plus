void Main() {

}

CTrackMania@ get_app() {
    return cast<CTrackMania>(GetApp());
}

CGameManiaAppPlayground@ get_cmap() {
    return app.Network.ClientManiaAppPlayground;
}

bool PlayerIsInGame() {
    // UILayers are only populated when the map loads and there are like 23 of them
    return (cmap !is null && cmap.UILayers.Length > 10)
}

void RM_Singletons() {
    if (UI::MenuItem("Maps")) {
        LastUsedDfm.Map_RefreshFromDisk();
        NotifyRefresh("Refreshed Maps");
    }
    if (UI::MenuItem("Replays")) {
        LastUsedDfm.Replay_RefreshFromDisk();
        NotifyRefresh("Refreshed Replays");
    }
    if (UI::MenuItem("All Media")) {
        for (uint i = 0; i < mediaTypes.Length; i++) {
            auto item = mediaTypes[i];
            LastUsedDfm.Media_RefreshFromDisk(item, uint(EMediaScope::AllData));
        }
        NotifyRefresh("Refreshed all media types with scope " + tostring(EMediaScope::AllData));
    }
}

void RM_MediaType(CGameDataFileManagerScript::EMediaType &in mt) {
    if (UI::BeginMenu(tostring(mt), true)) {
        for (uint i = 0; i < mediaScopes.Length; i++) {
            auto item = mediaScopes[i];
            RM_MediaScope(mt, item);
        }
        UI::EndMenu();
    }
}

void RM_MediaScope(CGameDataFileManagerScript::EMediaType &in mt, EMediaScope &in scope) {
    if (UI::MenuItem(tostring(scope) + "##" + tostring(mt))) {
        LastUsedDfm.Media_RefreshFromDisk(mt, uint(scope));
        NotifyRefresh("Refreshed " + tostring(mt) + " with scope " + tostring(scope));
        trace('Called: DataFileMgr.Media_RefreshFromDisk(' + tostring(mt) + ', ' + tostring(scope) + ')');
    }
}


void NotifyRefresh(const string &in msg) {
    UI::ShowNotification("Refresh Media", msg, vec4(.2, .6, .3, .3), 3000);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification("Refresh Media", msg, vec4(.9, .6, .1, .5), 7500);
}
