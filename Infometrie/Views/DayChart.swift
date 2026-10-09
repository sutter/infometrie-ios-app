import Charts
import SwiftUI

/// The journal's header, the same in every period: what span, how many passages. Live adds how fresh it is;
/// 7 j and 30 j add the chart of the checked kinds, where touching a bar shows that day in the list.
/// Live has no chart (2026-10-09): its 7-day strip repeated 7 j's with other rules and jumped to 7 j on a touch.
struct FeedDayChart: View {
    @Environment(AppModel.self) private var model
    /// "Tout écouter" (and "Rechercher" on iPad), at the end of the count's line: on a row of its own it cost
    /// about 60 pt above the cards (2026-10-09).
    let listen: AnyView

    var body: some View {
        if model.period.isLive { LiveHeader(listen: listen) } else { period }
    }

    private var period: some View {
        VStack(alignment: .leading, spacing: 8) {
            PeriodHeader(listen: listen)
            DayChart(days: model.historyDays, counts: model.dayCounts, kinds: model.filters.selectedKinds,
                     loading: model.dayCounts.isEmpty && model.isLoadingDayCounts, selectedDay: model.selectedDay,
                     identifier: "feed-day") { day in
                let next = model.selectedDay == day ? nil : day
                Task { await model.selectDay(next) }
            }
        }
    }
}

/// Passages per complete Paris day, the given kinds stacked in their colors. With `select`, touching a bar
/// reports its day, and sliding across the bars reports each new day under the finger; without it, the chart only reads.
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
    /// Compact, the user's pick on 2026-10-08 (option A of a sheet of four): at 120 pt the chart crowded out the
    /// cards; 64 pt until 2026-10-09, when the header above it made the block too tall.
    @ScaledMetric(relativeTo: .body) private var height = 56.0
    @ScaledMetric(relativeTo: .caption2) private var labelHeight = 18.0
    /// The last day a slide reached: the selection given back may lag behind, and reporting that day again would unselect it.
    @State private var slidDay: String?

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

    /// A week labels every day.
    private var isWeek: Bool { days.count <= 7 }
    private var labelStride: Int { isWeek ? 1 : 7 }
    /// Only the real yesterday reads "hier": a period stepped back ends earlier.
    private var yesterday: String? { ParisDay.days(count: 1, before: Date()).first }
    /// Sparse or very large labels at the edges grow inward, or the screen edge cuts them ("09/…").
    private var anchorsEdges: Bool { labelStride > 1 || dynamicType.isAccessibilitySize }

    /// Loaded, and nothing on any day: the bars would vanish and leave the dates alone.
    private var isEmpty: Bool { !loading && !days.isEmpty && segments.allSatisfy { $0.count == 0 } }
    /// At least 1, so a chart of empty days keeps a scale.
    private var peak: Int {
        max(1, segments.reduce(into: [String: Int]()) { $0[$1.day, default: 0] += $1.count }.values.max() ?? 1)
    }

    var body: some View {
        Chart(segments) { segment in
            // A week keeps slim 18 pt bars instead of filling its seventh of the width.
            BarMark(x: .value("Jour", segment.day), y: .value("Passages", segment.count),
                    width: isWeek ? .fixed(18) : .ratio(0.62))
                .foregroundStyle(FeedItem.color(ofKind: segment.kind))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.isTop ? 3 : 0, topTrailingRadius: segment.isTop ? 3 : 0))
                .opacity(selectedDay == nil || selectedDay == segment.day ? 1 : 0.3)
        }
        // A baseline keeps the chart's place on the page, empty days included.
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let plot = proxy.plotFrame {
                    let frame = geometry[plot]
                    Rectangle().fill(Brand.rule).frame(width: frame.width, height: 1)
                        .offset(x: frame.minX, y: frame.maxY - 1)
                    if isEmpty {
                        Text("Aucun passage sur ces jours").font(.footnote).foregroundStyle(Brand.secondary)
                            .frame(width: frame.width, height: frame.height).offset(x: frame.minX, y: frame.minY)
                    }
                }
            }
            .accessibilityHidden(true)
        }
        .chartYScale(domain: 0...peak)
        // The day labels are drawn by hand: on iOS 27 the axis ignored its chosen values and labeled all 30 days.
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            if let select {
                GeometryReader { geometry in
                    let day = { (location: CGPoint) -> String? in
                        guard let plot = proxy.plotFrame else { return nil }
                        return proxy.value(atX: location.x - geometry[plot].origin.x, as: String.self)
                    }
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in if let day = day(location) { select(day) } }
                        // Sliding across the bars selects the day under the finger. Only a horizontal slide
                        // counts, so the journal still scrolls vertically from the chart.
                        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { drag in
                            guard abs(drag.translation.width) > abs(drag.translation.height),
                                  let day = day(drag.location), day != (slidDay ?? selectedDay) else { return }
                            slidDay = day
                            select(day)
                        }
                        .onEnded { _ in slidDay = nil })
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
        let text = Text(day == yesterday ? "hier" : DayLabel.short(day))
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

