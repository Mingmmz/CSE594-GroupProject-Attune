import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var horizon: Horizon = .month
    @State private var anchor = Days.start
    @State private var rawView = false
    @State private var metric: Metric = .sleep
    @State private var focus: Window?
    var open: (Screen) -> Void

    private var windows: [Window] { Ledger.windows(anchor, horizon) }
    private var period: Window {
        Window(start: windows.first!.start, end: windows.last!.end,
               label: Days.text(anchor, horizon == .month ? "MMMM yyyy" : "yyyy"))
    }
    private var inFocus: Window { focus ?? period }
    private var active: [Adjustment] { store.state.adjustments.filter { $0.status(on: store.state.day) == .active } }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            PageTitle(kicker: "Your health, in context", title: "Overview", detail: "See how unusual records shape your patterns over time.")
            contextStrip
            trends
            #if os(macOS)
            HStack(alignment: .top, spacing: 15) { eventList; patterns }
            #else
            eventList
            patterns
            #endif
        }
        .onChange(of: store.state.day) { old, new in
            if Days.calendar.isDate(anchor, equalTo: old, toGranularity: horizon == .month ? .month : .year) {
                anchor = new
                focus = nil
            }
        }
    }

    private var contextStrip: some View {
        Button { open(.memory) } label: {
            HStack(spacing: 8) {
                Image(systemName: active.isEmpty ? "tray" : "checkmark.circle.fill").font(.subheadline).foregroundStyle(Theme.blue)
                Text(active.isEmpty ? "No active adjustments" : active.map { $0.reason.title }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 8)
                Text("Memory").font(.caption.weight(.semibold)).foregroundStyle(Theme.blue)
                Chevron()
            }.padding(.horizontal, 13).frame(minHeight: 43).background(Theme.mist, in: RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain)
    }

    private var trends: some View {
        Card {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(title: "Long-term patterns")
                        Text(period.label).font(.title2.bold()).tracking(-0.5)
                    }
                    Spacer(minLength: 3)
                    Button { shift(-1) } label: { controlIcon("chevron.left") }.buttonStyle(.plain)
                        .disabled(windows.first!.start <= Days.first).accessibilityLabel("Previous period")
                    Button { shift(1) } label: { controlIcon("chevron.right") }.buttonStyle(.plain)
                        .disabled(windows.last!.end >= store.state.day).accessibilityLabel("Next period")
                }
                HStack(spacing: 8) {
                    Picker("View range", selection: $horizon) {
                        ForEach(Horizon.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
                        .onChange(of: horizon) { _, _ in focus = nil }
                    Spacer(minLength: 2)
                    Button {
                        rawView.toggle()
                    } label: {
                        Label(rawView ? "Original" : "After context", systemImage: rawView ? "square.stack" : "line.3.horizontal.decrease.circle")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.blue)
                            .padding(.horizontal, 9).frame(minHeight: 35)
                            .background(Theme.mist, in: Capsule())
                    }.buttonStyle(.plain).accessibilityHint("Switch between original and after-context counts")
                }
                Text(rawView ? "Original unusual records before any adjustments." : "Unusual records still counted after your adjustments. A dot marks a period with records set aside.")
                    .font(.caption).foregroundStyle(Theme.slate)
                HeatMap(windows: windows, ledger: store.ledger, metric: metric, focus: focus, rawView: rawView) { chosenMetric, window in
                    metric = chosenMetric
                    focus = focus == window ? nil : window
                }
                HStack(spacing: 5) {
                    ForEach(Theme.tierLabels.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3).fill(Theme.tierFills[index]).frame(width: 12, height: 12)
                        Text(Theme.tierLabels[index]).font(.caption2.monospacedDigit()).foregroundStyle(Theme.slate)
                        if index < Theme.tierLabels.count - 1 { Spacer().frame(width: 3) }
                    }
                    Spacer(minLength: 2)
                    Text("— No logs").font(.caption2).foregroundStyle(Theme.slate)
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("Color key: zero, one, two to three, four to six, or seven or more unusual records. Dash means no logs.")
                Divider()
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Metric.allCases) { item in
                        TrendStat(metric: item, counts: store.ledger.totals(item, in: period))
                    }
                }
            }
        }
    }

    private var eventList: some View {
        let events = store.ledger.records(metric, in: inFocus).filter(\.unusual).reversed()
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(title: "What looked different")
                    Spacer(minLength: 4)
                    if focus != nil {
                        Button("Clear range") { focus = nil }.font(.caption)
                    }
                }
                Picker("Records category", selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
                Text(focus.map { Days.range($0.start, $0.end) } ?? period.label)
                    .font(.caption).foregroundStyle(Theme.slate)
                if events.isEmpty {
                    Text(store.ledger.records(metric, in: inFocus).isEmpty ? "No records in this range." : "No unusual records in this range.")
                        .font(.subheadline).foregroundStyle(Theme.slate).padding(.vertical, 9)
                } else {
                    ForEach(Array(events.prefix(4))) { log in RecordRow(log: log, ledger: store.ledger) { open(.record(log)) } }
                    if events.count > 4 {
                        DisclosureGroup("Show all \(events.count) records") {
                            VStack(spacing: 7) {
                                ForEach(Array(events.dropFirst(4))) { log in RecordRow(log: log, ledger: store.ledger) { open(.record(log)) } }
                            }.padding(.top, 6)
                        }.font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    private var patterns: some View {
        Card {
            VStack(alignment: .leading, spacing: 11) {
                Eyebrow(title: "Your usual pattern")
                ForEach(Metric.allCases) { item in
                    let current = store.ledger.usual(item)
                    let baseline = store.ledger.usual(item, raw: true)
                    HStack(alignment: .center, spacing: 7) {
                        MetricGlyph(metric: item)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.stat).font(.subheadline.weight(.semibold))
                            Text("\(current.used) \(item.units) used").font(.caption2).foregroundStyle(Theme.slate)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.format(current.value)).font(.subheadline.bold()).monospacedDigit()
                            if baseline.value != current.value {
                                Text("Original: " + item.format(baseline.value)).font(.caption2).foregroundStyle(Theme.slate)
                            }
                        }
                    }
                }
                Divider()
                let paused = store.ledger.reminder(metric, store.state.day)
                Text(store.ledger.coaching(metric, day: store.state.day)).font(.caption).foregroundStyle(Theme.slate)
                if paused { Badge(metric.prompt + " paused", color: Theme.gold) }
                Text("Daily estimates use the latest 30 days; cycle uses up to six logged intervals.")
                    .font(.caption2).foregroundStyle(Theme.slate)
            }
        }
    }

    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name).font(.caption.bold()).foregroundStyle(Theme.blue)
            .frame(width: 35, height: 35).background(Theme.mist, in: RoundedRectangle(cornerRadius: 8))
    }

    private func shift(_ direction: Int) {
        let unit: Calendar.Component = horizon == .month ? .month : .year
        let base = windows.first!.start
        if let next = Days.calendar.date(byAdding: unit, value: direction, to: base),
           Days.first <= next && next <= store.state.day {
            anchor = next; focus = nil
        }
    }
}

