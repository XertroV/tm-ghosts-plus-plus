// "Library" tab: everything saved locally, across every map.
//
// The existing Saved tab only lists ghosts for the map you are on, which is the right
// default while driving but useless for finding something later. This is the other half:
// search across all maps, sort, import files dropped into the ghosts folder by hand, and
// remove entries.

enum LibrarySort {
    Newest = 0,
    Oldest = 1,
    Fastest = 2,
    Name = 3
}

class LibraryTab : Tab {
    private string filter;
    private bool thisMapOnly = false;
    private LibrarySort sortBy = LibrarySort::Newest;
    private bool deleteFileToo = false;
    private string pendingDeleteKey;

    LibraryTab() {
        super("Library");
    }

    void DrawInner() override {
        if (!Cache::IsInitialized) {
            UI::Text("Loading cache...");
            return;
        }

        DrawControls();
        UI::Separator();

        auto rows = SelectRows();
        if (rows.IsEmpty()) {
            UI::TextWrapped(filter.Length > 0
                ? "\\$aaaNothing matches \"" + filter + "\"."
                : "\\$aaaNo saved ghosts yet. Save one from the Curr Ghosts tab, or drop "
                  ".ghost.gbx files into the plugin's ghosts folder and press Import.");
            return;
        }
        DrawTable(rows);
    }

    private void DrawControls() {
        UI::SetNextItemWidth(240);
        filter = UI::InputText("Search", filter);
        UI::SameLine();
        thisMapOnly = UI::Checkbox("This map only", thisMapOnly);

        UI::SetNextItemWidth(140);
        if (UI::BeginCombo("Sort", SortName(sortBy))) {
            if (UI::Selectable(SortName(LibrarySort::Newest), sortBy == LibrarySort::Newest)) sortBy = LibrarySort::Newest;
            if (UI::Selectable(SortName(LibrarySort::Oldest), sortBy == LibrarySort::Oldest)) sortBy = LibrarySort::Oldest;
            if (UI::Selectable(SortName(LibrarySort::Fastest), sortBy == LibrarySort::Fastest)) sortBy = LibrarySort::Fastest;
            if (UI::Selectable(SortName(LibrarySort::Name), sortBy == LibrarySort::Name)) sortBy = LibrarySort::Name;
            UI::EndCombo();
        }
        UI::SameLine();
        if (UI::Button(Icons::Plus + " Import")) {
            startnew(CoroutineFunc(this.RunImport));
        }
        AddSimpleTooltip("Indexes any .ghost.gbx in the plugin's ghosts folder that the "
            "library does not already know about.\n\n" + GHOSTS_DIR);
    }

    private void RunImport() {
        uint added = Cache::ImportUnindexedGhosts();
        if (added > 0) NotifySuccess("Imported " + added + " ghost" + (added == 1 ? "" : "s") + ".");
        else Notify("No new ghost files found.");
    }

    private string SortName(LibrarySort s) {
        switch (s) {
            case LibrarySort::Newest: return "Newest first";
            case LibrarySort::Oldest: return "Oldest first";
            case LibrarySort::Fastest: return "Fastest first";
            case LibrarySort::Name: return "Name";
        }
        return "?";
    }

    /** Filtered and sorted view over the cache. */
    private Json::Value@[]@ SelectRows() {
        Json::Value@[] rows;
        string needle = filter.ToLower();
        for (uint i = 0; i < Cache::GhostsArr.Length; i++) {
            auto j = Cache::GhostsArr[i];
            if (thisMapOnly && string(j['uid']) != s_currMap) continue;
            if (needle.Length > 0) {
                string hay = (string(j.Get('name', "")) + " " + string(j.Get('date', ""))).ToLower();
                if (hay.IndexOf(needle) < 0) continue;
            }
            rows.InsertLast(j);
        }
        SortRows(rows);
        return rows;
    }

    private void SortRows(Json::Value@[]@ rows) {
        // Small lists (a personal library, not a database), so an insertion sort keeps
        // this readable and avoids needing a comparison callback.
        for (uint i = 1; i < rows.Length; i++) {
            auto item = rows[i];
            int k = int(i) - 1;
            while (k >= 0 && ShouldComeAfter(rows[k], item)) {
                @rows[k + 1] = rows[k];
                k--;
            }
            @rows[k + 1] = item;
        }
    }