/// The period or the chosen day above the chart, the total first (the user's pick on 2026-10-09, option C of
/// sheet 04): what it is, how many passages, when. On the right, the arrows step whole periods, back through
/// calendar weeks and months; once a day is chosen they step days, beside the cross that restores the period.
private struct PeriodHeader: View {
    @Environment(AppModel.self) private var model
    let listen: AnyView

    private var day: String? { model.selectedDay }
    private var counts: [DayCount] { model.dayCounts.filter { day == nil || $0.day == day } }
    private var total: Int { counts.reduce(0) { $0 + $1.total(for: model.filters) } }
    private var loading: Bool { model.dayCounts.isEmpty && model.isLoadingDayCounts }

    /// When, short enough for one line beside the arrows on a 375 pt iPhone: the dates ("2 – 8 oct.", the tab
    /// already says 7 j), "Septembre" for a past month, or the chosen day, "dimanche 27 sept.".
    private var title: String {
        if let day { return DayLabel.compact(day) }
        guard let first = model.historyDays.first, let last = model.historyDays.last else { return "" }
        return model.period == .month && model.periodOffset > 0 ? DayLabel.month(first) : DayLabel.shortRange(first, last)
    }

    var body: some View {
        JournalHeader(title: title, total: total, loading: loading,
                      identifier: day == nil ? "feed-status" : "feed-day-selection", listen: listen) { controls }
            .sensoryFeedback(.selection, trigger: model.periodOffset)
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 4) {
            if let day {
                let index = model.historyDays.firstIndex(of: day)
                ArrowPair(previous: target(index, -1).map { target in { Task { await model.selectDay(target) } } },
                          next: target(index, 1).map { target in { Task { await model.selectDay(target) } } },
                          previousLabel: "Jour précédent", nextLabel: "Jour suivant", id: "feed-day")
                Button { Task { await model.selectDay(nil) } } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Brand.ink)
                        .frame(width: 32, height: 32).background(Circle().fill(Brand.surface))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toute la période")
                .accessibilityIdentifier("feed-day-clear")
            } else {
                let unit = model.period == .week ? "Semaine" : "Mois"
                ArrowPair(previous: model.canStepBack ? { Task { await model.stepPeriod(1) } } : nil,
                          next: model.periodOffset > 0 ? { Task { await model.stepPeriod(-1) } } : nil,
                          previousLabel: "\(unit) précédent\(unit == "Semaine" ? "e" : "")",
                          nextLabel: model.periodOffset == 1 ? "Derniers jours" : "\(unit) suivant\(unit == "Semaine" ? "e" : "")",
                          // Far back in weeks, a third button returns to the latest days in one touch.
                          latest: model.periodOffset >= 2 ? { Task { await model.stepPeriod(-model.periodOffset) } } : nil,
                          id: "feed-period")
            }
        }
    }

    private func target(_ index: Int?, _ offset: Int) -> String? {
        index.map { $0 + offset }.flatMap { model.historyDays.indices.contains($0) ? model.historyDays[$0] : nil }
    }
}

/// Live's header, in the period header's look: "Aujourd'hui" and how fresh the list is, today's passages since
/// midnight in Paris from `/days`. No arrows: the past is in 7 j and 30 j.
private struct LiveHeader: View {
    @Environment(AppModel.self) private var model
    let listen: AnyView

    var body: some View {
        // Re-read the age every 15 seconds; the feed itself refreshes every 30.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            JournalHeader(title: "Aujourd’hui", note: model.lastRefresh.map { LiveAge.label(of: $0, at: context.date) },
                          total: model.todayCounts?.total(for: model.filters) ?? 0, loading: model.todayCounts == nil,
                          identifier: "feed-status", listen: listen) { EmptyView() }
        }
    }
}

/// The age of Live's last refresh, short enough for one line: "à l'instant", "il y a 3 min", "il y a 2 h".
enum LiveAge {
    static func label(of date: Date, at now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "à l’instant" }
        if seconds < 3_600 { return "il y a \(Int(seconds / 60)) min" }
        return "il y a \(Int(seconds / 3_600)) h"
    }
}

/// Two lines in every period and for a chosen day, so the header keeps its height (the user, 2026-10-09): when,
/// bold on one line, with the arrows at its end; then how many passages, with "Tout écouter" at its end. The time
/// in interventions was removed the same day. At accessibility sizes everything stacks.
private struct JournalHeader<Controls: View>: View {
    let title: String
    /// Small and gray after the title: Live's freshness.
    var note: String?
    let total: Int
    let loading: Bool
    let identifier: String
    let listen: AnyView
    @ViewBuilder let controls: Controls
    @Environment(\.dynamicTypeSize) private var dynamicType
    private static var french: Locale { Locale(identifier: "fr_FR") }

    private var passages: String { total <= 1 ? "passage" : "passages" }

