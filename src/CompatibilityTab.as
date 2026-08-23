// Settings > Compatibility.
//
// The point of this tab: when a game update breaks something, you can see exactly what
// broke and what you lost, instead of the plugin silently going dark. Upstream's
// equivalent tab could only tell you "safe: false" and offer to override it wholesale.

[SettingsTab name="Compatibility" icon="Wrench" order=98]
void RenderCompatibilityTab() {
    UI::TextWrapped(
        "Every feature that depends on the game's internal memory layout is probed "
        "separately. A game update that breaks one of them disables that feature only -- "
        "the rest of the plugin keeps working."
    );
    UI::Separator();

    UI::Text("Game build: \\$aaa" + GetGameExeVersion());
    uint failed = Compat::CountFailed();
    if (failed == 0) {
        UI::Text("Status: \\$4c4everything this plugin needs is present on this build.");
    } else {
        UI::Text("Status: \\$fc4" + failed + " feature" + (failed == 1 ? "" : "s") +
                 " unavailable on this build.");
    }

    if (UI::Button(Icons::Refresh + " Re-check everything")) {
        Compat::ResetAll();
        startnew(Compat::ReprobeWhenPlaygroundLoaded);
    }
    AddSimpleTooltip("Runs every probe again. Useful after loading a map, since a few " +
                     "checks need one to be able to run at all.");

    UI::Separator();

    bool wasEnabled = S_EnableCodePatches;
    S_EnableCodePatches = UI::Checkbox("Enable memory patching features", S_EnableCodePatches);
    AddSimpleTooltip(
        "On by default, and required for stutterless pausing, slow motion and the "
        "flicker fix.\n\nThese are the only features that write to the game's code in "
        "memory, and so the only ones that could crash it. Each patch is checked against "
        "this exact game build before anything is written.\n\nTurn this off to rule the "
        "plugin out if you are investigating a crash."
    );
    if (wasEnabled != S_EnableCodePatches && !S_EnableCodePatches) {
        // Take effect immediately rather than waiting for the next scrubber tick.
        NoFlashCar::IsApplied = false;
        KinematicsControl::IsApplied = false;
        CameraPolish::Hook_CameraUpdatePos.SetAppliedSoon(false);
    }

    UI::Separator();

    if (UI::BeginTable("compat-caps", 3, UI::TableFlags::SizingStretchProp)) {
        UI::TableSetupColumn("Feature", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Technique", UI::TableColumnFlags::WidthFixed, 130);
        UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthFixed, 110);
        UI::TableHeadersRow();

        for (uint i = 0; i < Compat::g_Caps.Length; i++) {
            auto cap = Compat::g_Caps[i];
            UI::TableNextRow();

            UI::TableNextColumn();
            UI::Text(cap.title);
            AddSimpleTooltip(cap.id + "\n\n" + cap.impact);

            UI::TableNextColumn();
            UI::Text("\\$aaa" + Compat::TierName(cap.tier));
            AddSimpleTooltip(Compat::TierExplanation(cap.tier));

            UI::TableNextColumn();
            UI::Text(CompatStatusLabel(cap));
            AddSimpleTooltip(Compat::WhyUnavailable(cap.id));
        }

        UI::EndTable();
    }

    UI::Separator();
    UI::TextWrapped(
        "\\$aaaIf something here is red after a game update, that feature's offsets need "
        "re-deriving -- it is not a setting you can flip. Reporting the feature name and "
        "the game build above is enough to fix it."
    );

#if DEV
    UI::Separator();
    UI::Text("\\$aaaDiagnostics (dev build only)");


    if (UI::Button(Icons::Search + " Dump ghost struct layout to log")) {
        GhostDiag::DumpCurrentGhost();
    }
    AddSimpleTooltip(
        "Reads inside the first loaded ghost and reports every {pointer, length, capacity} "
        "triple it finds, as offsets relative to the reflected anchor members.\n\n"
        "This is how the checkpoint and input buffer offsets get re-derived after a game "
        "update. Reading within the object is safe; nothing found is dereferenced."
    );
#endif
}

string CompatStatusLabel(Compat::Capability@ cap) {
    if (cap.tier == Compat::Tier::CodePatch && !S_EnableCodePatches) {
        return "\\$888off";
    }
    if (cap.needsPlayground && GetApp().PlaygroundScript is null) {
        return "\\$88fneeds a map";
    }
    if (cap.IsPending) return "\\$fc4checking\\$z (" + cap.attempts + ")";
    if (!cap.hasRun) return "\\$888not checked";
    return cap.ok ? "\\$4c4available" : "\\$f44unavailable";
}
