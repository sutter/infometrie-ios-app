import SwiftUI
import Observation

@MainActor @Observable
final class AppModel {
    enum Tab: Hashable { case feed, saved, account }
    var tab: Tab = .feed
    var isSearchPresented = false
    /// Changing it rebuilds the journal's navigation stack, which pops it back to the feed.
    private(set) var feedStackID = UUID()
    var session: Session?
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
    /// Passages already opened or listened to, with the time they were seen (stored on the device).
    private(set) var seen: [Int64: Date] = [:]
    var isRefreshing = false
    /// Live (the last 24 hours, polled) or the last 7 or 30 complete Paris days (`/history`, `/days`).
    private(set) var period: FeedPeriod = .live
    /// One day of the period chosen on the chart; nil shows the whole period.
    private(set) var selectedDay: String?
    /// The Paris days the period covers, oldest first.
    private(set) var historyDays: [String] = []
    private(set) var historyItems: [FeedItem] = []
    private(set) var historyHasMore = false
    private(set) var dayCounts: [DayCount] = []
    private(set) var isLoadingHistory = false
    private(set) var isLoadingMoreHistory = false
    var feedError: String?
    var choicesError: String?
    var lastRefresh: Date?
    var notice: String?
    enum WordTimingState { case loading, available, unavailable, failed }
    private(set) var wordTimings: [Int64: SequenceWordTimings] = [:]
    private(set) var wordTimingStates: [Int64: WordTimingState] = [:]
    var isAuthenticated: Bool { session != nil }
    var visibleItems: [FeedItem] { (period.isLive ? items : historyItems).filter(filters.accepts) }
    /// The first page of the current period is on its way.
    var isLoadingPassages: Bool { period.isLive ? isRefreshing : isLoadingHistory }
    var accountID: String { session?.email.lowercased() ?? "" }
    let api: APIClient
    private let sessionStore: SessionStore
    private let remembersEmail: Bool
    private let restoresSession: Bool
    let player = PlaybackModel()
    private var lastSeq: Int64 = 0
    private var requestID = UUID()
    /// History has its own guard: its items carry `seq` 0 and must never touch the live cursor.
    private var historyRequestID = UUID()
    private let searches = SearchStore()
    private let seenStore = SeenStore()
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
            session = result; email = result.email
            if remembersEmail { UserDefaults.standard.set(result.email, forKey: "last-email") }
            loadSearches()
        } catch APIError.deviceQuota(let max, let devices) {
            quota = QuotaPrompt(maximum: max, devices: devices)
        } catch { loginError = message(for: error) }
    }

    func logout(reason: String? = nil) {
        sessionStore.clearSession()
        session = nil; resetContent(); loginError = reason
    }
    private func resetContent() {
        wordTimingGeneration = UUID()
        for task in wordTimingTasks.values { task.cancel() }
        wordTimingTasks = [:]; wordTimings = [:]; wordTimingStates = [:]
        requestID = UUID(); player.stop()
        items = []; persons = []; parties = []; savedSearches = []; seen = [:]
        filters = SearchFilters(); draft = SearchFilters(); tab = .feed; isSearchPresented = false
        lastSeq = 0; lastRefresh = nil; feedError = nil; choicesError = nil
        resetHistory(); period = .live; selectedDay = nil
        isRefreshing = false; quota = nil; notice = nil
    }

    func refresh(reset: Bool = false) async {
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
        guard let token = session?.token else { return }
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
        let changed = value != filters
        filters = value; draft = value; tab = .feed; isSearchPresented = false
        for index in savedSearches.indices where savedSearches[index].filters == value && !savedSearches[index].isArchived {
            savedSearches[index].lastUsedAt = Date()
        }
        persistSearches()
        if changed {
            requestID = UUID(); lastSeq = 0; items = []
            if period.isLive { await refresh(reset: true) } else { await reloadHistory() }
        }
    }

    // MARK: Periods

    func selectPeriod(_ value: FeedPeriod) async {
        guard value != period else { return }
        period = value; selectedDay = nil; feedError = nil
        if value.isLive {
            resetHistory()
            await refresh(reset: items.isEmpty)
        } else { await reloadHistory() }
    }
    /// Shows one day of the period, or the whole period with nil.
    func selectDay(_ day: String?) async {
        guard !period.isLive, day != selectedDay, day.map(historyDays.contains) ?? true else { return }
        selectedDay = day
        let id = UUID(); historyRequestID = id
        historyItems = []; historyHasMore = false; isLoadingMoreHistory = false; feedError = nil
        await loadHistoryPage(id: id)
    }
    /// Pull to refresh: the live cursor from zero, or the period's counts and first page again.
    func reload() async {
        if period.isLive { await refresh(reset: true) } else { await reloadHistory() }
    }
    /// Back in the foreground: a 7 or 30 day period moves on once a new day has started in Paris.
    func reloadHistoryIfDayChanged(now: Date = Date()) async {
        guard !period.isLive, period.days(before: now) != historyDays else { return }
        await reloadHistory(now: now)
    }
    func reloadHistory(now: Date = Date()) async {
        guard let session, !period.isLive else { return }
        let id = UUID(); historyRequestID = id
        let criteria = filters, span = period
        historyDays = span.days(before: now)
        if let day = selectedDay, !historyDays.contains(day) { selectedDay = nil }
        dayCounts = []; historyItems = []; historyHasMore = false; isLoadingMoreHistory = false; feedError = nil
        async let counts = api.days(token: session.token, filters: criteria, count: span.rawValue)
        async let page: Void = loadHistoryPage(id: id)
        do {
            let result = try await counts
            guard historyRequestID == id, self.session?.token == session.token, !Task.isCancelled else { await page; return }
            dayCounts = result.days
        } catch {
            if historyRequestID == id, !Task.isCancelled { failHistory(error) }
        }
        await page
    }
    /// The next page of the period or day, once the list reaches its end.
    func loadMoreHistory() async {
        guard let session, !period.isLive, historyHasMore, !isLoadingHistory, !isLoadingMoreHistory,
              let last = historyItems.last, let window = historyWindow else { return }
        let id = historyRequestID, criteria = filters
        isLoadingMoreHistory = true
        defer { if historyRequestID == id { isLoadingMoreHistory = false } }
        do {
            let result = try await api.history(token: session.token, filters: criteria, from: window.from, to: window.to, beforeID: last.id)
            guard historyRequestID == id, self.session?.token == session.token, !Task.isCancelled else { return }
            let known = Set(historyItems.map(\.id))
            historyItems += result.items.filter { !known.contains($0.id) }
            historyHasMore = result.hasMore && !result.items.isEmpty
        } catch {
            if historyRequestID == id, !Task.isCancelled { failHistory(error) }
        }
    }
    private var historyWindow: (from: String, to: String)? {
        if let selectedDay { return (selectedDay, selectedDay) }
        guard let first = historyDays.first, let last = historyDays.last else { return nil }
        return (first, last)
    }
    private func loadHistoryPage(id: UUID) async {
        guard let session, let window = historyWindow else { return }
        let criteria = filters
        isLoadingHistory = true
        defer { if historyRequestID == id { isLoadingHistory = false } }
        do {
            let result = try await api.history(token: session.token, filters: criteria, from: window.from, to: window.to)
            guard historyRequestID == id, self.session?.token == session.token, !Task.isCancelled else { return }
            historyItems = result.items; historyHasMore = result.hasMore; lastRefresh = Date()
        } catch {
            if historyRequestID == id, !Task.isCancelled { failHistory(error) }
        }
    }
    private func failHistory(_ error: Error) {
        handleSessionError(error)
        if isAuthenticated { feedError = message(for: error) }
    }
    private func resetHistory() {
        historyRequestID = UUID()
        historyDays = []; historyItems = []; historyHasMore = false; dayCounts = []
        isLoadingHistory = false; isLoadingMoreHistory = false
    }
    func returnToFeedRoot() { feedStackID = UUID(); tab = .feed }
    func openSearch(_ value: SearchFilters) {
        draft = value
        if !draft.hasKinds { draft.selectKind(0) }
        isSearchPresented = true
    }
    func newSearch() { openSearch(SearchFilters()) }
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
        catch { savedSearches = []; notice = "Les suivis enregistrés n’ont pas pu être lus." }
        seen = seenStore.load(account: accountID)
    }
    func isSeen(_ item: FeedItem) -> Bool { seen[item.id] != nil }
    /// Called when a passage page opens or a passage plays in "Tout écouter".
    func markSeen(_ item: FeedItem) {
        guard seen[item.id] == nil, !accountID.isEmpty else { return }
        seen[item.id] = Date()
        seenStore.save(seen, account: accountID)
    }
    func toggleSeen(_ item: FeedItem) {
        guard !accountID.isEmpty else { return }
        seen[item.id] = isSeen(item) ? nil : Date()
        seenStore.save(seen, account: accountID)
    }
    private func persistSearches() {
        do { try searches.save(savedSearches, account: accountID) }
        catch { notice = "Impossible d’enregistrer vos suivis sur cet appareil." }
    }
    func sequence(_ item: FeedItem) async throws -> SequenceDetail {
        guard let token = session?.token else { throw APIError.sessionExpired }
        do {
            let value = try await api.sequence(id: item.id, token: token)
            guard session?.token == token, !Task.isCancelled else { throw CancellationError() }
            if value.item.canPlay, !value.verbatim.isEmpty { loadWordTimings(for: value.id) }
            return value
        } catch {
            if session?.token == token { handleSessionError(error) }
            throw error
        }
    }
    func loadWordTimings(for sequenceID: Int64, retry: Bool = false) {
        guard let token = session?.token, wordTimingTasks[sequenceID] == nil,
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
                self.wordTimingStates[sequenceID] = .failed
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
