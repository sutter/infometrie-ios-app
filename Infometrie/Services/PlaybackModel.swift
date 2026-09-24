import AVFoundation
import Observation

@MainActor @Observable
final class PlaybackModel {
    @ObservationIgnored let player = AVPlayer()
    var queue: [FeedItem] = []
    var index = 0
    var detail: SequenceDetail?
    var isPodcast = false
    var isLoading = false
    var isPlaying = false
    var isScrubbing = false
    var ended = false
    var error: String?
    var position: Double = 0
    var duration: Double = 0
    var instant: Date?
    var transcriptNotice: String?
    var current: FeedItem? { queue.indices.contains(index) ? queue[index] : nil }
    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool { index + 1 < queue.count }
    @ObservationIgnored private var relay: HLSRelay?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var didCorrectStart = false
    @ObservationIgnored private var mediaClock: MediaClock?
    @ObservationIgnored private var seekRequest: UUID?
    @ObservationIgnored private var pendingWord: Int?
    @ObservationIgnored private var wordAwaitingHLSClock: (instant: Date, position: Double)?
    @ObservationIgnored private var wordAwaitingTimings: PendingWordSeek?
    @ObservationIgnored private var hasUserSought = false
    @ObservationIgnored private var autoplayOnLoad = true
    @ObservationIgnored private var resumeAfterScrubbing = false
    @ObservationIgnored private weak var app: AppModel?

