const string CACHE_LOGINS_FILE = IO::FromStorageFolder("player_names.jsons");
const string CACHE_FAVORITES_FILE = IO::FromStorageFolder("favorite_players.jsons");
const string INDEX_GHOSTS_FILE = IO::FromStorageFolder("ghost_index.jsons");
const string CACHE_MAPS_FILE = IO::FromStorageFolder("maps.jsons");
const string GHOSTS_DIR = IO::FromStorageFolder("ghosts/");

namespace Cache {
    dictionary Logins;
    dictionary LoginNames;
    Json::Value@[] LoginsArr;
    dictionary Favorites;
    Json::Value@[] FavoritesArr;
    dictionary Maps;
    Json::Value@[] MapsArr;
    dictionary Ghosts;
    Json::Value@[] GhostsArr;

    bool hasDoneInit = false;
    bool isLoading = false;
    bool get_IsInitialized() { return hasDoneInit && !isLoading; }
    void Initialize() {
        if (hasDoneInit) return;
        hasDoneInit = true;
        isLoading = true;
        if (!IO::FolderExists(GHOSTS_DIR)) IO::CreateFolder(GHOSTS_DIR);
        PopulateFromFile(Logins, LoginsArr, CACHE_LOGINS_FILE);
        PopulateFromFile(Favorites, FavoritesArr, CACHE_FAVORITES_FILE, true);
        PopulateFromFile(Ghosts, GhostsArr, INDEX_GHOSTS_FILE);
        PopulateFromFile(Maps, MapsArr, CACHE_MAPS_FILE);
        PopulateLoginNames();
        StartHttpServer();
        isLoading = false;
    }

    void PopulateFromFile(dictionary@ d, Json::Value@[]@ arr, const string &in path, bool checkRemoved = false) {
        if (!IO::FileExists(path)) return;
        IO::File f(path, IO::FileMode::Read);
        while (!f.EOF()) {
            auto l = f.ReadLine().Trim();
            if (l.Length == 0) continue;
            // trace('loading json: ' + l);
            auto j = Json::Parse(l);
            string key = string(j['key']);
            if (d.Exists(key)) {
                int ix = int(d[key]);
                @arr[ix] = j;
            } else {
                d[key] = arr.Length;
                arr.InsertLast(j);
            }
        }
    }

    void CheckForNameToAddSoon(const string &in name, uint time) {
        startnew(_CheckForNameToAddSoon, array<string> = {name, tostring(time)});
    }

