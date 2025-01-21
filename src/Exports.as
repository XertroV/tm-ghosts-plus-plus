namespace Ghosts_PP {
    import void Call_Ghosts_SetStartTime(CSmArenaRulesMode@ ps, uint startTime) from "Ghosts_PP";
    import array<CGameCtnGhost@>@ GetCurrentGhosts(CGameCtnApp@ app) from "Ghosts_PP";
    import bool IsSpectatingGhost() from "Ghosts_PP";
    import uint GetSpectatingGhostInstanceId(CGameCtnApp@ app) from "Ghosts_PP";
    import NGameGhostClips_SClipPlayerGhost@ GetGhostFromInstanceId(CGameCtnApp@ app, uint instanceId) from "Ghosts_PP";
    import uint GetGhostVisEntityId(NGameGhostClips_SClipPlayerGhost@ g) from "Ghosts_PP";
    import NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) from "Ghosts_PP";
    // PB ghost that respawns at CPs with you; returns -1 if null issue or not found
    import int GetLaunchedCpGhostIx(NGameGhostClips_SMgr@ mgr) from "Ghosts_PP";
    // PB ghost that respawns at CPs with you; returns -1 if null issue or not found
    import int GetLaunchedCpGhostInstanceId(NGameGhostClips_SMgr@ mgr) from "Ghosts_PP";
    // PB ghost that respawns at CPs with you
    import NGameGhostClips_SClipPlayerGhost@ GetLaunchedCpGhost(NGameGhostClips_SMgr@ mgr) from "Ghosts_PP";
}

import float CSmArenaRules_GetGhostAlpha(CSmArenaRules@ arenaRules) from "Ghosts_PP";
import void CSmArenaRules_SetGhostAlpha(CSmArenaRules@ arenaRules, float maxGhostAlpha) from "Ghosts_PP";

namespace Ghosts_PP {
    import IInputChange@[]@ GetGhostInputData(CGameCtnGhost@ ghost) from "Ghosts_PP";
    // import IGhostSample@[]@ GetGhostSampleData(CGameCtnGhost@ ghost) from "Ghosts_PP";

    import CheckpointIxTime@[]@ GetGhostCheckpoints(CGameCtnGhost@ ghost) from "Ghosts_PP";
}
