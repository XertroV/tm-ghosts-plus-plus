namespace Live {
    /* example ret val:
            RetVal = {"monthList": MonthObj[], "itemCount": 23, "nextRequestTimestamp": 1654020000, "relativeNextRequest": 22548}
            MonthObj = {"year": 2022, "month": 5, "lastDay": 31, "days": DayObj[], "media": {...}}
            DayObj = {"campaignId": 3132, "mapUid": "fJlplQyZV3hcuD7T1gPPTXX7esd", "day": 4, "monthDay": 31, "seasonUid": "aad0f073-c9e0-45da-8a70-c06cf99b3023", "leaderboardGroup": null, "startTimestamp": 1596210000, "endTimestamp": 1596300000, "relativeStart": -57779100, "relativeEnd": -57692700}
        as of 2022-05-31 there are 23 items, so limit=100 will give you all data till 2029.
    */
    Json::Value@ GetTotdByMonth(uint length = 100, uint offset = 0) {
        return CallLiveApiPath("/api/token/campaign/month?" + LengthAndOffset(length, offset));
    }

    /* use Personal_Best for seasonUid for global leaderboards; <https://webservices.openplanet.dev/live/leaderboards/top> */
    Json::Value@ GetMapRecords(const string &in seasonUid, const string &in mapUid, bool onlyWorld = true, uint length=5, uint offset=0) {
        // Personal_Best
        string qParams = onlyWorld ? "?onlyWorld=true" : "";
        if (onlyWorld) qParams += "&" + LengthAndOffset(length, offset);
        return CallLiveApiPath("/api/token/leaderboard/group/" + seasonUid + "/map/" + mapUid + "/top" + qParams);
    }

    /* use Personal_Best for seasonUid for global leaderboards; <https://webservices.openplanet.dev/live/leaderboards/top> */
    Json::Value@ GetMapRecordsMeat(const string &in seasonUid, const string &in mapUid, bool onlyWorld = true, uint length=5, uint offset=0) {
        auto resp = GetMapRecords(seasonUid, mapUid, onlyWorld, length, offset);
        return resp['tops'][0]['top'];
    }
}
