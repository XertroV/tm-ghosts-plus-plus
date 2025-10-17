bool GameVersionSafe = false;
bool KnownSafe = false;
const string[] KnownSafeVersions = {
    "2024-07-02_14_35", "2024-08-08_14_58", "2024-08-30_17_09", "2024-09-17_11_17", "2024-10-04_11_08",
    "2024-12-04_12_20", "2024-12-12_15_15", "2025-07-04_14_15",
};
const string configUrl = "https://openplanet.dev/plugin/ghosts-pp/config/version-compat";

[Setting hidden]
string S_SavedOkayGameVersion = "";

/**
 * New version checklist:
 * - Update KnownSafeVersions
 * - Update JSON config on site
 * - Update info toml min version
 */

void CheckAndSetGameVersionSafe() {
    EnsureGameVersionCompatibility();
    if (!GameVersionSafe) {
        WarnBadGameVersion();
    }
}

string GetGameExeVersion() {
    return GetApp().SystemPlatform.ExeVersion;
}

string TmGameVersion = "";
void EnsureGameVersionCompatibility() {
    if (GameVersionSafe) return;
    TmGameVersion = GetGameExeVersion();
    GameVersionSafe = KnownSafeVersions.Find(TmGameVersion) > -1;
    KnownSafe = GameVersionSafe;
    if (GameVersionSafe) return;
    bool fromOpenplanet = GetStatusFromOpenplanet();
    trace("Got GameVersionSafe status: " + fromOpenplanet);
    GameVersionSafe = GameVersionSafe
        || fromOpenplanet
        || TmGameVersion == S_SavedOkayGameVersion;
}

void WarnBadGameVersion() {
    NotifyWarning("Game version ("+TmGameVersion+") not marked as compatible with this version of the plugin -- will be inactive!\n\nChecking new versions is a manual process and avoids crashing your game after an update.");
}

bool requestStarted = true;
bool requestEnded = true;

bool GetStatusFromOpenplanet() {
    // string configUrl = "https://openplanet.dev/plugin/" + Meta::ExecutingPlugin().ID + "/config/version-compat";
    trace('Version Compat URL: ' + configUrl);
    auto req = Net::HttpGet(configUrl);
    requestStarted = true;
    requestEnded = false;
    while (!req.Finished()) yield();
    if (req.ResponseCode() != 200) {
        warn('getting plugin enabled status: code: ' + req.ResponseCode() + '; error: ' + req.Error() + '; body: ' + req.String());
        return RetryGetStatus(2000);
    }
    requestEnded = true;
    try {
        auto j = Json::Parse(req.String());
        auto myVer = Meta::ExecutingPlugin().Version;
        if (!j.HasKey(myVer) || j[myVer].GetType() != Json::Type::Object) return false;
        // if we have this key, then it's okay
        return j[myVer].HasKey(TmGameVersion);
    } catch {
        warn("exception: " + getExceptionInfo());
        return RetryGetStatus(2000);
    }
}

uint retries = 0;

bool RetryGetStatus(uint delay) {
    trace('retrying GetStatusFromOpenplanet in ' + delay + ' ms');
    sleep(delay);
    retries++;
    if (retries > 5) {
        warn('not retying anymore, too many failures.');
        return false;
    }
    trace('retrying...');
    return GetStatusFromOpenplanet();
}

[SettingsTab name="Game Version Check" icon="ExclamationTriangle" order=99]
void OverrideGameSafetyCheck_Settings() {
    UI::Text("Game version safe? " + tostring(GameVersionSafe));
    UI::Text("Check request started: " + tostring(requestStarted));
    UI::Text("Check request ended: " + tostring(requestEnded));
    if (!GameVersionSafe && UI::Button("Disable safety features and run anyway")) {
        OverrideGameSafetyCheck_GhostsPP();
    }
    if (!GameVersionSafe && UI::Button("Disable safety features and run and remember game version")) {
        OverrideGameSafetyCheck_GhostsPP();
        S_SavedOkayGameVersion = TmGameVersion;
    }
}

void OverrideGameSafetyCheck_GhostsPP(bool safe = true) {
    GameVersionSafe = safe;
}

bool IsGameVersionSafe_GhostsPP() {
    return GameVersionSafe;
}
