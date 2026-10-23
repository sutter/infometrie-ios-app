import Foundation
import Testing
@testable import InfometrieCore

@Suite(.serialized)
struct CoreTests {
    private let fixture = #"{"id":42,"seq":101,"at":"2026-09-21T10:00:00Z","kind":"intervention","media":"radio","channel":"Radio Test","person":"Camille Martin","party":"DEMO-A","title":"Un passage","duration_sec":30,"has_media":true,"unknown":"ignored"}"#
    private func item() throws -> FeedItem { try JSONDecoder().decode(FeedItem.self, from: Data(fixture.utf8)) }

    @Test func summaryThatRepeatsTheTranscriptIsHidden() {
        let item = FeedItem(id: 1, at: "2026-10-01T10:00:00Z", kind: "intervention", media: "tv", channel: "TV Test",
                            person: "Camille Martin", party: "TEST", title: "Extrait")
        let verbatim = "Si je peux me permettre de vous répondre,\n\nil se trouve que moi j'ai mes enfants en lycée."
        func summary(_ resume: String) -> String? { SequenceDetail(item: item, resume: resume, verbatim: verbatim).summary }
        #expect(summary("Si je peux me permettre de vous répondre, il se trouve que moi j'ai mes enfants en lycée.") == nil)
        #expect(summary("Si je peux me permettre de vous répondre, il se trouve") == nil)
        #expect(summary("Si je peux me permettre de vous répondre, il se trouve…") == nil)
        #expect(summary("Si je peux me permettre de vous répondre, il se trouve que moi ...") == nil)
        #expect(summary("  ") == nil)
        #expect(summary("… il se trouve que moi j'ai mes enfants en lycée.") != nil, "Un extrait du milieu n’est pas le début du texte")
        #expect(summary("La députée défend l’école publique de Seine-Saint-Denis.") == "La députée défend l’école publique de Seine-Saint-Denis.")
    }

