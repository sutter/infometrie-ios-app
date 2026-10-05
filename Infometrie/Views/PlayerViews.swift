import SwiftUI
import AVKit

struct SequenceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType
    let item: FeedItem
    @State private var detail: SequenceDetail?
    @State private var error: String?
    @State private var reload = 0
    @State private var isTranscriptExpanded = false
    @State private var transcriptReading = TranscriptReadingState()
    private var isCurrent: Bool { model.player.current?.id == item.id && !model.player.isPodcast }
    private var displayDetail: SequenceDetail? { isCurrent ? model.player.detail ?? detail : detail }
    private var displayItem: FeedItem { displayDetail?.item ?? item }

    var body: some View {
        VStack(spacing: 0) { sequenceContent }
            // Group the scroll view and its safe-area controls before hiding the presenter.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("sequence-content")
            .accessibilityHidden(isTranscriptExpanded)
            .fullScreenCover(isPresented: $isTranscriptExpanded) {
                if let detail = displayDetail {
                    TranscriptFullscreenView(detail: detail, reading: transcriptReading)
                        .environment(model)
                }
            }
            .onDisappear {
                // Presenting the reading view must keep the existing AVPlayer alive.
                if isCurrent && !isTranscriptExpanded { model.player.stop() }
            }
    }

    /// The transcript heading and a paragraph, drawn as placeholders until the passage arrives.
    private var textSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Le texte", systemImage: "text.quote").font(.headline)
            Text(String(repeating: "Le texte du passage arrive, ligne après ligne, dans cette zone. ", count: 4))
                .font(.body).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .skeleton()
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement du texte")
    }

    private var sequenceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PassageHeading(item: displayItem, titleIdentifier: "sequence-title")
                if isCurrent, let playbackError = model.player.error { ErrorNotice(message: playbackError) }
                if isCurrent, displayItem.canPlay, displayItem.video {
                    NativeVideo(player: model.player.player).aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if let error {
                    ErrorNotice(message: error) { self.error = nil; reload += 1 }
                } else if let detail = displayDetail {
                    if displayItem.isTweet {
                        if !detail.verbatim.isEmpty && detail.verbatim != displayItem.title {
                            AppSection(title: "La publication") {
                                Text(detail.verbatim).font(.body).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("publication-text")
                            }
                        }
                        if displayItem.publicationURL == nil {
                            Text("Le lien vers cette publication n’est pas disponible.")
                                .font(.subheadline).foregroundStyle(Brand.secondary)
                        }
                    } else if !detail.verbatim.isEmpty {
                        TranscriptView(detail: detail, timings: model.wordTimings[detail.id], isCurrent: isCurrent,
                                       reading: transcriptReading, onExpand: { isTranscriptExpanded = true }) { word in
                            if isCurrent { model.player.seekToWord(word, sequenceID: detail.id) }
                            else { model.player.start(items: [item], app: model, podcast: false, atWord: word) }
                        }.id(detail.id).transition(.opacity)
                    } else { Text("Le texte n’est pas disponible pour ce passage.").foregroundStyle(Brand.secondary) }
                    if !displayItem.isTweet && !detail.resume.isEmpty {
                        SequenceDisclosure(title: "Lire le résumé", icon: "text.alignleft") {
                            Text(detail.resume).font(.body).lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }.accessibilityIdentifier("sequence-summary")
                    }
                } else { textSkeleton }
                SequenceDisclosure(title: "À propos du passage", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        KindBadge(item: item)
                        if !item.party.isEmpty { Text(item.party) }
                        if !item.role.isEmpty { Text(item.role) }
                        if !item.show.isEmpty { Label(item.show, systemImage: "antenna.radiowaves.left.and.right") }
                        if let date = item.date { Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar") }
                        if item.isCitation && !item.citedBy.isEmpty { Label("Mention par \(item.citedBy)", systemImage: "quote.bubble") }
                    }.font(.subheadline).foregroundStyle(Brand.secondary)
                }.accessibilityIdentifier("sequence-context")
            }.padding(20).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
                .motion(value: displayDetail?.id)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isTranscriptExpanded {
                if displayItem.isTweet, let url = displayItem.publicationURL {
                    Link(destination: url) { Label("Voir la publication sur X", systemImage: "arrow.up.right") }
                        .buttonStyle(ActionButtonStyle(prominent: true))
                        .accessibilityIdentifier("open-publication")
                        .accessibilityHint("Ouvre la publication dans X ou votre navigateur")
                        .padding(16).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
                        .background(Brand.background).overlay(alignment: .top) { AppRule() }
                } else if displayItem.canPlay {
                    if isCurrent { PlaybackDock() }
                    else {
                        Button { model.player.start(items: [item], app: model, podcast: false) } label: {
                            AdaptiveRow {
                                Label("Écouter ce passage", systemImage: "play.fill")
                                if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
                                if item.durationSec > 0 {
                                    Text(item.readableDuration).font(.subheadline.monospacedDigit())
                                        .accessibilityLabel("Durée : \(item.readableDuration)")
                                }
                            }
                        }.buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("play-sequence")
                            .padding(16).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity).background(Brand.background)
                            .overlay(alignment: .top) { AppRule() }
                    }
                }
            }
        }
        .scrollEdgeEffectHidden(true, for: .bottom)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .background(Brand.background).appNavigationTitle(item.isTweet ? "Publication X" : "Séquence")
        .toolbar(.hidden, for: .tabBar)
        .task(id: reload) {
            do {
                let value = try await model.sequence(item)
                guard !Task.isCancelled else { return }
                detail = value
                // Prepare the detail player without autoplay so the passage opens
                // with its video frame and an explicit play control.
                if value.item.canPlay, model.player.current == nil {
                    model.player.prepare(item: value.item, detail: value, app: model)
                }
            }
            catch { if !Task.isCancelled { self.error = model.message(for: error) } }
        }
    }
}

