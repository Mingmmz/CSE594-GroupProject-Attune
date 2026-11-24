import SwiftUI

@main struct AttuneApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("Attune") {
            RootView()
                .environmentObject(store)
                .environment(\.calendar, Days.pickerCalendar)
                .environment(\.timeZone, Days.pickerCalendar.timeZone)
                .tint(Theme.blue)
                .preferredColorScheme(.light)
                #if os(macOS)
                .frame(minWidth: 790, minHeight: 630)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 800)
        .windowResizability(.contentMinSize)
        #endif
    }
}

final class AppStore: ObservableObject {
    @Published private(set) var state: DemoState {
        didSet { if let encoded = try? JSONEncoder().encode(state) { defaults.set(encoded, forKey: key) } }
    }
    private let defaults: UserDefaults
    private let key = "attune.native.stage3.v1"
    var ledger: Ledger { Ledger(state: state) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(DemoState.self, from: $0) } ?? DemoState()
    }

    func draft(for log: HealthLog) -> Draft {
        if let found = state.drafts.first(where: { !$0.editing && $0.anchor == log.day && $0.metric == log.metric }) { return found }
        let nearDeadline = log.metric == .sleep && (Days.make(2026, 10, 26)...Days.make(2026, 10, 30)).contains(log.day)
        return Draft(metric: log.metric, anchor: log.day, start: nearDeadline ? Days.make(2026, 10, 26) : log.day,
                     end: nearDeadline ? Days.make(2026, 10, 30) : log.day)
    }

    func edit(_ adjustment: Adjustment) -> Draft {
        state.drafts.first { $0.id == adjustment.id } ?? adjustment.editableDraft()
    }

    func save(_ draft: Draft) {
        var next = state
        if let index = next.drafts.firstIndex(where: { $0.id == draft.id }) { next.drafts[index] = draft }
        else { next.drafts.append(draft) }
        state = next
    }

    func discard(_ id: UUID) { state.drafts.removeAll { $0.id == id } }

    func apply(_ draft: Draft) {
        var next = ledger.adding(draft).state
        next.drafts.removeAll { $0.id == draft.id }
        state = next
    }

    func revise(_ adjustment: Adjustment) {
        guard let index = state.adjustments.firstIndex(where: { $0.id == adjustment.id }) else { return }
        var next = state
        next.adjustments[index] = adjustment
        next.drafts.removeAll { $0.id == adjustment.id }
        state = next
    }

    func advance() {
        if state.day < Days.last { state.day = Days.add(state.day, 1) }
    }

    func dismiss(_ key: String) {
        if !state.dismissed.contains(key) { state.dismissed.append(key) }
    }

    func reset() { state = DemoState() }
}

enum Theme {
    static let ink = Color(red: 0.09, green: 0.15, blue: 0.23)
    static let slate = Color(red: 0.30, green: 0.37, blue: 0.46)
    static let blue = Color(red: 0.18, green: 0.32, blue: 0.49)
    static let mist = Color(red: 0.92, green: 0.95, blue: 0.98)
    static let canvas = Color(red: 0.955, green: 0.968, blue: 0.980)
    static let edge = Color(red: 0.86, green: 0.90, blue: 0.94)
    static let quiet = Color(red: 0.91, green: 0.928, blue: 0.95)
    static let green = Color(red: 0.12, green: 0.37, blue: 0.32)
    static let gold = Color(red: 0.52, green: 0.31, blue: 0.07)
    static let tierFills = [quiet, Color(red: 0.76, green: 0.85, blue: 0.94),
                            Color(red: 0.53, green: 0.69, blue: 0.84),
                            Color(red: 0.25, green: 0.43, blue: 0.60), blue]
    static let tierLabels = ["0", "1", "2–3", "4–6", "7+"]
    static func metric(_ metric: Metric) -> Color {
        switch metric {
        case .sleep: Color(red: 0.31, green: 0.27, blue: 0.64)
        case .activity: Color(red: 0.59, green: 0.31, blue: 0.10)
        case .cycle: Color(red: 0.59, green: 0.22, blue: 0.39)
        }
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat
    let content: Content
    init(_ padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding; self.content = content()
    }
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(.white, in: RoundedRectangle(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Theme.edge, lineWidth: 1).allowsHitTesting(false) }
    }
}

struct Eyebrow: View {
    var title: String
    var body: some View {
        Text(title.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1).foregroundStyle(Theme.slate).accessibilityAddTraits(.isHeader)
    }
}

struct Badge: View {
    let label: String
    var color: Color = Theme.blue
    init(_ label: String, color: Color = Theme.blue) { self.label = label; self.color = color }
    var body: some View {
        Text(label).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 5).background(color.opacity(0.1), in: Capsule())
    }
}

struct ActionButton: View {
    let title: String
    var icon: String? = nil
    var secondary = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let icon { Label(title, systemImage: icon) }
                else { Text(title) }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 43)
            .padding(.horizontal, 8)
            .foregroundStyle(secondary ? Theme.blue : Color.white)
            .background(secondary ? Theme.mist : Theme.blue, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.slate)
            .accessibilityHidden(true)
    }
}

