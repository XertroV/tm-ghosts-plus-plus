// Genuinely version-dependent constants.
//
// Not to be confused with upstream's GameVersionCompat.as, which this fork deleted: that
// file decided whether the plugin was allowed to run *at all*, based on a hand-maintained
// list of build strings. This file is the legitimate remainder -- a handful of offsets
// that really do differ between game generations and have to be chosen at runtime.
//
// TODO: replace this with a probe that reads both candidate offsets and picks whichever
// yields a sane clip player, so a new game generation is detected rather than assumed.
// Until then the behaviour below is preserved exactly as upstream had it.

// Selects the ghost clips manager's clip-player offsets (0x20 vs 0x30).
// See GhostClips.as: O_GhostClipsMgr_ClipPlayer1.
bool FLAG_GameVer2025 = true;

// The running game's build string, cached. Compared lexically against build strings to
// pick offsets -- see GhostClips.as: O_GCP_CONSTS_OFF, which shifts by 0x8 on builds from
// 2024-06-20_19_53 onwards. Empty until SetGameVerFlags() runs; consumers that may be
// reached earlier fill it in lazily.
string TmGameVersion = "";

void SetGameVerFlags() {
    auto app = GetApp();
    auto ver = app.SystemPlatform.ExeVersion;
    TmGameVersion = ver;
    FLAG_GameVer2025 = ver.StartsWith("2025-0");
    log_trace("game build " + ver + " -> FLAG_GameVer2025 = " + tostring(FLAG_GameVer2025));
}

string GetGameExeVersion() {
    return GetApp().SystemPlatform.ExeVersion;
}
