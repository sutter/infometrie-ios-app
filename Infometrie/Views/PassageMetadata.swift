import SwiftUI

/// The passage date as every variant writes it: `25/09 14:39`.
struct PassageDate: View {
    let item: FeedItem
    /// The Paris day the list is about (today in Live, a chosen day): a passage of that day shows its time alone.
    var day: String?

    var body: some View {
        if let date = item.date, day != nil, ParisDay.string(date) == day {
            Text(date, style: .time).foregroundStyle(Brand.secondary).monospacedDigit()
                .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
        } else if let date = item.date {
            Text("\(date, format: .dateTime.day(.twoDigits).month(.twoDigits)) \(date, style: .time)")
                .foregroundStyle(Brand.secondary).monospacedDigit()
                .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
        }
    }
}

/// The listening duration, shown only for a playable passage.
struct PassageDuration: View {
    let item: FeedItem

    var body: some View {
        if item.canPlay && item.durationSec > 0 {
            // The duration alone: the headphones icon beside it added noise, not meaning.
            Text(item.readableDuration)
                .monospacedDigit()
                .foregroundStyle(Brand.secondary)
                .fixedSize()
                .accessibilityLabel("Durée d’écoute : \(item.readableDuration)")
        }
    }
}

/// The broadcaster logo, or its name when no logo is bundled; X gets its tile.
struct ChannelSource: View {
    let item: FeedItem
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 7) {
            ChannelMark(item: item, size: size)
            if !ChannelMark.hasLogo(for: item) {
                Text(item.channel).foregroundStyle(Brand.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.isTweet ? item.kindLabel : item.channel)
    }
}

/// The passage kind as a ghost tag: its pictogram and its name in the kind's color, on a light tint of it, with no
/// outline. The solid bar beside each row already carries the color; the tag stays light. The name is in lowercase
/// since 2026-10-09: spaced capitals read letter by letter, competed with the speaker's name and widened the line.
struct KindTag: View {
    let label: String
    let kind: String
    @ScaledMetric(relativeTo: .caption) private var height = 24.0

    init(item: FeedItem) { label = item.kindLabel; kind = item.kind }
    /// A kind named on its own, as in a suivi: `kind` is an API kind (`intervention`, `citation`, `tweet`).
    init(kind: String, label: String) { self.kind = kind; self.label = label }

