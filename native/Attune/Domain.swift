import Foundation

enum Days {
    static let zone = TimeZone(secondsFromGMT: 0)!
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func make(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func add(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    static func normalized(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static var pickerCalendar: Calendar {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        return local
    }

    static func toPicker(_ day: Date, using local: Calendar = pickerCalendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = 12
        return local.date(from: parts)!
    }

    static func fromPicker(_ selection: Date, using local: Calendar = pickerCalendar) -> Date {
        let parts = local.dateComponents([.year, .month, .day], from: selection)
        return calendar.date(from: parts)!
    }

    static func text(_ date: Date, _ pattern: String = "MMM d") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = pattern
        return f.string(from: date)
    }

    static func range(_ start: Date, _ end: Date?) -> String {
        guard let end else { return text(start) + " onward" }
        return start == end ? text(start) : text(start) + " – " + text(end)
    }

    static let first = make(2026, 1, 1)
    static let start = make(2026, 10, 29)
    static let last = make(2026, 11, 15)
    static let lastEditable = make(2028, 12, 31)
    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
}

enum Metric: String, Codable, CaseIterable, Identifiable {
    case sleep, activity, cycle
    var id: Self { self }
    var title: String { switch self { case .sleep: "Sleep"; case .activity: "Activity"; case .cycle: "Cycle" } }
    var icon: String { switch self { case .sleep: "bed.double.fill"; case .activity: "figure.walk"; case .cycle: "drop.fill" } }
    var measure: String { switch self { case .sleep: "Sleep score"; case .activity: "Steps"; case .cycle: "Cycle interval" } }
    var stat: String { switch self { case .sleep: "Usual sleep score"; case .activity: "Usual daily steps"; case .cycle: "Usual cycle interval" } }
    var units: String { switch self { case .sleep: "nights"; case .activity: "days"; case .cycle: "intervals" } }
    var rawName: String { switch self { case .sleep: "Sleep score, duration and bedtime"; case .activity: "Recorded steps and goal history"; case .cycle: "Logged period starts and intervals" } }
    var prompt: String { switch self { case .sleep: "Bedtime reminder"; case .activity: "Step goal reminder"; case .cycle: "Cycle reflection reminder" } }
    var scopePrompt: String { switch self { case .sleep: "Which nights?"; case .activity: "Which days?"; case .cycle: "Which cycle dates?" } }
    var contextPrompt: String { switch self { case .sleep: "What affected your sleep?"; case .activity: "What affected your activity?"; case .cycle: "What was different around this cycle?" } }
    var options: [Reason] {
        switch self {
        case .sleep: [.deadline, .travel, .care]
        case .activity: [.injury, .travel, .busy]
        case .cycle: [.routine, .stress, .timing]
        }
    }
    var rule: String {
        switch self {
        case .sleep: "Score below 70 in this demo."
        case .activity: "Fewer than 6,000 steps in this demo. The separate daily goal is 8,000 steps."
        case .cycle: "Interval outside this demo’s reference range of 26–32 days. This is not a clinical threshold."
        }
    }
    func unusual(_ value: Int) -> Bool {
        switch self { case .sleep: value < 70; case .activity: value < 6000; case .cycle: !(26...32).contains(value) }
    }
    func format(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.locale(Locale(identifier: "en_US"))) + (self == .activity ? " steps" : self == .cycle ? " days" : "")
    }
}

enum Reason: String, Codable, CaseIterable, Identifiable {
    case deadline, travel, care, injury, busy, routine, stress, timing, other
    var id: Self { self }
    var title: String {
        switch self {
        case .deadline: "Work deadline"; case .travel: "Travel"; case .care: "Caregiving"; case .injury: "Injury recovery"
        case .busy: "Busy schedule"; case .routine: "Routine change"; case .stress: "Stressful period"; case .timing: "One-off cycle change"; case .other: "Personal context"
        }
    }
    var example: String {
        switch self {
        case .deadline: "I’ve been staying up late to meet a Friday deadline."
        case .travel: "Travel temporarily changed my routine."
        case .care: "I was up during the night caring for someone."
        case .injury: "I’m recovering from a leg injury and walking less than usual."
        case .busy: "An unusually busy week changed when I could walk."
        case .routine: "My routine changed around the time of this period."
        case .stress: "I had an unusually stressful period and want to note the timing."
        case .timing: "I noticed a one-off timing change and want to see if it repeats."
        case .other: ""
        }
    }
    var suggestion: String {
        switch self {
        case .deadline: "If helpful, revisit your usual bedtime when the deadline passes."
        case .travel, .busy: "Review your usual pattern again when your schedule settles."
        case .care: "Revisit your evening routine when it is practical for you."
        case .injury: "Review your activity in the context of recovery. You can skip prompts to make up missed steps."
        case .routine, .stress, .timing: "Keep the logged dates and compare future entries. A note alone cannot establish a cause."
        case .other: "Review which records fit your usual pattern again at your next check-in."
        }
    }
    var keywords: [String] {
        switch self {
        case .deadline: ["deadline", "project", "exam", "assignment"]; case .travel: ["travel", "flight", "jet lag"]
        case .care: ["caring", "caregiv"]; case .injury: ["injur", "sprain", "recover", "ankle"]; case .busy: ["busy", "overtime"]
        case .routine: ["routine", "travel", "schedule"]; case .stress: ["stress"]; case .timing: ["timing", "one-off"]; case .other: []
        }
    }
}

enum CorrectionMode: String, Codable, CaseIterable, Identifiable {
    case exclude, keep, measurement
    var id: Self { self }
    var title: String {
        switch self { case .exclude: "Don’t count in trends"; case .keep: "Count it, add a note"; case .measurement: "Flag a measurement" }
    }
    var short: String {
        switch self { case .exclude: "Set aside"; case .keep: "Counts with context"; case .measurement: "Measurement flagged" }
    }
    var detail: String {
        switch self {
        case .exclude: "Keep the log and set its value aside from the usual estimate and trend count."
        case .keep: "Keep counting the value and attach your context."
        case .measurement: "Keep the original source value and flag a possible mismatch for review."
        }
    }
    var icon: String {
        switch self { case .exclude: "line.3.horizontal.decrease.circle"; case .keep: "text.bubble"; case .measurement: "flag" }
    }
}

struct HealthLog: Identifiable, Equatable {
    var metric: Metric
    var day: Date
    var value: Int
    var note: String? = nil
    var id: String { metric.rawValue + "-" + Days.text(day, "yyyy-MM-dd") }
    var unusual: Bool { metric.unusual(value) }
    var shown: String { metric.format(value) + (metric == .sleep ? " / 100" : "") }
}

enum DemoData {
    static let logs: [HealthLog] = {
        let total = Days.calendar.dateComponents([.day], from: Days.first, to: Days.last).day!
        var logs: [HealthLog] = []
        for index in 0...total {
            let day = Days.add(Days.first, index)
            // Deliberately leave a few missing dates. Empty cells are distinct from zero.
            if index % 47 == 12 && day < Days.make(2026, 10, 1) { continue }
            let dayOfMonth = Days.calendar.component(.day, from: day)
            let month = Days.calendar.component(.month, from: day)
            let sleep = 77 + (index * 11 % 13)
            let steps = 7750 + (index * 347 % 2100)
            let sleepDip = ((index * 17 + month) % (month == 4 || month == 8 ? 8 : 15)) < 2
            let stepDip = ((index * 7 + month) % (month == 6 || month == 10 ? 11 : 21)) < 2
            var score = sleepDip ? 60 + index % 9 : sleep
            var stepCount = stepDip ? 3700 + index * 219 % 2100 : steps
            if month == 10 && (26...30).contains(dayOfMonth) {
                score = [68, 66, 64, 62, 60][dayOfMonth - 26]
                stepCount = [5100, 4500, 3800, 3200, 3150][dayOfMonth - 26]
            }
            if Scores.recovery.contains(day) { score = 80; stepCount = 7680 }
            let sleepNote: String? = day == Days.start ? "5 hr 02 min · 2:10 a.m. bedtime · 1 interruption · 21% deep sleep"
                : day == Days.add(Days.start, 1) ? "Demo signal: resting heart rate above the person’s usual range." : nil
            logs.append(HealthLog(metric: .sleep, day: day, value: score, note: sleepNote))
            logs.append(HealthLog(metric: .activity, day: day, value: stepCount))
        }
        let starts: [(Int, Int, Int)] = [(1, 9, 29), (2, 7, 29), (3, 7, 28), (4, 5, 29), (5, 10, 35),
            (6, 8, 29), (7, 7, 29), (8, 5, 29), (9, 3, 29), (10, 2, 29), (10, 24, 22), (11, 13, 20)]
        for (month, day, interval) in starts { logs.append(HealthLog(metric: .cycle, day: Days.make(2026, month, day), value: interval)) }
        return logs.sorted { $0.day < $1.day }
    }()

