const string CACHE_LOGINS_FILE = IO::FromStorageFolder("player_names.jsons");
const string CACHE_FAVORITES_FILE = IO::FromStorageFolder("favorite_players.jsons");
const string INDEX_GHOSTS_FILE = IO::FromStorageFolder("ghost_index.jsons");
const string CACHE_MAPS_FILE = IO::FromStorageFolder("maps.jsons");
const string GHOSTS_DIR = IO::FromStorageFolder("ghosts/");

namespace Cache {
    dictionary Logins;
    dictionary Favorites;
    dictionary Ghosts;
    dictionary Maps;

    bool hasDoneInit = false;
    bool isLoading = false;
    bool get_IsInitialized() { return hasDoneInit && !isLoading; }
    void Initialize() {
        if (hasDoneInit) return;
        hasDoneInit = true;
        isLoading = true;
        if (!IO::FolderExists(GHOSTS_DIR)) IO::CreateFolder(GHOSTS_DIR);
        PopulateFromFile(Logins, CACHE_LOGINS_FILE);
        PopulateFromFile(Favorites, CACHE_FAVORITES_FILE);
        PopulateFromFile(Ghosts, INDEX_GHOSTS_FILE);
        PopulateFromFile(Maps, CACHE_MAPS_FILE);
        isLoading = false;
    }

    void PopulateFromFile(dictionary@ d, const string &in path) {
        if (!IO::FileExists(path)) return;
        IO::File f(path, IO::FileMode::Read);
        while (!f.EOF()) {
            auto l = f.ReadLine().Trim();
            if (l.Length == 0) continue;
            auto j = Json::Parse(l);
            d[string(j['key'])] = j;
        }
    }

    void AddName(const string &in wsid, const string &in login, const string &in name) {

    }

    void GetName(const string &in login) {

    }

    void AddRecord(CMapRecord@ rec) {
        auto RecId = CalcRecId(rec.WebServicesUserId, rec.MapUid, rec.Time, rec.Timestamp);
        auto gs = Ghosts;
        if (gs.Exists(RecId)) return;
        auto j = Json::Object();
        j['wsid'] = rec.WebServicesUserId;
        j['uid'] = rec.MapUid;
        j['time'] = rec.Time;
        j['timestamp'] = rec.Timestamp;
        j['accountId'] = rec.AccountId;
        j['fileName'] = rec.FileName;
        j['replayUrl'] = rec.ReplayUrl;
        j['key'] = RecId;
        SaveAndProcessRecord(j);
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
        auto buf = req.Buffer();
        string key = j['key'];
        SaveGhostFile(key, buf);
        Ghosts[key] = j;
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

    void SaveToGhostsCache(Json::Value@ j) {
        IO::File f(INDEX_GHOSTS_FILE, IO::FileMode::Append);
        f.WriteLine(Json::Write(j));
        f.Close();
    }
}