    var body: some View {
        if dynamicType.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) { titleText; countText }
                controls
                listen
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) { titleText; Spacer(minLength: 0); controls }
                // The button keeps its 44 pt to touch but not in the layout, so the line stays as tall as its text.
                HStack(spacing: 8) { countText; Spacer(minLength: 0); listen.padding(.vertical, -8) }
            }
        }
    }

    /// Carries the whole summary for VoiceOver and the UI tests: "2 – 8 oct., 56 passages".
    private var titleText: some View {
        (Text(title.prefix(1).uppercased(with: Self.french) + title.dropFirst()).font(.title3.weight(.bold)).foregroundStyle(Brand.ink)
            + Text(note.map { "  \($0)" } ?? "").font(.footnote).foregroundStyle(Brand.secondary))
            // One line at standard sizes, shrinking a little before it would wrap; accessibility sizes wrap.
            .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(dynamicType.isAccessibilitySize ? 1 : 0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([title, note, "\(total) \(passages)"].compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(identifier)
    }

    private var countText: some View {
        // French groups thousands with a narrow no-break space, which this font draws almost invisibly ("5623"):
        // a plain no-break space reads "5 623".
        (Text(total.formatted(.number.locale(Self.french)).replacingOccurrences(of: "\u{202F}", with: "\u{00A0}"))
            .fontWeight(.semibold).foregroundStyle(Brand.ink)
            + Text(" \(passages)").foregroundStyle(Brand.secondary))
            .font(.subheadline.monospacedDigit())
            .contentTransition(.numericText())
            .skeleton(loading)
            .accessibilityHidden(true)
    }
}

/// Back and forward as one capsule of 44 pt buttons; a missing action disables its side. With `latest`,
/// a third button jumps to the latest days, shown only when it saves several touches.
private struct ArrowPair: View {
    let previous: (() -> Void)?
    let next: (() -> Void)?
    let previousLabel: String
    let nextLabel: String
    var latest: (() -> Void)?
    /// `<id>-previous`, `<id>-next` and `<id>-latest`.
    let id: String

    var body: some View {
        HStack(spacing: 0) {
            arrow("chevron.left", action: previous, label: previousLabel, id: "\(id)-previous")
            divider
            arrow("chevron.right", action: next, label: nextLabel, id: "\(id)-next")
            if let latest {
                divider
                arrow("forward.end", action: latest, label: "Revenir aux derniers jours", id: "\(id)-latest")
            }
        }
        .background(Capsule().fill(Brand.surface))
    }

    private var divider: some View { Rectangle().fill(Brand.rule).frame(width: 1, height: 20).accessibilityHidden(true) }

    private func arrow(_ icon: String, action: (() -> Void)?, label: String, id: String) -> some View {
        Button { action?() } label: {
            Image(systemName: icon).font(.body.weight(.semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(action == nil ? Brand.secondary.opacity(0.5) : Brand.ink)
        .disabled(action == nil)
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
        return "\(date.formatted(Date.FormatStyle(locale: french, timeZone: ParisDay.timeZone).weekday(.wide))) \(dayMonth(day))"
    }
    /// "7 octobre", "1er octobre": French writes the first of the month as an ordinal.
    static func dayMonth(_ day: String) -> String {
        guard let date = ParisDay.date(day) else { return day }
        return "\(dayNumber(date)) \(date.formatted(Date.FormatStyle(locale: french, timeZone: ParisDay.timeZone).month(.wide)))"
    }
    /// "Septembre", with the year when it is not the current one: "Décembre 2025".
    static func month(_ day: String, now: Date = Date()) -> String {
        guard let date = ParisDay.date(day) else { return day }
        let style = Date.FormatStyle(locale: french, timeZone: ParisDay.timeZone)
        let sameYear = ParisDay.calendar.isDate(date, equalTo: now, toGranularity: .year)
        let name = date.formatted(sameYear ? style.month(.wide) : style.month(.wide).year())
        return name.prefix(1).uppercased(with: french) + name.dropFirst()
    }
    /// "dimanche 27 sept.": the weekday whole, the month abbreviated.
    static func compact(_ day: String) -> String {
        guard let date = ParisDay.date(day) else { return day }
        return "\(date.formatted(Date.FormatStyle(locale: french, timeZone: ParisDay.timeZone).weekday(.wide))) \(shortDayMonth(day))"
    }
    /// "27 sept.", "1er oct.", "4 mai".
    static func shortDayMonth(_ day: String) -> String {
        guard let date = ParisDay.date(day) else { return day }
        return "\(dayNumber(date)) \(date.formatted(Date.FormatStyle(locale: french, timeZone: ParisDay.timeZone).month(.abbreviated)))"
    }
    /// "2 – 8 oct.", or "28 sept. – 4 oct." across months.
    static func shortRange(_ first: String, _ last: String) -> String {
        guard let start = ParisDay.date(first), let end = ParisDay.date(last) else { return "\(first) – \(last)" }
        let sameMonth = ParisDay.calendar.isDate(start, equalTo: end, toGranularity: .month)
        return "\(sameMonth ? dayNumber(start) : shortDayMonth(first)) – \(shortDayMonth(last))"
    }
    private static func dayNumber(_ date: Date) -> String {
        let number = ParisDay.calendar.component(.day, from: date)
        return number == 1 ? "1er" : "\(number)"
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
