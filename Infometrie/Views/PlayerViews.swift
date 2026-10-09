import SwiftUI
import AVKit

struct SequenceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The passage shown: it changes in place when the reader moves to the next one, so back still leads to the list.
    @State private var item: FeedItem
    /// The list the passage was opened from (the journal as filtered, or a profile's day), for "Passage suivant".
    private let list: [FeedItem]
    @State private var detail: SequenceDetail?
    @State private var error: String?
    @State private var reload = 0
    @State private var isTranscriptExpanded = false
    @State private var transcriptReading = TranscriptReadingState()
    @State private var contentScrolled = false
    @State private var pageScrolledByReader = false
    @State private var pageInteracting = false

    init(item: FeedItem, list: [FeedItem] = []) {
        _item = State(initialValue: item)
        self.list = list
    }

    /// The passage after this one in the list it was opened from.
    private var nextItem: FeedItem? {
        guard let index = list.firstIndex(where: { $0.id == item.id }), list.indices.contains(index + 1) else { return nil }
        return list[index + 1]
    }

    /// Replaces the passage in place: the player of this one stops, the next one prepares without playing, and the
    /// page starts again at its top with the full heading.
    private func show(_ next: FeedItem) {
        model.player.stop()
        detail = nil; error = nil
        transcriptReading = TranscriptReadingState()
        pageScrolledByReader = false; contentScrolled = false
        item = next
        model.markSeen(next)
    }
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

    /// The heading (kind, speaker, title) and the video stay on screen while the text, its summary and the context
    /// scroll below them (the user, 2026-10-09). At accessibility sizes, or in landscape, they would fill the screen:
    /// there they scroll with the rest.
    private var pinsHeader: Bool { !dynamicType.isAccessibilitySize && verticalSizeClass != .compact }

    /// The pinned heading shrinks while the reader scrolls the page or the text down: the title on one or two
    /// lines beside a video thumbnail, so the text keeps the screen (the user's pick on 2026-10-09; a long title and
    /// a full-width video left two lines of text). Following the listening never shrinks it, nor would the video
    /// shrink while it is watched; scrolling back to the top, or touching it, restores it.
    private var compactHeader: Bool { pinsHeader && (pageScrolledByReader || transcriptReading.textScrolledByReader) }

    private var showsVideo: Bool { isCurrent && displayItem.canPlay && displayItem.video }

    /// One video view in both states, resized rather than replaced, so the picture never cuts out.
    private var video: some View {
        Color.clear.aspectRatio(16 / 9, contentMode: .fit)
            .frame(width: compactHeader ? 112 : nil)
            .frame(maxWidth: compactHeader ? nil : .infinity)
            .overlay { NativeVideo(player: model.player.player) }
            .clipShape(RoundedRectangle(cornerRadius: compactHeader ? 4 : 6))
    }

    @ViewBuilder private var header: some View {
        let layout = compactHeader
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
        layout {
            if compactHeader { compactHeading } else {
                PassageHeading(item: displayItem, titleIdentifier: "sequence-title", linksPerson: true)
            }
            if isCurrent, !compactHeader, let playbackError = model.player.error { ErrorNotice(message: playbackError) }
            if showsVideo { video.layoutPriority(compactHeader ? 1 : 0) }
        }
    }

    /// The speaker and the title, short: touching it brings the full heading back.
    private var compactHeading: some View {
        Button {
            pageScrolledByReader = false; transcriptReading.textScrolledByReader = false
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayItem.person).font(.footnote.weight(.semibold)).foregroundStyle(Brand.secondary).lineLimit(1)
                Text(displayItem.displayTitle).font(.subheadline.weight(.bold)).foregroundStyle(Brand.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                    .accessibilityIdentifier("sequence-title")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Affiche l’en-tête complet")
    }

    private var sequenceContent: some View {
        VStack(spacing: 0) {
            if pinsHeader {
                header
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppLayout.margin).padding(.top, compactHeader ? 8 : 20).padding(.bottom, 12)
                    .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
                    .background(Brand.background)
                    // A hairline once the content scrolls under the heading, so the text never runs into the title.
                    .overlay(alignment: .bottom) { if contentScrolled { AppRule() } }
                    .motion(value: compactHeader)
                    // Above the scroll: the content passes under the heading, never over it.
                    .zIndex(1)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !pinsHeader { VStack(alignment: .leading, spacing: 24) { header } }
                    if let error {
                        ErrorNotice(message: error) { self.error = nil; reload += 1 }
                    } else if let detail = displayDetail {
                        if displayItem.isTweet {
                            PublicationPost(item: displayItem, text: detail.verbatim)
                        } else if !detail.verbatim.isEmpty {
                            TranscriptView(detail: detail, timings: model.wordTimings[detail.id], isCurrent: isCurrent,
                                           reading: transcriptReading, onExpand: { isTranscriptExpanded = true }) { word in
                                if isCurrent { model.player.seekToWord(word, sequenceID: detail.id) }
                                else { model.player.start(items: [item], app: model, podcast: false, atWord: word) }
                            }.id(detail.id).transition(.opacity)
                        } else { Text("Le texte n’est pas disponible pour ce passage.").foregroundStyle(Brand.secondary) }
                        if !displayItem.isTweet, let summary = detail.summary {
                            // Always open, at the user's request on 2026-10-08: the summary is read, not hunted for.
                            SequenceSection(title: "Résumé", icon: "text.alignleft") {
                                Text(summary).font(.body).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.accessibilityIdentifier("sequence-summary")
                        }
                        if let next = nextItem {
                            NextPassage(item: next) { show(next) }
                        }
                    } else { textSkeleton }
                }.padding(.horizontal, AppLayout.margin).padding(.top, pinsHeader ? 12 : 20).padding(.bottom, 20)
                    .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
            }
            // A new scroll per passage, so "Passage suivant" opens the next one at its top.
            .id(item.id)
            .clipped()
            .onScrollPhaseChange { _, phase in pageInteracting = phase == .interacting || phase == .decelerating }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                contentScrolled = offset > 1
                // Shrinks past 8 pt; restores only when the reader pulls the page down at its top. Shrinking the
                // heading lets the scroll grow and settle back to 0, and restoring at 0 looped: shrink, restore,
                // shrink, with the content flickering over the heading (2026-10-09).
                if offset > 8, pageInteracting { pageScrolledByReader = true }
                else if offset < -8, pageInteracting { pageScrolledByReader = false }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isTranscriptExpanded {
                // A publication X has no bottom bar: its link sits under the post (`PublicationPost`).
                if !displayItem.isTweet, displayItem.canPlay {
                    if isCurrent { PlaybackDock() }
                    else if displayDetail == nil && error == nil {
                        // While the passage loads, the player's own shape, greyed: the page prepares the player on
                        // opening, and the "Écouter ce passage" button that flashed here first changed the bottom's
                        // height and shape on every opening (2026-10-09).
                        PlaybackDock().skeleton().disabled(true).accessibilityHidden(true)
                    } else {
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
                            .padding([.horizontal, .top], 16).modifier(HomeIndicatorPadding()).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity).background(Brand.background)
                            .overlay(alignment: .top) { AppRule() }
                    }
                }
            }
        }
        .scrollEdgeEffectHidden(true)
        .background(Brand.background).appNavigationTitle(item.isTweet ? "Publication X" : "Séquence")
        // Pushed pages keep the room for their player: no tab bar, no listening accessory.
        .pushedPage(model)
        .onAppear { model.markSeen(item) }
        .task(id: "\(item.id)-\(reload)") {
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

/// The passage after this one in the list it was opened from, at the end of the page: reading on without going back
/// to the list (2026-10-09). Its kind, time and speaker, then its title, like a journal row.
private struct NextPassage: View {
    let item: FeedItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Passage suivant").font(.footnote.weight(.semibold)).foregroundStyle(Brand.secondary)
                    HStack(spacing: 8) {
                        KindTag(item: item)
                        PassageDate(item: item, day: item.date.map(ParisDay.string)).font(.footnote)
                    }
                    Text(item.person).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                    Text(item.displayTitle).font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(Brand.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { AppRule() }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Passage suivant : \(item.person), \(item.displayTitle)")
        .accessibilityIdentifier("next-passage")
    }
}

/// The post of a publication X, set off by an ink bar like the journal's rows, then a discreet link to it on X
/// (2026-10-09: a full-width vermillon "Voir la publication sur X" was the strongest thing on the page and sent the
/// reader out of the app, while the post itself was already shown). No card: the page has none.
private struct PublicationPost: View {
    let item: FeedItem
    let text: String

    /// The post, unless it only repeats the title.
    private var post: String? {
        let post = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return post.isEmpty || post == item.title ? nil : post
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let post {
                Text(post).font(.body).lineSpacing(6).foregroundStyle(Brand.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 16)
                    .overlay(alignment: .leading) {
                        Capsule().fill(FeedItem.color(ofKind: "tweet")).frame(width: 3).accessibilityHidden(true)
                    }
                    .accessibilityIdentifier("publication-text")
            }
            if let url = item.publicationURL {
                Link(destination: url) {
                    Label("Voir sur X", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .foregroundStyle(Brand.ink)
                .accessibilityLabel("Voir la publication sur X")
                .accessibilityHint("Ouvre la publication dans X ou votre navigateur")
                .accessibilityIdentifier("open-publication")
            } else {
                Text("Le lien vers cette publication n’est pas disponible.")
                    .font(.subheadline).foregroundStyle(Brand.secondary)
            }
        }
    }
}

/// A section of the passage page under an icon header, its content always open.
private struct SequenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SequenceSectionLabel(title: title, icon: icon).accessibilityAddTraits(.isHeader)
            content().frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 20)
        }
        .overlay(alignment: .top) { AppRule() }
        .accessibilityElement(children: .contain)
    }
}

