// Per-feature compatibility, replacing upstream Ghosts++'s single global kill-switch.
//
// Ghosts++ decided at startup whether the whole plugin was allowed to run, by matching
// the game's exact build string against a hand-maintained list (and a JSON file on
// openplanet.dev that a human had to remember to update). Miss the list and every render
// and init path returned immediately -- a fully working plugin that did nothing. That is
// what left it dead on game build 2026-02-02_17_51 while all of its byte patterns still
// resolved perfectly.
//
// Here, every version-fragile operation is a Capability with its own probe. A probe that
// fails disables exactly one feature and explains why. Nothing consults a version list,
// and nothing phones home.

/**
 * Code patches rewrite game code in memory. Stutterless pausing, slow motion and the
 * flicker fix all depend on them, so they are on by default -- turning them off by
 * default would be the same self-disabling behaviour this fork exists to remove.
 *
 * What makes that safe here, and did not exist upstream: each patch has a probe that
 * confirms its byte pattern still matches this exact build before anything is written,
 * and the patch verifies the original bytes at the target address as well. A game update
 * that moves the pattern disables that one patch instead of corrupting game code.
 *
 * The switch exists so that if you ever suspect the plugin in a crash, you can rule out
 * every memory write in one click.
 *
 * Declared at global scope because Openplanet only picks up settings on global variables.
 */
// Hidden from the auto-generated settings UI and rendered by RenderCompatibilityTab()
// instead, so it sits next to the capability table it actually governs.
[Setting hidden]
bool S_EnableCodePatches = true;


namespace Compat {
    /** How likely a game update is to break this, and how badly. */
    enum Tier {
        // Resolved by name through reflection; adapts to layout changes on its own.
        Reflected = 0,
        // A reflected anchor plus a hardcoded delta. Survives most updates, but breaks
        // silently if a neighbouring field moves -- so these probes sanity-check values.
        AnchoredOffset = 1,
        // A raw pointer walk with no reflected anchor. Breaks on any layout change.
        PointerChain = 2,
        // Byte-pattern scan and/or code patching. Can crash the game, so opt-in.
        CodePatch = 3
    }

    funcdef bool ProbeFn();

    class Capability {
        string id;
        string title;
        // What the user loses when this is unavailable.
        string impact;
        Tier tier;
        ProbeFn@ probe;
        // Some probes can only run with a map loaded (they walk live game structures).
        bool needsPlayground;

        bool hasRun;
        bool ok;
        string failure;
        // Set while the probe is executing, so a probe that reaches guarded code cannot
        // recurse back into itself.
        bool running;
        // Inconclusive-retry bookkeeping.
        uint attempts;
        uint retryAfter;

        Capability(const string &in id, const string &in title, const string &in impact,
                   Tier tier, ProbeFn@ probe, bool needsPlayground = false) {
            this.id = id;
            this.title = title;
            this.impact = impact;
            this.tier = tier;
            @this.probe = probe;
            this.needsPlayground = needsPlayground;
            this.hasRun = false;
            this.ok = false;
            this.failure = "not probed yet";
            this.running = false;
            this.attempts = 0;
            this.retryAfter = 0;
        }

        /** Runs the probe and caches the result. Never throws, never recurses. */
        void Run() {
            if (hasRun || running) return;
            // An inconclusive probe asked to wait; honour that rather than hammering it
            // every frame from Available().
            if (retryAfter > Time::Now) return;

            if (probe is null) {
                hasRun = true;
                ok = false;
                failure = "no probe registered";
                return;
            }

            running = true;
            attempts++;
            g_LastProbeFailure = "";
            g_ProbeInconclusive = false;
            bool threw = false;
            try {
                ok = probe();
            } catch {
                ok = false;
                threw = true;
                failure = "probe threw: " + getExceptionInfo();
            }
            running = false;

            if (ok) {
                hasRun = true;
                failure = "";
                log_trace("capability OK: " + id);
                return;
            }
            if (threw) {
                hasRun = true;
                log_warn("capability UNAVAILABLE: " + id + " -- " + failure);
                return;
            }

            // Probes report specifics through FailWith(); fall back to a generic message
            // if one returned false without setting a reason.
            failure = g_LastProbeFailure != ""
                ? g_LastProbeFailure
                : "the game layout no longer matches what this feature expects";

            if (g_ProbeInconclusive && attempts < PROBE_MAX_ATTEMPTS) {
                // Not an answer yet -- try again shortly, and stay un-run meanwhile.
                retryAfter = Time::Now + PROBE_RETRY_MS;
                log_trace("capability pending: " + id + " -- " + failure);
                return;
            }
            hasRun = true;
            if (g_ProbeInconclusive) {
                failure = "could not be confirmed after " + attempts + " attempts: " + failure;
            }
            log_warn("capability UNAVAILABLE: " + id + " -- " + failure);
        }

