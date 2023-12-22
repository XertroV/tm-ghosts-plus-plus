namespace Ghosts_PP {
    import void Call_Ghosts_SetStartTime(CSmArenaRulesMode@ ps, uint startTime) from "Ghosts_PP";
    import array<CGameCtnGhost@>@ GetCurrentGhosts(CGameCtnApp@ app) from "Ghosts_PP";
    import bool IsSpectatingGhost() from "Ghosts_PP";
    import uint GetSpectatingGhostInstanceId(CGameCtnApp@ app) from "Ghosts_PP";
    import NGameGhostClips_SClipPlayerGhost@ GetGhostFromInstanceId(CGameCtnApp@ app, uint instanceId) from "Ghosts_PP";
    import uint GetGhostVisEntityId(NGameGhostClips_SClipPlayerGhost@ g) from "Ghosts_PP";
}
