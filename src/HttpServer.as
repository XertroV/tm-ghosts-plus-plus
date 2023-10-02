// // Adapted from Archivist

// const uint PORT = 29807;
// const string HOSTNAME = "localhost";

// /* Main server logic */

// HttpServer@ server = null;

// // Start the http server. Idempotent.
// void StartHttpServer() {
//     if (server !is null) return;
//     @server = HttpServer(HOSTNAME, PORT);
//     @server.RequestHandler = RouteRequests;
//     server.StartServer();
// }

// /* Request handler -- saving ghosts */

// HttpResponse@ RouteRequests(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
//     log_info("Route: " + route);
//     log_info("Data length: " + data.Length);
//     if (route.StartsWith('/save_ghost/')) return HandleGhostUpload(type, route, headers, data);
//     if (route == '/get_ghost/') return HandleGetGhost(type, route, headers, data);
//     return Handle404(type, route, headers, data);
// }

// HttpResponse@ Handle404(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
//     if (type != "POST") return HttpResponse(405, "Must be a POST request.");
//     log_info("Data: " + data);
//     try {
//         // See K_RunResult in TM_Archivist_Local.Script.txt
//         auto report = Json::Parse(data);
//         LocalStats::IncrRuns(report['MapUid'], !bool(report['Partial']), report['DurationSec'], report['NbRespawns'], report['NbCheckpoints']);
//     } catch {
//         log_warn("Exception processing report result: " + getExceptionInfo());
//     }
//     return HttpResponse(200, "Ta");
// }

// HttpResponse@ HandleReportValidation(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
//     if (type != "POST") return HttpResponse(405, "Must be a POST request.");
//     log_info("Data: " + data);
//     try {
//         auto report = Json::Parse(data);
//         // LocalStats::IncrRuns(report['MapUid'], !bool(report['Partial']), report['DurationSec'], report['NbRespawns'], report['NbCheckpoints']);
//         string ghostId = report['GhostId'];
//         OnNewValidationGhost(ghostId);
//     } catch {
//         log_warn("Exception processing report result: " + getExceptionInfo());
//     }
//     return HttpResponse(200, "Ta");
// }

// HttpResponse@ HandleGhostUpload(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
//     if (type != "POST" && type != "GET") return HttpResponse(405, "Must be a POST or GET request.");
//     if (!route.ToLower().EndsWith(".ghost.gbx")) {
//         return HttpResponse(404);
//     }
//     uint suffix = 0;
//     while (IO::FileExists(Net::UrlDecode(ReplayPathWithSuffix(route, suffix)))) {
//         suffix++;
//         if (suffix >= 100) throw("More than 100 replays with the same filename...");
//     }
//     auto fname = Net::UrlDecode(ReplayPathWithSuffix(route, suffix));
//     string folderPath = GetFolderPath(fname);

//     if (type == "GET") {
//         try {
//             IO::File gfile(fname, IO::FileMode::Read);
//             return HttpResponse(200, gfile.ReadToEnd());
//         } catch {
//             return HttpResponse(500, "Exception reading ghost: " + getExceptionInfo());
//         }
//     }

//     if (S_ShowSaveNotifications) {
//         Notify("Saving ghost to: " + fname);
//     }
//     if (!IO::FolderExists(folderPath)) {
//         IO::CreateFolder(folderPath, true);
//     }
//     IO::File ghostFile(fname, IO::FileMode::Write);
//     ghostFile.Write(data);
//     ghostFile.Close();
//     return HttpResponse(200, fname);
// }


// string ReplayPathWithSuffix(const string &in route, uint suffixCount) {
//     string path = route;
//     if (!path.StartsWith("/")) path = "/" + path;
//     path = IO::FromUserGameFolder("Replays" + path);
//     if (suffixCount > 0) {
//         path += "_" + Text::Format("%02d", suffixCount);
//     }
//     return path;
// }