private struct SequenceDisclosure<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        DisclosureGroup {
            content().frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4).padding(.bottom, 20)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Brand.tint)
                    .accessibilityHidden(true)
                Text(title).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Brand.tint).frame(minHeight: 56).padding(.vertical, 4)
        }
        .tint(Brand.tint)
        .overlay(alignment: .top) { AppRule() }
    }
}

/// The text can scroll independently; the timeline and transport stay within reach.
struct PlaybackDock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType
    var compact = false
    /// "Tout écouter": previous and next lead, as prominent buttons around a round play button,
    /// and replace the 10-second skips.
    var queue = false
    @ScaledMetric(relativeTo: .title2) private var playCircleSize = 56.0
    /// Counts the user's own presses so a haptic follows them, never automatic queue moves.
    @State private var presses = 0
    private var playback: PlaybackModel { model.player }
    var body: some View {
        VStack(spacing: 10) {
            if playback.error != nil {
                Text("Écoute indisponible").font(.headline)
                let retry = Button("Réessayer l’écoute") { playback.retry() }.buttonStyle(ActionButtonStyle(prominent: true))
                retry
                // A passage that fails must not block the queue.
                if queue { HStack(spacing: 12) { queueButton(forward: false); queueButton(forward: true) } }
            } else {
                VStack(spacing: 0) {
                    Slider(value: Binding(get: { min(playback.position, max(1, playback.duration)) }, set: { playback.scrub(to: $0) }), in: 0...max(1, playback.duration), onEditingChanged: { editing in
                        if editing { playback.beginScrubbing() } else { playback.endScrubbing() }
                    })
                        .frame(minHeight: 44)
                        .disabled(playback.isLoading || playback.error != nil || playback.duration <= 0)
                        .accessibilityLabel("Position dans le passage")
                        .accessibilityHint(playback.isLoading ? "Préparation de l’écoute" : "")
                        .accessibilityIdentifier("player-position")
                    HStack {
                        Text(clock(playback.position)).accessibilityIdentifier("player-elapsed")
                        Spacer()
                        Text(clock(playback.duration)).accessibilityLabel("Durée totale, \(clock(playback.duration))")
                    }.font(.subheadline.monospacedDigit()).foregroundStyle(Brand.secondary)
                        .contentTransition(.numericText())
                        .motion(Motion.quick, value: clock(playback.position) + clock(playback.duration))
                        .skeleton(playback.isLoading)
                }
                if queue {
                    // Past XL, "Précédent" no longer fits beside the play button: stack rather than split the word.
                    if dynamicType > .xLarge {
                        queueButton(forward: false)
                        queueButton(forward: true)
                        playCircle
                    } else {
                        HStack(spacing: 8) { queueButton(forward: false); playCircle; queueButton(forward: true) }
                    }
                } else if compact {
                    HStack(spacing: 12) {
                        skipButton(forward: false)
                        playButton.labelStyle(.iconOnly)
                        skipButton(forward: true)
                    }
                } else if dynamicType.isAccessibilitySize {
                    playButton
                    HStack(spacing: 16) { skipButton(forward: false); skipButton(forward: true) }
                } else {
                    HStack(spacing: 12) { skipButton(forward: false); playButton; skipButton(forward: true) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
        .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        .background(Brand.background).overlay(alignment: .top) { AppRule() }
        .sensoryFeedback(.impact(weight: .light), trigger: presses)
    }
    private var playButton: some View {
        Button { presses += 1; playback.toggle() } label: {
            Label(playLabel, systemImage: playSymbol)
                .contentTransition(.symbolEffect(.replace))
        }.buttonStyle(ActionButtonStyle(prominent: true))
            .motion(Motion.quick, value: playSymbol)
            .disabled(playback.isLoading || playback.error != nil)
            .accessibilityIdentifier("player-toggle")
    }
    private var playSymbol: String { playback.isPlaying ? "pause.fill" : playback.ended ? "arrow.counterclockwise" : "play.fill" }
    private var playLabel: String { playback.isPlaying ? "Pause" : playback.ended ? "Réécouter" : "Écouter" }
    /// The queue's play control stays discreet: previous and next are the main actions there.
    private var playCircle: some View {
        Button { presses += 1; playback.toggle() } label: {
            Image(systemName: playSymbol).font(.title2)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: playCircleSize, height: playCircleSize)
                .overlay { Circle().strokeBorder(Brand.rule) }
                .contentShape(Circle())
        }.buttonStyle(PressableStyle()).foregroundStyle(Brand.tint)
            .disabled(playback.isLoading || playback.error != nil)
            .accessibilityLabel(playLabel)
            .accessibilityIdentifier("player-toggle")
            .motion(Motion.quick, value: playSymbol)
    }
    private func queueButton(forward: Bool) -> some View {
        Button { presses += 1; forward ? playback.next() : playback.previous() } label: {
            HStack(spacing: 4) {
                if !forward { Image(systemName: "backward.end.fill") }
                Text(forward ? "Suivant" : "Précédent").lineLimit(1).minimumScaleFactor(0.85)
                if forward { Image(systemName: "forward.end.fill") }
            }
        }.buttonStyle(ActionButtonStyle(prominent: true, horizontalPadding: 10))
            .disabled(forward ? !playback.hasNext : !playback.hasPrevious)
            .accessibilityLabel(forward ? "Séquence suivante" : "Séquence précédente")
            .accessibilityIdentifier(forward ? "player-next" : "player-previous")
    }
    private func skipButton(forward: Bool) -> some View {
        Button { presses += 1; playback.seek(playback.position + (forward ? 10 : -10)) } label: {
            Image(systemName: forward ? "goforward.10" : "gobackward.10")
                .font(.title2).frame(minWidth: 52, maxWidth: dynamicType.isAccessibilitySize ? .infinity : 60, minHeight: 56)
                .overlay { Capsule().strokeBorder(Brand.rule) }
                .contentShape(Rectangle())
        }.buttonStyle(PressableStyle()).foregroundStyle(Brand.tint)
            .disabled(playback.isLoading || playback.error != nil)
            .accessibilityLabel(forward ? "Avancer de 10 secondes" : "Reculer de 10 secondes")
    }
    private func clock(_ seconds: Double) -> String {
        let value = seconds.isFinite ? max(0, Int(seconds)) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

struct PodcastView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let item = model.player.current {
                        PassageHeading(item: item, titleIdentifier: "podcast-title")
                            .id(item.id).transition(.opacity)
                    }
                    if let error = model.player.error { ErrorNotice(message: error) }
                    if model.player.current?.video == true {
                        NativeVideo(player: model.player.player).aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if let detail = model.player.detail, !detail.verbatim.isEmpty {
                        TranscriptView(detail: detail, timings: model.wordTimings[detail.id], isCurrent: true) { word in
                            model.player.seekToWord(word, sequenceID: detail.id)
                        }.id(detail.id).transition(.opacity)
                    }
                }.padding(20).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
                    .motion(value: model.player.current?.id)
                    .motion(value: model.player.detail?.id)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { PlaybackDock(queue: true) }
            .background(Brand.background).appNavigationTitle("Tout écouter")
            .toolbar {
                // The position shares the title line to leave the height to the passage.
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(model.player.index + 1) / \(model.player.queue.count)")
                        .font(.footnote).foregroundStyle(Brand.secondary).monospacedDigit()
                        .lineLimit(1).fixedSize()
                        .contentTransition(.numericText())
                        .motion(value: model.player.index)
                        .accessibilityLabel("Passage \(model.player.index + 1) sur \(model.player.queue.count)")
                }
                .sharedBackgroundVisibility(.hidden)
                // A regular glass circle, like the system back button; never the prominent confirmation style.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.player.stop() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Fermer")
                        .accessibilityIdentifier("close-podcast")
                }
            }
        }.presentationDragIndicator(.visible)
    }
}

struct NativeVideo: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player; controller.showsPlaybackControls = false
        controller.allowsPictureInPicturePlayback = false
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { controller.player = player }
}
