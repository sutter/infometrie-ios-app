import SwiftUI

/// A second presentation of the same transcript and player, never a second player.
struct TranscriptFullscreenView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicType
    let detail: SequenceDetail
    let reading: TranscriptReadingState

    private var isCurrent: Bool { model.player.current?.id == detail.id && !model.player.isPodcast }
    private var currentDetail: SequenceDetail { isCurrent ? model.player.detail ?? detail : detail }

    var body: some View {
        VStack(spacing: 0) { readingContent }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fullscreen-transcript")
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { dismiss() }
    }

    private var readingContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentDetail.item.person).font(.headline)
                        .lineLimit(dynamicType.isAccessibilitySize ? 2 : 1)
                    Text(currentDetail.item.channel).font(.subheadline).foregroundStyle(Brand.secondary)
                        .lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Brand.tint)
                .accessibilityLabel("Réduire le texte")
                .accessibilityIdentifier("collapse-transcript")
            }
            .padding(.vertical, 12)

            TranscriptView(detail: currentDetail, timings: model.wordTimings[detail.id], isCurrent: isCurrent,
                           reading: reading, expanded: true) { word in
                if isCurrent { model.player.seekToWord(word, sequenceID: detail.id) }
                else { model.player.start(items: [detail.item], app: model, podcast: false, atWord: word) }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if currentDetail.item.canPlay {
                if isCurrent { PlaybackDock(compact: true) }
                else {
                    Button { model.player.start(items: [detail.item], app: model, podcast: false) } label: {
                        Label("Écouter ce passage", systemImage: "play.fill")
                    }
                    .buttonStyle(ActionButtonStyle(prominent: true))
                    .accessibilityIdentifier("play-sequence")
                    .padding(16).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
                    .background(Brand.background).overlay(alignment: .top) { AppRule() }
                }
            }
        }
        .foregroundStyle(Brand.ink).tint(Brand.tint)
        .background(Brand.background)
    }
}
