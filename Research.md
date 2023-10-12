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


# CPlugVehicleVisModel

- 0x58
  - ptr to struct
  - 0x0
    - ptr to NPlugModelKit_SDataBase

# CAudioSourceEngine

code that writes to volumeDB:

```
Trackmania.exe+1328DFB - F3 0F11 3F            - movss [rdi],xmm7
Trackmania.exe+1328DFF - F3 0F11 83 D8000000   - movss [rbx+000000D8],xmm0
Trackmania.exe+1328E07 - F3 0F11 73 6C         - movss [rbx+6C],xmm6
Trackmania.exe+1328E0C - E9 B3000000           - jmp Trackmania.exe+1328EC4
Trackmania.exe+1328E11 - 48 8B 03              - mov rax,[rbx]
Trackmania.exe+1328E14 - 48 8D 7B 64           - lea rdi,[rbx+64]
Trackmania.exe+1328E18 - BA 00300110           - mov edx,10013000 // CAudioSourceSurface class id
```

pattern = "F3 0F 11 3F F3 0F 11 83 ?? 00 00 00 F3 0F 11 73 ?? E9 ?? ?? ?? ?? 48 8B 03 48 8D 7B ?? BA 00 30 01 10"