struct MetricGlyph: View {
    let metric: Metric
    var body: some View {
        Image(systemName: metric.icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.metric(metric))
            .frame(width: 34, height: 34)
            .background(Theme.metric(metric).opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }
}

enum HomeTab: String, CaseIterable, Identifiable {
    case overview = "Overview", summary = "Summary", ask = "Ask Attune", profile = "Profile"
    var id: Self { self }
    var icon: String {
        switch self { case .overview: "chart.bar.xaxis"; case .summary: "list.bullet.rectangle"; case .ask: "sparkles"; case .profile: "person.crop.circle" }
    }
}

enum Screen: Identifiable {
    case record(HealthLog), correction(Draft), memory, adjustment(UUID), inbox, demo
    var id: String {
        switch self {
        case .record(let log): "record-" + log.id
        case .correction(let draft): "correction-" + draft.id.uuidString
        case .memory: "memory"
        case .adjustment(let id): "adjustment-" + id.uuidString
        case .inbox: "inbox"
        case .demo: "demo"
        }
    }
}

struct PageTitle: View {
    var kicker: String
    var title: String
    var detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(title: kicker)
            Text(title).font(.system(size: 36, weight: .bold)).tracking(-1.8).foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail).font(.subheadline).foregroundStyle(Theme.slate).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SheetFrame<Content: View>: View {
    var title: String
    var subtitle: String
    var back: (() -> Void)? = nil
    var close: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                if let back {
                    Button(action: back) {
                        Image(systemName: "chevron.left").font(.headline).frame(width: 31, height: 33)
                    }.buttonStyle(.plain).accessibilityLabel("Back")
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.slate)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 23)).foregroundStyle(Theme.slate.opacity(0.72))
                        .frame(width: 43, height: 43)
                }.buttonStyle(.plain).accessibilityLabel("Back to Home")
            }
            .padding(.horizontal, 17).padding(.vertical, 7)
            .background(.white)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14, content: content)
                    .frame(maxWidth: 570).padding(18)
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Theme.ink).background(Theme.canvas)
        #if os(macOS)
        .frame(width: 630, height: 675)
        #endif
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab: HomeTab = .overview
    @State private var screen: Screen?
    @State private var demoReset = 0

    var body: some View {
        HStack(spacing: 0) {
            #if os(macOS)
            sidebar
            Rectangle().fill(Theme.edge).frame(width: 1)
            #endif
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        switch tab {
                        case .overview: OverviewView(open: open).id(demoReset)
                        case .summary: SummaryView(open: open)
                        case .ask: AskView(open: open)
                        case .profile: ProfileView(open: open)
                        }
                    }
                    .frame(maxWidth: 1050)
                    .padding(.horizontal, horizontalPad)
                    .padding(.top, 12).padding(.bottom, 25)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                #if os(iOS)
                tabBar
                #endif
            }
            .background(Theme.canvas)
        }
        .foregroundStyle(Theme.ink)
        .sheet(item: $screen) { destination in
            screenView(destination).id(destination.id)
                .environmentObject(store)
                .environment(\.calendar, Days.pickerCalendar).environment(\.timeZone, Days.pickerCalendar.timeZone)
        }
    }

    private var horizontalPad: CGFloat {
        #if os(macOS)
        29
        #else
        16
        #endif
    }

    private var topBar: some View {
        HStack {
            Label("ATTUNE", systemImage: "waveform.path").font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.4).foregroundStyle(Theme.blue)
            Spacer()
            Button { open(.demo) } label: {
                Label(Days.text(store.state.day), systemImage: "calendar")
                    .font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 7)
                    .background(Color.white, in: Capsule())
            }.buttonStyle(.plain).accessibilityLabel("Demo date, " + Days.text(store.state.day))
            Button { open(.inbox) } label: {
                Image(systemName: "bell").font(.system(size: 15, weight: .semibold))
                    .frame(width: 35, height: 33).background(Color.white, in: Capsule())
            }.buttonStyle(.plain).accessibilityLabel("Follow-ups")
        }
        .padding(.horizontal, horizontalPad).padding(.vertical, 10)
        .background(Theme.canvas)
    }

    #if os(macOS)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 37, height: 37).background(Theme.blue, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Attune").font(.title3.bold())
                    Text("Personal patterns").font(.caption2).foregroundStyle(Theme.slate)
                }
            }
            .padding(.bottom, 23)
            Eyebrow(title: "Your health")
            ForEach(HomeTab.allCases) { item in
                Button { tab = item } label: {
                    Label(item.rawValue, systemImage: item.icon).font(.subheadline.weight(tab == item ? .semibold : .medium))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 9).padding(.vertical, 9)
                        .background(tab == item ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(tab == item ? Theme.blue : Theme.slate)
                }.buttonStyle(.plain)
            }
            Spacer()
            Button { open(.memory) } label: {
                Label("Memory", systemImage: "tray.full").font(.subheadline).padding(7)
            }.buttonStyle(.plain)
            Divider()
            Label("Fictional demo data", systemImage: "circle.dotted").font(.caption2)
                .foregroundStyle(Theme.slate).padding(.top, 5).padding(.bottom, 4)
        }
        .padding(15).frame(width: 178)
        .background(Theme.mist)
    }
    #endif

    #if os(iOS)
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { item in
                Button { tab = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 19, weight: .semibold))
                        Text(item.rawValue).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(tab == item ? Theme.blue : Theme.slate)
                }.buttonStyle(.plain)
            }
        }.background(.regularMaterial).overlay(alignment: .top) { Divider() }
    }
    #endif

    private func open(_ destination: Screen) { screen = destination }
    private func home() { screen = nil; tab = .overview }

    @ViewBuilder private func screenView(_ item: Screen) -> some View {
        switch item {
        case .record(let log): RecordView(log: log, open: open, close: { screen = nil })
        case .correction(let draft): CorrectionView(draft: draft, open: open, home: home, close: { screen = nil })
        case .memory: MemoryView(open: open, close: { screen = nil })
        case .adjustment(let id): AdjustmentView(id: id, open: open, close: { screen = nil })
        case .inbox: InboxView(open: open, close: { screen = nil })
        case .demo: DemoControls(close: { screen = nil }, reset: { demoReset += 1; home() })
        }
    }
}