private struct SequenceSectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .foregroundStyle(Brand.tint)
                .accessibilityHidden(true)
            Text(title).font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Brand.tint).frame(minHeight: 48)
    }
}

/// The bottom bars of a passage page (player, "Voir la publication sur X", "Écouter ce passage"): no margin under
/// them where the home indicator's 34 pt safe area already clears them, 12 pt on a phone with a home button, which
/// has none (2026-10-09: the 12 to 16 pt they added left a gap the user found too wide).
struct HomeIndicatorPadding: ViewModifier {
    @State private var inset: CGFloat = 0

    func body(content: Content) -> some View {
        content.padding(.bottom, max(0, 12 - inset))
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset = $0 }
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
                        .tint(Brand.accent)
                        // Where the person speaks: a darker gray on the track itself, the rest being the context the
                        // API adds around the passage (2026-10-09: "0:13" at rest read as listening started; a pale
                        // vermillon band under the track was found ugly the same day).
                        .background { speechBand }
                        .disabled(playback.isLoading || playback.error != nil || playback.duration <= 0)
                        .accessibilityLabel("Position dans le passage")
                        .accessibilityValue(speechValue)
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
                } else if compact || dynamicType.isAccessibilitySize {
                    // At accessibility sizes too: "Écouter" on its own row over the skips took half the screen and
                    // hid the passage's speaker. The play button keeps "Écouter" for VoiceOver.
                    HStack(spacing: 12) {
                        skipButton(forward: false)
                        playButton.labelStyle(.iconOnly)
                        skipButton(forward: true)
                    }
                } else {
                    HStack(spacing: 12) { skipButton(forward: false); playButton; skipButton(forward: true) }
                }
            }
        }
        .padding(.horizontal, AppLayout.margin).padding(.top, 8).modifier(HomeIndicatorPadding())
        .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        .background(Brand.background).overlay(alignment: .top) { AppRule() }
        .sensoryFeedback(.impact(weight: .light), trigger: presses)
    }
    /// Drawn behind the system slider: its unfilled track is translucent, so the gray shows through it, while the
    /// vermillon fill and the thumb, glass or not, lie over it with no seam (2026-10-09: drawn over the track, it
    /// left a gap beside the thumb once the thumb turned to glass under the finger). The slider stays the native
    /// control the UI tests drive.
    @ViewBuilder private var speechBand: some View {
        if let range = playback.speechRange, playback.duration > 0 {
            GeometryReader { geometry in
                // The thumb's center travels inside the track, half a thumb (about 19 pt on iOS 26) from each end.
                let inset: CGFloat = 19, span = max(0, geometry.size.width - 2 * inset)
                let x = { (seconds: Double) in inset + span * min(1, max(0, seconds / playback.duration)) }
                let start = x(range.lowerBound), end = x(range.upperBound)
                Capsule().fill(Brand.secondary.opacity(0.55))
                    .frame(width: max(6, end - start), height: 6)
                    .position(x: (start + end) / 2, y: geometry.size.height / 2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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
                .background(Brand.actionWash, in: Circle())
                .contentShape(Circle())
        }.buttonStyle(PressableStyle()).foregroundStyle(Brand.actionText)
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
                .background(Brand.actionWash, in: Capsule())
                .contentShape(Rectangle())
        }.buttonStyle(PressableStyle()).foregroundStyle(Brand.actionText)
            .disabled(playback.isLoading || playback.error != nil)
            .accessibilityLabel(forward ? "Avancer de 10 secondes" : "Reculer de 10 secondes")
    }
    /// "0:21, prise de parole de 0:13 à 0:30".
    private var speechValue: String {
        let at = clock(playback.position)
        guard let range = playback.speechRange else { return at }
        return "\(at), prise de parole de \(clock(range.lowerBound)) à \(clock(range.upperBound))"
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
                VStack(alignment: .leading, spacing: 24) {
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
                }.padding(.horizontal, AppLayout.margin).padding(.vertical, 20).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
                    .motion(value: model.player.current?.id)
                    .motion(value: model.player.detail?.id)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { PlaybackDock(queue: true) }
            .background(Brand.background).appNavigationTitle("Tout écouter")
            // Each passage the queue plays counts as seen, like an opened page.
            .onChange(of: model.player.current?.id, initial: true) {
                if let item = model.player.current { model.markSeen(item) }
            }
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