    private enum Scores {
        static let recovery: Set<Date> = [Days.make(2026, 10, 31), Days.make(2026, 11, 1), Days.make(2026, 11, 2)]
    }
}

struct Draft: Identifiable, Codable, Equatable {
    var id = UUID()
    var metric: Metric
    var anchor: Date
    var mode: CorrectionMode = .exclude
    var reason: Reason? = nil
    var note = ""
    var start: Date
    var end: Date?
    var keepNote = false
    var pause = false
    var askAgain = true
    var dismissedRecurring = false
    var editing = false
    var retainedThrough: Date? = nil

    var sampleReason: Reason {
        reason ?? metric.options.first { r in r.keywords.contains { note.localizedCaseInsensitiveContains($0) } } ?? .other
    }

    var appliedEnd: Date? {
        if let retainedThrough { return min(end ?? retainedThrough, retainedThrough) }
        return end
    }

    var possibleError: String? {
        if let end, end < start { return "Choose an end date on or after the start date." }
        if let retainedThrough, start > retainedThrough { return "Choose a start on or before the existing end date." }
        if !(start <= anchor && (appliedEnd ?? Days.lastEditable) >= anchor) && !editing {
            return "Include the selected record or return to the summary and choose a different record."
        }
        if reason == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Choose an example or add an explanation to continue." }
        return nil
    }
}

enum RuleStatus: String {
    case active = "Active", scheduled = "Scheduled", ended = "Ended early", completed = "Completed", undone = "Undone"
}
enum ManagementAction {
    case extend(Date), end(resumeOn: Date), undo, clearNote
}

struct Adjustment: Identifiable, Codable, Equatable {
    var id: UUID
    var metric: Metric
    var mode: CorrectionMode
    var reason: Reason
    var note: String?
    var start: Date
    var end: Date?
    var endedThrough: Date?
    var paused: Bool
    var askAgain: Bool
    var undone = false
    var anchor: Date

