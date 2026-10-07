import Foundation
import Testing
@testable import InfometrieCore

@Suite(.serialized)
struct CoreTests {
    private let fixture = #"{"id":42,"seq":101,"at":"2026-09-21T10:00:00Z","kind":"intervention","media":"radio","channel":"Radio Test","person":"Camille Martin","party":"DEMO-A","title":"Un passage","duration_sec":30,"has_media":true,"unknown":"ignored"}"#
    private func item() throws -> FeedItem { try JSONDecoder().decode(FeedItem.self, from: Data(fixture.utf8)) }

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
