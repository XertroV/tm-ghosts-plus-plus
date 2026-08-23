// Capability registrations and their probes.
//
// A probe answers one question: "does this technique still line up with the game as it is
// right now?" It must be cheap, must not crash, and should verify a *value* wherever it
// can, not just the presence of a name -- a field can still exist while its neighbours
// have shifted, which is precisely how a hardcoded delta breaks silently.

namespace Compat {
    // Registered from Main(), never from a global initialiser: global init order across
    // files is not guaranteed, and probes read other globals.
    void RegisterAllCapabilities() {
        if (!g_Caps.IsEmpty()) return;

        Register("ghost-clips",
            "Ghost clip playback",
            "Scrubbing, pausing and slow motion are unavailable.",
            Tier::Reflected, ProbeFn(Probe_GhostClips));

        Register("intercepts",
            "Game event hooks",
            "Ghosts will not be detected as they load, and the scrubber will not follow spawns.",
            Tier::Reflected, ProbeFn(Probe_Intercepts));

        Register("ghost-metadata",
            "Ghost skin and trail colour",
            "Ghost car skins and light trail colours cannot be read.",
            Tier::AnchoredOffset, ProbeFn(Probe_GhostMetadata));

        Register("ghost-inputs",
            "Ghost inputs and checkpoints",
            "Input display and per-checkpoint split times are unavailable.",
            Tier::AnchoredOffset, ProbeFn(Probe_GhostInputs));

        // Separate from ghost-inputs on purpose. The checkpoint buffer is a different
        // offset (NbRespawns + 0x8, measured correct) and reading it does not go anywhere
        // near the input parsing that is currently shelved.
        Register("ghost-checkpoints",
            "Ghost checkpoint splits",
            "Per-checkpoint split times and ghost comparison are unavailable.",
            Tier::AnchoredOffset, ProbeFn(Probe_GhostCheckpoints));

        Register("ghost-ent-records",
            "Ghost telemetry samples",
            "Per-sample telemetry (speed, position over time) cannot be read.",
            Tier::AnchoredOffset, ProbeFn(Probe_GhostEntRecords));

        // Needs a playground: the probe verifies the value it reads is a real 0..1
        // opacity, and there is nothing to read outside a map.
        Register("ghost-alpha",
            "Ghost opacity control",
            "Ghost transparency cannot be overridden.",
            Tier::AnchoredOffset, ProbeFn(Probe_GhostAlpha), true);

        Register("scene-time",
            "Scene time control",
            "Stutterless pausing and slow motion fall back to the game's own timing.",
            Tier::AnchoredOffset, ProbeFn(Probe_SceneTime));

        Register("back-to-menu-flag",
            "Return-to-menu detection",
            "The plugin may not clean up ghosts when you leave a map.",
            Tier::AnchoredOffset, ProbeFn(Probe_BackToMenuFlag));

        Register("game-camera",
            "Camera control",
            "Camera cycling, free cam and camera overrides are unavailable.",
            Tier::PointerChain, ProbeFn(Probe_GameCamera), true);

        Register("ghost-visibility",
            "Ghost visibility toggle",
            "Showing and hiding ghosts through the game's own setting is unavailable.",
            Tier::PointerChain, ProbeFn(Probe_GhostVisibility), true);

        Register("ghost-save",
            "Saving ghosts for later",
            "Ghosts cannot be saved to your local library.",
            Tier::PointerChain, ProbeFn(Probe_GhostSave));

        Register("no-flash-car",
            "Flicker fix near finish",
            "Ghost cars may flicker near the finish line.",
            Tier::CodePatch, ProbeFn(Probe_NoFlashCar));

        Register("kinematics-control",
            "Stutterless pausing and slow motion",
            "Pausing and slow motion fall back to the game's own timing, which stutters.",
            Tier::CodePatch, ProbeFn(Probe_KinematicsControl));

        Register("camera-polish",
            "Camera hold at end of replay",
            "The camera may jump to a thumbnail or spectator view near the end of a replay.",
            Tier::CodePatch, ProbeFn(Probe_CameraPolish));

        log_trace("registered " + g_Caps.Length + " capabilities");
    }

    // --- Reflected -------------------------------------------------------------------

    bool Probe_GhostClips() {
        string missing = MissingMembers("CGameCtnMediaClipPlayer", {"EdMediaTracks"});
        if (missing != "") return FailWith(missing);
        missing = MissingMembers("ISceneVis", {"HackScene"});
        if (missing != "") return FailWith(missing);
        return true;
    }

    bool Probe_Intercepts() {
        const string[] classes = {
            "CSmArenaRulesMode", "CGameGhostMgrScript",
            "CGamePlaygroundUIConfig", "CGameScriptHandlerPlaygroundInterface"
        };
        for (uint i = 0; i < classes.Length; i++) {
            if (!HasType(classes[i])) return FailWith("class '" + classes[i] + "' no longer exists");
        }
        return true;
    }

