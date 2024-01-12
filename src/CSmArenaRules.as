const uint16 O_CSMARENARULES_MAXGHOSTALPHA = GetOffset("CSmArenaRules", "RulesStateEndTime") + 0x8;

float CSmArenaRules_GetGhostAlpha(CSmArenaRules@ arenaRules) {
    return Dev::GetOffsetFloat(arenaRules, O_CSMARENARULES_MAXGHOSTALPHA);
}

void CSmArenaRules_SetGhostAlpha(CSmArenaRules@ arenaRules, float maxGhostAlpha) {
    Dev::SetOffset(arenaRules, O_CSMARENARULES_MAXGHOSTALPHA, maxGhostAlpha);
}
