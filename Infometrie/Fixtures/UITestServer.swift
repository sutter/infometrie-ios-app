#if DEBUG
import Foundation

/// Serves the API locally, so UI tests exercise the real screens, API client, Keychain and HLS relay
/// without a remote account. This transport exists only in Debug and requires explicit UI-test switches:
/// `INFOMETRIE_LOGIN_TEST_ID` starts signed out, `--signed-in` starts with a fixture session.
final class UITestServer: URLProtocol, @unchecked Sendable {
    static let token = "login-ui-fixture"
    static let email = "connexion@example.invalid"

    @MainActor static func appModel() -> AppModel? {
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("--uitesting") else { return nil }
        let signedIn = process.arguments.contains("--signed-in")
        let namespace: String
        if let id = process.environment["INFOMETRIE_LOGIN_TEST_ID"], UUID(uuidString: id) != nil { namespace = id }
        else if signedIn { namespace = "signed-in" }
        else { return nil }
        // The actual Keychain is exercised under a dedicated service, never the user's session.
        let sessionStore = SessionStore(service: "fr.yacast.infometrie.ios.ui-tests.\(namespace)")
        if signedIn {
            try? sessionStore.save(Session(token: token, email: email, fullname: "Compte de test API",
                                           organisation: "Validation locale", expires: 3600, deviceId: 38), account: "session")
        }
        if process.arguments.contains("--reset-searches") { SearchStore().clear(account: email) }
        // Every UI test starts with nothing seen, so a passage opened by one test never greys another's.
        SeenStore().clear(account: email)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestServer.self]
        return AppModel(api: APIClient(session: URLSession(configuration: configuration)),
                        sessionStore: sessionStore, remembersEmail: false)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() { }

