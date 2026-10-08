import Foundation

enum APIError: Error, LocalizedError, Sendable {
    case invalidCredentials, inactiveSubscription, sessionExpired
    case deviceQuota(Int, [DeviceInfo])
    case server(Int), invalidResponse, untrustedMedia, notFound, historyUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Email ou mot de passe invalide."
        case .inactiveSubscription: "Votre abonnement n’est pas actif. Gérez votre compte sur le portail web InfoMétrie."
        case .sessionExpired: "Session terminée : appareil révoqué ou abonnement inactif. Reconnectez-vous."
        case .deviceQuota: "La limite d’appareils de votre compte est atteinte."
        case .server(let code): "Le serveur est momentanément indisponible (\(code)). Réessayez."
        case .invalidResponse: "La réponse du serveur est invalide. Réessayez."
        case .untrustedMedia: "L’adresse de ce média n’est pas autorisée."
        case .notFound: "Le contenu demandé n’est plus disponible."
        case .historyUnavailable: "L’historique est momentanément indisponible. Réessayez."
        }
    }
}

final class APIClient: @unchecked Sendable {
    static let baseURL = URL(string: "https://hls-test.yacast.fr")!
    /// `/feed` serves at most this many of the newest passages; older ones come from `/history`.
    static let feedLimit = 50
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIClient.baseURL, session: URLSession? = nil) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.urlCache = nil
        self.session = session ?? URLSession(configuration: config, delegate: SameOriginRedirectDelegate(), delegateQueue: nil)
    }
    /// A copy of the JSON transport, so media requests reach the same server as the API.
    var transportConfiguration: URLSessionConfiguration { session.configuration }
    func request(path: String, token: String? = nil, query: [URLQueryItem] = []) -> URLRequest {
        var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { parts.queryItems = query }
        var request = URLRequest(url: parts.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }
    func login(_ login: LoginRequest) async throws -> Session {
        var request = request(path: "rest/v1/auth/login")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(login)
        let result: Session = try await send(request, isLogin: true)
        guard !result.token.isEmpty, !result.email.isEmpty else { throw APIError.invalidResponse }
        return result
    }
    func feedRequest(token: String, filters: SearchFilters, since: Int64) -> URLRequest {
        var query = [URLQueryItem(name: "since_seq", value: String(since)), URLQueryItem(name: "limit", value: String(Self.feedLimit))]
        query.append(.init(name: "kinds", value: filters.selectedKinds.joined(separator: ",")))
        return request(path: "rest/v1/feed", token: token, query: query + audienceQuery(filters))
    }
    private func audienceQuery(_ filters: SearchFilters) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        if !filters.persons.isEmpty { query.append(.init(name: "persons", value: filters.persons.sorted().joined(separator: ","))) }
        if !filters.parties.isEmpty { query.append(.init(name: "parties", value: filters.parties.sorted().joined(separator: ","))) }
        return query
    }
    func feed(token: String, filters: SearchFilters, since: Int64 = 0) async throws -> FeedResponse {
        guard filters.hasKinds else { return FeedResponse(items: [], lastSeq: since) }
        return try await send(feedRequest(token: token, filters: filters, since: since))
    }
    /// Items of the Paris days `from` to `to`, both included, newest first; `beforeID` asks for the next page.
    /// Without bounds, the server's window is the last 24 hours: Live's.
    func history(token: String, filters: SearchFilters, from: String? = nil, to: String? = nil, beforeID: Int64? = nil, limit: Int = 50) async throws -> HistoryResponse {
        guard filters.hasKinds else { return HistoryResponse() }
        var query: [URLQueryItem] = []
        if let from { query.append(.init(name: "from", value: from)) }
        if let to { query.append(.init(name: "to", value: to)) }
        query += [URLQueryItem(name: "kinds", value: filters.selectedKinds.joined(separator: ",")),
                  URLQueryItem(name: "limit", value: String(limit))]
        if let beforeID { query.append(.init(name: "before_id", value: String(beforeID))) }
        return try await historySend(request(path: "rest/v1/history", token: token, query: query + audienceQuery(filters)))
    }
    /// Counts of the last `count` complete Paris days. The route takes no `kinds`: every kind is counted.
    func days(token: String, filters: SearchFilters, count: Int) async throws -> DaysResponse {
        let query = [URLQueryItem(name: "days", value: String(count))] + audienceQuery(filters)
        return try await historySend(request(path: "rest/v1/days", token: token, query: query))
    }
    /// Activity of one person of the panel; 404 means the person is not in the panel.
    func profile(token: String, person: String, days: Int) async throws -> PersonProfile {
        let query = [URLQueryItem(name: "person", value: person), URLQueryItem(name: "days", value: String(days))]
        return try await historySend(request(path: "rest/v1/profile", token: token, query: query))
    }
    private func historySend<T: Decodable>(_ request: URLRequest) async throws -> T {
        do { return try await send(request) }
        catch APIError.server(503) { throw APIError.historyUnavailable }
    }
    func persons(token: String) async throws -> [Person] { try await send(request(path: "rest/v1/persons", token: token)) }
    func parties(token: String) async throws -> [Party] { try await send(request(path: "rest/v1/parties", token: token)) }
    func sequence(id: Int64, token: String) async throws -> SequenceDetail {
        try await send(request(path: "rest/v1/sequences/\(id)", token: token))
    }
    func wordTimings(id: Int64, token: String) async throws -> SequenceWordTimings? {
        do {
            let result: SequenceWordTimings = try await send(request(path: "rest/v1/sequences/\(id)/words", token: token))
            guard result.sequence == id, APIDate.parse(result.origin) != nil else { throw APIError.invalidResponse }
            return result
        } catch APIError.notFound { return nil }
        catch APIError.server(502) { return nil }
    }
    func playlistURL(for detail: SequenceDetail, margin: Int = 0) throws -> URL {
        let path = detail.playlist.isEmpty ? "/rest/v1/hls/\(detail.id)/index.m3u8" : detail.playlist
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              Self.sameOrigin(url, baseURL) else { throw APIError.untrustedMedia }
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw APIError.untrustedMedia }
        parts.queryItems = (parts.queryItems ?? []).filter { $0.name != "margin" }
            + [.init(name: "margin", value: String(max(0, min(60, margin))))]
        guard let result = parts.url else { throw APIError.untrustedMedia }
        return result
    }
    static func sameOrigin(_ a: URL, _ b: URL) -> Bool {
        a.scheme?.lowercased() == b.scheme?.lowercased() && a.host?.lowercased() == b.host?.lowercased()
            && (a.port ?? 443) == (b.port ?? 443) && a.user == nil && a.password == nil
    }
    private func send<T: Decodable>(_ request: URLRequest, isLogin: Bool = false) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw isLogin ? APIError.invalidCredentials : APIError.sessionExpired
        case 403: throw isLogin ? APIError.inactiveSubscription : APIError.sessionExpired
        case 404: throw APIError.notFound
        case 409 where isLogin:
            guard let body = try? JSONDecoder().decode(DeviceQuotaResponse.self, from: data),
                  body.maxDevices >= 0 else { throw APIError.invalidResponse }
            throw APIError.deviceQuota(body.maxDevices, body.devices)
        default: throw APIError.server(http.statusCode)
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.invalidResponse }
    }
}
