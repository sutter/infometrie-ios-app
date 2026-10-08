import Foundation
import Testing
@testable import InfometrieCore

@Suite(.serialized)
struct SwaggerContractTests {
    private let sequence = #"{"id":42,"seq":108,"at":"2026-09-21T10:00:00Z","kind":"intervention","media":"radio","channel":"Radio Test","person":"Camille Martin","party":"TEST","title":"Extrait","duration_sec":18,"has_media":true,"verbatim":"Un passage avec quatre mots.","play_from":"2026-09-21T10:00:00Z","speech_start":"2026-09-21T10:00:02Z","speech_duration_sec":12,"playlist":"/rest/v1/hls/42/index.m3u8"}"#
    private let timings = #"{"sequence":42,"origin":"2026-09-21T10:00:00Z","sentences":[{"text":"Un passage avec quatre mots.","start_ms":2000,"end_ms":11500,"words":[{"text":"Un","start_ms":2000,"end_ms":2300},{"text":"passage","start_ms":4000,"end_ms":4600},{"text":"avec","start_ms":5500,"end_ms":5800},{"text":"quatre","start_ms":9000,"end_ms":9500},{"text":"mots.","start_ms":11000,"end_ms":11500}]}]}"#

    @Test func mobileLoginUsesDocumentedRouteJSONAnd201Response() async throws {
        let client = client(routes: ["/rest/v1/auth/login": (201, #"{"token":"fixture-jwt","expires":1790013600,"device_id":7,"email":"client@example.invalid","fullname":"Client Test","organisation":"Test"}"#)])
        let session = try await client.login(LoginRequest(email: "client@example.invalid", password: "fixture-password", deviceUid: "stable-install-id", deviceName: "iPhone", deviceModel: "Apple iPhone", replaceDeviceId: 6))
        #expect(session.deviceId == 7)
        #expect(session.expires == 1790013600)
        let request = try #require(ContractProtocol.requests.first)
        #expect(request.url?.path == "/rest/v1/auth/login")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["device_uid"] as? String == "stable-install-id")
        #expect(body["replace_device_id"] as? Int == 6)
        #expect(body["email"] as? String == "client@example.invalid")
    }

    @Test func authenticatedFeedReferencesDetailAndWordsUseTheSameMobileContract() async throws {
        let client = client(routes: [
            "/rest/v1/feed": (200, "{\"items\":[\(sequence)],\"last_seq\":108}"),
            "/rest/v1/persons": (200, #"[{"name":"Camille Martin","party":"TEST","role":"Invitée"}]"#),
            "/rest/v1/parties": (200, #"[{"code":"TEST","name":"Groupe Test"}]"#),
            "/rest/v1/sequences/42": (200, sequence),
            "/rest/v1/sequences/42/words": (200, timings)
        ])
        let feed = try await client.feed(token: "fixture-jwt", filters: SearchFilters(persons: ["Camille Martin"], parties: ["TEST"]), since: 77)
        #expect(feed.lastSeq == 108)
        #expect(feed.items.first?.id == 42)
        #expect(try await client.persons(token: "fixture-jwt").first?.name == "Camille Martin")
        #expect(try await client.parties(token: "fixture-jwt").first?.code == "TEST")
        let detail = try await client.sequence(id: 42, token: "fixture-jwt")
        let words = try #require(await client.wordTimings(id: 42, token: "fixture-jwt"))
        let timeline = TranscriptTimeline(detail: detail, timings: words)
        #expect(timeline.hasPreciseTimings)
        let origin = try #require(APIDate.parse(words.origin))
        let target = try #require(timeline.instant(forWord: 2))
        #expect(abs(target.timeIntervalSince(origin) - 5.501) < 0.0001)
        #expect(ContractProtocol.requests.count == 5)
        #expect(ContractProtocol.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-jwt" })
        let request = try #require(ContractProtocol.requests.first?.url)
        let query = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(.init(name: "since_seq", value: "77")))
        #expect(query.contains(.init(name: "persons", value: "Camille Martin")))
    }

    @Test func documentedTimingFallbackDoesNotPreventPlayback() async throws {
        for code in [404, 502] {
            let client = client(routes: ["/rest/v1/sequences/42/words": (code, "{}")])
            #expect(try await client.wordTimings(id: 42, token: "fixture-jwt") == nil)
        }
    }

    @Test func timingAuthenticationFailuresStillRevokeTheSession() async {
        for code in [401, 403] {
            let client = client(routes: ["/rest/v1/sequences/42/words": (code, "{}")])
            do { _ = try await client.wordTimings(id: 42, token: "fixture-jwt"); Issue.record("Expected session expiry") }
            catch APIError.sessionExpired { }
            catch { Issue.record("Wrong error: \(error)") }
        }
    }

    @Test func unrelatedOrMalformedTimingResponsesAreNotAccepted() async {
        for body in ["{}", timings.replacingOccurrences(of: "\"sequence\":42", with: "\"sequence\":99"), timings.replacingOccurrences(of: "2026-09-21T10:00:00Z", with: "not-a-date")] {
            let client = client(routes: ["/rest/v1/sequences/42/words": (200, body)])
            do { _ = try await client.wordTimings(id: 42, token: "fixture-jwt"); Issue.record("Expected invalid response") }
            catch APIError.invalidResponse { }
            catch { Issue.record("Wrong error: \(error)") }
        }
    }

    @Test func sequence404HasAUsefulErrorInsteadOfAServerOutage() async {
        let client = client(routes: ["/rest/v1/sequences/42": (404, "{}")])
        do { _ = try await client.sequence(id: 42, token: "fixture-jwt"); Issue.record("Expected unavailable sequence") }
        catch APIError.notFound { }
        catch { Issue.record("Wrong error: \(error)") }
    }

    @Test func historyAndDaysSendTheDocumentedParameters() async throws {
        let client = client(routes: [
            "/rest/v1/history": (200, "{\"items\":[\(sequence.replacingOccurrences(of: "\"seq\":108", with: "\"seq\":0"))],\"has_more\":true}"),
            "/rest/v1/days": (200, #"{"days":[{"day":"2026-10-06","interventions":2,"citations":40,"tweets":5,"intervention_sec":310},{"day":"2026-10-07"}]}"#)
        ])
        let filters = SearchFilters(persons: ["Sam Laurent", "Camille Martin"], parties: ["TEST"], interventions: true, citations: true, tweets: false)
        let page = try await client.history(token: "fixture-jwt", filters: filters, from: "2026-10-01", to: "2026-10-07", beforeID: 42)
        #expect(page.hasMore)
        #expect(page.items.first?.id == 42)
        #expect(page.items.first?.seq == 0)
        let days = try await client.days(token: "fixture-jwt", filters: filters, count: 7).days
        #expect(days.map(\.day) == ["2026-10-06", "2026-10-07"])
        #expect(days[0].citations == 40 && days[0].interventionSec == 310)
        #expect(days[1].interventions == 0 && days[1].tweets == 0)
        #expect(ContractProtocol.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-jwt" })
        let history = query(of: ContractProtocol.requests[0])
        #expect(ContractProtocol.requests[0].url?.path == "/rest/v1/history")
        #expect(history["from"] == "2026-10-01")
        #expect(history["to"] == "2026-10-07")
        #expect(history["kinds"] == "intervention,citation")
        #expect(history["persons"] == "Camille Martin,Sam Laurent")
        #expect(history["parties"] == "TEST")
        #expect(history["before_id"] == "42")
        #expect(history["limit"] == "50")
        let count = query(of: ContractProtocol.requests[1])
        #expect(ContractProtocol.requests[1].url?.path == "/rest/v1/days")
        #expect(count["days"] == "7")
        #expect(count["kinds"] == nil)
        #expect(count["persons"] == "Camille Martin,Sam Laurent")
    }

    @Test func historyWithoutKindsSendsNothingAndMissingFieldsDecode() async throws {
        let client = client(routes: ["/rest/v1/history": (200, "{}")])
        let none = SearchFilters(interventions: false, citations: false, tweets: false)
        #expect(try await client.history(token: "fixture-jwt", filters: none, from: "2026-10-01", to: "2026-10-07").items.isEmpty)
        #expect(ContractProtocol.requests.isEmpty)
        let page = try await client.history(token: "fixture-jwt", filters: SearchFilters(), from: "2026-10-01", to: "2026-10-07")
        #expect(page.items.isEmpty && !page.hasMore)
        #expect(query(of: ContractProtocol.requests[0])["before_id"] == nil)
    }

    @Test func historyOutageHasItsOwnMessage() async {
        for path in ["/rest/v1/history", "/rest/v1/days"] {
            let client = client(routes: [path: (503, "{}")])
            do {
                if path.hasSuffix("days") { _ = try await client.days(token: "fixture-jwt", filters: SearchFilters(), count: 30) }
                else { _ = try await client.history(token: "fixture-jwt", filters: SearchFilters(), from: "2026-09-08", to: "2026-10-07") }
                Issue.record("Expected history outage")
            } catch APIError.historyUnavailable {
                #expect(APIError.historyUnavailable.errorDescription?.contains("historique") == true)
            } catch { Issue.record("Wrong error: \(error)") }
        }
        let client = client(routes: ["/rest/v1/days": (401, "{}")])
        do { _ = try await client.days(token: "fixture-jwt", filters: SearchFilters(), count: 7); Issue.record("Expected session expiry") }
        catch APIError.sessionExpired { }
        catch { Issue.record("Wrong error: \(error)") }
    }

    @Test func profileDecodesTheRealAnswerShape() async throws {
        let body = #"{"person":{"name":"Camille Martin","role":"Personnalité fictive","party":"TEST"},"totals":{"interventions":440,"intervention_sec":14869,"citations":147,"tweets":0},"days":[{"day":"2026-10-01","interventions":108,"citations":7,"tweets":0,"intervention_sec":3460}],"top_channels":[{"channel":"Radio Test","channel_key":"radio_test","interventions":354,"intervention_sec":11973}]}"#
        let client = client(routes: ["/rest/v1/profile": (200, body)])
        let profile = try await client.profile(token: "fixture-jwt", person: "Camille Martin", days: 7)
        #expect(profile.person.name == "Camille Martin" && profile.person.party == "TEST")
        #expect(profile.totals.interventions == 440 && profile.totals.interventionSec == 14869 && profile.totals.citations == 147)
        #expect(profile.days.first?.interventionSec == 3460)
        #expect(profile.topChannels.first?.channelKey == "radio_test" && profile.topChannels.first?.interventions == 354)
        let sent = query(of: ContractProtocol.requests[0])
        #expect(ContractProtocol.requests[0].url?.path == "/rest/v1/profile")
        #expect(sent["person"] == "Camille Martin" && sent["days"] == "7")
        #expect(ContractProtocol.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer fixture-jwt")
        let sparse = self.client(routes: ["/rest/v1/profile": (200, #"{"person":{"name":"Camille Martin"}}"#)])
        let empty = try await sparse.profile(token: "fixture-jwt", person: "Camille Martin", days: 30)
        #expect(empty.days.isEmpty && empty.topChannels.isEmpty && empty.totals.interventions == 0)
    }

    @Test func profileOfAPersonOutsideThePanelIsNotFound() async {
        let client = client(routes: ["/rest/v1/profile": (404, #"{"error":true,"reason":"Unknown person"}"#)])
        do { _ = try await client.profile(token: "fixture-jwt", person: "Inconnu", days: 7); Issue.record("Expected not found") }
        catch APIError.notFound { }
        catch { Issue.record("Wrong error: \(error)") }
    }

    @Test func spokenDurationsReadNaturally() {
        #expect(SpokenDuration.label(seconds: 45) == "45 s")
        #expect(SpokenDuration.label(seconds: 720) == "12 min")
        #expect(SpokenDuration.label(seconds: 14869) == "4 h 07")
        #expect(SpokenDuration.label(seconds: -3) == "0 s")
    }

    private func query(of request: URLRequest) -> [String: String] {
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    @Test func playlistMarginsRespectSwaggerBoundsAndKeepOtherQueryItems() throws {
        let item = try JSONDecoder().decode(FeedItem.self, from: Data(sequence.utf8))
        let detail = SequenceDetail(item: item, resume: "", verbatim: "", playlist: "/rest/v1/hls/42/index.m3u8?fixture=1&margin=30")
        let client = APIClient()
        for (requested, expected) in [(-10, "0"), (0, "0"), (10, "10"), (90, "60")] {
            let url = try client.playlistURL(for: detail, margin: requested)
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(url.host == "hls-test.yacast.fr")
            #expect(query.filter { $0.name == "margin" }.count == 1)
            #expect(query.contains(.init(name: "margin", value: expected)))
            #expect(query.contains(.init(name: "fixture", value: "1")))
        }
    }

    private func client(routes: [String: (Int, String)]) -> APIClient {
        ContractProtocol.routes = routes; ContractProtocol.requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ContractProtocol.self]
        return APIClient(session: URLSession(configuration: config))
    }
}

private final class ContractProtocol: URLProtocol, @unchecked Sendable {
    // Confined to this serialized suite; each request is fully awaited before the next.
    nonisolated(unsafe) static var routes: [String: (Int, String)] = [:]
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 1024), data = Data()
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                guard count > 0 else { break }
                data.append(contentsOf: bytes.prefix(count))
            }
            captured.httpBody = data
        }
        Self.requests.append(captured)
        let (status, body) = Self.routes[request.url!.path] ?? (500, "{}")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
