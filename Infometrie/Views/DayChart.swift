import Charts
import SwiftUI

/// The journal's chart in 7 j and 30 j: the checked kinds of the period, and the chosen day with its row.
/// Touching a bar shows that day in the list; touching it again, or the cross, shows the whole period.
struct FeedDayChart: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DayChart(days: model.historyDays, counts: model.dayCounts, kinds: model.filters.selectedKinds,
                     loading: model.dayCounts.isEmpty && model.isLoadingHistory, selectedDay: model.selectedDay,
                     identifier: "feed-day") { day in
                let next = model.selectedDay == day ? nil : day
                Task { await model.selectDay(next) }
            }
            if let day = model.selectedDay { DaySelection(day: day) }
        }
    }
}

/// Passages per complete Paris day, the given kinds stacked in their colors. With `select`, touching a bar
/// reports its day; without it, the chart only reads.
struct DayChart: View {
    let days: [String]
    let counts: [DayCount]
    let kinds: [String]
    var loading = false
    var selectedDay: String?
    /// Prefix of the identifiers: `<identifier>-chart`, and `<identifier>-<yyyy-mm-dd>` per day.
    var identifier = "day"
    var select: ((String) -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicType
    /// Compact, the user's pick on 2026-10-08 (option A of a sheet of four): at 120 pt the chart crowded out the cards.
    @ScaledMetric(relativeTo: .body) private var height = 64.0
    @ScaledMetric(relativeTo: .caption2) private var labelHeight = 18.0

    private struct Segment: Identifiable {
        let day: String
        let kind: String
        let count: Int
        /// The top of the day's stack gets the rounded corners.
        var isTop = false
        var id: String { "\(day)-\(kind)" }
    }

    private var byDay: [String: DayCount] {
        Dictionary(counts.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
    }
    /// Stacked bottom to top in the order of the type checkboxes.
    private var segments: [Segment] {
        let byDay = byDay
        return days.flatMap { day in
            var stack = kinds.map { kind in
                // While loading, a gentle wave stands in for the bars under the skeleton.
                let value = loading ? 3 + Int((day.utf8.last ?? 0) & 3) : byDay[day]?.count(ofKind: kind) ?? 0
                return Segment(day: day, kind: kind, count: value)
            }
            if let top = stack.lastIndex(where: { $0.count > 0 }) { stack[top].isTop = true }
            return stack
        }
    }
    /// Every day of a week; over 30 days, yesterday then every seventh day before it, like the client's
    /// reference chart. At accessibility sizes only the first and the last of them fit.
    private var labeledDays: [String] {
        let labeled = days.enumerated().filter { (days.count - 1 - $0.offset) % labelStride == 0 }.map(\.element)
        guard dynamicType.isAccessibilitySize, let first = labeled.first, let last = labeled.last, first != last else { return labeled }
        return [first, last]
    }

    private var labelStride: Int { days.count <= 7 ? 1 : 7 }
    /// Sparse or very large labels at the edges grow inward, or the screen edge cuts them ("09/…").
    private var anchorsEdges: Bool { labelStride > 1 || dynamicType.isAccessibilitySize }

    var body: some View {
        Chart(segments) { segment in
            // A week keeps slim 18 pt bars instead of filling its seventh of the width.
            BarMark(x: .value("Jour", segment.day), y: .value("Passages", segment.count),
                    width: days.count <= 7 ? .fixed(18) : .ratio(0.62))
                .foregroundStyle(FeedItem.color(ofKind: segment.kind))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.isTop ? 3 : 0, topTrailingRadius: segment.isTop ? 3 : 0))
                .opacity(selectedDay == nil || selectedDay == segment.day ? 1 : 0.3)
        }
        // The day labels are drawn by hand: on iOS 27 the axis ignored its chosen values and labeled all 30 days.
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            if let select {
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            let x = location.x - geometry[plot].origin.x
                            if let day = proxy.value(atX: x, as: String.self) { select(day) }
                        }
                }
            }
        }
        .chartOverlay(alignment: .topLeading) { proxy in
            GeometryReader { geometry in
                if let plot = proxy.plotFrame {
                    let frame = geometry[plot]
                    ForEach(labeledDays, id: \.self) { day in
                        if let x = proxy.position(forX: day) { dayLabel(day, at: frame.minX + x, width: geometry.size.width, top: frame.maxY + 4) }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(height: min(height, 110))
        .padding(.bottom, labelHeight)
        .skeleton(loading)
        .sensoryFeedback(.selection, trigger: selectedDay)
        // One VoiceOver element per day, laid over its bar, which also lets UI tests touch a day.
        .accessibilityElement(children: .contain)
        .accessibilityChildren {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    Rectangle()
                        .accessibilityLabel(DayLabel.spoken(day, counts: byDay[day], kinds: kinds))
                        .accessibilityValue(selectedDay == day ? "Sélectionné" : "")
                        .accessibilityAddTraits(select == nil ? [] : .isButton)
                        .accessibilityAction { select?(day) }
                        .accessibilityIdentifier("\(identifier)-\(day)")
                }
            }
        }
        .accessibilityLabel("Passages par jour")
        .accessibilityIdentifier("\(identifier)-chart")
    }

    /// Centered under its bar; at the edges it starts or ends at the bar's center.
    @ViewBuilder private func dayLabel(_ day: String, at x: CGFloat, width: CGFloat, top: CGFloat) -> some View {
        let text = Text(day == days.last ? "hier" : DayLabel.short(day))
            .font(.caption2.monospacedDigit()).foregroundStyle(Brand.secondary)
            .fixedSize()
        if anchorsEdges && day == labeledDays.last {
            text.frame(width: width, alignment: .trailing).offset(x: x - width, y: top)
        } else if anchorsEdges && day == labeledDays.first {
            text.frame(width: width, alignment: .leading).offset(x: x, y: top)
        } else {
            text.frame(width: width, alignment: .center).offset(x: x - width / 2, y: top)
        }
    }
}

