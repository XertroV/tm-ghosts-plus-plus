void Main() {
    startnew(InitCoro);
}

void InitCoro() {
    IO::FileSource refreshCode("RefreshRecords.Script.txt");
    string manialinkScript = refreshCode.ReadToEnd();
    MLHook::InjectManialinkToPlayground("Hook_RefreshRecords", manialinkScript, true);
}

bool g_windowVisible = false;
uint lastRefresh = 0;
void RenderInterface() {
    if (UI::Begin("Refresh Records Demo", g_windowVisible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse)) {
        if (MDisabledButton(lastRefresh + 5000 > Time::Now, "Refresh Records")) {
            lastRefresh = Time::Now;
            MLHook::Queue_ToInjectedManialink("RefreshRecords", "Hook_RefreshRecords");
        }
    }
    UI::End();
}

void RenderMenu() {
    if (UI::MenuItem("\\$2f8" + Icons::ListAlt + "\\$z Refresh Records", "", g_windowVisible)) {
        g_windowVisible = !g_windowVisible;
    }
}

CTrackMania@ get_app() {
    return cast<CTrackMania>(GetApp());
}

CGameManiaAppPlayground@ get_cmap() {
    return app.Network.ClientManiaAppPlayground;
}
