import SwiftUI
import AVKit

struct SequenceView: View {
    @Environment(AppModel.self) private var model
    let item: FeedItem
    @State private var detail: SequenceDetail?
    @State private var error: String?
    @State private var reload = 0
    private var isCurrent: Bool { model.player.current?.id == item.id && !model.player.isPodcast }
    private var displayDetail: SequenceDetail? { isCurrent ? model.player.detail ?? detail : detail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                if model.isDemo { DemoBanner() }
                HStack { KindBadge(item: item); Spacer(); Label(item.channel, systemImage: item.media == "tv" ? "tv" : "radio").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                Text(item.title).font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-0.7)
                HStack(spacing: 13) {
                    PersonAvatar(item: item, size: 50)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.person).font(.headline)
                        Text([item.party, item.role].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if item.hasMedia {
                    if isCurrent {
                        PlayerPanel().environment(model)
                    } else {
                        Button { model.player.start(items: [item], app: model, podcast: false) } label: {
                            VStack(spacing: 20) {
                                WaveformArt().frame(height: 64).padding(.horizontal, 15)
                                HStack {
                                    Image(systemName: "play.circle.fill").font(.largeTitle)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Lire cette séquence").font(.headline)
                                        Text(model.isDemo ? "Son de démonstration · \(item.durationLabel)" : "\(item.durationLabel) · \(item.channel)").font(.caption).foregroundStyle(.white.opacity(0.65))
                                    }
                                    Spacer()
                                }
                            }.foregroundStyle(.white).padding(24)
                                .background(Brand.navy.gradient, in: RoundedRectangle(cornerRadius: 25))
                        }.buttonStyle(.plain).accessibilityIdentifier("play-sequence")
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    if !item.show.isEmpty { Label(item.show, systemImage: "antenna.radiowaves.left.and.right") }
                    if let date = item.date { Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar") }
                    if item.isCitation && !item.citedBy.isEmpty { Label("Mention par \(item.citedBy)", systemImage: "quote.bubble") }
                }.font(.caption).foregroundStyle(.secondary)
                if let error {
                    ErrorNotice(message: error) { self.error = nil; reload += 1 }
                } else if let detail = displayDetail {
                    if !detail.resume.isEmpty { textSection(title: "Résumé", text: detail.resume) }
                    if !detail.verbatim.isEmpty {
                        TranscriptView(detail: detail, timings: model.wordTimings[detail.id], isCurrent: isCurrent) { word in
                            if isCurrent { model.player.seekToWord(word, sequenceID: detail.id) }
                            else { model.player.start(items: [item], app: model, podcast: false, atWord: word) }
                        }.id(detail.id)
                    } else { Text("Le verbatim n’est pas disponible pour cette séquence.").font(.subheadline).foregroundStyle(.secondary) }
                } else { ProgressView("Chargement du verbatim…").frame(maxWidth: .infinity).padding(30) }
                Label("Consultation seule · sans export ni partage", systemImage: "lock")
                    .font(.caption2).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
            }.padding(22).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Brand.background).navigationTitle("Séquence").navigationBarTitleDisplayMode(.inline)
        .task(id: reload) {
            do { detail = try await model.sequence(item) }
            catch { if !Task.isCancelled { self.error = model.message(for: error) } }
        }
        .onDisappear { if isCurrent { model.player.stop() } }
    }
    private func textSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            Text(text).font(.body).foregroundStyle(.secondary).lineSpacing(5)
        }
    }
}

