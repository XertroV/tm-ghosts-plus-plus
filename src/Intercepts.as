void Intercepts() {
    // Dev::InterceptProc("CGameEditorPluginMap", "AutoSave", _AutoSave);
    // Dev::InterceptProc("CGameEditorPluginMapMapType", "AutoSave", _AutoSave);
    // Dev::InterceptProc("CSmEditorPluginMapType", "AutoSave", _AutoSave);
}

bool _AutoSave(CMwStack &in stack, CMwNod@ nod) {
    bool ret = true;
    print('intercepted autosave');
    return ret;
}