    private bool ShouldComeAfter(Json::Value@ a, Json::Value@ b) {
        switch (sortBy) {
            case LibrarySort::Newest: return int64(a.Get('timestamp', 0)) < int64(b.Get('timestamp', 0));
            case LibrarySort::Oldest: return int64(a.Get('timestamp', 0)) > int64(b.Get('timestamp', 0));
            case LibrarySort::Fastest: {
                int ta = int(a.Get('time', 0));
                int tb = int(b.Get('time', 0));
                // Imported entries have no race time; keep them at the end rather than
                // letting a 0 masquerade as the fastest run in the library.
                if (ta <= 0) return tb > 0;
                if (tb <= 0) return false;
                return ta > tb;
            }
            case LibrarySort::Name: return string(a.Get('name', "")).ToLower() > string(b.Get('name', "")).ToLower();
        }
        return false;
    }

    private void DrawTable(Json::Value@[]@ rows) {
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.3, .3, .3, .3));
        if (UI::BeginTable("ghost-library", 6, TABLE_FLAGS)) {
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 80.);
            UI::TableSetupColumn("Saved", UI::TableColumnFlags::WidthFixed, 90.);
            UI::TableSetupColumn("Map", UI::TableColumnFlags::WidthFixed, 46.);
            UI::TableSetupColumn("Load", UI::TableColumnFlags::WidthFixed, 46.);
            UI::TableSetupColumn("Remove", UI::TableColumnFlags::WidthFixed, 46.);
            UI::TableHeadersRow();

            UI::ListClipper clip(rows.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawRow(rows[i]);
                    UI::PopID();
                }
            }
            UI::EndTable();
        }
        UI::PopStyleColor();

        UI::Separator();
        deleteFileToo = UI::Checkbox("Also delete the file when removing", deleteFileToo);
        AddSimpleTooltip("Off: the ghost is dropped from the library but the .ghost.gbx "
            "stays on disk and can be re-imported.\nOn: the file is deleted permanently.");

    }

    private void DrawRow(Json::Value@ j) {
        string key = j['key'];
        int time = int(j.Get('time', 0));
        bool isThisMap = string(j['uid']) == s_currMap;

        UI::TableNextRow();

        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        UI::Text(Text::OpenplanetFormatCodes(string(j.Get('name', "?"))));

        UI::TableNextColumn();
        UI::Text(time > 0 ? Time::Format(time) : "\\$666-");

        UI::TableNextColumn();
        UI::Text("\\$aaa" + string(j.Get('date', "?")));

        UI::TableNextColumn();
        // Loading a ghost recorded on another map does nothing useful, so say so rather
        // than offering a button that silently fails.
        UI::Text(isThisMap ? "\\$4c4here" : "\\$888other");
        if (!isThisMap) AddSimpleTooltip("Saved on a different map (" + string(j['uid']) + ").");

        UI::TableNextColumn();
        if (MDisabledButton(!isThisMap, Icons::Play + "##load")) {
            startnew(CoroutineFuncUserdata(LoadFromLibrary), j);
        }
        if (isThisMap) AddSimpleTooltip("Load this ghost.");

        UI::TableNextColumn();
        // Two-step inline confirm rather than a modal: removal can delete a file from
        // disk, so it should not happen on a single mis-click.
        if (pendingDeleteKey == key) {
            if (UI::Button("Sure?##confirm")) {
                if (Cache::DeleteSavedGhost(key, deleteFileToo)) {
                    NotifySuccess("Removed from library.");
                } else {
                    NotifyWarning("Could not remove that ghost.");
                }
                pendingDeleteKey = "";
            }
            AddSimpleTooltip(deleteFileToo
                ? "Removes the entry AND deletes the file permanently."
                : "Removes the entry. The file stays on disk and can be re-imported.");
        } else {
            if (UI::Button(Icons::Times + "##del")) pendingDeleteKey = key;
            AddSimpleTooltip("Remove from the library.");
        }
    }
}

void LoadFromLibrary(ref@ r) {
    auto j = cast<Json::Value>(r);
    if (j is null) return;
    try {
        Cache::LoadGhost(string(j['key']));
    } catch {
        NotifyWarning("Could not load that ghost: " + getExceptionInfo());
    }
}
