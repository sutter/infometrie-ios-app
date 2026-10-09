import SwiftUI
import Observation

@MainActor @Observable
final class TranscriptReadingState {
    var followsPlayback = true
    var visiblePassage: Int?
    @ObservationIgnored private var resume: Task<Void, Never>?

    /// Scrolling by hand suspends following, which comes back on its own a few seconds after the finger lifts, like
    /// the lyrics in Musique (2026-10-09: the "Reprendre le suivi" button was removed at the user's request).
    func scrollPhaseChanged(to phase: ScrollPhase, suspends: Bool = true) {
        if phase == .interacting {
            resume?.cancel()
            if suspends { followsPlayback = false }
        } else if phase == .idle, !followsPlayback {
            resume?.cancel()
            resume = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                self?.followsPlayback = true
            }
        }
    }
    /// A tapped word brings following back at once.
    func followNow() { resume?.cancel(); followsPlayback = true }
}

struct TranscriptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .body) private var textHeight = 250.0
    @State private var textContentHeight: CGFloat?
    @State private var localReading = TranscriptReadingState()
    private let sharedReading: TranscriptReadingState?
    private var reading: TranscriptReadingState { sharedReading ?? localReading }
    private let expanded: Bool
    private let onExpand: (() -> Void)?
    let detail: SequenceDetail
    let isCurrent: Bool
    let onSeek: (Int) -> Void
    private let standardTimeline: TranscriptTimeline
    private let largeTextTimeline: TranscriptTimeline
    private var timeline: TranscriptTimeline { dynamicType.isAccessibilitySize ? largeTextTimeline : standardTimeline }

    init(detail: SequenceDetail, timings: SequenceWordTimings? = nil, isCurrent: Bool, reading: TranscriptReadingState? = nil, expanded: Bool = false, onExpand: (() -> Void)? = nil, onSeek: @escaping (Int) -> Void) {
        self.detail = detail; self.isCurrent = isCurrent; self.onSeek = onSeek
        self.sharedReading = reading; self.expanded = expanded; self.onExpand = onExpand
        standardTimeline = TranscriptTimeline(detail: detail, timings: timings)
        largeTextTimeline = TranscriptTimeline(detail: detail, timings: timings, maximumWordsPerPassage: 4)
    }

    /// No word is marked before listening starts: a highlighted first word at rest is only noise.
    private var activeWord: Int? {
        guard isCurrent, model.player.isPlaying || model.player.position > 0 else { return nil }
        return timeline.wordIndex(at: model.player.instant)
    }
    private var canSeek: Bool { detail.item.canPlay && timeline.canSynchronize }
    /// Feedback to a word the user just tapped, such as one outside the available excerpt.
    private var notice: String? { isCurrent ? model.player.transcriptNotice : nil }

    var body: some View {
        content
            // Tapped-word feedback slides in rather than pops.
            .motion(value: notice)
    }

    @ViewBuilder private var content: some View {
        if expanded {
            // No header: the text starts right away, and resuming sits below it as on the page.
            VStack(alignment: .leading, spacing: 12) {
                if let notice {
                    Text(notice).font(.footnote).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("transcript-notice")
                }
                textScroll.frame(maxHeight: .infinity)
                    .overlay(alignment: .topLeading) { positionStatus }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                AppRule()
                VStack(alignment: .leading, spacing: 0) {
                    // No "Verbatim" title: the text follows the passage title directly; only the
                    // fullscreen control remains, on the right.
                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                        if let onExpand {
                            Button(action: onExpand) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.body.weight(.semibold))
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).foregroundStyle(Brand.tint)
                            .accessibilityLabel("Afficher le texte en plein écran")
                            .accessibilityIdentifier("expand-transcript")
                        }
                    }
                    .overlay(alignment: .topLeading) { positionStatus }
                    // As tall as the text, up to the former fixed height: a short verbatim leaves no gap.
                    textScroll.frame(height: min(textContentHeight ?? textHeight, textHeight, 380))
                }.padding(.top, 4)
                if let notice {
                    Text(notice).font(.footnote).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("transcript-notice")
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { AppRule() }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    private var positionValue: String {
        activeWord.map { "Mot \($0 + 1) sur \(timeline.words.count)" } ?? (isCurrent ? "Aucun mot actif" : "En attente de lecture")
    }

    /// No position label is drawn; VoiceOver still reads where listening stands in the text, and whether the text
    /// follows it.
    private var positionStatus: some View {
        ZStack {
            Color.clear.frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Le texte")
                .accessibilityValue(positionValue)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("transcript-position")
            Color.clear.frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Suivi de l’écoute")
                .accessibilityValue(reading.followsPlayback ? "Activé" : "Désactivé")
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("transcript-follow")
        }
    }

    private var textScroll: some View {
        @Bindable var reading = reading
        return ScrollView {
            VStack(alignment: .leading, spacing: expanded ? 24 : 16) {
                ForEach(timeline.passages) { passage in
                    Text(attributed(passage))
                        .font(expanded ? .title2.weight(.semibold) : .body)
                        .lineSpacing(expanded ? 8 : 6)
                        .foregroundStyle(Brand.ink).tint(Brand.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(passage.id)
                        .accessibilityIdentifier("transcript-passage-\(passage.id)")
                }
                if expanded, isCurrent, let error = model.player.error { ErrorNotice(message: error) }
            }.scrollTargetLayout().padding(.vertical, expanded ? 12 : 4)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textContentHeight = $0 }
        }
        .scrollEdgeEffectHidden(true)
        .accessibilityIdentifier("transcript-scroll")
        .scrollPosition(id: $reading.visiblePassage, anchor: .top)
        .onScrollPhaseChange { _, phase in reading.scrollPhaseChanged(to: phase) }
        .onChange(of: timeline.passageID(forWord: activeWord)) { _, passage in
            if reading.followsPlayback { follow(passage) }
        }
        .onChange(of: reading.followsPlayback) { _, following in
            if following { follow(timeline.passageID(forWord: activeWord)) }
        }
        .onAppear { if reading.followsPlayback { follow(timeline.passageID(forWord: activeWord)) } }
        .environment(\.openURL, OpenURLAction { url in
            guard canSeek, url.scheme == "infometrie-transcript", url.host == "seek",
                  url.pathComponents.count == 3, url.pathComponents[1] == String(detail.id),
                  let word = Int(url.pathComponents[2]), timeline.words.indices.contains(word) else { return .discarded }
            reading.followNow()
            onSeek(word)
            return .handled
        })
    }

    private func follow(_ passage: Int?) {
        guard let passage else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { reading.visiblePassage = passage }
    }

    private func attributed(_ passage: TranscriptTimeline.Passage) -> AttributedString {
        let text = (timeline.text as NSString).substring(with: passage.range)
        var result = AttributedString(text)
        let currentWord = activeWord
        for word in timeline.words[passage.wordIDs] {
            let relative = NSRange(location: word.range.location - passage.range.location, length: word.range.length)
            guard let stringRange = Range(relative, in: text), let range = Range(stringRange, in: result) else { continue }
            if canSeek, timeline.instant(forWord: word.id) != nil {
                result[range].link = URL(string: "infometrie-transcript://seek/\(detail.id)/\(word.id)")
                result[range][AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle(pattern: .solid, color: .clear)
            }
            if word.id == currentWord {
                result[range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Brand.primaryForeground
                result[range][AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Brand.primary
            }
        }
        return result
    }
}
