// "Compare" tab: split times for every loaded ghost, as deltas against a reference.
//
// Splits are read from raw game structures, so they are cached and only refreshed when
// asked for or when the set of loaded ghosts changes -- never per frame.

class CompareTab : Tab {
    private GhostSplits@[] cached;
    private uint cachedGhostCount = 0;
    private uint refIx = 0;
    private bool showCumulative = true;

    CompareTab() {
        super("Compare");
    }

    void OnMapChange() override {
        cached.RemoveRange(0, cached.Length);
        cachedGhostCount = 0;
        refIx = 0;
    }

    private void Refresh() {
        // Copies into the existing array rather than rebinding it: `cached` is a value
        // array, so it is never null and needs no handle juggling here.
        auto fresh = ReadAllGhostSplits();
        cached.RemoveRange(0, cached.Length);
        for (uint i = 0; i < fresh.Length; i++) cached.InsertLast(fresh[i]);
        auto mgr = GhostClipsMgr::Get(GetApp());
        cachedGhostCount = mgr is null ? 0 : mgr.Ghosts.Length;
        if (refIx >= cached.Length) refIx = 0;
    }

    /** Cheap check so the table follows ghosts being loaded or unloaded. */
    private bool GhostCountChanged() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        uint n = mgr is null ? 0 : mgr.Ghosts.Length;
        return n != cachedGhostCount;
    }

    void DrawInner() override {
        if (!Compat::Available("ghost-checkpoints")) {
            UI::TextWrapped("\\$f44Checkpoint splits are unavailable on this game build.");
            UI::TextWrapped("\\$aaa" + Compat::WhyUnavailable("ghost-checkpoints"));
            return;
        }

        if (UI::Button(Icons::Refresh + " Refresh")) Refresh();
        UI::SameLine();
        showCumulative = UI::Checkbox("Cumulative", showCumulative);
        AddSimpleTooltip("On: time from the start of the run to each checkpoint.\n"
            "Off: time taken for each individual sector.");

        // Reloading when the ghost list changes keeps this in step without polling the
        // game structures every frame.
        if (GhostCountChanged()) Refresh();

        if (cached.IsEmpty()) {
            UI::TextWrapped("\\$aaaNo ghosts loaded, or none of them recorded checkpoints.");
            return;
        }

        DrawReferencePicker();
        UI::Separator();
        DrawTable();
        UI::Separator();
        DrawSpeedTrace();
    }

    /**
     * Speed over the run for the ghost currently being spectated.
     *
     * Drawn from the live trace rather than the ghost's recorded samples -- see
     * TelemetryTrace. It fills in as the run plays, so an unwatched run has no graph yet.
     */
    private void DrawSpeedTrace() {
        if (!TelemetryTrace::HasData) {
            UI::TextWrapped("\\$aaaSpeed graph: spectate a ghost and let it play to record "
                + "its trace. Nothing is recorded while scrubbing.");
            return;
        }

        float maxSpeed = TelemetryTrace::MaxSpeed;
        if (maxSpeed <= 0) return;

        UI::Text("Speed  \\$aaatop " + Text::Format("%.0f", maxSpeed * 3.6) + " km/h, "
            + TelemetryTrace::Length + " samples");

        float[] plot;
        for (uint i = 0; i < TelemetryTrace::samples.Length; i++) {
            plot.InsertLast(TelemetryTrace::samples[i].speed * 3.6f);
        }
        // Openplanet's signature is (label, values, offset, height) -- it auto-scales to
        // the data, so no min/max is passed.
        UI::PlotLines("##speed-trace", plot, 0, 90.0f);

        // Numbers at the playhead, so the graph can be read against what is on screen.
        auto now = TelemetryTrace::SampleAt(int(scrubberMgr.pauseAt));
        if (now !is null) {
            UI::Text("At " + Time::Format(now.time) + ":  "
                + Text::Format("%.0f", now.speed * 3.6) + " km/h"
                + "   \\$aaagear\\$z " + now.gear
                + "   \\$4c4gas\\$z " + Text::Format("%.0f", now.gas * 100) + "%"
                + "   \\$f44brake\\$z " + Text::Format("%.0f", now.brake * 100) + "%"
                + "   \\$88fsteer\\$z " + Text::Format("%+.2f", now.steer));
        }
    }

    private void DrawReferencePicker() {
        UI::AlignTextToFramePadding();
        UI::Text("Compare against:");
        UI::SameLine();
        UI::SetNextItemWidth(260);
        if (UI::BeginCombo("##compare-ref", Label(cached[refIx]))) {
            for (uint i = 0; i < cached.Length; i++) {
                if (UI::Selectable(Label(cached[i]), i == refIx)) refIx = i;
            }
            UI::EndCombo();
        }
    }

    private string Label(GhostSplits@ g) {
        return Text::OpenplanetFormatCodes(g.nickname) + "  \\$aaa" + Time::Format(g.raceTime);
    }

    /** Longest split list across the loaded ghosts, so the table covers every checkpoint. */
    private uint MaxSplitCount() {
        uint n = 0;
        for (uint i = 0; i < cached.Length; i++) {
            if (cached[i].splits.Length > n) n = cached[i].splits.Length;
        }
        return n;
    }

    private void DrawTable() {
        uint nCps = MaxSplitCount();
        if (nCps == 0) {
            UI::TextWrapped("\\$aaaThese ghosts have no checkpoint data.");
            return;
        }

        auto refGhost = cached[refIx];
        int nCols = int(cached.Length) + 1;
        if (!UI::BeginTable("compare-splits", nCols,
                UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollX
                | UI::TableFlags::Borders | UI::TableFlags::RowBg)) {
            return;
        }

        UI::TableSetupColumn("CP", UI::TableColumnFlags::WidthFixed, 46);
        for (uint i = 0; i < cached.Length; i++) {
            UI::TableSetupColumn(Text::OpenplanetFormatCodes(cached[i].nickname));
        }
        UI::TableHeadersRow();

        for (uint cp = 0; cp < nCps; cp++) {
            UI::TableNextRow();
            UI::TableNextColumn();
            // The last entry is the finish, not a checkpoint.
            UI::Text(cp + 1 == nCps ? "\\$ff8Fin" : "" + (cp + 1));

            for (uint g = 0; g < cached.Length; g++) {
                UI::TableNextColumn();
                DrawCell(cached[g], refGhost, cp);
            }
        }
        UI::EndTable();

        UI::Separator();
        UI::TextWrapped("\\$aaaGreen is faster than the reference, red is slower. "
            + (showCumulative
                ? "Cumulative: total elapsed time at each checkpoint."
                : "Sector: time spent between the previous checkpoint and this one."));
    }

    private void DrawCell(GhostSplits@ g, GhostSplits@ refGhost, uint cp) {
        int t = SplitValue(g, cp);
        int r = SplitValue(refGhost, cp);
        if (t < 0) {
            UI::Text("\\$666-");
            return;
        }
        if (g is refGhost || r < 0) {
            UI::Text(Time::Format(t));
            return;
        }
        int delta = t - r;
        // Exact ties are common on the reference's own row and on identical runs; showing
        // a signed zero there would be noise.
        string deltaStr = delta == 0
            ? "\\$aaa=0.000"
            : (delta < 0 ? "\\$4c4-" : "\\$f44+") + Time::Format(delta < 0 ? -delta : delta);
        UI::Text(Time::Format(t) + "  " + deltaStr);
    }

    /** Cumulative or per-sector time at a checkpoint, or -1 if this ghost lacks it. */
    private int SplitValue(GhostSplits@ g, uint cp) {
        int t = g.TimeAt(cp);
        if (t < 0) return -1;
        if (showCumulative || cp == 0) return t;
        int prev = g.TimeAt(cp - 1);
        if (prev < 0) return -1;
        return t - prev;
    }
}
