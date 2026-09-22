import SwiftUI
import Observation

@MainActor @Observable
final class AppModel {
    enum Tab: Hashable { case feed, search, saved, account }
    var tab: Tab = .feed
    var session: Session?
    var isDemo = false
    var isRestoring = true
    var isLoggingIn = false
    var loginError: String?
    var quota: QuotaPrompt?
    var email: String
    var items: [FeedItem] = []
    var persons: [Person] = []
    var parties: [Party] = []
    var filters = SearchFilters()
    var draft = SearchFilters()
    var savedSearches: [SavedSearch] = []
    var isRefreshing = false
    var feedError: String?
    var choicesError: String?
    var lastRefresh: Date?
    var notice: String?
    enum WordTimingState { case loading, available, unavailable }
    private(set) var wordTimings: [Int64: SequenceWordTimings] = [:]
    private(set) var wordTimingStates: [Int64: WordTimingState] = [:]
    var isAuthenticated: Bool { isDemo || session != nil }
    var visibleItems: [FeedItem] { items.filter(filters.accepts) }
    var accountID: String { isDemo ? "local-demo" : session?.email.lowercased() ?? "" }
    let api: APIClient
    private let sessionStore: SessionStore
    private let remembersEmail: Bool
    private let restoresSession: Bool
    let player = PlaybackModel()
    private var lastSeq: Int64 = 0
    private var requestID = UUID()
    private let searches = SearchStore()
    @ObservationIgnored private var wordTimingTasks: [Int64: Task<Void, Never>] = [:]
    @ObservationIgnored private var wordTimingGeneration = UUID()

    init(api: APIClient = APIClient(), sessionStore: SessionStore = SessionStore(), remembersEmail: Bool = true, restoresSession: Bool = true) {
        self.api = api
        self.sessionStore = sessionStore
        self.remembersEmail = remembersEmail
        self.restoresSession = restoresSession
        email = remembersEmail ? UserDefaults.standard.string(forKey: "last-email") ?? "" : ""
    }

    struct QuotaPrompt: Identifiable {
        let id = UUID()
        let maximum: Int
        let devices: [DeviceInfo]
    }

    func restore() async {
        guard isRestoring else { return }
        if restoresSession, let saved = sessionStore.read(Session.self, account: "session") {
            // Swagger still declares `expires` without a unit; the server decides validity.
            if !saved.token.isEmpty {
                session = saved; email = saved.email
                loadSearches()
            } else { sessionStore.clearSession() }
        }
        isRestoring = false
        if ProcessInfo.processInfo.arguments.contains("--demo") { enterDemo() }
    }

