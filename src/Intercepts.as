#if DEV

/* ReentrancyLocker usage:
    auto lockObj = Lock("SomeId"); // get lock; define this instance locally, don't keep it around
    if (lockObj is null) return true; // check not null
    bool ret = OnInteceptedX(...); // main logic
    lockObj.Unlock(); // optional, will call this via destuctor so GC is mb okay
    return ret;
*/
ReentrancyLocker@ Safety = ReentrancyLocker();

bool _Media_RefreshFromDisk(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    auto scope = EMediaScope(stack.CurrentUint());
    auto mt = CGameDataFileManagerScript::EMediaType(stack.CurrentEnum(1));
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Media_RefreshFromDisk!');
    print('Media_RefreshFromDisk called for type: ' + tostring(mt) + " with scope: " + tostring(scope));
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _Map_RefreshFromDisk(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Map_RefreshFromDisk!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _Replay_RefreshFromDisk(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Replay_RefreshFromDisk!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _UserSave_DeleteFile(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR UserSave_DeleteFile!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _Replay_Save(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Replay_Save!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _Replay_Author_Save(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Replay_Author_Save!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _Campaign_Get(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Campaign_Get!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

bool _Replay_Load(CMwStack &in stack, CMwNod@ nod) {
    InterceptLock@ l = Safety.Lock('DataFileMgr');
    if (l is null) return true;
    bool ret = true;
    CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(nod);
    // @LastUsedDfm = dfm;
    print('\\$29f >> GOT INTERCEPT FOR Replay_Load!');
    print('dfm.IdName; ' + dfm.IdName);
    print('dfm.Id; ' + dfm.Id.Value);
    l.Unlock();
    return ret;
}

#endif
