import SwiftUI

struct TranscriptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .body) private var textHeight = 250.0
    @State private var followsPlayback = true
    @State private var visiblePassage: Int?
    let detail: SequenceDetail
    let isCurrent: Bool
    let onSeek: (Int) -> Void
    private let standardTimeline: TranscriptTimeline
    private let largeTextTimeline: TranscriptTimeline
    private var timeline: TranscriptTimeline { dynamicType.isAccessibilitySize ? largeTextTimeline : standardTimeline }

    init(detail: SequenceDetail, timings: SequenceWordTimings? = nil, isCurrent: Bool, onSeek: @escaping (Int) -> Void) {
        self.detail = detail; self.isCurrent = isCurrent; self.onSeek = onSeek
        standardTimeline = TranscriptTimeline(detail: detail, timings: timings)
        largeTextTimeline = TranscriptTimeline(detail: detail, timings: timings, maximumWordsPerPassage: 4)
    }

    private var activeWord: Int? { timeline.wordIndex(at: isCurrent ? model.player.instant : nil) }
    private var canSeek: Bool { detail.item.hasMedia && timeline.canSynchronize }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Verbatim").font(.title2.bold())
                Spacer()
                if isCurrent {
                    Button { model.player.toggle() } label: {
                        Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill").frame(width: 30, height: 30)
                    }.buttonStyle(.glass)
                        .disabled(model.player.isLoading || model.player.error != nil)
                        .accessibilityLabel(model.player.isPlaying ? "Mettre le verbatim en pause" : "Reprendre la lecture du verbatim")
                        .accessibilityIdentifier("transcript-toggle")
                }
            }
            if canSeek {
                Text("Touchez un mot pour rejoindre ce passage.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(activeWord.map { "Mot \($0 + 1) sur \(timeline.words.count)" } ?? (isCurrent ? "Aucun mot actif" : "En attente de lecture"))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .accessibilityIdentifier("transcript-position")
                    Spacer()
                    Button { followsPlayback.toggle() } label: {
                        Label(followsPlayback ? "Suivi auto" : "Reprendre le suivi", systemImage: followsPlayback ? "checkmark.circle.fill" : "arrow.down.to.line")
                            .font(.caption.weight(.medium))
                    }.accessibilityIdentifier("transcript-follow")
                        .accessibilityValue(followsPlayback ? "Activé" : "Désactivé")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(timeline.passages) { passage in
                        Text(attributed(passage)).font(.body).lineSpacing(7)
                            .tint(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(passage.id)
                            .accessibilityIdentifier("transcript-passage-\(passage.id)")
                    }
                }.scrollTargetLayout().padding(.vertical, 4)
            }
            .frame(height: min(textHeight, 380))
            .accessibilityIdentifier("transcript-scroll")
            // Bind the inner scroll view directly: following the text must not
            // scroll the surrounding page away from the player's controls.
            .scrollPosition(id: $visiblePassage, anchor: .top)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { followsPlayback = false }
            }
            .onChange(of: timeline.passageID(forWord: activeWord)) { _, passage in
                if followsPlayback { follow(passage) }
            }
            .onChange(of: followsPlayback) { _, following in
                if following { follow(timeline.passageID(forWord: activeWord)) }
            }
            .onAppear { if followsPlayback { follow(timeline.passageID(forWord: activeWord)) } }
            .environment(\.openURL, OpenURLAction { url in
                guard canSeek, url.scheme == "infometrie-transcript", url.host == "seek",
                      url.pathComponents.count == 3, url.pathComponents[1] == String(detail.id),
                      let word = Int(url.pathComponents[2]), timeline.words.indices.contains(word) else { return .discarded }
                followsPlayback = true
                onSeek(word)
                return .handled
            })
            if isCurrent, let notice = model.player.transcriptNotice {
                Text(notice).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("transcript-notice")
            }
            if timeline.hasPreciseTimings {
                Label("Synchronisation par mot", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Brand.blue).accessibilityIdentifier("transcript-precise")
            } else if model.wordTimingStates[detail.id] == .loading {
                HStack(spacing: 8) { ProgressView(); Text("Chargement des repères précis…") }
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(canSeek
                     ? "Calage estimé : les repères précis ne sont pas disponibles pour ce texte."
                     : "Les repères temporels nécessaires à la synchronisation ne sont pas disponibles.")
                    .font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("transcript-estimated")
                if !model.isDemo, detail.item.hasMedia {
                    Button("Réessayer la synchronisation") { model.loadWordTimings(for: detail.id, retry: true) }
                        .font(.caption).accessibilityIdentifier("retry-transcript-timing")
                }
            }
        }.padding(20).background(Brand.card, in: RoundedRectangle(cornerRadius: 23))
    }

    private func follow(_ passage: Int?) {
        guard let passage else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { visiblePassage = passage }
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
                result[range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Brand.blue
                result[range][AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Brand.blue.opacity(0.16)
            }
        }
        return result
    }
}