        /** True while an inconclusive probe is still waiting for a usable answer. */
        bool get_IsPending() {
            return !hasRun && attempts > 0;
        }

        void Reset() {
            hasRun = false;
            ok = false;
            failure = "not probed yet";
            running = false;
            attempts = 0;
            retryAfter = 0;
        }
    }

    Capability@[] g_Caps;

    // Probes return a plain bool; FailWith() stashes the specific reason for the
    // settings tab and returns false, so it reads naturally at a call site:
    //     if (...) return FailWith("active camera type read as 0x...");
    string g_LastProbeFailure;
    bool FailWith(const string &in reason) {
        g_LastProbeFailure = reason;
        return false;
    }

    // A probe that cannot tell yet -- the structure it reads is not populated during map
    // load, say -- must not be recorded as a failure. Reporting "broken" for something
    // that is merely not ready is the same mistake as upstream's version list, just at a
    // smaller scale. Inconclusive results are not cached; the probe is asked again later.
    bool g_ProbeInconclusive;
    bool Inconclusive(const string &in reason) {
        g_ProbeInconclusive = true;
        g_LastProbeFailure = reason;
        return false;
    }

    // How long to wait before asking an inconclusive probe again, and how many times
    // before admitting the answer is never coming and calling it a failure.
    const uint PROBE_RETRY_MS = 2000;
    const uint PROBE_MAX_ATTEMPTS = 10;

    void Register(const string &in id, const string &in title, const string &in impact,
                  Tier tier, ProbeFn@ probe, bool needsPlayground = false) {
        if (Get(id) !is null) {
            log_warn("duplicate capability registration ignored: " + id);
            return;
        }
        g_Caps.InsertLast(Capability(id, title, impact, tier, probe, needsPlayground));
    }

    Capability@ Get(const string &in id) {
        for (uint i = 0; i < g_Caps.Length; i++) {
            if (g_Caps[i].id == id) return g_Caps[i];
        }
        return null;
    }

    /**
     * Whether a feature is safe to use right now. Cheap enough to call per frame:
     * the probe runs at most once, then the answer is cached.
     */
    bool Available(const string &in id) {
        auto cap = Get(id);
        if (cap is null) {
            log_warn("unknown capability queried: " + id);
            return false;
        }
        if (cap.tier == Tier::CodePatch && !S_EnableCodePatches) return false;
        // Not a failure -- just too early to tell. Deliberately not cached.
        if (cap.needsPlayground && GetApp().PlaygroundScript is null) return false;
        cap.Run();
        return cap.ok;
    }

    /** Guard for code paths that must not run against a layout we no longer recognise. */
    void Require(const string &in id) {
        if (Available(id)) return;
        auto cap = Get(id);
        throw("Ghosts++: '" + id + "' is unavailable on this game build" +
              (cap is null ? "" : " (" + cap.failure + ")"));
    }

