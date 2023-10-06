// does not override mediatracker
const uint16 O_GAMECAM_ACTIVE_CAM_TYPE = 0x188;
const uint16 O_GAMECAM_USE_ALT = 0x24;
const uint16 O_APP_GAMECAM = GetOffset("CGameCtnApp", "GameScene") + 0x10;

class GameCamera {
    GameCamera() {}

    protected CMwNod@ GetSelf() {
        return Dev::GetOffsetNod(GetApp(), O_APP_GAMECAM);
    }

    uint get_ActiveCam() {
        auto gc = GetSelf();
        if (gc is null) return uint(-1);
        auto ac = Dev::GetOffsetUint32(gc, O_GAMECAM_ACTIVE_CAM_TYPE);
        if (0 < ac && ac < 0x2E) return ac;
        warn_every_60_s("Active cam value on GameCamera struct seems wrong: " + Text::Format("0x%08x", ac));
        return uint(-1);
    }

    // does not override mediatracker, works for spectators
    void set_ActiveCam(uint value) {
        if (value < 0x12 || 0x15 < value) throw("Invalid active cam: range is 0x12 - 0x14 inclusive");
        auto gc = GetSelf();
        if (gc is null) return;
        auto ac = Dev::GetOffsetUint32(gc, O_GAMECAM_ACTIVE_CAM_TYPE);
        // check the value looks right
        if (0 < ac && ac < 0x2E) {
            Dev::SetOffset(gc, O_GAMECAM_ACTIVE_CAM_TYPE, value);
        } else {
            warn_every_60_s("Active cam value on GameCamera struct seems wrong: " + Text::Format("0x%08x", ac));
        }
    }
}


dictionary warnTracker;
void warn_every_60_s(const string &in msg) {
    if (warnTracker is null) return;
    if (warnTracker.Exists(msg)) {
        uint lastWarn = uint(warnTracker[msg]);
        if (Time::Now - lastWarn < 60000) return;
    } else {
        NotifyWarning(msg);
    }
    warnTracker[msg] = Time::Now;
    warn(msg);
}
