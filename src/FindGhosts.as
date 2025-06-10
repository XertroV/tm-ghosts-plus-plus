GhostFinder@ g_GhostFinder;

funcdef void LBRecordMapF(uint rank, uint time, Json::Value@ j);

class GhostFinder {
    bool gotNbPlayers = false;
    bool gotTopRecords = false;
    int nbPlayers = -1;
    int worstTime = -1;
    string uid;
    // (rank, time)
    nat2[] knownTimes;
    Json::Value@[] apiRespForTimes;


    GhostFinder() {
        trace('GhostFinder init');
        uid = CurrentMap;
        if (uid.Length == 0) return;
    }

    int get_NbRecords() {
        return knownTimes.Length;
    }

    void ForEachLBRecord(LBRecordMapF@ f) {
        for (uint i = 0; i < knownTimes.Length; i++) {
            auto rt = knownTimes[i];
            auto j = apiRespForTimes[i];
            f(rt.x, rt.y, j);
        }
    }
    void ForLBRecord(uint index, LBRecordMapF@ f) {
        auto rt = knownTimes[index];
        auto j = apiRespForTimes[index];
        f(rt.x, rt.y, j);
    }

    void EnsureLoaded() {
        if (!initStarted) startnew(CoroutineFunc(this.Init));
    }

    // using reset can lead to race conditions, better to replace it
    // void Reset() {
    //     uid = s_currMap;
    //     gotNbPlayers = false;
    //     gotTopRecords = false;
    //     knownTimes.RemoveRange(0, knownTimes.Length);
    //     startnew(CoroutineFunc(this.Init));
    // }

    private bool initStarted = false;
    void Init() {
        if (initStarted) return;
        initStarted = true;
        log_trace('GhostFinder.Init');
        while (!S_ShowWindow) yield();
        if (uid != s_currMap) return;
        log_trace('GhostFinder.Init running');
        // get nb players for searching purposes later if needed
        // get top records for loading ghosts anywhere on LB
        await({
            startnew(CoroutineFunc(this.LoadNbPlayers)),
            startnew(CoroutineFunc(this.LoadTopRecords))
        });

        log_trace('GhostFinder.Init complete');
    }

    bool get_IsInitialized() {
        return gotNbPlayers && gotTopRecords;
    }

    void LoadNbPlayers() {
        // auto resp = MapMonitor::GetNbPlayersForMap(uid);
        // // log_trace(Json::Write(resp));
        // if (resp.GetType() != Json::Type::Object) {
        //     log_warn("unknown nb players response: " + Json::Write(resp));
        // }
        // nbPlayers = resp['nb_players'];
        // worstTime = resp["last_highest_score"];
        gotNbPlayers = true;
        // // if (nbPlayers > 0)
        //     // AddTime(nbPlayers, worstTime);
        log_trace('done load nb players');
    }

    void LoadTopRecords() {
        auto records = Live::GetMapRecordsMeat("Personal_Best", uid, true, 100);
        AddJsonTimes(records);
        gotTopRecords = true;
        log_trace('done load top records');
    }

    void AddJsonTimes(Json::Value@ arr) {
        awaitable@[] coros;
        for (uint i = 0; i < arr.Length; i++) {
            coros.InsertLast(startnew(CoroutineFuncUserdata(AddJsonTime), arr[i]));
        }
        await(coros);
    }

    void AddJsonTime(ref@ jsonObj) {
        auto j = cast<Json::Value>(jsonObj);
        uint rank = j['position'];
        uint time = j['score'];
        j['time'] = time;
        string accountId = j['accountId'];
        string login = WSIDToLogin(accountId);
        string name = NadeoServices::GetDisplayNameAsync(accountId);
        j['login'] = login;
        j['name'] = name;
        Cache::AddLogin(accountId, login, name);
        AddTime(rank, time, j);
    }

    void AddTime(uint rank, uint time, Json::Value@ j) {
        bool inserted = false;
        if (knownTimes.Length > 0 && rank < knownTimes[knownTimes.Length-1].x) {
            // todo: optimize to use binary search
            for (uint i = 0; i < knownTimes.Length; i++) {
                if (rank > knownTimes[i].x) continue;
                knownTimes.InsertAt(i, nat2(rank, time));
                apiRespForTimes.InsertAt(i, j);
                inserted = true;
                break;
            }
        }
        if (!inserted) {
            knownTimes.InsertLast(nat2(rank, time));
            apiRespForTimes.InsertLast(j);
        }
    }

    bool isLoading = false;

    // returns wsids
    string[]@ FindAroundRank(uint rank, uint nbGhosts) {
        int rankToGet = int(rank) - nbGhosts / 2;
        return GetWsidsForRankAndNb(rankToGet, nbGhosts);
    }

