using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.Collections.Generic;
using System.Text.RegularExpressions;

class VirtualEfbServer {
    static TcpListener server;
    static string rootDir;
    static bool running = true;
    static int port = 8088;

    static readonly Dictionary<string, string> MimeTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
        { ".html", "text/html; charset=utf-8" },
        { ".htm", "text/html; charset=utf-8" },
        { ".css", "text/css; charset=utf-8" },
        { ".js", "application/javascript; charset=utf-8" },
        { ".json", "application/json; charset=utf-8" },
        { ".webmanifest", "application/manifest+json; charset=utf-8" },
        { ".png", "image/png" },
        { ".jpg", "image/jpeg" },
        { ".jpeg", "image/jpeg" },
        { ".svg", "image/svg+xml" },
        { ".ico", "image/x-icon" },
        { ".pdf", "application/pdf" },
        { ".apk", "application/vnd.android.package-archive" }
    };

    static string GetLocalIp() {
        try {
            using (Socket socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, 0)) {
                socket.Connect("8.8.8.8", 65530);
                IPEndPoint ep = socket.LocalEndPoint as IPEndPoint;
                if (ep != null) return ep.Address.ToString();
            }
        } catch {}
        return "127.0.0.1";
    }

    static void Main(string[] args) {
        Console.Title = "Virtual EFB Companion Server";
        rootDir = AppDomain.CurrentDomain.BaseDirectory;
        ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | SecurityProtocolType.Tls11 | SecurityProtocolType.Tls;

        if (args.Length > 0) int.TryParse(args[0], out port);
        if (port <= 0) port = 8088;

        string localIp = GetLocalIp();

        int preferredPort = port;
        bool started = false;
        Exception lastEx = null;

        for (int offset = 0; offset < 20; offset++) {
            try {
                port = preferredPort + offset;
                server = new TcpListener(IPAddress.Any, port);
                server.Start();
                started = true;
                break;
            } catch (SocketException ex) {
                lastEx = ex;
            }
        }

        if (!started) {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("Could not start server on Port " + preferredPort + ": " + (lastEx != null ? lastEx.Message : "Port unavailable"));
            Console.ResetColor();
            Console.WriteLine("Press any key to exit...");
            try { Console.ReadKey(); } catch {}
            return;
        }

        string desktopUrl = "http://localhost:" + port + "/";
        string tabletUrl = "http://" + localIp + ":" + port + "/";

        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("=================================================================");
        Console.WriteLine("           VIRTUAL EFB - PC & TABLET COMPANION SERVER            ");
        Console.WriteLine("=================================================================");
        Console.ResetColor();
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("  Server Status        : ACTIVE (Port " + port + ")");
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("  YOUR PC IP FOR TABLET: " + localIp);
        Console.ForegroundColor = ConsoleColor.White;
        Console.WriteLine("  TABLET BROWSER URL   : " + tabletUrl);
        if (File.Exists(Path.Combine(rootDir, "EFB.apk"))) {
            Console.WriteLine("  TABLET APK DOWNLOAD  : " + tabletUrl + "EFB.apk");
        }
        Console.WriteLine("  PC DESKTOP BROWSER   : " + desktopUrl);
        Console.ResetColor();
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("=================================================================");
        Console.WriteLine("  Opening " + desktopUrl + " in your browser...");
        Console.WriteLine("  (Keep this window open while flying to sync checklists)");
        Console.WriteLine("  Press 'Q' or close this window to stop the server.");
        Console.WriteLine("=================================================================");
        Console.ResetColor();

        try {
            Process.Start(desktopUrl);
        } catch {}

        ThreadPool.QueueUserWorkItem(ListenLoop);

        while (running) {
            try {
                if (Console.KeyAvailable) {
                    var k = Console.ReadKey(true);
                    if (k.Key == ConsoleKey.Q) break;
                }
            } catch {}
            Thread.Sleep(250);
        }

        try { server.Stop(); } catch {}
    }

    static void ListenLoop(object state) {
        while (running) {
            try {
                TcpClient client = server.AcceptTcpClient();
                ThreadPool.QueueUserWorkItem(HandleClient, client);
            } catch {
                if (!running) break;
            }
        }
    }

    static void HandleClient(object state) {
        using (TcpClient client = (TcpClient)state) {
            try {
                client.ReceiveTimeout = 10000;
                client.SendTimeout = 10000;
                using (NetworkStream stream = client.GetStream()) {
                    byte[] buffer = new byte[65536];
                    int bytesRead = stream.Read(buffer, 0, buffer.Length);
                    if (bytesRead <= 0) return;

                    string headerText = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                    int headerEnd = headerText.IndexOf("\r\n\r\n");
                    if (headerEnd < 0) return;

                    string firstLine = headerText.Substring(0, headerText.IndexOf("\r\n"));
                    string[] parts = firstLine.Split(' ');
                    if (parts.Length < 2) return;

                    string method = parts[0].ToUpperInvariant();
                    string rawUrl = parts[1];

                    int qIdx = rawUrl.IndexOf('?');
                    string pathPart = qIdx >= 0 ? rawUrl.Substring(0, qIdx) : rawUrl;
                    string queryPart = qIdx >= 0 ? rawUrl.Substring(qIdx + 1) : "";

                    string rawPath = pathPart.TrimStart('/');
                    string path = Uri.UnescapeDataString(rawPath);

                    // Read POST body if present
                    string body = "";
                    int contentLength = 0;
                    var mLen = Regex.Match(headerText, @"Content-Length:\s*(\d+)", RegexOptions.IgnoreCase);
                    if (mLen.Success) int.TryParse(mLen.Groups[1].Value, out contentLength);

                    int bodyStart = headerEnd + 4;
                    int bodyBytesAlreadyRead = bytesRead - bodyStart;
                    using (var ms = new MemoryStream()) {
                        if (bodyBytesAlreadyRead > 0) {
                            ms.Write(buffer, bodyStart, Math.Min(bodyBytesAlreadyRead, contentLength));
                        }
                        while (ms.Length < contentLength) {
                            int r = stream.Read(buffer, 0, (int)Math.Min((long)buffer.Length, contentLength - ms.Length));
                            if (r <= 0) break;
                            ms.Write(buffer, 0, r);
                        }
                        body = Encoding.UTF8.GetString(ms.ToArray());
                    }

                    // CORS pre-flight
                    if (method == "OPTIONS") {
                        SendResponse(stream, 204, "No Content", "text/plain", new byte[0]);
                        return;
                    }

                    // API: info
                    if (method == "GET" && path == "api/info") {
                        byte[] b = Encoding.UTF8.GetBytes("{\"ok\":true,\"ip\":\"" + GetLocalIp() + "\",\"port\":" + port + "}");
                        SendResponse(stream, 200, "OK", "application/json; charset=utf-8", b);
                        return;
                    }

                    // API: atis proxy
                    if (method == "GET" && path == "api/atis") {
                        var mIcao = Regex.Match(queryPart, @"icao=([^&]+)");
                        string icao = mIcao.Success ? Uri.UnescapeDataString(mIcao.Groups[1].Value) : "";
                        icao = Regex.Replace(icao, "[^A-Za-z0-9]", "").ToUpper();
                        try {
                            using (var wc = new WebClient()) {
                                wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
                                string html = wc.DownloadString("https://atis.guru/atis/" + icao);
                                byte[] b = Encoding.UTF8.GetBytes(html);
                                SendResponse(stream, 200, "OK", "text/html; charset=utf-8", b);
                            }
                        } catch {
                            SendResponse(stream, 502, "Bad Gateway", "text/plain", Encoding.UTF8.GetBytes("502 Failed to fetch ATIS"));
                        }
                        return;
                    }

                    // API: state (two-way sync between Tablet App & PC Web Version)
                    if (method == "GET" && path == "api/state") {
                        try {
                            string appJsPath = Path.Combine(rootDir, "js", "app.js");
                            string js = File.Exists(appJsPath) ? File.ReadAllText(appJsPath, Encoding.UTF8) : "";
                            string stamp = "0";
                            var mStamp = Regex.Match(js, @"const DEFAULT_STAMP = (\d+);");
                            if (mStamp.Success) stamp = mStamp.Groups[1].Value;
                            string appsRaw = "[]";
                            var mApps = Regex.Match(js, @"(?s)const DEFAULT_APPS = (\[.*?\]);");
                            if (mApps.Success) appsRaw = mApps.Groups[1].Value;
                            string setRaw = "{}";
                            var mSet = Regex.Match(js, @"const DEFAULT_SETTINGS = (\{.*?\});");
                            if (mSet.Success) setRaw = mSet.Groups[1].Value;
                            string stateJson = "{\"stamp\":" + stamp + ",\"apps\":" + appsRaw + ",\"settings\":" + setRaw + "}";
                            byte[] b = Encoding.UTF8.GetBytes(stateJson);
                            SendResponse(stream, 200, "OK", "application/json; charset=utf-8", b);
                        } catch {
                            SendResponse(stream, 500, "Internal Server Error", "text/plain", new byte[0]);
                        }
                        return;
                    }

                    // API: sync-defaults
                    if (method == "POST" && path == "api/sync-defaults") {
                        try {
                            string appJsPath = Path.Combine(rootDir, "js", "app.js");
                            if (File.Exists(appJsPath)) {
                                string js = File.ReadAllText(appJsPath, Encoding.UTF8);
                                var matchStamp = Regex.Match(body, "\"stamp\"\\s*:\\s*(\\d+)");
                                if (matchStamp.Success) {
                                    js = Regex.Replace(js, @"const DEFAULT_STAMP = \d+;", "const DEFAULT_STAMP = " + matchStamp.Groups[1].Value + ";");
                                }
                                var matchApps = Regex.Match(body, "\"apps\"\\s*:\\s*(\\[.*?\\])(,\\s*\"settings\"|\\})", RegexOptions.Singleline);
                                if (matchApps.Success) {
                                    js = Regex.Replace(js, @"(?s)const DEFAULT_APPS = \[.*?\];", "const DEFAULT_APPS = " + matchApps.Groups[1].Value + ";");
                                }
                                var matchSet = Regex.Match(body, "\"settings\"\\s*:\\s*(\\{.*?\\})\\s*\\}", RegexOptions.Singleline);
                                if (matchSet.Success) {
                                    js = Regex.Replace(js, @"const DEFAULT_SETTINGS = \{.*?\};", "const DEFAULT_SETTINGS = " + matchSet.Groups[1].Value + ";");
                                }
                                File.WriteAllText(appJsPath, js, Encoding.UTF8);
                            }
                            byte[] ok = Encoding.UTF8.GetBytes("{\"ok\":true}");
                            SendResponse(stream, 200, "OK", "application/json; charset=utf-8", ok);
                        } catch {
                            SendResponse(stream, 500, "Internal Server Error", "text/plain", new byte[0]);
                        }
                        return;
                    }

                    // API: save-checklist
                    if (method == "POST" && path == "api/save-checklist") {
                        try {
                            var matchAc = Regex.Match(body, "\"aircraft\"\\s*:\\s*\"(.*?)\"");
                            var matchTitle = Regex.Match(body, "\"title\"\\s*:\\s*\"(.*?)\"");
                            var matchB64 = Regex.Match(body, "\"base64\"\\s*:\\s*\"(.*?)\"");
                            var matchId = Regex.Match(body, "\"id\"\\s*:\\s*\"(.*?)\"");

                            if (matchAc.Success && matchTitle.Success && matchB64.Success) {
                                string ac = matchAc.Groups[1].Value;
                                string title = matchTitle.Groups[1].Value;
                                string b64 = matchB64.Groups[1].Value;
                                string id = matchId.Success ? matchId.Groups[1].Value : ("chk_" + DateTime.UtcNow.Ticks);

                                string safeName = Regex.Replace(ac + "-" + title, @"[^A-Za-z0-9._-]+", "-").Trim('-') + ".pdf";
                                string chkDir = Path.Combine(rootDir, "checklists");
                                if (!Directory.Exists(chkDir)) Directory.CreateDirectory(chkDir);

                                File.WriteAllBytes(Path.Combine(chkDir, safeName), Convert.FromBase64String(b64));

                                string idxPath = Path.Combine(chkDir, "index.json");
                                string idxContent = File.Exists(idxPath) ? File.ReadAllText(idxPath, Encoding.UTF8).Trim() : "[]";
                                if (!idxContent.Contains(safeName)) {
                                    string newItem = "{\"id\":\"" + id + "\",\"aircraft\":\"" + ac + "\",\"title\":\"" + title + "\",\"file\":\"../checklists/" + safeName + "\"}";
                                    if (idxContent == "[]" || string.IsNullOrEmpty(idxContent)) {
                                        idxContent = "[" + newItem + "]";
                                    } else {
                                        idxContent = idxContent.TrimEnd(']', ' ', '\r', '\n') + "," + newItem + "]";
                                    }
                                    File.WriteAllText(idxPath, idxContent, Encoding.UTF8);
                                }
                            }
                            byte[] ok = Encoding.UTF8.GetBytes("{\"ok\":true}");
                            SendResponse(stream, 200, "OK", "application/json; charset=utf-8", ok);
                        } catch {
                            SendResponse(stream, 500, "Internal Server Error", "text/plain", new byte[0]);
                        }
                        return;
                    }

                    // API: delete-checklist
                    if (method == "POST" && path == "api/delete-checklist") {
                        try {
                            var matchId = Regex.Match(body, "\"id\"\\s*:\\s*\"(.*?)\"");
                            if (matchId.Success) {
                                string id = matchId.Groups[1].Value;
                                string chkDir = Path.Combine(rootDir, "checklists");
                                string idxPath = Path.Combine(chkDir, "index.json");
                                if (File.Exists(idxPath)) {
                                    string raw = File.ReadAllText(idxPath, Encoding.UTF8);
                                    string pattern = @"\{[^{}]*?""id""\s*:\s*""" + Regex.Escape(id) + @"""[^{}]*?\},?";
                                    string updated = Regex.Replace(raw, pattern, "");
                                    updated = Regex.Replace(updated, @",\s*\]", "]");
                                    updated = Regex.Replace(updated, @"\[\s*,", "[");
                                    File.WriteAllText(idxPath, updated, Encoding.UTF8);
                                }
                            }
                            byte[] ok = Encoding.UTF8.GetBytes("{\"ok\":true}");
                            SendResponse(stream, 200, "OK", "application/json; charset=utf-8", ok);
                        } catch {
                            SendResponse(stream, 500, "Internal Server Error", "text/plain", new byte[0]);
                        }
                        return;
                    }

                    // Static file serving
                    if (string.IsNullOrEmpty(path)) path = "index.html";
                    string fullPath = Path.GetFullPath(Path.Combine(rootDir, path));

                    if (!fullPath.StartsWith(rootDir, StringComparison.OrdinalIgnoreCase) || !File.Exists(fullPath)) {
                        byte[] notFound = Encoding.UTF8.GetBytes("404 Not Found");
                        SendResponse(stream, 404, "Not Found", "text/plain", notFound);
                        return;
                    }

                    string ext = Path.GetExtension(fullPath);
                    string mime;
                    if (!MimeTypes.TryGetValue(ext, out mime)) mime = "application/octet-stream";

                    byte[] fileBytes = File.ReadAllBytes(fullPath);
                    SendResponse(stream, 200, "OK", mime, fileBytes);
                }
            } catch {}
        }
    }

    static void SendResponse(NetworkStream stream, int statusCode, string statusText, string contentType, byte[] bodyBytes) {
        try {
            string headers = "HTTP/1.1 " + statusCode + " " + statusText + "\r\n" +
                             "Content-Type: " + contentType + "\r\n" +
                             "Content-Length: " + bodyBytes.Length + "\r\n" +
                             "Connection: close\r\n" +
                             "Access-Control-Allow-Origin: *\r\n" +
                             "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                             "Access-Control-Allow-Headers: Content-Type\r\n" +
                             "Cache-Control: no-cache\r\n\r\n";
            byte[] headerBytes = Encoding.ASCII.GetBytes(headers);
            stream.Write(headerBytes, 0, headerBytes.Length);
            if (bodyBytes.Length > 0) {
                stream.Write(bodyBytes, 0, bodyBytes.Length);
            }
            stream.Flush();
        } catch {}
    }
}