    void _CheckForNameToAddSoon(ref@ r) {
        auto args = cast<string[]>(r);
        string name = args[0];
        uint time = Text::ParseUInt(args[1]);
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            auto g = mgr.Ghosts[i].GhostModel;
            if (string(g.GhostNickname) == name && g.RaceTime == time) {
                AddLogin(LoginToWSID(g.GhostLogin), g.GhostLogin, name);
                break;
            }
        }
    }

    void AddLogin(const string &in wsid, const string &in login, const string &in name) {
        Json::Value@ j;
        if (LoginNames.Exists(login + name)) return;
        if (Logins.Exists(login)) {
            @j = GetLogin(login);
            j['names'][name] = 1;
        } else {
            @j = Json::Object();
            j['names'] = Json::Object();
            j['names'][name] = 1;
            j['wsid'] = wsid;
            j['key'] = login;
            Logins[login] = LoginsArr.Length;
            LoginsArr.InsertLast(j);
        }
        LoginNames[login+name] = true;
        SaveToLoginCache(j);
        // g_Players.OnUpdatedPlayers
        g_Players.OnPlayerAdded();
    }

    void PopulateLoginNames() {
        for (uint i = 0; i < LoginsArr.Length; i++) {
            auto j = LoginsArr[i];
            string login = j['key'];
            // log_trace('login name obj: ' + Json::Write(j));
            auto names = j['names'].GetKeys();
            for (uint n = 0; n < names.Length; n++) {
                string name = names[n];
                LoginNames[login+name] = true;
            }
        }
    }

    Json::Value@ GetLogin(const string &in login) {
        int ix = int(Logins[login]);
        return LoginsArr[ix];
    }

    void GetPlayersFromNameFilter(const string &in filter, Json::Value@[]@ arr) {
        string fLower = filter.ToLower();
        for (uint i = 0; i < LoginsArr.Length; i++) {
            auto j = LoginsArr[i];
            auto names = j['names'].GetKeys();
            for (uint n = 0; n < names.Length; n++) {
                if (MatchFilter(fLower, string(names[n]))) {
                    arr.InsertLast(j);
                    break;
                }
            }
        }
    }

    void GetFavoritesFromNameFilter(const string &in filter, Json::Value@[]@ arr) {
        string fLower = filter.ToLower();
        for (uint i = 0; i < FavoritesArr.Length; i++) {
            auto j = FavoritesArr[i];
            if (!bool(j['f'])) continue;
            string key = j['key'];
            if (!Logins.Exists(key)) {
                warn("Missing login finding favs: " + key);
                continue;
            }
            auto login = GetLogin(key);
            auto names = login['names'].GetKeys();
            for (uint n = 0; n < names.Length; n++) {
                if (MatchFilter(fLower, string(names[n]))) {
                    arr.InsertLast(login);
                    break;
                }
            }
        }
    }

    void DrawPlayerFavButton(const string &in login) {
        bool exists = Favorites.Exists(login);
        bool isFav = exists && bool(FavoritesArr[int(Favorites[login])]['f']);
        if (isFav) {
            if (UI::ButtonColored(Icons::Star + "##" + login, .3)) {
                RemoveFromFavorites(login);
            }
        } else {
            if (UI::Button(Icons::StarO + "##" + login)) {
                AddToFavorites(login);
            }
        }
    }

    void RemoveFromFavorites(const string &in login) {
        if (!Favorites.Exists(login)) return;
        auto j = FavoritesArr[int(Favorites[login])];
        Favorites.Delete(login);
        j['f'] = false;
        SaveFavoriteToCache(j);
        g_Favorites.OnFavAdded();
    }

    void AddToFavorites(const string &in login) {
        auto j = Json::Object();
        j['key'] = login;
        j['f'] = true;
        if (Favorites.Exists(login)) {
            @j = FavoritesArr[int(Favorites[login])];
            j['f'] = true;
        } else {
            Favorites[login] = FavoritesArr.Length;
            FavoritesArr.InsertLast(j);
        }
        SaveFavoriteToCache(j);
        g_Favorites.OnFavAdded();
    }

    void GetGhostsForMap(const string &in uid, Json::Value@[]@ arr) {
        if (uid.Length == 0) return;
        for (uint i = 0; i < GhostsArr.Length; i++) {
            auto j = GhostsArr[i];
            if (uid == string(j['uid'])) {
                arr.InsertLast(j);
            }
        }
    }

    void AddRecord(CMapRecord@ rec, const string &in login, const string &in nickname) {
        auto RecId = CalcRecId(rec.WebServicesUserId, rec.MapUid.GetName(), rec.Time, rec.Timestamp);
        auto gs = Ghosts;
        auto time = Time::Format(rec.Time);
        if (gs.Exists(RecId)) {
            Notify("Ghost is alredy cached: " + nickname + " / " + time);
            return;
        }
        auto j = Json::Object();
        j['wsid'] = rec.WebServicesUserId;
        j['uid'] = rec.MapUid.GetName();
        j['time'] = rec.Time;
        j['timestamp'] = rec.Timestamp;
        j['date'] = Time::FormatString("%Y-%m-%d", rec.Timestamp);
        // j['accountId'] = rec.AccountId;
        j['fileName'] = rec.FileName;
        j['replayUrl'] = rec.ReplayUrl;
        j['key'] = RecId;
        j['name'] = nickname;
        AddLogin(rec.WebServicesUserId, login, nickname);
        SaveAndProcessRecord(j);
        NotifySuccess("Saved ghost: " + nickname + " / " + time);
        g_Saved.OnNewGhostSaved();
    }

    string CalcRecId(const string &in wsid, const string &in uid, uint time, uint stamp) {
        return Crypto::MD5(Crypto::MD5(wsid) + Crypto::MD5(uid + tostring(time) + tostring(stamp)));
    }

    void SaveAndProcessRecord(Json::Value@ j) {
        string url = j['replayUrl'];
        auto req = Net::HttpGet(url);
        while (!req.Finished()) yield();
        if (req.ResponseCode() > 299) {
            warn("Bad response downloading ghost: " + req.ResponseCode() + "; " + req.Body);
        }
        NotifySuccess("Downloaded ghost from Nadeo");
        IO::SetClipboard(url);
        auto buf = req.Buffer();
        string key = j['key'];
        SaveGhostFile(key, buf);
        Ghosts[key] = GhostsArr.Length;
        GhostsArr.InsertLast(j);
        SaveToGhostsCache(j);

    }

    string GetGhostFilename(const string &in key) {
        return GHOSTS_DIR + key + ".ghost.gbx";
    }

    void SaveGhostFile(const string &in key, MemoryBuffer@ buf) {
        buf.Seek(0);
        IO::File f(GetGhostFilename(key), IO::FileMode::Write);
        f.Write(buf);
        f.Close();
    }

    void LoadGhost(const string &in key) {
        if (Ghosts.Exists(key)) {
            // Core::LoadGhost(GetGhostFilename(key));
            auto j = GetGhost(key);
            Update_ML_SetGhostLoading(j['wsid']);
            Core::LoadGhostFromUrl(j['fileName'], GetGhostLocalURL(key));
            Update_ML_SetGhostLoaded(j['wsid']);
            NotifySuccess("Loaded ghost.");
        } else {
            NotifyWarning("Ghost not in cache.");
        }
    }

    void LoadGhostsForWsids(string[]@ wsids, const string &in uid) {
        for (uint i = 0; i < wsids.Length; i++) {
            Update_ML_SetGhostLoading(wsids[i]);
        }
        Core::LoadGhostOfPlayers(wsids, uid);
        for (uint i = 0; i < wsids.Length; i++) {
            Update_ML_SetGhostLoaded(wsids[i]);
        }
    }

    Json::Value@ GetGhost(const string &in key) {
        int ix = int(Ghosts[key]);
        return GhostsArr[ix];
    }

    MemoryBuffer@ ReadGhost(const string &in key) {
        auto fname = GetGhostFilename(key);
        if (!IO::FileExists(fname) && IO::FileExists(fname.Replace('.ghost.gbx', '.replay.gbx'))) {
            fname = fname.Replace('.ghost.gbx', '.replay.gbx');
        }
        IO::File f(fname, IO::FileMode::Read);
        return f.Read(f.Size());
    }

    string GetGhostLocalURL(const string &in key) {
        return HTTP_BASE_URL + "get_ghost/" + key;
    }



    void SaveToGhostsCache(Json::Value@ j) {
        IO::File f(INDEX_GHOSTS_FILE, IO::FileMode::Append);
        f.WriteLine(Json::Write(j));
        f.Close();
    }

    void SaveToLoginCache(Json::Value@ j) {
        IO::File f(CACHE_LOGINS_FILE, IO::FileMode::Append);
        f.WriteLine(Json::Write(j));
        f.Close();
    }

    void SaveFavoriteToCache(Json::Value@ j) {
        IO::File f(CACHE_FAVORITES_FILE, IO::FileMode::Append);
        f.WriteLine(Json::Write(j));
        f.Close();
    }
}


bool MatchFilter(const string &in filter, const string &in text) {
    return filter.Length == 0 || text.ToLower().Contains(filter);
}