    var body: some View {
        HStack(spacing: 6) {
            pictogram.font(.caption2.weight(.bold))
            Text(label).font(.footnote.weight(.semibold))
                // Shrinks only when the tag would not fit: at accessibility sizes "INTERVENTION" grew wider than
                // an iPhone 13 mini and, fixed at its ideal width, pushed the whole page off the left edge.
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .foregroundStyle(FeedItem.labelColor(ofKind: kind))
        .padding(.horizontal, 9).frame(minHeight: height)
        .background(FeedItem.color(ofKind: kind).opacity(0.12), in: Capsule())
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// X uses its own mark; the other kinds an SF Symbol.
    @ViewBuilder private var pictogram: some View {
        if kind == "tweet" { Image("x.logo") } else { Image(systemName: FeedItem.symbol(ofKind: kind)) }
    }
}

/// The three kinds as pale tiles fanned out, intervention, citation and X: the app's illustration, on the
/// empty journal and the login screen. The bleu canard citation sits in front at the center.
/// A ring of the page color sets each tile apart where they overlap.
struct KindFan: View {
    @ScaledMetric(relativeTo: .title) private var tile = 56.0

    var body: some View {
        ZStack {
            kindTile("intervention", angle: -10).offset(x: -tile * 0.72, y: tile * 0.08)
            kindTile("tweet", angle: 10).offset(x: tile * 0.72, y: tile * 0.08)
            kindTile("citation", angle: 0)
        }
        .frame(height: tile * 1.35)
        .accessibilityHidden(true)
    }

    private func kindTile(_ kind: String, angle: Double) -> some View {
        RoundedRectangle(cornerRadius: tile * 0.27, style: .continuous)
            .fill(FeedItem.wash(ofKind: kind))
            .frame(width: tile, height: tile)
            .overlay {
                Group { if kind == "tweet" { Image("x.logo") } else { Image(systemName: FeedItem.symbol(ofKind: kind)) } }
                    .font(.title2.weight(.semibold)).foregroundStyle(FeedItem.color(ofKind: kind))
            }
            .padding(3)
            .background(Brand.background, in: RoundedRectangle(cornerRadius: tile * 0.3, style: .continuous))
            .rotationEffect(.degrees(angle))
    }
}

/// The small gray title of a section ("Apparence", "Votre abonnement"…): one style for every section label.
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The person and their party on one line, then their role when it adds something.
struct PassageSpeaker: View {
    let item: FeedItem
    var nameFont: Font = .subheadline
    var lineLimit: Int? = 2
    /// A seen passage steps back: the name turns secondary like the title.
    var dimmed = false
    /// 14 pt at the default size, a step under the name, scaled like `footnote` (13 until 2026-10-09).
    @ScaledMetric(relativeTo: .footnote) private var roleSize = 14.0

    var body: some View {
        let party = item.party.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = item.role.trimmingCharacters(in: .whitespacesAndNewlines)
        let repeatsParty = role.range(of: party, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
            || party.range(of: role, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        let name = Text(item.person).font(nameFont.weight(.semibold)).foregroundStyle(dimmed ? Brand.secondary : Brand.ink)
        // Name and party share one color (the user, 2026-10-09); the separator and the role stay gray.
        let partyText = Text(party).font(nameFont).foregroundStyle(dimmed ? Brand.secondary : Brand.ink)
        VStack(alignment: .leading, spacing: 1) {
            // Name · party on one line when it fits; otherwise the party moves below, never leaving a lone "·".
            ViewThatFits(in: .horizontal) {
                (party.isEmpty ? name : name + Text(" · ").font(nameFont).foregroundStyle(Brand.secondary) + partyText)
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 1) {
                    name.lineLimit(lineLimit)
                    if !party.isEmpty { partyText.lineLimit(lineLimit) }
                }
            }
            if !role.isEmpty && (party.isEmpty || !repeatsParty) {
                Text(role).font(.system(size: roleSize)).foregroundStyle(Brand.secondary).lineLimit(lineLimit)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The top of a passage page, in the order of the user's reference: kind, date and duration with the
/// channel logo on the right; the person, party and role; then the title.
struct PassageHeading: View {
    let item: FeedItem
    let titleIdentifier: String
    /// The passage page links the speaker to their profile when they belong to the panel.
    var linksPerson = false
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        // The context (12 inside), then the title, 24 apart on the 8 pt grid. The title speaks for
        // itself: no "Propos" label above it.
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                facts
                speaker
            }
            // `title3` (20 pt) since 2026-10-09, `title2` before: still above the feed card's 18 pt.
            Text(item.displayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(titleIdentifier)
        }
    }

    @ViewBuilder private var speaker: some View {
        let speaker = PassageSpeaker(item: item, nameFont: .headline, lineLimit: nil)
        if linksPerson, model.persons.contains(where: { $0.name == item.person }) {
            NavigationLink { PersonView(name: item.person) } label: {
                // The name keeps the full width it is offered, so its ViewThatFits wraps; in an HStack beside a
                // Spacer it measured its ideal one-line width and pushed the page off screen at accessibility sizes.
                speaker
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 28)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.secondary).accessibilityHidden(true)
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ouvre sa fiche")
            .accessibilityIdentifier("sequence-person")
        } else { speaker }
    }

    /// One line when it fits; otherwise kind and logo, then date and duration.
    @ViewBuilder private var facts: some View {
        let kind = KindTag(item: item)
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    kind; PassageDate(item: item); channelName; PassageDuration(item: item); ChannelMark(item: item)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        kind; PassageDate(item: item); channelName; PassageDuration(item: item)
                        Spacer(minLength: 0); ChannelMark(item: item, size: 24)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) { kind; Spacer(minLength: 0); ChannelMark(item: item, size: 24) }
                        HStack(spacing: 10) { PassageDate(item: item); channelName; Spacer(minLength: 0); PassageDuration(item: item) }
                    }
                }
            }
        }
        .font(.footnote)
    }

    /// The logo names the channel; its name shows only when no logo is bundled.
    @ViewBuilder private var channelName: some View {
        if !ChannelMark.hasLogo(for: item) { Text(item.channel).foregroundStyle(Brand.secondary) }
    }
}

extension FeedItem {
    /// Vermillon for interventions, bleu canard for citations, noir chaud otherwise (X): bars, outlines and checkboxes.
    static func color(ofKind kind: String) -> Color {
        kind == "intervention" ? Brand.intervention : kind == "citation" ? Brand.citation : Brand.ink
    }
    /// The kind's small text on the page, a step deeper than its bar for 4.5:1.
    static func labelColor(ofKind kind: String) -> Color {
        kind == "intervention" ? Brand.interventionLabel : kind == "citation" ? Brand.citationLabel : Brand.ink
    }
    /// The kind as a solid fill under white text (X: noir chaud under blanc cassé, inverted in dark).
    static func fill(ofKind kind: String) -> Color {
        kind == "intervention" ? Brand.interventionFill : kind == "citation" ? Brand.citationFill : Brand.primary
    }
    static func wash(ofKind kind: String) -> Color {
        kind == "intervention" ? Brand.interventionWash : kind == "citation" ? Brand.citationWash : Brand.surface
    }
    var kindColor: Color { Self.color(ofKind: kind) }
    static func symbol(ofKind kind: String) -> String {
        kind == "tweet" ? "text.bubble" : kind == "citation" ? "quote.bubble" : kind == "intervention" ? "waveform" : "doc.text"
    }
    var kindSymbol: String { Self.symbol(ofKind: kind) }

    var readableDuration: String {
        let seconds = max(0, durationSec)
        if seconds < 60 { return "\(seconds) s" }
        let remainder = seconds % 60
        return remainder == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(remainder) s"
    }
}