struct PlayerPanel: View {
    @Environment(AppModel.self) private var model
    private var playback: PlaybackModel { model.player }
    var body: some View {
        VStack(spacing: 18) {
            if playback.current?.video == true && !model.isDemo {
                NativeVideo(player: playback.player).aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                WaveformArt(color: Brand.blue).frame(height: 70).padding(.horizontal, 15).padding(.top, 10)
            }
            if let error = playback.error { ErrorNotice(message: error) { playback.retry() } }
            if playback.isLoading { ProgressView("Préparation de la lecture…").font(.caption) }
            VStack(spacing: 4) {
                Slider(value: Binding(get: { min(playback.position, max(1, playback.duration)) }, set: { playback.scrub(to: $0) }), in: 0...max(1, playback.duration), onEditingChanged: { editing in
                    if editing { playback.beginScrubbing() } else { playback.endScrubbing() }
                })
                    .disabled(playback.isLoading || playback.error != nil || playback.duration <= 0)
                    .accessibilityLabel("Position dans la séquence")
                    .accessibilityIdentifier("player-position")
                HStack {
                    Text(clock(playback.position)).accessibilityIdentifier("player-elapsed"); Spacer()
                    Text(playback.ended ? "Fin de la lecture" : "−\(clock(max(0, playback.duration - playback.position)))")
                }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 25) {
                if playback.isPodcast {
                    Button { playback.previous() } label: { Image(systemName: "backward.end.fill") }
                        .disabled(!playback.hasPrevious).accessibilityLabel("Séquence précédente")
                }
                Button { playback.seek(playback.position - 10) } label: { Image(systemName: "gobackward.10") }.accessibilityLabel("Reculer de 10 secondes")
                Button { playback.toggle() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : playback.ended ? "arrow.counterclockwise" : "play.fill")
                        .font(.title2).frame(width: 54, height: 54)
                }.buttonStyle(.glassProminent)
                    .accessibilityLabel(playback.isPlaying ? "Pause" : playback.ended ? "Recommencer" : "Lecture")
                    .accessibilityIdentifier("player-toggle")
                Button { playback.seek(playback.position + 10) } label: { Image(systemName: "goforward.10") }.accessibilityLabel("Avancer de 10 secondes")
                if playback.isPodcast {
                    Button { playback.next() } label: { Image(systemName: "forward.end.fill") }
                        .disabled(!playback.hasNext).accessibilityLabel("Séquence suivante").accessibilityIdentifier("player-next")
                }
            }.font(.system(size: 22)).disabled(playback.isLoading || playback.error != nil)
            if model.isDemo { Text("Audio instrumental de démonstration").font(.caption2).foregroundStyle(.secondary) }
        }.padding(20).background(Brand.card, in: RoundedRectangle(cornerRadius: 25))
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
                    if model.isDemo { DemoBanner() }
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "Le podcast de votre veille")
                        Text(model.player.current?.title ?? "Votre sélection").font(.system(.title, design: .rounded, weight: .bold))
                        Text(model.player.current?.person ?? "").font(.subheadline).foregroundStyle(.secondary)
                    }
                    PlayerPanel()
                    if let detail = model.player.detail, !detail.verbatim.isEmpty {
                        TranscriptView(detail: detail, timings: model.wordTimings[detail.id], isCurrent: true) { word in
                            model.player.seekToWord(word, sequenceID: detail.id)
                        }.id(detail.id)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text("À l’écoute").font(.title2.bold()); Spacer(); Text("\(model.player.queue.count) séquences").font(.caption).foregroundStyle(.secondary) }
                        Text("Du plus ancien au plus récent").font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(model.player.queue.enumerated()), id: \.element.id) { index, item in
                            Button { model.player.select(index) } label: {
                                HStack(spacing: 13) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(index == model.player.index ? Brand.blue : Color.primary.opacity(0.04))
                                        Image(systemName: index == model.player.index ? "waveform" : "play.fill")
                                            .foregroundStyle(index == model.player.index ? .white : .secondary)
                                    }.frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.person).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text(item.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Text(item.durationLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }.padding(.vertical, 7)
                            }.buttonStyle(.plain).accessibilityIdentifier("queue-item-\(index)")
                        }
                    }
                }.padding(22).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .background(Brand.background).navigationTitle("Podcast").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer", systemImage: "xmark") { model.player.stop() }.accessibilityIdentifier("close-podcast") } }
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
