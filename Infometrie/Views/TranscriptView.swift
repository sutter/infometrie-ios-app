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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "text.quote").foregroundStyle(Brand.blue).accessibilityHidden(true)
                    Text("Le texte")
                        .accessibilityIdentifier("transcript-position")
                        .accessibilityValue(activeWord.map { "Mot \($0 + 1) sur \(timeline.words.count)" } ?? (isCurrent ? "Aucun mot actif" : "En attente de lecture"))
                }.font(.headline)
                if canSeek {
                    Text("Touchez un mot pour rejoindre ce passage.")
                        .font(.subheadline).foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                .scrollEdgeEffectHidden(true)
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
            }.padding(20)

            VStack(alignment: .leading, spacing: 10) {
                if canSeek, isCurrent {
                    Button { followsPlayback.toggle() } label: {
                        Label(followsPlayback ? "Suivi de l’écoute activé" : "Reprendre le suivi", systemImage: followsPlayback ? "checkmark.circle.fill" : "arrow.down.to.line")
                            .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(Brand.blue).accessibilityIdentifier("transcript-follow")
                        .accessibilityValue(followsPlayback ? "Activé" : "Désactivé")
                }
                if isCurrent, let notice = model.player.transcriptNotice {
                    Text(notice).font(.footnote).foregroundStyle(.primary).accessibilityIdentifier("transcript-notice")
                }
                if timeline.hasPreciseTimings {
                    Label("Synchronisation par mot", systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(Brand.blue).accessibilityIdentifier("transcript-precise")
                } else if model.wordTimingStates[detail.id] == .loading {
                    HStack(spacing: 8) { ProgressView(); Text("Chargement des repères précis…") }
                        .font(.footnote).foregroundStyle(Brand.secondary)
                } else {
                    Text(canSeek
                         ? "Calage estimé : le texte peut être décalé."
                         : "Les repères temporels nécessaires à la synchronisation ne sont pas disponibles.")
                        .font(.footnote).foregroundStyle(Brand.secondary).accessibilityIdentifier("transcript-estimated")
                    if !model.isDemo, detail.item.hasMedia {
                        Button("Réessayer la synchronisation") { model.loadWordTimings(for: detail.id, retry: true) }
                            .buttonStyle(ActionButtonStyle()).accessibilityIdentifier("retry-transcript-timing")
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.blue.opacity(0.04))
        }
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.06)) }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
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