    // --- Anchored offsets ------------------------------------------------------------

    bool Probe_GhostMetadata() {
        string missing = MissingMembers("CGameCtnGhost", {"LightTrailColor", "ModelIdentAuthor"});
        return missing == "" ? true : FailWith(missing);
    }

    /**
     * The CGameCtnGhost accessors carry hardcoded field deltas that only hold for the
     * layout they were measured against. A size change means fields moved, so at least
     * some of those deltas now address whatever took their place.
     *
     * This has to be caught by reflection rather than by reading and sanity-checking the
     * result: a read through a stale offset can land on unmapped memory, and that kills
     * the game outright instead of raising an exception a probe could catch. Checking the
     * size is the only safe way to ask the question.
     *
     * Note this is a coarse gate -- it condemns every offset in the file over any size
     * change, including ones that did not move. When it fires, the fix is to re-measure
     * with GhostStructDump.as and update DGAMECTNGHOST_VERIFIED_SIZE, not to widen the
     * check. Measuring took one in-game dump; guessing cost several crashes.
     */
    bool CheckGeneratedGhostLayout() {
        uint live = SizeOf("CGameCtnGhost");
        if (live == 0) return Inconclusive("CGameCtnGhost size not reported yet");
        if (live != DGAMECTNGHOST_VERIFIED_SIZE) {
            return FailWith("CGameCtnGhost is 0x" + Text::Format("%x", live) +
                " on this build, but these offsets were measured against 0x" +
                Text::Format("%x", DGAMECTNGHOST_VERIFIED_SIZE) +
                ". Re-run the ghost struct dump (Settings > Compatibility, dev build) and " +
                "update the offsets before this can be read safely.");
        }
        return true;
    }

    bool Probe_GhostInputs() {
        string missing = MissingMembers("CGameCtnGhost", {"NbRespawns", "Validate_GameModeCustomData"});
        if (missing != "") return FailWith(missing);
        if (!CheckGeneratedGhostLayout()) return false;
        // SHELVED. Parsing input data crashes the game on this build and the cause is not
        // yet known. What is established, so this can be picked up cleanly later:
        //
        //   - the offsets are correct (measured; see DGAMECTNGHOST_VERIFIED_SIZE)
        //   - BytesPtr is readable for all BytesLen bytes (traced: 1070/1070 copied)
        //   - BittableMemoryBuffer cannot fault: bounds-checked reads over a local copy
        //   - it dies inside parse tick 0, at bit position 0
        //   - statement tracing put it at res.InsertLast(), the very first append
        //   - dropping the shared interface from TmInputChange did not fix it
        //   - moving the parse off the render thread did not fix it
        //
        // Ruled out: stale offsets, the BytesPtr dereference, ImGui index overflow,
        // running off the end of the bit buffer, malformed data late in the run, and the
        // shared-type cross-module ABI.
        //
        // To resume: delete this block. The [inputread] traces are still in place and
        // will localise the failure again immediately.
        return FailWith("parsing input data crashes the game on this build, so it is " +
            "disabled. The offsets and memory reads are verified correct; the fault is " +
            "in the parse loop's first iteration and is still being investigated.");
    }

    bool Probe_GhostCheckpoints() {
        string missing = MissingMembers("CGameCtnGhost", {"NbRespawns"});
        if (missing != "") return FailWith(missing);
        return CheckGeneratedGhostLayout();
    }

    bool Probe_GhostEntRecords() {
        string missing = MissingMembers("CGameCtnGhost", {"Validate_ExtraTool_Info"});
        if (missing != "") return FailWith(missing);
        return CheckGeneratedGhostLayout();
    }

    bool Probe_GhostAlpha() {
        string missing = MissingMembers("CSmArenaRules", {"RulesStateEndTime"});
        if (missing != "") return FailWith(missing);
        // The offset lands on a float alpha. If the surrounding layout shifted we would be
        // reading something else entirely, so check the value is a plausible opacity.
        auto rules = FindArenaRules();
        if (rules is null) {
            // Claiming "available" without ever reading the value would cache a pass we
            // never actually verified, which is the whole point of this tier's probe.
            return Inconclusive("no arena rules to read an opacity from yet");
        }
        float alpha = Dev::GetOffsetFloat(rules, O_CSMARENARULES_MAXGHOSTALPHA);
        if (alpha < 0.0f || alpha > 1.0f || alpha != alpha) {
            return FailWith("read " + alpha + " where a 0..1 opacity was expected -- " +
                            "the fields around RulesStateEndTime have moved");
        }
        return true;
    }

    bool Probe_SceneTime() {
        string missing = MissingMembers("ISceneVis", {"ScenePhy"});
        return missing == "" ? true : FailWith(missing);
    }

