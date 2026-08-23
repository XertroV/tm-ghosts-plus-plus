// Makes map camera triggers survive scrubbing.
//
// Maps can force a camera at a point on the track (the classic case being a forced cam3
// section). Those triggers fire when a car drives through them, so during normal playback
// the camera is right -- but scrubbing jumps over the trigger entirely. Rewind past one
// and the camera stays in whatever the last trigger set; skip forward over one and it
// never changes. That is upstream #16, and #30 ("stuck in cam3" on Summer 2020 #25, a map
// with a forced-camera section) is the same bug reported from the other side.
//
// Reading the map's trigger blocks directly would need block enumeration and a
// position-to-trigger mapping. Watching what the camera actually does is far cheaper and
// needs nothing version-fragile: record which camera was active at which point in the
// run, then re-apply the right one when the timeline moves somewhere else. The first pass
// through a section teaches it; every later scrub gets it right.
//
// Sampled on a short interval rather than every frame: reading the active camera goes
// through the game camera struct, and per-frame raw reads are a hazard this plugin has
// already been bitten by.

[Setting category="Camera" name="Restore map camera triggers when scrubbing" description="Remembers which camera each part of a run used, and restores it when you scrub. Without this, scrubbing past a map's forced-camera section leaves you stuck in whichever camera the last trigger set."]
bool S_RestoreCameraOnScrub = true;

namespace CameraTimeline {
    // Active camera values the game uses for cam1/cam2/cam3. Anything outside this is not
    // a camera we should be recording or restoring.
    const uint CAM_MIN = 0x12;
    const uint CAM_MAX = 0x14;

    // How often to look at the active camera during playback.
    const uint SAMPLE_INTERVAL_MS = 50;
    // Two samples closer together than this are treated as the same trigger point.
    const int MERGE_WINDOW_MS = 30;

    int[] times;
    uint[] cams;
    uint lastSampleAt = 0;
    uint lastSeenCam = 0;

    void Reset() {
        times.RemoveRange(0, times.Length);
        cams.RemoveRange(0, cams.Length);
        lastSeenCam = 0;
        lastSampleAt = 0;
    }

    uint get_Length() { return times.Length; }

    /**
     * Record the camera in use at this point of the run.
     *
     * Only called during ordinary playback -- while scrubbing the camera is whatever we
     * just restored, and recording that would overwrite what the map actually does.
     */
    void Observe(int ghostTimeMs) {
        if (!S_RestoreCameraOnScrub) return;
        if (ghostTimeMs < 0) return;
        if (lastSampleAt + SAMPLE_INTERVAL_MS > Time::Now) return;
        lastSampleAt = Time::Now;
        if (!Compat::Available("game-camera")) return;

        uint cam = GameCamera().ActiveCam;
        if (cam < CAM_MIN || cam > CAM_MAX) return;
        if (cam == lastSeenCam) return;
        lastSeenCam = cam;
        Record(ghostTimeMs, cam);
    }

    void Record(int timeMs, uint cam) {
        // Keep sorted by time; a run can be watched out of order.
        uint at = times.Length;
        for (uint i = 0; i < times.Length; i++) {
            if (times[i] > timeMs) { at = i; break; }
        }
        // Replace rather than stack up entries when the same point is re-observed.
        if (at > 0 && Math::Abs(times[at - 1] - timeMs) <= MERGE_WINDOW_MS) {
            cams[at - 1] = cam;
            return;
        }
        times.InsertAt(at, timeMs);
        cams.InsertAt(at, cam);
        log_trace("camera timeline: cam " + Text::Format("0x%02x", cam)
            + " at " + Time::Format(timeMs) + " (" + times.Length + " entries)");
    }

    /** The camera that should be active at this point, or 0 if nothing was recorded. */
    uint CamAt(int ghostTimeMs) {
        uint found = 0;
        for (uint i = 0; i < times.Length; i++) {
            if (times[i] > ghostTimeMs) break;
            found = cams[i];
        }
        return found;
    }

    /**
     * Put the camera back to whatever the map had at this point in the run.
     * Called when the timeline jumps rather than advances.
     */
    void RestoreAt(int ghostTimeMs) {
        if (!S_RestoreCameraOnScrub) return;
        if (times.IsEmpty()) return;
        if (!Compat::Available("game-camera")) return;

        uint want = CamAt(ghostTimeMs);
        if (want < CAM_MIN || want > CAM_MAX) return;

        auto gc = GameCamera();
        if (gc.ActiveCam == want) return;
        gc.ActiveCam = want;
        // Keeps Observe() from immediately recording the value we just restored as though
        // the map had triggered it.
        lastSeenCam = want;
        log_trace("camera timeline: restored cam " + Text::Format("0x%02x", want)
            + " for " + Time::Format(ghostTimeMs));
    }
}