struct HeatMap: View {
    var windows: [Window]
    var ledger: Ledger
    var metric: Metric
    var focus: Window?
    var rawView: Bool
    var select: (Metric, Window) -> Void

    var body: some View {
        if windows.count == 12 {
            ViewThatFits(in: .horizontal) {
                grid(windows).frame(minWidth: 540)
                VStack(spacing: 10) {
                    grid(Array(windows.prefix(6)))
                    grid(Array(windows.suffix(6)))
                }
            }
        } else {
            grid(windows)
        }
    }

    private func grid(_ slice: [Window]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Color.clear.frame(width: 52, height: 15).accessibilityHidden(true)
                ForEach(slice) { segment in
                    Text(segment.label).font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.slate)
                        .lineLimit(1).frame(maxWidth: .infinity).accessibilityHidden(true)
                }
            }
            ForEach(Metric.allCases) { row in
                HStack(spacing: 4) {
                    Text(row.title).font(.caption.weight(.medium)).lineLimit(1)
                        .frame(width: 52, alignment: .leading)
                    ForEach(slice) { segment in
                        let count = ledger.totals(row, in: segment)
                        let shown = rawView ? count.raw : count.counted
                        let tier = TrendCount.tier(for: shown)
                        Button { select(row, segment) } label: {
                            Text(count.records == 0 ? "—" : "\(shown)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(tier >= 3 ? .white : Theme.ink)
                                .frame(maxWidth: .infinity, minHeight: 33)
                                .background(count.records == 0 ? Color.white : Theme.tierFills[tier], in: RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6).strokeBorder(metric == row && focus == segment ? Theme.ink : Theme.edge, lineWidth: metric == row && focus == segment ? 2 : 1)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if count.setAside > 0 && !rawView {
                                        Circle().fill(tier >= 3 ? Color.white : Theme.green).frame(width: 4, height: 4).padding(4)
                                    }
                                }
                        }.buttonStyle(.plain)
                            .accessibilityLabel(row.title + ", " + Days.range(segment.start, segment.end))
                            .accessibilityValue(count.records == 0 ? "No logs" : "\(shown) unusual records, \(count.setAside) set aside")
                    }
                }
            }
        }
    }
}

struct TrendStat: View {
    let metric: Metric
    let counts: TrendCount
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.metric(metric))
            if counts.records == 0 {
                Text("No logs").font(.caption.bold())
            } else {
                HStack(spacing: 3) {
                    Text("\(counts.raw)").foregroundStyle(Theme.slate)
                    Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.slate)
                    Text("\(counts.counted)").foregroundStyle(counts.setAside > 0 ? Theme.green : Theme.ink)
                }.font(.system(size: 19, weight: .bold, design: .rounded)).monospacedDigit()
            }
            Text("Original → counted").font(.system(size: 9)).foregroundStyle(Theme.slate)
        }.frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title + (counts.records == 0 ? ": no logs" : ": \(counts.raw) unusual originally, \(counts.counted) counted"))
    }
}

