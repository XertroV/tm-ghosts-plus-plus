// Library operations over the saved-ghost cache: deleting, and importing files that were
// dropped into the ghosts folder by hand.
//
// The index is an append-only JSONL file, which is fine for adding but means removing an
// entry requires rewriting it. That is cheap here -- a saved-ghost library is hundreds of
// entries, not millions -- and keeping the on-disk index honest matters more than the
// write cost.

namespace Cache {
    /**
     * Rewrites the whole index from the in-memory array.
     *
     * Writes to a temporary file and swaps it in, so an interrupted write cannot leave a
     * truncated index behind -- losing the record of every saved ghost would be a great
     * deal worse than failing to delete one.
     */
    bool RewriteGhostsIndex() {
        string tmp = INDEX_GHOSTS_FILE + ".tmp";
        try {
            IO::File f(tmp, IO::FileMode::Write);
            for (uint i = 0; i < GhostsArr.Length; i++) {
                f.WriteLine(Json::Write(GhostsArr[i]));
            }
            f.Close();
        } catch {
            log_warn("could not write ghost index: " + getExceptionInfo());
            return false;
        }
        try {
            if (IO::FileExists(INDEX_GHOSTS_FILE)) IO::Delete(INDEX_GHOSTS_FILE);
            IO::Move(tmp, INDEX_GHOSTS_FILE);
        } catch {
            log_warn("could not replace ghost index: " + getExceptionInfo());
            return false;
        }
        return true;
    }

    /** Rebuilds the key -> index map after the array has been reordered or shortened. */
    void ReindexGhosts() {
        Ghosts.DeleteAll();
        for (uint i = 0; i < GhostsArr.Length; i++) {
            Ghosts[string(GhostsArr[i]['key'])] = i;
        }
    }

    /**
     * Removes a saved ghost from the library.
     *
     * deleteFile also removes the .ghost.gbx from disk. Off by default at the call site:
     * dropping an index entry is recoverable by re-importing, deleting the file is not.
     */
    bool DeleteSavedGhost(const string &in key, bool deleteFile) {
        if (!Ghosts.Exists(key)) return false;
        int ix = int(Ghosts[key]);
        if (ix < 0 || uint(ix) >= GhostsArr.Length) return false;

        string fileName = string(GhostsArr[ix]['fileName']);
        GhostsArr.RemoveAt(ix);
        ReindexGhosts();
        if (!RewriteGhostsIndex()) return false;

        if (deleteFile) {
            string path = GHOSTS_DIR + fileName;
            try {
                if (IO::FileExists(path)) IO::Delete(path);
            } catch {
                log_warn("removed from index but could not delete " + path + ": "
                    + getExceptionInfo());
            }
        }
        log_info("removed saved ghost from library: " + key);
        return true;
    }

    /**
     * Indexes any .ghost.gbx sitting in the ghosts folder that the index does not know
     * about -- files copied in by hand, or left behind by an index that was lost.
     *
     * Metadata comes from the file name, which SaveGhost builds as
     * "<nickname>_<mapUid>_<timestamp>.ghost.gbx". Race time is not in there, so imported
     * entries carry a time of 0 and sort last; everything else about them works.
     *
     * Returns the number of files added.
     */
    uint ImportUnindexedGhosts() {
        if (!IO::FolderExists(GHOSTS_DIR)) return 0;
        auto files = IO::IndexFolder(GHOSTS_DIR, false);
        uint added = 0;
        for (uint i = 0; i < files.Length; i++) {
            string full = files[i];
            string name = full.Split("/")[full.Split("/").Length - 1];
            name = name.Split("\\")[name.Split("\\").Length - 1];
            if (!name.ToLower().EndsWith(".ghost.gbx")) continue;
            if (Ghosts.Exists(name)) continue;

            auto j = GhostJsonFromFileName(name);
            if (j is null) {
                log_warn("could not make sense of ghost file name, skipping: " + name);
                continue;
            }
            Ghosts[name] = GhostsArr.Length;
            GhostsArr.InsertLast(j);
            SaveToGhostsCache(j);
            added++;
            log_info("imported ghost file into library: " + name);
        }
        return added;
    }

    /** Parses "<nickname>_<mapUid>_<timestamp>.ghost.gbx". Null if it does not fit. */
    Json::Value@ GhostJsonFromFileName(const string &in fileName) {
        string stem = fileName.SubStr(0, fileName.Length - ".ghost.gbx".Length);
        auto parts = stem.Split("_");
        // Nicknames can contain underscores, so take the last two fields and treat
        // everything before them as the name.
        if (parts.Length < 3) return null;
        string ts = parts[parts.Length - 1];
        string uid = parts[parts.Length - 2];
        string nick = "";
        for (uint i = 0; i + 2 < parts.Length; i++) {
            if (i > 0) nick += "_";
            nick += parts[i];
        }
        if (uid.Length == 0 || nick.Length == 0) return null;

        uint stamp = 0;
        try { stamp = Text::ParseUInt(ts); } catch { }

        auto j = Json::Object();
        j['wsid'] = "";
        j['uid'] = uid;
        j['time'] = 0;
        j['timestamp'] = stamp;
        j['date'] = stamp > 0 ? Time::FormatString("%Y-%m-%d", stamp) : "imported";
        j['fileName'] = fileName;
        j['replayUrl'] = GetGhostLocalURL(fileName);
        j['key'] = fileName;
        j['name'] = nick;
        j['imported'] = true;
        return j;
    }
}