// // Note: must use `/` for final path delimeter.
// string GetFolderPath(const string &in path) {
//     auto parts = path.Split("/");
//     if (parts.Length < 2) throw("Bad path for getting folder: " + path);
//     parts.RemoveLast();
//     return string::Join(parts, "/");
// }


// /* Main server class */


// enum ServerState {
//     NotStarted,
//     Running,
//     Shutdown,
//     Error
// }

// class HttpResponse {
//     int status = 405;
//     string _body;
//     dictionary headers;

//     string body {
//         get { return _body; }
//     }

//     // yep works
//     void set_body(const string &in value) {
//         _body = value;
//         headers['Content-Length'] = tostring(value.Length);
//     }

//     HttpResponse() {
//         InitHeaders();
//     }
//     HttpResponse(int status, const string &in body = "") {
//         InitHeaders();
//         this.status = status;
//         this.body = body;
//     }

//     protected void InitHeaders() {
//         headers['Content-Length'] = tostring(0);
//         headers['Content-Type'] = "text/plain";
//         headers['Server'] = "AngelScript HttpServer " + Meta::ExecutingPlugin().Version;
//         headers['Connection'] = "close";
//     }

//     const string StatusMsgText() {
//         switch (status) {
//             case 200: return "OK";
//             case 404: return "Not Found";
//             case 405: return "Method Not Allowed";
//             case 500: return "Internal Server Error";
//         }
//         if (status < 300) return "OK?";
//         if (status < 400) return "Redirect?";
//         if (status < 500) return "Request Error?";
//         return "Server Error?";
//     }
// }

// // Returns status
// funcdef HttpResponse@ ReqHandlerFunc(const string &in type, const string &in route, dictionary@ headers, const string &in data);

// /* An http server. Call `.StartServer()` to start listening. Default port is 29805 and default host is localhost. */
// class HttpServer {
//     // 29805 = 0x746d = 'tm'
//     uint16 port = 29805;
//     string host = "localhost";
//     protected ServerState state = ServerState::NotStarted;

//     HttpServer() {}
//     HttpServer(uint16 port) {
//         this.port = port;
//     }
//     HttpServer(const string &in hostname) {
//         this.host = hostname;
//     }
//     HttpServer(const string &in hostname, uint16 port) {
//         this.port = port;
//         this.host = hostname;
//     }

//     protected Net::Socket@ socket = null;
//     ReqHandlerFunc@ RequestHandler = null;

//     void Shutdown() {
//         state = ServerState::Shutdown;
//         try {
//             socket.Close();
//         } catch {}
//         log_info("Server shut down.");
//     }

//     void StartServer() {
//         if (RequestHandler is null) {
//             throw("Must set .RequestHandler before starting server!");
//         }
//         if (state != ServerState::NotStarted) {
//             throw("Cannot start HTTP server twice.");
//         }
//         @socket = Net::Socket();
//         log_info("Starting server: " + host + ":" + port);
//         if (!socket.Listen(host, port)) {
//             SetError("failed to start listening");
//             return;
//         }
//         state = ServerState::Running;
//         log_info("Server running.");
//         startnew(CoroutineFunc(this.AcceptConnections));
//     }

//     protected void SetError(const string &in errMsg) {
//         log_warn('HttpServer terminated with error: ' + errMsg);
//         state = ServerState::Error;
//         try {
//             socket.Close();
//         } catch {};
//         @socket = null;
//     }

//     protected void AcceptConnections() {
//         while (state == ServerState::Running) {
//             yield();
//             auto client = socket.Accept();
//             if (client is null) continue;
//             log_info("Accepted new client // Remote: " + client.GetRemoteIP());
//             startnew(CoroutineFuncUserdata(this.RunClient), client);
//         }
//     }