    /** Explanation suitable for a tooltip on a disabled button. */
    string WhyUnavailable(const string &in id) {
        auto cap = Get(id);
        if (cap is null) return "Unknown feature '" + id + "'.";
        if (cap.tier == Tier::CodePatch && !S_EnableCodePatches) {
            return "Memory patching is turned off.\n\nEnable it under Settings > Compatibility " +
                   "if you accept the (small) risk of a game crash.";
        }
        if (cap.needsPlayground && GetApp().PlaygroundScript is null) {
            return "Not available outside a map -- load a map and this will light up.";
        }
        if (cap.IsPending) {
            return "Still working this out -- the game structure this reads is not " +
                   "populated yet.\n\nLast look: " + cap.failure;
        }
        if (!cap.ok && cap.hasRun) {
            return cap.impact + "\n\nReason: " + cap.failure;
        }
        return cap.impact;
    }

    /**
     * Runs every probe that can run right now and logs a summary.
     * Called at startup and again once a map is loaded, since some probes need one.
     */
    void ProbeAll() {
        uint okCount = 0;
        uint failedCount = 0;
        uint waiting = 0;
        for (uint i = 0; i < g_Caps.Length; i++) {
            auto cap = g_Caps[i];
            // Already settled: keep the verdict. Checking needsPlayground first would
            // re-file a determined capability as "waiting" whenever a map unloads.
            if (cap.hasRun) {
                if (cap.ok) okCount++;
                else failedCount++;
                continue;
            }
            if (cap.needsPlayground && GetApp().PlaygroundScript is null) {
                waiting++;
                continue;
            }
            cap.Run();
            if (cap.ok) okCount++;
            else if (cap.hasRun) failedCount++;
            else waiting++;
        }
        log_info("compatibility: " + okCount + "/" + (okCount + failedCount) +
                 " capabilities available" +
                 (waiting > 0 ? ", " + waiting + " still to determine" : ""));
    }

    /** Any probe that asked to be retried and has not yet settled. */
    bool AnyPending() {
        for (uint i = 0; i < g_Caps.Length; i++) {
            if (g_Caps[i].IsPending) return true;
        }
        return false;
    }

    /** Forces every probe to run again -- used by the settings tab's re-check button. */
    void ResetAll() {
        for (uint i = 0; i < g_Caps.Length; i++) g_Caps[i].Reset();
    }

    /**
     * Some probes walk live game structures and can only run with a map loaded.
     * Waits for the first playground, then fills in the rest of the picture.
     */
    void ReprobeWhenPlaygroundLoaded() {
        while (GetApp().PlaygroundScript is null) yield();
        // Give the playground a moment to finish populating before walking it.
        sleep(500);
        ProbeAll();
        // Some structures (the active camera especially) are still empty this early.
        // Keep asking until every probe has settled one way or the other, rather than
        // recording "not ready yet" as "broken".
        while (AnyPending()) {
            sleep(PROBE_RETRY_MS);
            for (uint i = 0; i < g_Caps.Length; i++) {
                if (g_Caps[i].IsPending) g_Caps[i].Run();
            }
        }
        ProbeAll();
    }

    /** How many capabilities are unavailable for a real reason (not just "no map yet"). */
    uint CountFailed() {
        uint n = 0;
        for (uint i = 0; i < g_Caps.Length; i++) {
            if (g_Caps[i].hasRun && !g_Caps[i].ok) n++;
        }
        return n;
    }

    string TierName(Tier t) {
        switch (t) {
            case Tier::Reflected: return "reflected";
            case Tier::AnchoredOffset: return "anchored offset";
            case Tier::PointerChain: return "pointer chain";
            case Tier::CodePatch: return "code patch";
        }
        return "unknown";
    }

    string TierExplanation(Tier t) {
        switch (t) {
            case Tier::Reflected:
                return "Looked up by name at runtime. Adapts to game updates on its own.";
            case Tier::AnchoredOffset:
                return "A named field plus a fixed distance. Usually survives updates; the probe " +
                       "sanity-checks the value it reads in case neighbouring fields moved.";
            case Tier::PointerChain:
                return "A raw walk through game memory with nothing named to anchor to. " +
                       "Most likely of the read-only techniques to break on an update.";
            case Tier::CodePatch:
                return "Rewrites game code in memory. The only category that can crash the game.";
        }
        return "";
    }
}
