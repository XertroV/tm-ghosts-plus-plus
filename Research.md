# CGameCtnGhost

- 0x38
  - buffer of (checkpointId, raceTime) structs (nat2)
- 0x70
  - CSystemPackDesc for ghost skin
- 0x78
  - CSystemPackDesc for horn
- 0xF0
  - string: club tag

# CTmRaceResultNod

- 0x18 (or 0x20)
  - ptr to 0x50 bytes into CGameCtnGhost (uint4 time, uint4 score, uint4 respawns, uint4 spwan landmark id, checkpoints buf)