    override func startLoading() {
        guard let url = request.url, APIClient.sameOrigin(url, APIClient.baseURL) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        if url.path == "/rest/v1/auth/login" {
            respondToLogin()
            return
        }
        guard request.httpMethod == "GET", request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)" else {
            respond(401); return
        }
        if ProcessInfo.processInfo.arguments.contains("--feed-kinds-fixture") {
            respondToKindsFixture(url)
            return
        }
        respondWithContent(url)
    }

    private func respondToLogin() {
        let body = bodyData().flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        guard request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              request.value(forHTTPHeaderField: "Authorization") == nil,
              body?["email"] as? String == Self.email,
              let uid = body?["device_uid"] as? String, UUID(uuidString: uid) != nil,
              let name = body?["device_name"] as? String, !name.isEmpty,
              let model = body?["device_model"] as? String, !model.isEmpty else {
            respond(422); return
        }
        switch body?["password"] as? String {
        case "invalide": respond(401)
        case "inactif": respond(403)
        case "hors-ligne": client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case "quota" where body?["replace_device_id"] as? Int != 37:
            respond(409, ["error": true, "reason": "device quota reached", "max_devices": 1,
                          "devices": [["id": 37, "name": "Ancien iPhone", "model": "iPhone"]]])
        case "valide", "quota":
            respond(201, ["token": Self.token, "expires": 3600, "device_id": 38,
                          "email": Self.email, "fullname": "Compte de test API", "organisation": "Validation locale"])
        default: respond(401)
        }
    }

    /// Routes of `FixtureContent`: feed, filter choices, sequences, word timings and HLS media.
    private func respondWithContent(_ url: URL) {
        let route = Array(url.pathComponents.dropFirst(3))
        let item = route.count >= 2 ? Int64(route[1]).flatMap { id in FixtureContent.all.first { $0.id == id } } : nil
        switch (route.first ?? "", route.count) {
        case ("feed", 1): respondToFeed(url)
        case ("history", 1): respondToHistory(url)
        case ("days", 1): respondToDays(url)
        case ("persons", 1): respond(200, json(FixtureContent.persons))
        case ("parties", 1): respond(200, json(FixtureContent.parties))
        case ("sequences", 2):
            guard let item else { respond(404); return }
            let detail = FixtureContent.detail(item)
            var body = json(item) as? [String: Any] ?? [:]
            body["resume"] = detail.resume; body["verbatim"] = detail.verbatim
            body["play_from"] = detail.playFrom; body["speech_start"] = detail.speechStart
            body["speech_duration_sec"] = detail.speechDurationSec
            respond(200, body)
        case ("sequences", 3) where route[2] == "words":
            // Without the switch, the server has no timings, like most passages on HLS Test.
            guard let item, item.canPlay, ProcessInfo.processInfo.arguments.contains("--precise-word-timings") else { respond(404); return }
            respond(200, json(FixtureContent.wordTimings(item)))
        case ("hls", 3):
            guard let item, item.canPlay else { respond(404); return }
            respondWithMedia(route[2], for: item)
        default: respond(404)
        }
    }

    private func respondToFeed(_ url: URL) {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func values(_ name: String) -> Set<String>? {
            query.first { $0.name == name }?.value.map { Set($0.split(separator: ",").map(String.init)) }
        }
        guard let kinds = values("kinds"), !kinds.isEmpty else { respond(422); return }
        let since = query.first { $0.name == "since_seq" }?.value.flatMap { Int64($0) } ?? 0
        let persons = values("persons"), parties = values("parties")
        let items = FixtureContent.feed.filter { item in
            item.seq > since && kinds.contains(item.kind)
                && persons?.contains(item.person) != false && parties?.contains(item.party) != false
        }
        let lastSeq = max(since, FixtureContent.feed.map(\.seq).max() ?? 0)
        respond(200, ["last_seq": lastSeq, "items": json(items)])
    }

    /// Items of a window of Paris days, newest first, paged on the id like the server.
    private func respondToHistory(_ url: URL) {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        func values(_ name: String) -> Set<String>? { value(name).map { Set($0.split(separator: ",").map(String.init)) } }
        guard let from = value("from").flatMap(ParisDay.date), let last = value("to").flatMap(ParisDay.date),
              let to = ParisDay.calendar.date(byAdding: .day, value: 1, to: last), from < to,
              to.timeIntervalSince(from) <= 31 * 86_400 + 3_600,
              let kinds = values("kinds"), !kinds.isEmpty else { respond(400); return }
        let limit = value("limit").flatMap { Int($0) } ?? 50
        let before = value("before_id").flatMap { Int64($0) } ?? .max
        let persons = values("persons"), parties = values("parties")
        let matches = FixtureContent.history.filter { item in
            guard let date = item.date else { return false }
            return date >= from && date < to && item.id < before && kinds.contains(item.kind)
                && persons?.contains(item.person) != false && parties?.contains(item.party) != false
        }.sorted { $0.id > $1.id }
        respond(200, ["items": json(Array(matches.prefix(limit))), "has_more": matches.count > limit])
    }

    /// Every kind counted per complete Paris day, oldest first, today left out.
    private func respondToDays(_ url: URL) {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func values(_ name: String) -> Set<String>? {
            query.first { $0.name == name }?.value.map { Set($0.split(separator: ",").map(String.init)) }
        }
        let count = query.first { $0.name == "days" }?.value.flatMap { Int($0) } ?? 7
        guard (1...31).contains(count) else { respond(400); return }
        let persons = values("persons"), parties = values("parties")
        let items = FixtureContent.history.filter { persons?.contains($0.person) != false && parties?.contains($0.party) != false }
        let days = ParisDay.days(count: count, before: Date()).map { day in
            let passages = items.filter { $0.date.map(ParisDay.string) == day }
            return DayCount(day: day, interventions: passages.filter { $0.kind == "intervention" }.count,
                            citations: passages.filter(\.isCitation).count, tweets: passages.filter(\.isTweet).count,
                            interventionSec: passages.filter { $0.kind == "intervention" }.reduce(0) { $0 + $1.durationSec })
        }
        respond(200, ["days": json(days)])
    }

    /// The media always starts at the passage; its program date tells the player where it sits in time.
    private func respondWithMedia(_ file: String, for item: FeedItem) {
        if file == "index.m3u8" {
            let segments = FixtureContent.segmentDurations.enumerated().map { index, duration in
                String(format: "#EXTINF:%.6f,\nfixture-audio-%02d.ts", duration, index)
            }
            let playlist = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-TARGETDURATION:3", "#EXT-X-MEDIA-SEQUENCE:0",
                            "#EXT-X-PLAYLIST-TYPE:VOD", "#EXT-X-PROGRAM-DATE-TIME:\(item.at)"] + segments + ["#EXT-X-ENDLIST"]
            respond(200, data: Data(playlist.joined(separator: "\n").utf8), type: "application/vnd.apple.mpegurl")
            return
        }
        let allowed = FixtureContent.segmentDurations.indices.contains { file == String(format: "fixture-audio-%02d.ts", $0) }
        guard allowed, let resource = Bundle.main.url(forResource: (file as NSString).deletingPathExtension, withExtension: "ts"),
              let data = try? Data(contentsOf: resource) else { respond(404); return }
        respond(200, data: data, type: "video/mp2t")
    }

    private func respondToKindsFixture(_ url: URL) {
        let content: [[String: Any]] = [(901, "intervention"), (902, "citation"), (903, "tweet")].map { id, kind in
            ["id": id, "seq": id, "at": APIDate.string(Date()), "kind": kind,
             "media": kind == "tweet" ? "x" : "radio", "channel": kind == "tweet" ? "X" : "Canal de test",
             "channel_key": kind == "tweet" ? "x" : "unknown_test_channel",
             "person": "Camille Test", "party": "TEST", "title": "Contenu \(kind)",
             "has_media": true, // Deliberately inconsistent for X: it still must not be played.
             "url": kind == "tweet" ? "https://x.com/i/status/123456789" : "",
             "verbatim": "Texte complet de la publication de test."]
        }
        if url.path == "/rest/v1/feed" {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let kinds = query.first(where: { $0.name == "kinds" })?.value, !kinds.isEmpty else { respond(422); return }
            // Any kind change must start at zero; otherwise older matching records are missed.
            let head = query.first(where: { $0.name == "since_seq" })?.value == "0"
            let allowed = Set(kinds.split(separator: ",").map(String.init))
            respond(200, ["last_seq": 1000, "items": head ? content.filter { allowed.contains($0["kind"] as! String) } : []])
        } else if url.path == "/rest/v1/sequences/903" {
            respond(200, content[2])
        } else if ["/rest/v1/persons", "/rest/v1/parties"].contains(url.path) {
            respond(200, [])
        } else { respond(404) }
    }

    private func bodyData() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    /// Encodes a model with its API field names, as a JSON object or array.
    private func json(_ value: some Encodable) -> Any {
        (try? JSONEncoder().encode(value)).flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? [:]
    }

    private func respond(_ status: Int, _ body: Any = [:]) {
        respond(status, data: (try? JSONSerialization.data(withJSONObject: body)) ?? Data(), type: "application/json")
    }

    private func respond(_ status: Int, data: Data, type: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": type])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
#endif
