import SwiftUI
import Observation

@Observable
final class TranscriptReadingState {
    var followsPlayback = true
    var visiblePassage: Int?
}

struct TranscriptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .body) private var textHeight = 250.0
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

    private var activeWord: Int? { timeline.wordIndex(at: isCurrent ? model.player.instant : nil) }
    private var canSeek: Bool { detail.item.canPlay && timeline.canSynchronize }
    /// Following is on by default and says nothing; the control appears only once scrolling suspended it.
    private var showsResume: Bool { canSeek && isCurrent && !reading.followsPlayback }
    /// Feedback to a word the user just tapped, such as one outside the available excerpt.
    private var notice: String? { isCurrent ? model.player.transcriptNotice : nil }

    var body: some View {
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
                if showsResume { followButton }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                AppRule()
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        positionStatus
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
                    textScroll.frame(height: min(textHeight, 380))
                }.padding(.top, 4).padding(.bottom, 8)
                if showsResume || notice != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if showsResume { followButton }
                        if let notice {
                            Text(notice).font(.footnote).foregroundStyle(Brand.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("transcript-notice")
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { AppRule() }
                }
            }
        }
    }

    private var positionValue: String {
        activeWord.map { "Mot \($0 + 1) sur \(timeline.words.count)" } ?? (isCurrent ? "Aucun mot actif" : "En attente de lecture")
    }

    /// No position label is drawn; VoiceOver still reads where listening stands in the text.
    private var positionStatus: some View {
        Color.clear.frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel("Le texte")
            .accessibilityValue(positionValue)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("transcript-position")
    }

    private var textScroll: some View {
        @Bindable var reading = reading
        return ScrollView {
            VStack(alignment: .leading, spacing: expanded ? 24 : 16) {
                ForEach(timeline.passages) { passage in
                    Text(attributed(passage))
                        .font(expanded ? .title2.weight(.semibold) : .body)
                        .lineSpacing(expanded ? 8 : 3)
                        .foregroundStyle(Brand.ink).tint(Brand.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(passage.id)
                        .accessibilityIdentifier("transcript-passage-\(passage.id)")
                }
                if expanded, isCurrent, let error = model.player.error { ErrorNotice(message: error) }
            }.scrollTargetLayout().padding(.vertical, expanded ? 12 : 4)
        }
        .scrollEdgeEffectHidden(true)
        .accessibilityIdentifier("transcript-scroll")
        .scrollPosition(id: $reading.visiblePassage, anchor: .top)
        .onScrollPhaseChange { _, phase in
            if phase == .interacting { reading.followsPlayback = false }
        }
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
            reading.followsPlayback = true
            onSeek(word)
            return .handled
        })
    }

    private var followButton: some View {
        Button { reading.followsPlayback = true } label: {
            Label("Reprendre le suivi", systemImage: "arrow.down.to.line")
                .font(.subheadline.weight(.medium))
                .frame(minWidth: 44, maxWidth: expanded ? nil : .infinity, minHeight: 44, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.tint)
        .accessibilityIdentifier("transcript-follow")
        .accessibilityValue(reading.followsPlayback ? "Activé" : "Désactivé")
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