    init() {
        player.allowsExternalPlayback = false
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.pause() }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in self?.pause() }
        }
    }
    func start(items: [FeedItem], app: AppModel, podcast: Bool, atWord: Int? = nil) {
        stop()
        queue = items.filter(\.canPlay)
        guard !queue.isEmpty else { return }
        self.app = app; isPodcast = podcast; index = 0
        loadCurrent(atWord: atWord)
    }
    func prepare(item: FeedItem, detail: SequenceDetail, app: AppModel) {
        guard item.canPlay else { return }
        stop()
        queue = [item]
        self.app = app; isPodcast = false; index = 0
        loadCurrent(autoplay: false, preparedDetail: detail)
    }
    func select(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        self.index = index; loadCurrent()
    }
    func next() { if hasNext { select(index + 1) } }
    func previous() { if hasPrevious { select(index - 1) } else { seek(0) } }
    func retry() { loadCurrent(autoplay: autoplayOnLoad) }
    func pause() { player.pause(); isPlaying = false; resumeAfterScrubbing = false }
    func toggle() {
        guard !isLoading, error == nil, player.currentItem != nil else { return }
        if isPlaying { pause() }
        else { if ended { seek(0); ended = false }; player.play(); isPlaying = true }
    }
    func seek(_ seconds: Double) {
        wordAwaitingHLSClock = nil
        wordAwaitingTimings = nil
        seek(seconds, userInitiated: true)
    }
    func beginScrubbing() {
        guard !isLoading, error == nil, duration > 0 else { return }
        resumeAfterScrubbing = isPlaying
        player.pause(); isPlaying = false; isScrubbing = true
        seekRequest = nil
        player.currentItem?.cancelPendingSeeks()
        wordAwaitingHLSClock = nil
        wordAwaitingTimings = nil
        hasUserSought = true
    }
    func scrub(to seconds: Double) {
        guard isScrubbing else { seek(seconds); return }
        guard seconds.isFinite else { return }
        position = max(0, min(seconds, duration))
        instant = mediaClock?.instant(at: position)
        ended = false; transcriptNotice = nil
    }
    func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        seek(position)
        if resumeAfterScrubbing { player.play(); isPlaying = true }
        resumeAfterScrubbing = false
    }
    func seekToWord(_ index: Int, sequenceID: Int64) {
        guard current?.id == sequenceID else { return }
        wordAwaitingHLSClock = nil; wordAwaitingTimings = nil
        if error != nil { loadCurrent(atWord: index); return }
        pendingWord = index
        hasUserSought = true
        transcriptNotice = nil
        // Keep the latest tap while the HLS window is loading.
        guard !isLoading, let detail else { return }
        let timeline = TranscriptTimeline(detail: detail, timings: app?.wordTimings[detail.id])
        guard let date = timeline.instant(forWord: index), let mediaClock else {
            transcriptNotice = "Les repères temporels de ce verbatim ne sont pas disponibles."
            pendingWord = nil
            return
        }
        let target = mediaClock.position(at: date)
        guard target >= 0, target < duration else {
            transcriptNotice = "Ce mot se situe en dehors de l’extrait disponible."
            pendingWord = nil
            return
        }
        pendingWord = nil
        seek(target, userInitiated: true)
        wordAwaitingHLSClock = !didCorrectStart && app?.isDemo == false ? (date, target) : nil
        wordAwaitingTimings = !timeline.hasPreciseTimings ? PendingWordSeek(index: index, position: target) : nil
    }
    func wordTimingsDidLoad(sequenceID: Int64) {
        guard current?.id == sequenceID, let detail, !isLoading, !isScrubbing, !ended,
              let requested = wordAwaitingTimings, let mediaClock else { return }
        let timeline = TranscriptTimeline(detail: detail, timings: app?.wordTimings[sequenceID])
        guard timeline.hasPreciseTimings, let date = timeline.instant(forWord: requested.index) else { return }
        wordAwaitingTimings = nil
        let base = mediaClock.position(at: date)
        let target = requested.target(precisePosition: base, currentPosition: position)
        guard target >= 0, target < duration else { return }
        // Reconcile a tap made before the word metadata arrived, preserving pause
        // and any progress made since that tap. Manual scrubbing cancels this intent.
        wordAwaitingHLSClock = !didCorrectStart && app?.isDemo == false ? (date, base) : nil
        seek(target, userInitiated: false)
    }
    private func seek(_ seconds: Double, userInitiated: Bool) {
        guard seconds.isFinite, duration > 0, let item = player.currentItem, item.status == .readyToPlay else { return }
        if userInitiated { hasUserSought = true; transcriptNotice = nil }
        let value = max(0, min(seconds, duration))
        let request = UUID(), generation = self.generation
        seekRequest = request
        position = value; instant = mediaClock?.instant(at: value); ended = false
        player.seek(to: CMTime(seconds: value, preferredTimescale: 60_000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == generation, self.seekRequest == request else { return }
                self.seekRequest = nil
                self.tick()
            }
        }
    }
    func stop() {
        generation = UUID(); loadTask?.cancel(); loadTask = nil
        pause(); player.replaceCurrentItem(with: nil)
        statusObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        relay?.stop(); relay = nil
        queue = []; detail = nil; isPodcast = false; position = 0; duration = 0; instant = nil
        mediaClock = nil; seekRequest = nil; pendingWord = nil; wordAwaitingHLSClock = nil; wordAwaitingTimings = nil; transcriptNotice = nil; hasUserSought = false
        isLoading = false; error = nil; ended = false; isScrubbing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func loadCurrent(atWord: Int? = nil, autoplay: Bool = true, preparedDetail: SequenceDetail? = nil) {
        guard let current, let app else { return }
        loadTask?.cancel(); pause(); player.replaceCurrentItem(with: nil)
        relay?.stop(); relay = nil; statusObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        let id = UUID(); generation = id
        autoplayOnLoad = autoplay
        isLoading = true; error = nil; ended = false; position = 0; duration = 0; detail = nil; didCorrectStart = false; isScrubbing = false
        instant = nil; mediaClock = nil; seekRequest = nil; pendingWord = atWord; wordAwaitingHLSClock = nil; wordAwaitingTimings = nil; hasUserSought = atWord != nil; transcriptNotice = nil
        loadTask = Task { [weak self, app] in
            guard let self else { return }
            do {
                let detail: SequenceDetail
                if let preparedDetail {
                    detail = preparedDetail
                } else {
                    detail = try await app.sequence(current)
                }
                guard self.generation == id, !Task.isCancelled else { return }
                self.detail = detail
                self.mediaClock = MediaClock(playFrom: detail.playFrom, margin: self.isPodcast || app.isDemo ? 0 : 10)
                let url: URL
                if app.isDemo {
                    let configuration = URLSessionConfiguration.ephemeral
                    configuration.protocolClasses = [DemoMediaProtocol.self]
                    let relay = HLSRelay(origin: DemoMediaProtocol.origin, token: DemoMediaProtocol.token, configuration: configuration)
                    self.relay = relay
                    try await relay.start()
                    guard self.generation == id, !Task.isCancelled else { relay.stop(); return }
                    url = try relay.localURL(for: DemoMediaProtocol.origin.appendingPathComponent("demo.m3u8"))
                } else {
                    guard let token = app.session?.token else { throw APIError.sessionExpired }
                    let relay = HLSRelay(origin: app.api.baseURL, token: token)
                    self.relay = relay
                    relay.onUnauthorized = { [weak app] in
                        Task { @MainActor in
                            guard app?.session?.token == token else { return }
                            app?.handleSessionError(APIError.sessionExpired)
                        }
                    }
                    try await relay.start()
                    guard self.generation == id, !Task.isCancelled else { relay.stop(); return }
                    url = try relay.localURL(for: app.api.playlistURL(for: detail, margin: self.isPodcast ? 0 : 10))
                }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: current.video ? .moviePlayback : .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                let item = AVPlayerItem(url: url)
                self.statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self, self.generation == id else { return }
                        if item.status == .failed {
                            self.error = "Impossible de lire cette séquence. Réessayez dans un instant."
                            self.isLoading = false; self.pause()
                        } else if item.status == .readyToPlay && self.isLoading {
                            self.isLoading = false
                            self.duration = item.duration.seconds.isFinite ? item.duration.seconds : Double(current.durationSec)
                            if let clock = MediaClock(currentDate: item.currentDate(), position: item.currentTime().seconds) {
                                self.mediaClock = clock; self.didCorrectStart = true
                            }
                            if let word = self.pendingWord {
                                self.seekToWord(word, sequenceID: detail.id)
                            } else if !app.isDemo && !self.isPodcast {
                                let offset = APIDate.parse(detail.playFrom).flatMap { self.mediaClock?.position(at: $0) } ?? 10
                                self.seek(offset, userInitiated: false)
                            }
                            if autoplay {
                                self.player.play(); self.isPlaying = true
                            }
                        }
                    }
                }
                self.endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.generation == id, self.seekRequest == nil, !self.isScrubbing else { return }
                        if self.isPodcast && self.hasNext { self.next() }
                        else { self.ended = true; self.pause() }
                    }
                }
                self.player.replaceCurrentItem(with: item)
            } catch {
                guard self.generation == id, !Task.isCancelled else { return }
                self.error = app.message(for: error); self.isLoading = false
            }
        }
    }
    private func tick() {
        guard let item = player.currentItem else { return }
        let total = item.duration.seconds
        if total.isFinite && total > 0 { duration = total }
        isPlaying = player.timeControlStatus == .playing
        // AVPlayer can publish the old position before a seek completes. Do not let
        // those callbacks undo the immediate text/slider update or a more recent tap.
        guard seekRequest == nil, !isScrubbing else { return }
        let seconds = item.currentTime().seconds
        guard seconds.isFinite else { return }
        position = max(0, seconds)
        if let clock = MediaClock(currentDate: item.currentDate(), position: seconds) {
            mediaClock = clock
            if !didCorrectStart {
                didCorrectStart = true
                if let requested = wordAwaitingHLSClock {
                    wordAwaitingHLSClock = nil
                    // If HLS exposed its real clock only after the tap, rebase that
                    // word and retain any playback progress since the seek.
                    let target = clock.position(at: requested.instant) + max(0, position - requested.position)
                    if target >= 0, target < duration, abs(target - position) > 0.05 {
                        wordAwaitingTimings?.rebaseClock(from: position, to: target)
                        seek(target, userInitiated: false)
                        return
                    }
                } else if !hasUserSought, !isPodcast, app?.isDemo == false,
                   let detail, let passage = APIDate.parse(detail.playFrom) {
                    let target = max(0, clock.position(at: passage))
                    if abs(target - 10) > 1.5 && position < target {
                        seek(target, userInitiated: false)
                        return
                    }
                }
            }
        }
        instant = mediaClock?.instant(at: position)
    }
}