    init(_ draft: Draft) {
        id = draft.id; metric = draft.metric; mode = draft.mode; reason = draft.sampleReason
        let text = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        note = draft.keepNote && !text.isEmpty ? text : nil
        start = draft.start; end = draft.end; endedThrough = draft.retainedThrough; paused = draft.pause
        askAgain = draft.askAgain; anchor = draft.anchor
    }

    var effectiveEnd: Date? {
        if let endedThrough { return min(end ?? endedThrough, endedThrough) }
        return end
    }

    func contains(_ day: Date) -> Bool {
        !undone && start <= day && (effectiveEnd.map { day <= $0 } ?? true)
    }

    func status(on day: Date) -> RuleStatus {
        if undone { return .undone }
        if endedThrough != nil { return .ended }
        if day < start { return .scheduled }
        if let effectiveEnd, day > effectiveEnd { return .completed }
        return .active
    }

    func editableDraft() -> Draft {
        Draft(id: id, metric: metric, anchor: anchor, mode: mode, reason: reason, note: note ?? "", start: start, end: end,
              keepNote: note != nil, pause: paused, askAgain: askAgain, editing: true, retainedThrough: endedThrough)
    }

    func revise(_ action: ManagementAction, on day: Date) -> Self? {
        var updated = self
        switch action {
        case .extend(let endDate):
            guard [.active, .scheduled].contains(status(on: day)), let end,
                  endDate > end, endDate <= Days.lastEditable else { return nil }
            updated.end = endDate
        case .end(let resumeOn):
            guard status(on: day) == .active, resumeOn > start, resumeOn >= day, resumeOn <= Days.add(day, 1),
                  end.map({ $0 > day && resumeOn <= $0 }) ?? true else { return nil }
            updated.endedThrough = Days.add(resumeOn, -1)
        case .undo:
            guard !undone else { return nil }
            updated.undone = true
        case .clearNote:
            updated.note = nil
        }
        return updated
    }
}

struct DemoState: Codable {
    var day = Days.start
    var adjustments: [Adjustment] = []
    var drafts: [Draft] = []
    var dismissed: [String] = []
}

enum Horizon: String, CaseIterable, Identifiable {
    case month = "Month", year = "Year"
    var id: Self { self }
}

struct Window: Identifiable, Equatable {
    var start: Date
    var end: Date
    var label: String
    var id: Date { start }
    func contains(_ day: Date) -> Bool { start <= day && day <= end }
}

struct TrendCount: Equatable {
    var records = 0
    var raw = 0
    var counted = 0
    var setAside: Int { raw - counted }
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(records: lhs.records + rhs.records, raw: lhs.raw + rhs.raw, counted: lhs.counted + rhs.counted)
    }
    var tier: Int { Self.tier(for: counted) }
    static func tier(for count: Int) -> Int {
        switch count { case 0: 0; case 1: 1; case 2...3: 2; case 4...6: 3; default: 4 }
    }
}