    @Test func decodeAPKContractAndDefaults() throws {
        let item = try item()
        #expect(item.id == 42)
        #expect(item.hasMedia)
        #expect(!item.video)
        #expect(item.show.isEmpty)
        #expect(item.durationLabel == "0:30")
        #expect(item.date != nil)
        let detail = try JSONDecoder().decode(SequenceDetail.self, from: Data(fixture.utf8))
        #expect(detail.id == 42)
        #expect(detail.verbatim.isEmpty)
        let data = Data(#"{"items":[],"last_seq":101}"#.utf8)
        #expect(try JSONDecoder().decode(FeedResponse.self, from: data).lastSeq == 101)
    }

    @Test func filtersIntersectPeopleAndPartiesAndAllowNoKinds() throws {
        var filters = SearchFilters()
        let item = try item()
        #expect(filters.accepts(item))
        filters.persons = ["Camille Martin"]
        filters.parties = ["DEMO-B"]
        #expect(!filters.accepts(item))
        filters.parties = ["DEMO-A"]
        #expect(filters.accepts(item))
        filters.interventions = false
        #expect(!filters.accepts(item))
        var citation = item; citation.kind = "citation"
        #expect(filters.accepts(citation))
        filters.citations = false
        filters.tweets = false
        #expect(!filters.hasKinds)
        #expect(!filters.accepts(citation))
    }

    @Test func mergeReplacesDuplicatesAndExpiresOldItems() throws {
        let now = try #require(APIDate.parse("2026-09-21T12:00:00Z"))
        let first = try item()
        var replacement = first; replacement.title = "Titre actualisé"; replacement.seq = 104
        var old = first; old = FeedItem(id: 9, seq: 90, at: "2026-09-19T12:00:00Z", kind: old.kind, media: old.media, channel: old.channel, person: old.person, party: old.party, title: old.title)
        let result = FeedMerge.merge(existing: [first, old], incoming: [replacement], now: now)
        #expect(result.count == 1)
        #expect(result.first?.title == "Titre actualisé")
    }

    /// `seq` is the polling cursor: shuffled by a backend restart, higher for a passage indexed late, 0 from /history.
    @Test func mergeOrdersByBroadcastTimeNotSeq() throws {
        let now = try #require(APIDate.parse("2026-10-23T12:00:00Z"))
        func passage(_ id: Int64, seq: Int64, at: String) -> FeedItem {
            FeedItem(id: id, seq: seq, at: at, kind: "intervention", media: "tv", channel: "TV", person: "Camille Martin", party: "", title: "")
        }
        let feed = [passage(1, seq: 900, at: "2026-10-23T01:07:00Z"), passage(2, seq: 100, at: "2026-10-23T08:22:00Z")]
        let late = passage(3, seq: 950, at: "2026-10-23T06:00:00Z")
        let history = passage(4, seq: 0, at: "2026-10-23T09:00:00+02:00") // 07:00Z: after 08:22Z as text, before it in time
        let result = FeedMerge.merge(existing: feed, incoming: [late, history], now: now)
        #expect(result.map(\.id) == [2, 4, 3, 1])
        #expect(FeedMerge.oldestFirst(result).map(\.id) == [1, 3, 4, 2])
    }

    /// The speaker already heads the card and the passage page, so a leading "(Name)" is dropped from the title.
    @Test func displayTitleDropsTheLeadingSpeakerOnly() {
        var item = FeedItem(id: 1, at: "2026-09-21T12:00:00Z", kind: "citation", media: "radio", channel: "Radio",
                            person: "Camille Martin", party: "", title: " (camille martin) Une journaliste résume le débat")
        #expect(item.displayTitle == "Une journaliste résume le débat")
        item.title = "Le débat selon (Camille Martin)"
        #expect(item.displayTitle == "Le débat selon (Camille Martin)")
    }

    @Test func feedParametersEncodeNamesAndOmitEmptyFilters() throws {
        let api = APIClient()
        var filters = SearchFilters(); filters.persons = ["Élodie D’Arcy", "Camille & Sam"]; filters.parties = ["DEMO-A"]
        let request = api.feedRequest(token: "unit-test-token", filters: filters, since: 12)
        let url = try #require(request.url)
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(values["persons"] == filters.persons.sorted().joined(separator: ","))
        #expect(values["parties"] == "DEMO-A")
        #expect(values["since_seq"] == "12")
        #expect(values["limit"] == "50")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer unit-test-token")
        let empty = api.feedRequest(token: "test", filters: SearchFilters(), since: 0)
        #expect(!(empty.url?.absoluteString.contains("persons=") ?? true))
    }

    @Test func loginEncodesDeviceReplacementWithoutRenamingContract() throws {
        let request = LoginRequest(email: "example@test.invalid", password: "fixture", deviceUid: "uuid", deviceName: "iPhone", deviceModel: "Apple iPhone", replaceDeviceId: 12)
        let value = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(value["device_uid"] as? String == "uuid")
        #expect(value["replace_device_id"] as? Int == 12)
        #expect(value["deviceName"] == nil)
    }

    @Test func savedSearchRoundTripRetainsFiltersAndArchive() throws {
        let original = SavedSearch(name: "Ma veille", filters: SearchFilters(persons: ["Camille Martin"], parties: ["DEMO-A"], interventions: true, citations: false), archivedAt: Date(timeIntervalSince1970: 100))
        let decoded = try JSONDecoder().decode(SavedSearch.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(decoded.isArchived)
    }

    @Test func savedSearchCriteriaNamePartiesAndSkipARepeatedName() {
        let parties = [Party(code: "DEMO-A", name: "Groupe de démonstration A")]
        let mixed = SearchFilters(persons: ["Sam Laurent", "Camille Martin"], parties: ["DEMO-B", "DEMO-A"])
        #expect(mixed.summary(parties: parties) == "Camille Martin · Sam Laurent · DEMO-B · Groupe de démonstration A")
        #expect(SearchFilters().summary() == "Tout le panel")
        let person = SearchFilters(persons: ["Camille Martin"])
        #expect(SavedSearch(name: " camille martin ", filters: person).criteria() == nil)
        #expect(SavedSearch(name: "Ma veille", filters: person).criteria() == "Camille Martin")
        #expect(SavedSearch(name: "Groupe A", filters: SearchFilters(parties: ["DEMO-A"])).criteria(parties: parties) == "Groupe de démonstration A")
    }

    @Test func suiviNamesComeFromTheirCriteriaAndTheJournalKindsDoNotChangeTheAudience() {
        let parties = [Party(code: "DEMO-B", name: "Groupe B")]
        let citations = SearchFilters(parties: ["DEMO-B"], interventions: false, citations: true, tweets: false)
        #expect(citations.suggestedName(parties: parties) == "Groupe B · Citations")
        #expect(SearchFilters(persons: ["Camille Martin"]).suggestedName() == "Camille Martin")
        #expect(SearchFilters(interventions: false, citations: false, tweets: true).suggestedName() == "Tout le panel · Publications X")
        #expect(SearchFilters().suggestedName() == "Tout le panel")
        #expect(SavedSearch(name: "Groupe B · Citations", filters: citations).criteria(parties: parties) == nil)

        let all = SearchFilters(persons: ["Camille Martin"])
        #expect(all.sameAudience(as: SearchFilters(persons: ["Camille Martin"], interventions: true, citations: false, tweets: false)))
        #expect(!all.sameAudience(as: SearchFilters(persons: ["Camille Martin"], parties: ["DEMO-B"])))
        #expect(!all.sameAudience(as: SearchFilters(persons: ["Alex Morgan"])))
    }

    @Test func savedSearchesRemainIsolatedBetweenAccounts() throws {
        let suite = "infometrie.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SearchStore(defaults: defaults)
        let saved = SavedSearch(name: "Compte A", filters: SearchFilters())
        try store.save([saved], account: " A@example.invalid ")
        #expect(try store.load(account: "a@example.invalid") == [saved])
        #expect(try store.load(account: "b@example.invalid").isEmpty)
        store.clear(account: "b@example.invalid")
        #expect(try store.load(account: "a@example.invalid").count == 1)
    }

    @Test func unreadableSuivisAreSetAsideBeforeTheNextSave() throws {
        let suite = "infometrie.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SearchStore(defaults: defaults)
        let key = "saved-searches." + Data("a@example.invalid".utf8).base64EncodedString()
        defaults.set(Data("not json".utf8), forKey: key)
        #expect(throws: (any Error).self) { try store.load(account: "a@example.invalid") }
        store.setAside(account: "a@example.invalid")
        try store.save([SavedSearch(name: "Camille Martin", filters: SearchFilters(persons: ["Camille Martin"]))], account: "a@example.invalid")
        #expect(defaults.data(forKey: "unreadable." + key) == Data("not json".utf8), "What was stored is kept aside, not overwritten")
        #expect(try store.load(account: "a@example.invalid").map(\.name) == ["Camille Martin"])
    }

    @Test func rewriteAllHLSResourcesAndPreserveTiming() throws {
        let base = URL(string: "https://hls-test.yacast.fr/rest/v1/hls/42/index.m3u8?margin=10")!
        let source = """
        #EXTM3U
        #EXT-X-KEY:METHOD=AES-128,URI="../key?id=1"
        #EXT-X-MAP:URI="init.mp4"
        #EXT-X-MEDIA:TYPE=AUDIO,URI="audio/index.m3u8"
        #EXT-X-PROGRAM-DATE-TIME:2026-09-21T10:00:00Z
        #EXTINF:5,
        segment.ts?q=2
        /media/absolute.ts
        """
        var urls: [URL] = []
        let result = try HLSManifest.rewrite(source, baseURL: base) { url in
            urls.append(url)
            return URL(string: "http://127.0.0.1:9999/resource/\(urls.count)")!
        }
        #expect(urls.count == 5)
        #expect(urls[0].absoluteString == "https://hls-test.yacast.fr/rest/v1/hls/key?id=1")
        #expect(urls.last?.path == "/media/absolute.ts")
        #expect(result.contains("#EXT-X-PROGRAM-DATE-TIME:2026-09-21T10:00:00Z"))
        #expect(result.contains("URI=\"http://127.0.0.1:9999/resource/1\""))
        #expect(!result.contains("segment.ts"))
    }

    @Test func foreignMediaCannotReceiveBearerToken() throws {
        let api = APIClient()
        let detail = SequenceDetail(item: try item(), resume: "", verbatim: "", playlist: "https://foreign.invalid/index.m3u8")
        #expect(throws: APIError.self) { try api.playlistURL(for: detail) }
        #expect(!APIClient.sameOrigin(URL(string: "http://hls-test.yacast.fr/x")!, APIClient.baseURL))
        #expect(!APIClient.sameOrigin(URL(string: "https://hls-test.yacast.fr:444/x")!, APIClient.baseURL))
        #expect(APIClient.sameOrigin(URL(string: "https://hls-test.yacast.fr:443/x")!, APIClient.baseURL))
    }

    @Test func playbackTimingHandlesMarginsAndSpeechBounds() throws {
        let item = try item()
        let start = try #require(item.date)
        let detail = SequenceDetail(item: item, resume: "", verbatim: "un deux trois quatre", playFrom: item.at, speechStart: item.at, speechDurationSec: 20)
        let clock = try #require(MediaClock(playFrom: item.at, margin: 10))
        let timeline = TranscriptTimeline(detail: detail)
        #expect(clock.position(at: start) == 10)
        #expect(MediaClock(playFrom: "", margin: 10) == nil)
        #expect(timeline.wordIndex(at: start.addingTimeInterval(10)) == 2)
        #expect(timeline.wordIndex(at: start.addingTimeInterval(-1)) == nil)
        #expect(timeline.wordIndex(at: start.addingTimeInterval(20)) == nil)
        #expect(APIDate.parse("2026-09-21T12:00:00.123+02:00") != nil)
    }

    @Test func sessionRevocationIsDifferentFromBadLogin() async throws {
        let client = mockClient(code: 401, body: "{}")
        do { let _ = try await client.feed(token: "test", filters: SearchFilters()); Issue.record("Expected session expiry") }
        catch APIError.sessionExpired { }
        catch { Issue.record("Wrong error: \(error)") }
        do { let _ = try await client.login(loginFixture()); Issue.record("Expected credentials failure") }
        catch APIError.invalidCredentials { }
        catch { Issue.record("Wrong error: \(error)") }
    }

    @Test func deviceQuotaIncludesReplacementChoices() async throws {
        // Live HLS Test returns a boolean `error`; it must not hide the device list.
        let client = mockClient(code: 409, body: #"{"error":true,"reason":"device quota reached","max_devices":2,"devices":[{"id":7,"name":"Ancien iPhone"}]}"#)
        do { let _ = try await client.login(loginFixture()); Issue.record("Expected device quota") }
        catch APIError.deviceQuota(let maximum, let devices) {
            #expect(maximum == 2); #expect(devices.first?.id == 7)
        } catch { Issue.record("Wrong error: \(error)") }
    }

    @Test func malformedSuccessDoesNotBecomeEmptyFeed() async throws {
        let client = mockClient(code: 200, body: #"{"unexpected":true}"#)
        do { let _ = try await client.feed(token: "test", filters: SearchFilters()); Issue.record("Expected invalid response") }
        catch APIError.invalidResponse { }
        catch { Issue.record("Wrong error: \(error)") }
    }

    @Test func malformedDeviceQuotaDoesNotInventAZeroLimit() async throws {
        let client = mockClient(code: 409, body: #"{"error":true,"reason":"device quota reached"}"#)
        do { let _ = try await client.login(loginFixture()); Issue.record("Expected invalid response") }
        catch APIError.invalidResponse { }
        catch { Issue.record("Wrong error: \(error)") }
    }

    private func loginFixture() -> LoginRequest {
        LoginRequest(email: "example@test.invalid", password: "fixture", deviceUid: "id", deviceName: "iPhone", deviceModel: "Apple")
    }
    private func mockClient(code: Int, body: String) -> APIClient {
        StubProtocol.status = code; StubProtocol.body = Data(body.utf8)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubProtocol.self]
        return APIClient(session: URLSession(configuration: config))
    }
}

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    // All consumers run in a serialized suite, with one awaited request at a time.
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