    func login(password: String, replaceDevice: Int64? = nil) async {
        guard !isLoggingIn else { return }
        isLoggingIn = true; loginError = nil; quota = nil
        defer { isLoggingIn = false }
        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let request = LoginRequest(email: cleanEmail, password: password, deviceUid: try sessionStore.deviceID(),
                                       deviceName: UIDevice.current.model, deviceModel: "Apple \(UIDevice.current.model)", replaceDeviceId: replaceDevice)
            let result = try await api.login(request)
            try sessionStore.save(result, account: "session")
            session = result; email = result.email; isDemo = false
            if remembersEmail { UserDefaults.standard.set(result.email, forKey: "last-email") }
            loadSearches()
        } catch APIError.deviceQuota(let max, let devices) {
            quota = QuotaPrompt(maximum: max, devices: devices)
        } catch { loginError = message(for: error) }
    }

    func enterDemo() {
        resetContent()
        isDemo = true; session = nil; isRestoring = false
        items = DemoContent.feed(); persons = DemoContent.persons; parties = DemoContent.parties
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting"), ProcessInfo.processInfo.arguments.contains("--precise-word-timings") {
            for item in items { wordTimings[item.id] = DemoContent.wordTimingFixture(item); wordTimingStates[item.id] = .available }
        }
        #endif
        if ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--reset-demo") {
            searches.clear(account: "local-demo")
        }
        lastRefresh = Date(); loadSearches()
    }

    func logout(reason: String? = nil) {
        if !isDemo { sessionStore.clearSession() }
        session = nil; isDemo = false; resetContent(); loginError = reason
    }
    private func resetContent() {
        wordTimingGeneration = UUID()
        for task in wordTimingTasks.values { task.cancel() }
        wordTimingTasks = [:]; wordTimings = [:]; wordTimingStates = [:]
        requestID = UUID(); player.stop()
        items = []; persons = []; parties = []; savedSearches = []
        filters = SearchFilters(); draft = SearchFilters(); tab = .feed
        lastSeq = 0; lastRefresh = nil; feedError = nil; choicesError = nil
        isRefreshing = false; quota = nil; notice = nil
    }

    func refresh(reset: Bool = false) async {
        if isDemo { lastRefresh = Date(); return }
        guard let session else { return }
        let id = UUID(); requestID = id
        let criteria = filters
        isRefreshing = true
        defer { if requestID == id { isRefreshing = false } }
        do {
            let response = try await api.feed(token: session.token, filters: criteria, since: reset ? 0 : lastSeq)
            guard requestID == id, self.session?.token == session.token, !Task.isCancelled else { return }
            items = FeedMerge.merge(existing: reset ? [] : items, incoming: response.items)
            lastSeq = reset ? response.lastSeq : max(lastSeq, response.lastSeq)
            lastRefresh = Date(); feedError = nil
        } catch {
            guard requestID == id, !Task.isCancelled else { return }
            handleSessionError(error)
            if isAuthenticated { feedError = message(for: error) }
        }
    }
    func loadChoices() async {
        guard !isDemo, let token = session?.token else { return }
        do {
            async let people = api.persons(token: token)
            async let groups = api.parties(token: token)
            let result = try await (people, groups)
            guard session?.token == token, !Task.isCancelled else { return }
            persons = result.0; parties = result.1; choicesError = nil
        } catch {
            guard session?.token == token, !Task.isCancelled else { return }
            handleSessionError(error)
            choicesError = "Le référentiel n’a pas pu être chargé. \(message(for: error))"
        }
    }
    func apply(_ value: SearchFilters) async {
        let changed = value.persons != filters.persons || value.parties != filters.parties
        filters = value; draft = value; tab = .feed
        for index in savedSearches.indices where savedSearches[index].filters == value && !savedSearches[index].isArchived {
            savedSearches[index].lastUsedAt = Date()
        }
        persistSearches()
        if changed {
            requestID = UUID(); lastSeq = 0
            if !isDemo { items = [] }
            await refresh(reset: true)
        }
    }
    func newSearch() { draft = SearchFilters(); tab = .search }
    func saveSearch(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        savedSearches.insert(SavedSearch(name: name, filters: draft), at: 0)
        persistSearches()
    }
    func archive(_ search: SavedSearch) {
        guard let index = savedSearches.firstIndex(where: { $0.id == search.id }) else { return }
        savedSearches[index].archivedAt = search.isArchived ? nil : Date()
        persistSearches()
    }
    func delete(_ search: SavedSearch) { savedSearches.removeAll { $0.id == search.id }; persistSearches() }
    private func loadSearches() {
        do { savedSearches = try searches.load(account: accountID) }
        catch { savedSearches = []; notice = "Les recherches enregistrées n’ont pas pu être lues." }
    }
    private func persistSearches() {
        do { try searches.save(savedSearches, account: accountID) }
        catch { notice = "Impossible d’enregistrer vos recherches sur cet appareil." }
    }
    func sequence(_ item: FeedItem) async throws -> SequenceDetail {
        if isDemo { return DemoContent.detail(item) }
        guard let token = session?.token else { throw APIError.sessionExpired }
        do {
            let value = try await api.sequence(id: item.id, token: token)
            guard session?.token == token, !Task.isCancelled else { throw CancellationError() }
            if value.item.hasMedia, !value.verbatim.isEmpty { loadWordTimings(for: value.id) }
            return value
        } catch {
            if session?.token == token { handleSessionError(error) }
            throw error
        }
    }
    func loadWordTimings(for sequenceID: Int64, retry: Bool = false) {
        guard !isDemo, let token = session?.token, wordTimingTasks[sequenceID] == nil,
              retry || wordTimingStates[sequenceID] == nil else { return }
        let generation = wordTimingGeneration
        wordTimingStates[sequenceID] = .loading
        // Optional STT metadata must not hold up sequence display or HLS playback.
        wordTimingTasks[sequenceID] = Task { [weak self, api] in
            let response: Result<SequenceWordTimings?, Error>
            do { response = .success(try await api.wordTimings(id: sequenceID, token: token)) }
            catch { response = .failure(error) }
            guard let self, self.wordTimingGeneration == generation, self.session?.token == token,
                  !Task.isCancelled else { return }
            self.wordTimingTasks[sequenceID] = nil
            switch response {
            case .success(let timings):
                self.wordTimings[sequenceID] = timings
                self.wordTimingStates[sequenceID] = timings == nil ? .unavailable : .available
                if timings != nil { self.player.wordTimingsDidLoad(sequenceID: sequenceID) }
            case .failure(let error):
                self.wordTimingStates[sequenceID] = .unavailable
                self.handleSessionError(error)
            }
        }
    }
    func handleSessionError(_ error: Error) {
        if case APIError.sessionExpired = error { logout(reason: error.localizedDescription) }
    }
    func message(for error: Error) -> String {
        if error is URLError { return "Serveur injoignable. Vérifiez votre connexion puis réessayez." }
        return error.localizedDescription
    }
}