struct Ledger {
    var state: DemoState
    var data: [HealthLog] = DemoData.logs
    func records(_ metric: Metric? = nil, in window: Window? = nil) -> [HealthLog] {
        data.filter { item in item.day <= state.day && (metric == nil || metric == item.metric) && (window?.contains(item.day) ?? true) }
    }
    func on(_ metric: Metric, _ day: Date) -> HealthLog? { records(metric).last { $0.day == day } }
    func adjustments(_ metric: Metric, _ day: Date) -> [Adjustment] {
        state.adjustments.filter { $0.metric == metric && $0.contains(day) }
    }
    func excluded(_ item: HealthLog) -> Bool {
        adjustments(item.metric, item.day).contains { $0.mode == .exclude }
    }
    func totals(_ metric: Metric, in window: Window) -> TrendCount {
        let logs = records(metric, in: window)
        let unusual = logs.filter(\.unusual)
        return TrendCount(records: logs.count, raw: unusual.count, counted: unusual.filter { !excluded($0) }.count)
    }
    func usual(_ metric: Metric, raw: Bool = false) -> (value: Int?, used: Int) {
        let logs = records(metric)
        let recent = metric == .cycle ? Array(logs.suffix(6)) : logs.filter { $0.day >= Days.add(state.day, -29) }
        let included = raw ? recent : recent.filter { !excluded($0) }
        let average = included.isEmpty ? nil : Int((Double(included.reduce(0) { $0 + $1.value }) / Double(included.count)).rounded())
        return (average, included.count)
    }
    func interpretation(_ log: HealthLog) -> String {
        let rules = adjustments(log.metric, log.day)
        let remarks = rules.filter { $0.mode != .measurement }.map { $0.reason.title }
        var original: String
        switch log.metric {
        case .sleep: original = log.unusual ? "Your sleep score was below your usual range in this example." : "Your sleep score was in your usual range in this example."
        case .activity: original = log.value < 8000 ? "You logged fewer than 8,000 steps. The log alone cannot explain why." : "You reached your 8,000-step goal."
        case .cycle: original = log.unusual ? "The interval differs from this example’s reference range. The date remains logged." : "The interval fits this example’s reference range."
        }
        if !remarks.isEmpty { original += " Context: " + Array(Set(remarks)).sorted().joined(separator: ", ") + "." }
        if rules.contains(where: { $0.mode == .exclude }) { original += " This record is set aside from the usual estimate." }
        if rules.contains(where: { $0.mode == .measurement }) { original += " A source measurement was flagged for review." }
        return original
    }
    func reminder(_ metric: Metric, _ day: Date) -> Bool {
        adjustments(metric, day).contains { $0.paused }
    }
    func coaching(_ metric: Metric, day: Date, includeRecentEnd: Bool = true) -> String {
        let active = adjustments(metric, day).filter { $0.mode != .measurement }
        let reasons = Array(Set(active.map(\.reason))).sorted { $0.title < $1.title }
        if !reasons.isEmpty { return reasons.map(\.suggestion).joined(separator: " ") }
        if includeRecentEnd, let ended = state.adjustments.last(where: { a in
            a.metric == metric && !a.undone && a.mode != .measurement && (a.effectiveEnd.map { $0 < day && $0 >= Days.add(day, -7) } ?? false)
        }) { return ended.reason.suggestion + " New records count again unless another adjustment applies." }
        switch metric {
        case .sleep: return "Review recent nights together to see whether your usual sleep pattern has changed."
        case .activity: return "Compare your logged steps with your goal and the context of your day."
        case .cycle: return "Review logged start dates alongside any context you chose to save."
        }
    }
    func adding(_ draft: Draft) -> Self {
        var updated = self
        if let index = updated.state.adjustments.firstIndex(where: { $0.id == draft.id }) {
            updated.state.adjustments[index] = Adjustment(draft)
        } else { updated.state.adjustments.append(Adjustment(draft)) }
        return updated
    }
    func recurring(_ draft: Draft) -> Bool {
        let previous = state.adjustments.filter { a in
            a.metric == draft.metric && a.reason == draft.sampleReason && a.id != draft.id && a.askAgain && !a.undone
                && a.mode == .exclude && (a.effectiveEnd.map { $0 < draft.start } ?? false)
        }
        return draft.sampleReason != .other && previous.contains { a in
            previous.contains { b in a.id != b.id && (a.effectiveEnd.map { $0 < b.start } ?? false) }
        }
    }
    func overlapping(_ adjustment: Adjustment) -> [Adjustment] {
        state.adjustments.filter {
            $0.id != adjustment.id && !$0.undone && $0.metric == adjustment.metric
                && $0.start <= (adjustment.effectiveEnd ?? .distantFuture)
                && ($0.effectiveEnd ?? .distantFuture) >= adjustment.start
        }
    }
    func measurementConflict(_ draft: Draft) -> HealthLog? {
        guard let item = on(draft.metric, draft.anchor) else { return nil }
        let pattern: String
        switch draft.metric {
        case .sleep: pattern = #"(?i)(?:sleep )?score (?:was|is) (\d{1,3})\b"#
        case .activity: pattern = #"(?i)(?:I walked|I logged|I took) (\d[\d,]*) steps\b"#
        case .cycle: pattern = #"(?i)(?:cycle )?interval (?:was|is) (\d{1,3}) days\b"#
        }
        guard let match = try? NSRegularExpression(pattern: pattern).firstMatch(in: draft.note, range: NSRange(draft.note.startIndex..., in: draft.note)),
            let range = Range(match.range(at: 1), in: draft.note),
            let value = Int(draft.note[range].replacingOccurrences(of: ",", with: "")), value != item.value else { return nil }
        return item
    }

    static func windows(_ date: Date, _ horizon: Horizon) -> [Window] {
        let calendar = Days.calendar
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        if horizon == .year {
            return (1...12).map { month in
                let start = Days.make(y, month, 1)
                let end = Days.add(calendar.date(byAdding: .month, value: 1, to: start)!, -1)
                return Window(start: start, end: end, label: Days.text(start, "MMM"))
            }
        }
        let start = Days.make(y, m, 1)
        let days = calendar.range(of: .day, in: .month, for: start)!.count
        return stride(from: 1, through: days, by: 7).map { first in
            let last = min(first + 6, days)
            return Window(start: Days.make(y, m, first), end: Days.make(y, m, last), label: first == last ? "\(first)" : "\(first)–\(last)")
        }
    }
}
