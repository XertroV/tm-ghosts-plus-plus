class ClearTask {
    CWebServicesTaskResult@ task;
    CMwNod@ nod;

    CGameUserManagerScript@ userMgr { get { return cast<CGameUserManagerScript>(nod); } }
    CGameDataFileManagerScript@ dataFileMgr { get { return cast<CGameDataFileManagerScript>(nod); } }
    CGameScoreAndLeaderBoardManagerScript@ scoreMgr { get { return cast<CGameScoreAndLeaderBoardManagerScript>(nod); } }

    ClearTask(CWebServicesTaskResult@ task, CMwNod@ owner) {
        @this.task = task;
        @nod = owner;
    }

    void Release() {
        if (userMgr !is null) userMgr.TaskResult_Release(task.Id);
        else if (dataFileMgr !is null) dataFileMgr.TaskResult_Release(task.Id);
        else if (scoreMgr !is null) scoreMgr.TaskResult_Release(task.Id);
        else throw("ClearTask.Release called but I don't know how to handle this type: " + Reflection::TypeOf(nod).Name);
    }
}

ClearTask@[] tasksToClear;

// Wait for the task to finish processing, then add it to the list of tasks to be cleared later. Execution returns immediately, so you should consume all data in the task before yielding.
void WaitAndClearTaskLater(CWebServicesTaskResult@ task, CMwNod@ owner) {
    while (task.IsProcessing) yield();
    tasksToClear.InsertLast(ClearTask(task, owner));
}

void ClearTaskCoro() {
    while (true) {
        yield();
        if (tasksToClear.Length == 0) continue;
        for (uint i = 0; i < tasksToClear.Length; i++) {
            tasksToClear[i].Release();
        }
        tasksToClear.RemoveRange(0, tasksToClear.Length);
    }
}
