/*
ReentrancyLocker helps avoid reentrancy issues with intercepted calls.

usage:
bool _InterceptCall(...) {
    auto lockObj = Lock("SomeId"); // get lock; define this instance locally, don't keep it around
    if (lockObj is null) return true; // check not null
    bool ret = OnInteceptedX(...); // main logic
    lockObj.Unlock(); // optional, will call this via destuctor so GC is mb okay
    return ret;
}
*/

class ReentrancyLocker {
    private dictionary lockedIds = {};
    ReentrancyLocker() {}
    InterceptLock@ Lock(const string &in id) {
        if (lockedIds.Exists(id)) {
            // warn('Tried to lock ID multiple times: ' + id);
            return null;
        }
        lockedIds[id] = true;
        // trace('Locked ID: ' + id);
        return InterceptLock(this, id);
    }
    void Unlock(const string &in id) {
        if (!lockedIds.Exists(id)) throw('Tried to unlock ID that was not locked: ' + id);
        lockedIds.Delete(id);
        // trace('Unlocked ID: ' + id);
    }
}

class InterceptLock {
    ReentrancyLocker@ locker;
    string id;
    private bool unlocked = false;

    InterceptLock(ReentrancyLocker@ _locker, const string &in _id) {
        @locker = _locker;
        id = _id;
    }

    ~InterceptLock() {
        this.Unlock();
    }

    void Unlock() {
        if (unlocked) return;
        unlocked = true;
        locker.Unlock(id);
    }
}