    // will return 2 options if it can
    string[]@ FindAroundTime(uint time, uint nb) {
        auto found = SearchForRanks(time, nb);
        string[] ret;
        for (uint i = 0; i < found.Length; i++) {
            if (!IsGhostLoaded(found[i]))
                ret.InsertLast(found[i]['accountId']);
        }
        log_trace('FindAroundTime ('+time+', '+nb+'): ' + string::Join(ret, ", "));
        return ret;
        // if (wsids.Length < 1) {
        //     NotifyWarning('Failed to find times around ' + time);
        //     return {};
        // }
        // return GetWsidsForRankAndNb(rank, nb);
        // return SearchForRanks(time, nb);
    }

    string[]@ GetWsidsForRankAndNb(uint rank, uint nbGhosts) {
        auto recs = Live::GetMapRecordsMeat("Personal_Best", uid, true, nbGhosts, rank - 1);
        AddJsonTimes(recs);
        isLoading = false;
        string[] ret;
        for (int i = 0; i < Math::Min(nbGhosts, recs.Length); i++) {
            ret.InsertLast(recs[i]['accountId']);
        }
        return ret;
    }

    // ignores nb param
    Json::Value@[]@ SearchForRanks(uint time, uint nb) {
        auto resp = MapMonitor::GetMapLbSurround(uid, time);
        auto recs = resp['tops'][0]['top'];
        log_debug('SearchForRanks found: ' + Json::Write(recs));
        Json::Value@[] ret;
        for (uint i = 0; i < recs.Length; i++) {
            auto j = recs[i];
            auto accountId = string(j['accountId']);
            auto login = WSIDToLogin(accountId);
            j['time'] = int(j['score']);
            j['login'] = login;
            j['name'] = NadeoServices::GetDisplayNameAsync(accountId);
            // accountId for medal times via surround LB
            if (recs[i]['accountId'] == "07386a4c-f744-40f6-82a6-7b8a037f3500") continue;
            ret.InsertLast(recs[i]);
        }
        return ret;
        // if (nb == 1) return {}
        // Json::Value@[] ret;
        // int min_time = recs[0]['score'];
        // int min_rank = recs[0]['position'];
        // int max_time = recs[recs.Length - 1]['score'];
        // int max_rank = recs[recs.Length - 1]['position'];
        // // while (ret.Length < rankBuffer) {
        // // }
        // for (uint i = 0; i < recs.Length; i++) {
        //     if (int(recs[i]['score']) == time) {
        //         return recs[i]['position'];
        //     }
        // }
        // return recs[0]['position'];
    }

    int SearchForRank(uint time, uint rankBuffer, uint depth = 0) {
        throw('deprecated');
        if (depth > 20) throw('depth too deep!');
        while (!IsInitialized) yield();
        if (knownTimes.Length < 2) PrepareBasicKnownTimes();
        if (uid != s_currMap) return -1;
        int ix = -1;
        for (uint i = 0; i < knownTimes.Length; i++) {
            if (time <= knownTimes[i].y) {
                ix = i;
                break;
            }
        }
        auto rankBufferMin1 = Math::Max(rankBuffer * 2, 1);
        if (ix < 0) {
            // todo: handle not found cause
            log_debug('returning ix < 0; nbPlayers: ' + nbPlayers);
            return nbPlayers > 0 ? Math::Max(1, nbPlayers - rankBuffer * 2) : -1;
        } else if (ix == 0) {
            // todo: handle case where best time is > time
            log_debug('returning b/c ix==0');
            return 1;
        // } else if (ix == knownTimes.Length - 1) {
        //     // todo: handle case where time is last time
        } else {
            auto before = knownTimes[ix-1];
            auto after = knownTimes[ix];
            if (before.x == 10000) {
                // we maxed out accuracy
                NotifyWarning("Ghost searching maxed out accuracy at rank 10k");
                return 10000;
            }
            log_debug('before: ' + before.ToString() + ', after: ' + after.ToString());
            if (after.x - before.x > 0) {
                // todo: gap in rankings index, should drill deeper
                // the lerping didn't work very well and was very slow to approach on more-played maps
                // auto t = Math::InvLerp(before.y, after.y, time);
                // uint guess = Math::Lerp(before.x, after.x, t);
                // print('b.y, a.y, time, b.x, a.x, t, guess' + string::Join({
                //     tostring(before.y), tostring(after.y), tostring(time), tostring(before.x), tostring(after.x), tostring(t), tostring(guess)
                // }, ", "));
                uint guess = (before.x + after.x) / 2;
                if (guess == before.x) return guess;
                if (guess == after.x) guess = after.x - rankBuffer;
                guess = Math::Min(guess, 10000);
                trace('rank guess: ' + guess);
                auto arr = Live::GetMapRecordsMeat("Personal_Best", uid, true, rankBufferMin1, guess - 1);
                AddJsonTimes(arr);
                return SearchForRank(time, rankBuffer, depth + 1);
            } else {
                log_debug('returning b/c adjacent: ' + before.ToString() + ' and ' + after.ToString());
                return after.x - rankBuffer;
            }
        }
    }

    void PrepareBasicKnownTimes() {
        throw('todo');
    }
}