/// The chosen day: previous and next as 44 pt buttons, since a bar of a 30-day chart is about 9 pt wide.
private struct DaySelection: View {
    @Environment(AppModel.self) private var model
    let day: String

    private var index: Int? { model.historyDays.firstIndex(of: day) }
    private var total: Int? { model.dayCounts.first { $0.day == day }?.total(for: model.filters) }

    var body: some View {
        HStack(spacing: 4) {
            step("chevron.left", label: "Jour précédent", id: "feed-day-previous", offset: -1)
            VStack(alignment: .leading, spacing: 2) {
                Text(DayLabel.long(day)).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                if let total {
                    Text(total <= 1 ? "\(total) passage" : "\(total) passages")
                        .font(.footnote.monospacedDigit()).foregroundStyle(Brand.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("feed-day-selection")
            step("chevron.right", label: "Jour suivant", id: "feed-day-next", offset: 1)
            Button { Task { await model.selectDay(nil) } } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Brand.ink)
            .accessibilityLabel("Toute la période")
            .accessibilityIdentifier("feed-day-clear")
        }
    }

    private func step(_ icon: String, label: String, id: String, offset: Int) -> some View {
        let target = index.map { $0 + offset }.flatMap { model.historyDays.indices.contains($0) ? model.historyDays[$0] : nil }
        return Button { if let target { Task { await model.selectDay(target) } } } label: {
            Image(systemName: icon).font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(target == nil ? Brand.secondary.opacity(0.5) : Brand.ink)
        .disabled(target == nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// Paris days as people read them.
enum DayLabel {
    private static let french = Locale(identifier: "fr_FR")

    /// "07/10".
    static func short(_ day: String) -> String {
        let parts = day.split(separator: "-")
        return parts.count == 3 ? "\(parts[2])/\(parts[1])" : day
    }
    /// "mercredi 7 octobre".
    static func long(_ day: String) -> String {
        guard let date = ParisDay.date(day) else { return day }
        return date.formatted(Date.FormatStyle(locale: french, timeZone: ParisDay.timeZone).weekday(.wide).day().month(.wide))
    }
    /// "mercredi 7 octobre, 2 interventions, 40 citations".
    static func spoken(_ day: String, counts: DayCount?, kinds: [String]) -> String {
        let parts = kinds.map { kind -> String in
            let count = counts?.count(ofKind: kind) ?? 0
            let name = kind == "intervention" ? "intervention" : kind == "citation" ? "citation" : "publication X"
            return count == 1 ? "1 \(name)" : "\(count) \(name == "publication X" ? "publications X" : name + "s")"
        }
        return ([long(day)] + parts).joined(separator: ", ")
    }
}
