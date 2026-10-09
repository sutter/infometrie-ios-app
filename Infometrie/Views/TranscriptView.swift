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
    @State private var localReading = TranscriptReadingState()
    private let sharedReading: TranscriptReadingState?
    private var reading: TranscriptReadingState { sharedReading ?? localReading }
    let detail: SequenceDetail
    let isCurrent: Bool
    let onSeek: (Int) -> Void
    private let standardTimeline: TranscriptTimeline
    private let largeTextTimeline: TranscriptTimeline
    private var timeline: TranscriptTimeline { dynamicType.isAccessibilitySize ? largeTextTimeline : standardTimeline }

    init(detail: SequenceDetail, timings: SequenceWordTimings? = nil, isCurrent: Bool, reading: TranscriptReadingState? = nil, onSeek: @escaping (Int) -> Void) {
        self.detail = detail; self.isCurrent = isCurrent; self.onSeek = onSeek
        self.sharedReading = reading
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

    /// The whole text, in the page: a box scrolling inside the scrolling page was one scroll too many, and the
    /// fullscreen text went with it (2026-10-09). The page follows the listening (`SequenceView`).
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppRule()
            textInline.padding(.top, 16)
                .overlay(alignment: .topLeading) { positionStatus }
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

    private var passages: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(timeline.passages) { passage in
                Text(attributed(passage))
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(Brand.ink).tint(Brand.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(passage.id)
                    .accessibilityIdentifier("transcript-passage-\(passage.id)")
            }
        }
    }

    /// The passages laid out in the page, which scrolls and follows them.
    private var textInline: some View {
        followsListening(passages.padding(.vertical, 4)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("transcript-scroll"))
    }

    /// Moves the reading to the passage being heard (`visiblePassage`, which the passage page follows), and lets a
    /// tapped word seek the player.
    private func followsListening(_ content: some View) -> some View {
        content
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