    bool Probe_BackToMenuFlag() {
        string missing = MissingMembers("CGameCtnApp", {"Editor"});
        return missing == "" ? true : FailWith(missing);
    }

    // --- Pointer chains --------------------------------------------------------------

    bool Probe_GameCamera() {
        if (!HasMember("CGameCtnApp", "GameScene")) {
            return FailWith("CGameCtnApp is missing: GameScene");
        }
        auto gc = Dev::GetOffsetNod(GetApp(), O_APP_GAMECAM);
        if (gc is null) {
            return Inconclusive("no camera object at GameScene+0x10 yet -- still loading?");
        }
        uint activeCam = Dev::GetOffsetUint32(gc, O_GAMECAM_ACTIVE_CAM_TYPE);
        // Zero means no camera is active yet, which is normal while a map loads. Only a
        // non-zero value out of range proves the struct actually moved.
        if (activeCam == 0) {
            return Inconclusive("no camera active yet");
        }
        if (activeCam >= 0x2E) {
            return FailWith("active camera type read as " + Text::Format("0x%08x", activeCam) +
                            ", outside the expected 0x01-0x2D range");
        }
        return true;
    }

    bool Probe_GhostSave() {
        if (!HasType("CGameGhostScript")) {
            return FailWith("class 'CGameGhostScript' no longer exists");
        }
        // CreateGhostScript() plants the ghost pointer at 0x20, so the struct has to
        // reach at least 0x28. Upstream assumed 0x58 and wrote out to 0x50; it is 0x38
        // today, and those writes ran off the end of the object.
        uint size = SizeOf("CGameGhostScript");
        if (size < 0x28) {
            return FailWith("CGameGhostScript is only " + size + " bytes (0x" +
                            Text::Format("%x", size) + "); the ghost pointer field at " +
                            "0x20 does not fit");
        }
        return true;
    }

    bool Probe_GhostVisibility() {
        auto appTy = Reflection::GetType("CTrackMania");
        if (appTy is null) return FailWith("class 'CTrackMania' no longer exists");
        auto rootMapM = appTy.GetMember("RootMap");
        if (rootMapM is null) return FailWith("CTrackMania is missing: RootMap");
        // The final nod must cast to CGameUserProfile; if the walk drifted it will not.
        // Uses the unchecked variant deliberately: the guarded one calls Require() for
        // this same capability, which would recurse straight back into this probe.
        auto profile = GetSpecialUserProfile_Unchecked(GetApp());
        if (profile is null) {
            // A null here means either "not populated yet" or "the offsets are wrong", and
            // the walk cannot tell them apart. Retry; the attempt cap turns a persistent
            // null into a reported failure on its own.
            return Inconclusive("the pointer walk from RootMap+0x48 did not land on a " +
                                "CGameUserProfile");
        }
        return true;
    }

    // --- Code patches ----------------------------------------------------------------

    // These probes deliberately do NOT call Dev::FindPattern themselves.
    //
    // Pattern scanning is context-sensitive -- upstream notes as much in Scrubber.as
    // ("the patch needs to be async otherwise the function won't be found (since we are
    // running out of MLHook context)"). Re-scanning from a probe coroutine produced
    // false negatives for patterns the patch objects had already located moments before.
    // The patchers scan once at construction and cache the address, so the honest
    // question is "did you find yours?", not "let me look again".

    bool Probe_NoFlashCar() {
        if (NoFlashCar::MP_Set338Pattern1.ptr == 0) {
            return FailWith("byte pattern 1 did not resolve on this build");
        }
        if (NoFlashCar::MP_Set338Pattern2.ptr == 0) {
            return FailWith("byte pattern 2 did not resolve on this build");
        }
        return true;
    }

    bool Probe_KinematicsControl() {
        if (KinematicsControl::kinematicsControlPatch.ptr == 0) {
            return FailWith("byte pattern did not resolve on this build");
        }
        // The patch is useless without somewhere to write the scene time.
        if (!HasMember("ISceneVis", "ScenePhy")) {
            return FailWith("ISceneVis is missing: ScenePhy");
        }
        return true;
    }

    bool Probe_CameraPolish() {
        // This hook resolves its pattern on a coroutine, so a zero here usually just
        // means the scan has not finished yet. Nudge it along and retry.
        CameraPolish::Hook_CameraUpdatePos.FindPatternPtr();
        if (CameraPolish::Hook_CameraUpdatePos.PatternPtr == 0) {
            return Inconclusive("hook pattern scan has not resolved yet");
        }
        return true;
    }

    // --- helper ----------------------------------------------------------------------

    // Best effort: the arena rules object is only reachable inside a playground.
    // Same path Main.as's ForceGhostAlphaLoop uses.
    CSmArenaRules@ FindArenaRules() {
        auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
        if (cp is null || cp.Arena is null) return null;
        return cp.Arena.Rules;
    }
}
