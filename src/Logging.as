enum LogLevel {
    Error,
    Warning,
    Info,
    Trace,
    Debug
}

void log_info(const string &in msg) {
    if (S_LogLevel >= LogLevel::Info)
        print("[INFO] " + msg);
}
void log_error(const string &in msg) {
    if (S_LogLevel >= LogLevel::Error)
        error("[ERROR] " + msg);
}
void log_warn(const string &in msg) {
    if (S_LogLevel >= LogLevel::Warning)
        warn("[WARNING] " + msg);
}
void log_trace(const string &in msg) {
    if (S_LogLevel >= LogLevel::Trace)
        trace("[TRACE] " + msg);
}
void log_debug(const string &in msg) {
    if (S_LogLevel >= LogLevel::Debug)
        trace("[DEBUG] " + msg);
}
