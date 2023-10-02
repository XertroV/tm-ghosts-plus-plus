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
        PopulateFromFile(Favorites, FavoritesArr, CACHE_FAVORITES_FILE);
        PopulateFromFile(Ghosts, GhostsArr, INDEX_GHOSTS_FILE);
        PopulateFromFile(Maps, MapsArr, CACHE_MAPS_FILE);
        PopulateLoginNames();
        StartHttpServer();
        isLoading = false;
    }

    void PopulateFromFile(dictionary@ d, Json::Value@[]@ arr, const string &in path) {
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

    void AddLogin(const string &in wsid, const string &in login, const string &in name) {
        Json::Value@ j;
        if (LoginNames.Exists(login + name)) return;
        if (Logins.Exists(login)) {
            @j = GetLogin(login);
            if (j['names'].HasKey(name)) return;
            j['names'][name] = 1;
        } else {
            @j = Json::Object();
            j['names'] = Json::Object();
            j['names'][name] = 1;
            j['wsid'] = wsid;
            j['key'] = login;
            Logins[login] = LoginsArr.Length;
            LoginsArr.InsertLast(login);
            LoginNames[login+name] = true;
        }
        SaveToLoginCache(j);
    }

    void PopulateLoginNames() {
        for (uint i = 0; i < LoginsArr.Length; i++) {
            auto j = LoginsArr[i];
            string login = j['key'];
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
        for (uint i = 0; i < LoginsArr.Length; i++) {
            auto j = LoginsArr[i];
            auto names = j['names'].GetKeys();
            for (uint n = 0; n < names.Length; n++) {
                if (MatchFilter(filter, string(names[n]))) {
                    arr.InsertLast(j);
                    break;
                }
            }
        }
    }

    void DrawPlayerFavButton(const string &in login) {
        if (Favorites.Exists(login)) {
            if (UI::ButtonColored(Icons::Star, .3)) {
                RemoveFromFavorites(login);
            }
        } else {
            if (UI::Button(Icons::StarO)) {
                AddToFavorites(login);
            }
        }
    }

    void RemoveFromFavorites(const string &in login) {

    }

    void AddToFavorites(const string &in login) {

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
        return GHOSTS_DIR + key + ".replay.gbx";
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
            Core::LoadGhostFromUrl(j['fileName'], GetGhostLocalURL(key));
            NotifySuccess("Loaded ghost.");
        } else {
            NotifyWarning("Ghost not in cache.");
        }
    }

    Json::Value@ GetGhost(const string &in key) {
        int ix = int(Ghosts[key]);
        return GhostsArr[ix];
    }

    MemoryBuffer@ ReadGhost(const string &in key) {
        IO::File f(GetGhostFilename(key), IO::FileMode::Read);
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
}


bool MatchFilter(const string &in filter, const string &in text) {
    return text.ToLower().Contains(filter);
}
