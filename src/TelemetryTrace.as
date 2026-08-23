// Speed and input trace for the ghost being spectated.
//
// Source is the VehicleState dependency: CSceneVehicleVis.AsyncState exposes FrontSpeed,
// CurGear, InputGasPedal, InputBrakePedal and InputSteer as reflected members. That
// matters -- it means this feature owns no offsets of its own. VehicleState resolves them,
// and a game update that moves them is that plugin's problem, not ours.
//
// The alternative was reviving ReadEntRecordData.as, which reads the ghost's recorded
// entity samples by chasing raw pointers. That file has been sitting inside `#if FALSE`
// for a long time and is written against an older layout; given how the input parser has
// gone, sampling live state is by far the better trade.
//
// The cost is that it learns by watching: a run has to play through once before its trace
// is complete. Scrubbing is not sampled, since the vehicle is not simulating then.

class TelemetrySample {
    int time;
    float speed;
    float gas;
    float brake;
    float steer;
    int gear;

    TelemetrySample(int time, float speed, float gas, float brake, float steer, int gear) {
        this.time = time;
        this.speed = speed;
        this.gas = gas;
        this.brake = brake;
        this.steer = steer;
        this.gear = gear;
    }
}

namespace TelemetryTrace {
    // ~30Hz. Fine enough to show braking points, coarse enough to stay cheap.
    const uint SAMPLE_INTERVAL_MS = 33;
    // Two samples this close in run-time are the same point; keeps a paused or looping
    // playback from stacking duplicates.
    const int MERGE_WINDOW_MS = 20;
    // A very long run at 30Hz; past this something is wrong and we stop growing.
    const uint MAX_SAMPLES = 40000;

    TelemetrySample@[] samples;
    uint tracedInstanceId = uint(-1);
    uint lastSampleAt = 0;

    void Reset() {
        samples.RemoveRange(0, samples.Length);
        tracedInstanceId = uint(-1);
        lastSampleAt = 0;
    }

    uint get_Length() { return samples.Length; }
    bool get_HasData() { return samples.Length > 1; }

    /** Highest recorded speed, for scaling a graph. Returns 0 when empty. */
    float get_MaxSpeed() {
        float m = 0;
        for (uint i = 0; i < samples.Length; i++) {
            if (samples[i].speed > m) m = samples[i].speed;
        }
        return m;
    }

    /**
     * Record the spectated ghost's state at this point of its run.
     *
     * Called from the scrubber while spectating and not scrubbing. Switching ghosts
     * discards the trace: it belongs to one run.
     */
    void Observe(uint instanceId, uint ghostVisId, int ghostTimeMs) {
        if (!S_RecordTelemetry) return;
        if (ghostTimeMs < 0) return;
        if (instanceId != tracedInstanceId) {
            Reset();
            tracedInstanceId = instanceId;
        }
        if (samples.Length >= MAX_SAMPLES) return;
        if (lastSampleAt + SAMPLE_INTERVAL_MS > Time::Now) return;
        lastSampleAt = Time::Now;

        auto vis = FindVis(ghostVisId);
        if (vis is null) return;
        auto st = vis.AsyncState;
        if (st is null) return;

        Record(TelemetrySample(ghostTimeMs, st.FrontSpeed, st.InputGasPedal,
            st.InputIsBraking ? 1.0f : st.InputBrakePedal, st.InputSteer, st.CurGear));
    }

    CSceneVehicleVis@ FindVis(uint targetVisId) {
        auto scene = GetApp().GameScene;
        if (scene is null) return null;
        auto viss = VehicleState::GetAllVis(scene);
        for (uint i = 0; i < viss.Length; i++) {
            if (Dev::GetOffsetUint32(viss[i], 0) == targetVisId) return viss[i];
        }
        return null;
    }

    void Record(TelemetrySample@ s) {
        // Keep ordered by run time; a run can be watched out of order.
        uint at = samples.Length;
        for (uint i = 0; i < samples.Length; i++) {
            if (samples[i].time > s.time) { at = i; break; }
        }
        if (at > 0 && Math::Abs(samples[at - 1].time - s.time) <= MERGE_WINDOW_MS) {
            @samples[at - 1] = s;
            return;
        }
        samples.InsertAt(at, s);
    }

    /** Sample nearest a point in the run, or null if nothing is recorded near it. */
    TelemetrySample@ SampleAt(int ghostTimeMs) {
        if (samples.IsEmpty()) return null;
        TelemetrySample@ best = null;
        int bestDiff = 0;
        for (uint i = 0; i < samples.Length; i++) {
            int d = Math::Abs(samples[i].time - ghostTimeMs);
            if (best is null || d < bestDiff) {
                @best = samples[i];
                bestDiff = d;
            }
            if (samples[i].time > ghostTimeMs && best !is null) break;
        }
        return best;
    }
}

[Setting category="Telemetry" name="Record speed and inputs while spectating" description="Samples the spectated ghost's speed, gear and inputs as it plays, so they can be graphed against the timeline. Sampled from the VehicleState plugin, so it costs nothing version-fragile."]
bool S_RecordTelemetry = true;