//     protected void RunClient(ref@ clientRef) {
//         auto client = cast<Net::Socket>(clientRef);
//         if (client is null) return;
//         uint clientStarted = Time::Now;
//         while (Time::Now - clientStarted < 10000 && client.Available() == 0) yield();
//         if (client.Available() == 0) {
//             log_info("Timing out client: " + client.GetRemoteIP());
//             client.Close();
//             return;
//         }
//         RunRequest(client);
//         log_trace("Closing client.");
//         client.Close();
//     }

//     protected void RunRequest(Net::Socket@ client) {
//         string reqLine;
//         if (!client.ReadLine(reqLine)) {
//             log_warn("RunRequest: could not read first line!");
//             return;
//         }
//         reqLine = reqLine.Trim();
//         auto reqParts = reqLine.Split(" ", 3);
//         log_trace("RunRequest got first line: " + reqLine + " (parts: " + reqParts.Length + ")");
//         auto headers = ParseHeaders(client);
//         log_trace("Got " + headers.GetSize() + " headers.");
//         // auto headerKeys = headers.GetKeys();
//         auto reqType = reqParts[0];
//         auto reqRoute = reqParts[1];
//         auto httpVersion = reqParts[2];
//         if (!httpVersion.StartsWith("HTTP/1.")) {
//             log_warn("Unsupported HTTP version: " + httpVersion);
//             return;
//         }
//         string data;
//         if (headers.Exists('Content-Length')) {
//             auto len = Text::ParseInt(string(headers['Content-Length']));
//             data = client.ReadRaw(len);
//         }
//         if (client.Available() > 0) {
//             log_warn("After reading headers and body there are " + client.Available() + " bytes remaining!");
//         }
//         HttpResponse@ resp = HttpResponse();
//         try {
//             @resp = RequestHandler(reqType, reqRoute, headers, data);
//         } catch {
//             log_error("Exception in RequestHandler: " + getExceptionInfo());
//             resp.status = 500;
//             resp.body = "Exception: " + getExceptionInfo();
//         }
//         string respHdrsStr = FormatHeaders(resp.headers);
//         string fullResponse = httpVersion + " " + resp.status + " " + resp.StatusMsgText() + "\r\n" + respHdrsStr;
//         fullResponse += "\r\n\r\n" + resp.body;
//         log_debug("Response: " + fullResponse);
//         // need to use WriteRaw b/c otherwise strings are length prefixed
//         client.WriteRaw(fullResponse);
//         log_info("["+Time::Stamp + " | " + client.GetRemoteIP()+"] " + reqType + " " + reqRoute + " " + resp.status);
//         log_trace("Completed request.");
//     }

//     protected dictionary@ ParseHeaders(Net::Socket@ client) {
//         dictionary headers;
//         string nextLine;
//         while (true) {
//             while (client.Available() == 0) yield();
//             client.ReadLine(nextLine);
//             nextLine = nextLine.Trim();
//             if (nextLine.Length > 0) {
//                 AddHeader(headers, nextLine);
//             } else break;
//         }
//         return headers;
//     }

//     protected void AddHeader(dictionary@ d, const string &in line) {
//         auto parts = line.Split(":", 2);
//         if (parts.Length < 2) {
//             log_warn("Header line failed to parse: " + line + " // " + parts[0]);
//         } else {
//             d[parts[0]] = parts[1];
//             if (parts[0].ToLower().Contains("authorization")) {
//                 parts[1] = "<auth omitted>";
//             }
//             log_trace("Parsed header line: " + parts[0] + ": " + parts[1]);
//         }
//     }
// }


// string FormatHeaders(dictionary@ headers) {
//     auto keys = headers.GetKeys();
//     for (uint i = 0; i < keys.Length; i++) {
//         if (keys[i].ToLower().Contains("authorization")) {
//             keys[i] += ": <auth omitted>";
//         } else {
//             keys[i] += ": " + string(headers[keys[i]]);
//         }
//     }
//     return string::Join(keys, "\r\n");
// }
