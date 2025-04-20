// ! Near finishes cars can flicker due to predictions about where the car will be next frame (or something like that)
// We can avoid this by disabling some writes to +0x338
// Note: this looks like offset 0x328 in GhostClips.as (O_GHOSTCLIPPLAYER_CURR_TIME3)
namespace NoFlashCar {
    const string Set338Pattern1 = "03 00 00 F3 0F 11 91 ?? 03 00 00 76";
    const uint16 Set338P1Offset = 3;
    const string Set338Pattern2 = "CD CC 4C 3E F3 0F 11 89 ?? 03 00 00 C3";
    const uint16 Set338P2Offset = 4;

    MemPatcher MP_Set338Pattern1 = MemPatcher(Set338Pattern1, {Set338P1Offset}, {"90 90 90 90 90 90 90 90"});
    MemPatcher MP_Set338Pattern2 = MemPatcher(Set338Pattern2, {Set338P2Offset}, {"90 90 90 90 90 90 90 90"});

    bool IsApplied {
        get {
            return MP_Set338Pattern1.IsApplied && MP_Set338Pattern2.IsApplied;
        }
        set {
            MP_Set338Pattern1.IsApplied = value;
            MP_Set338Pattern2.IsApplied = value;
        }
    }
}



/*

Trackmania.exe.text+FFF869 - 0F28 D0               - movaps xmm2,xmm0
Trackmania.exe.text+FFF86C - F3 0F59 D1            - mulss xmm2,xmm1
Trackmania.exe.text+FFF870 - F3 0F59 91 B8010000   - mulss xmm2,[rcx+000001B8]
Trackmania.exe.text+FFF878 - F3 0F58 91 38030000   - addss xmm2,[rcx+00000338]
Trackmania.exe.text+FFF880 - F3 0F11 91 38030000   - movss [rcx+00000338],xmm2 { Nop this (1/2) to avoid writing predictively to 0x338
 }
Trackmania.exe.text+FFF888 - 76 17                 - jna Trackmania.exe.text+FFF8A1
Trackmania.exe.text+FFF88A - 0F2F 91 30030000      - comiss xmm2,[rcx+00000330]
Trackmania.exe.text+FFF891 - 72 0E                 - jb Trackmania.exe.text+FFF8A1
Trackmania.exe.text+FFF893 - E8 28F1FFFF           - call Trackmania.exe.text+FFE9C0

0F 28 D0 F3 0F 59 D1 F3 0F 59 91 B8 01 00 00 F3 0F 58 91 38 03 00 00 F3 0F 11 91 38 03 00 00 76 17
        v 3 bs   v mov xmm2 to 0x338
unique: 03 00 00 F3 0F 11 91 ?? 03 00 00 76
offset: 3, len: 8


Trackmania.exe.text+FFEA0B - F3 0F11 89 38030000   - movss [rcx+00000338],xmm1 {
 }
Trackmania.exe.text+FFEA13 - C7 81 3C030000 00000000 - mov [rcx+0000033C],00000000 { 0 }
Trackmania.exe.text+FFEA1D - C3                    - ret
Trackmania.exe.text+FFEA1E - 0F2F 15 2F8FCE00      - comiss xmm2,[Trackmania.exe.rdata+3AA954] { (0.20) }
Trackmania.exe.text+FFEA25 - 76 0A                 - jna Trackmania.exe.text+FFEA31
Trackmania.exe.text+FFEA27 - C7 81 3C030000 CDCC4C3E - mov [rcx+0000033C],3E4CCCCD { 0.20 }
Trackmania.exe.text+FFEA31 - F3 0F11 89 38030000   - movss [rcx+00000338],xmm1 { Nop this (2/2) to avoid writing predictively to 0x338
 }
Trackmania.exe.text+FFEA39 - C3                    - ret

F3 0F 11 89 38 03 00 00 C7 81 3C 03 00 00 00 00 00 00 C3 0F 2F 15 2F 8F CE 00 76 0A C7 81 3C 03 00 00 CD CC 4C 3E F3 0F 11 89 38 03 00 00 C3

v float     v write to 0x338
CD CC 4C 3E F3 0F 11 89 ?? 03 00 00
unique: CD CC 4C 3E F3 0F 11 89 ?? 03 00 00
offset: 4,

*/