struct RecordRow: View {
    var log: HealthLog
    var ledger: Ledger
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                MetricGlyph(metric: log.metric)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Days.text(log.day) + " · " + log.shown).font(.subheadline.weight(.semibold))
                    Text(ledger.excluded(log) ? "Original log kept" : log.metric.measure).font(.caption2).foregroundStyle(Theme.slate)
                }
                Spacer(minLength: 3)
                Text(ledger.excluded(log) ? "Set aside" : log.unusual ? "Unusual" : "Typical")
                    .font(.caption2.weight(.semibold)).foregroundStyle(ledger.excluded(log) ? Theme.green : Theme.slate)
                Chevron()
            }.padding(7).background(Theme.canvas, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }
}

struct SummaryView: View {
    @EnvironmentObject private var store: AppStore
    var open: (Screen) -> Void
    var body: some View {
        PageTitle(kicker: Days.text(store.state.day, "EEEE, MMMM d"), title: "Summary", detail: "Latest records from your demo health journal.")
        ForEach(Metric.allCases) { metric in
            if let log = store.ledger.records(metric).last {
                Card {
                    RecordRow(log: log, ledger: store.ledger) { open(.record(log)) }
                    Text(store.ledger.interpretation(log)).font(.caption).foregroundStyle(Theme.slate).padding(.top, 5)
                }
            }
        }
        if !store.state.drafts.isEmpty {
            Card {
                Eyebrow(title: "Unfinished corrections")
                ForEach(store.state.drafts) { draft in
                    ActionButton(title: "Resume " + draft.metric.title.lowercased() + " draft", icon: "pencil", secondary: true) { open(.correction(draft)) }
                        .padding(.top, 5)
                }
            }
        }
    }
}

struct AskView: View {
    @EnvironmentObject private var store: AppStore
    @State private var metric: Metric = .sleep
    @State private var choice = 0
    var open: (Screen) -> Void

    var body: some View {
        PageTitle(kicker: "Context guide · Simulated", title: "Ask Attune", detail: "Read an explanation drawn from the demo logs and your saved adjustments.")
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Category", selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Question", selection: $choice) {
                    Text("Why this color?").tag(0)
                    Text("What counts now?").tag(1)
                    Text("What do I do next?").tag(2)
                }.pickerStyle(.segmented)
                Divider()
                Text(answer).font(.subheadline).foregroundStyle(Theme.slate)
                ActionButton(title: "View adjustments", icon: "tray.full", secondary: true) { open(.memory) }
            }
        }
    }

    private var answer: String {
        let windows = Ledger.windows(store.state.day, .month)
        let month = Window(start: windows.first!.start, end: windows.last!.end, label: "")
        let counts = store.ledger.totals(metric, in: month)
        let usual = store.ledger.usual(metric)
        switch choice {
        case 0:
            return "This month: \(counts.raw) unusual in the original logs and \(counts.counted) still counted. Each tile gets darker as that period’s count rises. \(metric.rule)"
        case 1:
            return "The usual estimate is \(metric.format(usual.value)) using \(usual.used) \(metric.units). Records set aside still appear in history, and you control when the adjustment ends."
        default:
            return store.ledger.coaching(metric, day: store.state.day) + (store.ledger.reminder(metric, store.state.day) ? " Your demo reminder is paused." : "")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    var open: (Screen) -> Void
    var body: some View {
        PageTitle(kicker: "Your controls", title: "Profile", detail: "Manage what Attune remembers about your circumstances.")
        Card {
            HStack(spacing: 11) {
                Text("M").font(.title2.bold()).foregroundStyle(Theme.blue).frame(width: 51, height: 51).background(Theme.mist, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maya").font(.title3.bold())
                    Text("Fictional demo profile").font(.caption).foregroundStyle(Theme.slate)
                }
                Spacer()
            }
        }
        Card {
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(title: "Current situations")
                let live = store.state.adjustments.filter { $0.status(on: store.state.day) == .active }
                if live.isEmpty { Text("No active adjustments.").font(.subheadline).foregroundStyle(Theme.slate) }
                ForEach(live) { rule in
                    Button { open(.adjustment(rule.id)) } label: {
                        HStack { MetricGlyph(metric: rule.metric); Text(rule.reason.title); Spacer(); Chevron() }
                    }.buttonStyle(.plain)
                }
                ActionButton(title: "Memory", icon: "tray.full") { open(.memory) }
                ActionButton(title: "Follow-ups", icon: "bell", secondary: true) { open(.inbox) }
            }
        }
        Card {
            Eyebrow(title: "Data and privacy")
            Text("This app uses fictional local records. Notes are stored on this device only. You can choose whether to keep your exact wording and can remove it later.")
                .font(.caption).foregroundStyle(Theme.slate).padding(.vertical, 5)
            ActionButton(title: "Demo controls", icon: "calendar", secondary: true) { open(.demo) }
        }
    }
}
