import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var store: AppStore
    var log: HealthLog
    var open: (Screen) -> Void
    var close: () -> Void

    var body: some View {
        SheetFrame(title: log.metric.title, subtitle: Days.text(log.day, "EEEE, MMMM d"), close: close) {
            let rules = store.ledger.adjustments(log.metric, log.day)
            let excluded = store.ledger.excluded(log)
            if !rules.isEmpty {
                Card(12) {
                    HStack {
                        Image(systemName: "checkmark.circle").foregroundStyle(Theme.green)
                        Text(excluded ? "Shown in history · not counted" : "Counts with context").font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("View memory") { open(.memory) }.font(.caption)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        MetricGlyph(metric: log.metric)
                        Text(log.metric.measure).font(.headline)
                        Spacer()
                        Badge(excluded ? "Set aside" : log.unusual ? "Unusual in demo" : "Typical", color: excluded ? Theme.green : Theme.blue)
                    }
                    Text(log.shown).font(.system(size: 47, weight: .semibold, design: .rounded)).tracking(-2).monospacedDigit()
                    if log.metric == .sleep && log.day == Days.start {
                        RecordFacts()
                    } else if let note = log.note {
                        Text(note).font(.caption).foregroundStyle(Theme.slate)
                    } else if log.metric == .activity {
                        Text("Daily goal: 8,000 steps").font(.caption).foregroundStyle(Theme.slate)
                    } else if log.metric == .cycle {
                        Text("Period start logged " + Days.text(log.day) + ".").font(.caption).foregroundStyle(Theme.slate)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title: "Interpretation · Simulated")
                    Text(store.ledger.interpretation(log)).font(.subheadline)
                    Text(log.metric.rule).font(.caption).foregroundStyle(Theme.slate)
                    Divider()
                    Text(store.ledger.coaching(log.metric, day: log.day)).font(.caption).foregroundStyle(Theme.slate)
                    if !rules.isEmpty {
                        ForEach(rules) { rule in
                            Button { open(.adjustment(rule.id)) } label: {
                                HStack { Text(rule.reason.title).font(.subheadline); Spacer(); Chevron() }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if log.metric == .sleep {
                Card {
                    Eyebrow(title: "Recent nights")
                    let lastSeven = store.ledger.records(.sleep).filter { $0.day <= log.day }.suffix(7)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(lastSeven)) { item in
                            VStack(spacing: 3) {
                                Text("\(item.value)").font(.caption2.monospacedDigit())
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(store.ledger.excluded(item) ? Color.clear : Theme.tierFills[2])
                                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.blue.opacity(0.57), lineWidth: store.ledger.excluded(item) ? 1 : 0) }
                                    .frame(height: CGFloat(item.value) * 0.58)
                                Text(Days.text(item.day, "d")).font(.caption2).foregroundStyle(Theme.slate)
                            }.frame(maxWidth: .infinity)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Days.text(item.day) + ", score \(item.value), " + (store.ledger.excluded(item) ? "set aside" : "counted"))
                        }
                    }.padding(.top, 5)
                    Text("Outlined = set aside from the usual estimate").font(.caption2).foregroundStyle(Theme.slate).padding(.top, 7)
                }
            }
            let draft = store.draft(for: log)
            ActionButton(title: store.state.drafts.contains(where: { $0.id == draft.id }) ? "Resume correction" : "Not Typical",
                         icon: "pencil.line") { open(.correction(draft)) }
        }
    }
}

struct RecordFacts: View {
    var body: some View {
        VStack(spacing: 0) {
            fact("Duration", "5 hr 02 min")
            fact("Bedtime", "2:10 a.m.")
            fact("Interruptions", "1")
            fact("Deep sleep", "21%")
        }.padding(.horizontal, 9).background(Theme.canvas, in: RoundedRectangle(cornerRadius: 9))
    }

    private func fact(_ key: String, _ value: String) -> some View {
        HStack { Text(key); Spacer(); Text(value).foregroundStyle(Theme.slate) }
            .font(.caption).padding(.vertical, 6)
    }
}

struct CorrectionView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: Draft
    @State private var phase: Phase = .context
    @State private var original: Ledger?
    @State private var showError = false
    @State private var confirmDiscard = false
    let open: (Screen) -> Void
    let home: () -> Void
    let close: () -> Void

    enum Phase: Int {
        case context, scope, review, applied
        var title: String {
            switch self { case .context: "01   Context"; case .scope: "02   Scope"; case .review: "03   Review"; case .applied: "04   Effect applied" }
        }
        var previous: Self? { Self(rawValue: rawValue - 1) }
    }

    init(draft: Draft, open: @escaping (Screen) -> Void, home: @escaping () -> Void, close: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.open = open; self.home = home; self.close = close
    }

    var body: some View {
        SheetFrame(title: phase == .applied ? "Adjustment saved" : "Not Typical",
                   subtitle: draft.metric.title + " · " + Days.text(draft.anchor),
                   back: phase == .context ? nil : { if phase == .applied { home() } else { goBack() } },
                   close: close) {
            if phase != .applied {
                HStack {
                    Eyebrow(title: phase.title)
                    Spacer()
                    if draft.editing { Badge("Editing saved adjustment") }
                }
                originalRecord
            }
            switch phase {
            case .context: context
            case .scope: scope
            case .review: review(saved: false)
            case .applied: review(saved: true)
            }
        }
        .id(phase)
        .onChange(of: draft) { _, next in if phase != .applied { store.save(next) } }
        .confirmationDialog("Discard this draft?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { store.discard(draft.id); close() }
            Button("Keep editing", role: .cancel) {}
        } message: { Text("This removes the unfinished text and choices from this device.") }
    }

    private var originalRecord: some View {
        Card(12) {
            HStack(spacing: 8) {
                MetricGlyph(metric: draft.metric)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.ledger.on(draft.metric, draft.anchor)?.shown ?? draft.metric.measure).font(.subheadline.bold())
                    Text("Your original records are kept.").font(.caption).foregroundStyle(Theme.slate)
                }
                Spacer()
            }
        }
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text("What should change?").font(.title3.bold())
                    ForEach(CorrectionMode.allCases) { mode in
                        let label = mode == .measurement && draft.metric == .sleep ? "My bedtime or score looks wrong" : mode.title
                        option(label, icon: mode.icon, selected: draft.mode == mode) { draft.mode = mode }
                    }
                    Text(draft.mode.detail).font(.caption).foregroundStyle(Theme.slate)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text(draft.metric.contextPrompt).font(.title3.bold())
                    Text("Choose an example or enter your own context.").font(.caption).foregroundStyle(Theme.slate)
                    ForEach(draft.metric.options) { reason in
                        option(reason.title, icon: "lightbulb", selected: draft.reason == reason) {
                            draft.reason = reason
                            draft.note = reason.example
                        }
                    }
                    TextField("Describe what happened…", text: $draft.note, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.plain).padding(10)
                        .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityIdentifier("correction-explanation")
                        .onChange(of: draft.note) { _, next in
                            if let reason = draft.reason, next != reason.example, !next.isEmpty { draft.reason = nil }
                        }
                    Text("You can also use your device’s dictation in this field when enabled.").font(.caption2).foregroundStyle(Theme.slate)
                    Toggle("Keep my exact wording after applying", isOn: $draft.keepNote).font(.subheadline)
                    Text("Drafts are stored on this device. Exact wording is cleared on apply unless you turn this on.").font(.caption2).foregroundStyle(Theme.slate)
                }
            }
            if showError && draft.reason == nil && draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Choose an example or add an explanation to continue.").font(.caption).foregroundStyle(Theme.gold)
            }
            ActionButton(title: "Choose dates", icon: "calendar") {
                guard draft.reason != nil || !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { showError = true; return }
                store.save(draft); showError = false; phase = .scope
            }
            draftActions
        }
    }

    private var scope: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text(draft.metric.scopePrompt).font(.title3.bold())
                    if !draft.editing {
                        option("Just " + Days.text(draft.anchor), icon: "calendar", selected: draft.start == draft.anchor && draft.end == draft.anchor) {
                            draft.start = draft.anchor; draft.end = draft.anchor
                        }
                        if draft.metric == .sleep {
                            let weekday = Days.calendar.component(.weekday, from: draft.anchor)
                            let friday = Days.add(draft.anchor, (6 - weekday + 7) % 7)
                            option("Through " + Days.text(friday, "EEE, MMM d"), icon: "calendar.badge.clock", selected: friday != draft.anchor && draft.end == friday) {
                                draft.end = friday
                            }
                        } else if draft.metric == .activity {
                            option("One week from " + Days.text(draft.anchor), icon: "calendar.badge.clock",
                                   selected: draft.start == draft.anchor && draft.end == Days.add(draft.anchor, 6)) {
                                draft.start = draft.anchor; draft.end = Days.add(draft.anchor, 6)
                            }
                        }
                    }
                    Toggle("Keep adjusting until I end it", isOn: openEnded).font(.subheadline)
                        .disabled(draft.retainedThrough != nil)
                    DatePicker("Start date", selection: beginning, in: pickerRange, displayedComponents: .date)
                        .font(.subheadline)
                    if draft.end != nil {
                        DatePicker("End date (included)", selection: ending, in: pickerRange, displayedComponents: .date)
                            .font(.subheadline)
                    }
                    Text(draft.appliedEnd.map { "Includes " + Days.text($0) + ". Usual settings resume " + Days.text(Days.add($0, 1)) + ", unless another adjustment applies." }
                         ?? "No automatic end date. Open Memory to end this adjustment when your situation changes.")
                        .font(.caption).foregroundStyle(Theme.slate)
                    Divider()
                    Toggle("Pause " + draft.metric.prompt.lowercased() + " during this range", isOn: $draft.pause).font(.subheadline)
                    Toggle("Ask before using similar context again", isOn: $draft.askAgain).font(.subheadline)
                    Text("A future check-in is optional. Attune never applies a new adjustment automatically.").font(.caption2).foregroundStyle(Theme.slate)
                }
            }
            if let end = draft.appliedEnd, end < draft.start {
                Text("Choose an end date on or after the start date.").font(.caption).foregroundStyle(Theme.gold)
            } else {
                ScopeTimeline(draft: draft, before: store.ledger, after: store.ledger.adding(draft))
            }
            if showError, let error = draft.possibleError {
                Text(error).font(.subheadline).foregroundStyle(Theme.gold)
            }
            ActionButton(title: "See AI-suggested changes", icon: "sparkles") {
                guard draft.possibleError == nil else { showError = true; return }
                store.save(draft); showError = false; phase = .review
            }
            draftActions
        }
    }

    private var openEnded: Binding<Bool> {
        Binding(get: { draft.end == nil }, set: { draft.end = $0 ? nil : max(draft.anchor, draft.start) })
    }

    private var ending: Binding<Date> {
        Binding(get: { Days.toPicker(draft.end ?? draft.anchor) }, set: { draft.end = Days.fromPicker($0) })
    }

    private var beginning: Binding<Date> {
        Binding(get: { Days.toPicker(draft.start) }, set: { draft.start = Days.fromPicker($0) })
    }

    private var pickerRange: ClosedRange<Date> { Days.toPicker(Days.first)...Days.toPicker(Days.lastEditable) }

    private func review(saved: Bool) -> some View {
        let before = saved ? original ?? store.ledger : store.ledger
        let after = saved ? store.ledger : store.ledger.adding(draft)
        return VStack(alignment: .leading, spacing: 12) {
            if saved {
                Card(13) {
                    Label("Effect applied · " + draft.mode.short, systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(Theme.green)
                }
                originalRecord
            } else {
                Card {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Eyebrow(title: "What Attune understood"); Spacer(); Badge("Simulated AI") }
                        Text(draft.sampleReason.title).font(.headline)
                        if !draft.note.isEmpty { Text("“" + draft.note + "”").font(.subheadline).foregroundStyle(Theme.slate) }
                        if let item = before.measurementConflict(draft) {
                            Label("Check the source: the original " + item.metric.measure.lowercased() + " is " + item.shown + ". Your explanation is still yours to edit.", systemImage: "exclamationmark.circle")
                                .font(.caption).foregroundStyle(Theme.gold)
                        }
                        Button("Edit my explanation") { phase = .context }.font(.subheadline.weight(.semibold))
                    }
                }
                if before.recurring(draft) && !draft.dismissedRecurring {
                    Card {
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(title: "Recurring context")
                            Text("Temporary again, or part of your routine?").font(.headline)
                            Text("You applied similar context to two earlier periods. Here you decide how this period counts.")
                                .font(.caption).foregroundStyle(Theme.slate)
                            option("Keep this temporary", icon: "calendar", selected: draft.mode == .exclude) { draft.mode = .exclude }
                            option("Count it in my usual pattern", icon: "chart.line.uptrend.xyaxis", selected: draft.mode == .keep) { draft.mode = .keep }
                            Button("Dismiss check-in") { draft.dismissedRecurring = true }.font(.caption)
                        }
                    }
                }
            }

            ChangePreview(draft: draft, before: before, after: after)
            ScopeTimeline(draft: draft, before: before, after: after)
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title: saved ? "What was saved" : "What will be saved")
                    Text("Reason, affected dates, reminder choice and adjustment history. " +
                         (draft.keepNote && !draft.note.isEmpty ? "Your exact wording is retained." : "Your exact wording is cleared when you apply."))
                        .font(.caption).foregroundStyle(Theme.slate)
                }
            }
            if saved {
                ActionButton(title: "Back to Home", icon: "chart.bar.xaxis", action: home)
                ActionButton(title: "View adjustment", icon: "tray.full", secondary: true) { open(.adjustment(draft.id)) }
            } else {
                ActionButton(title: draft.editing ? "Save adjustment" : "Apply adjustment", icon: "checkmark") {
                    guard draft.possibleError == nil else { phase = .scope; showError = true; return }
                    original = store.ledger
                    store.apply(draft)
                    phase = .applied
                }
                ActionButton(title: "Edit affected dates", icon: "calendar", secondary: true) { phase = .scope }
                draftActions
            }
        }
    }

    private var draftActions: some View {
        HStack {
            Button("Save draft & exit") { store.save(draft); close() }.font(.caption.weight(.semibold))
            Spacer()
            Button("Discard draft", role: .destructive) { confirmDiscard = true }.font(.caption)
        }.padding(.horizontal, 2).padding(.vertical, 4)
    }

    private func goBack() { if let previous = phase.previous { phase = previous; showError = false } }
}

private func option(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack {
            Label(title, systemImage: icon).font(.subheadline.weight(.medium))
            Spacer(minLength: 3)
            if selected { Image(systemName: "checkmark.circle.fill").font(.caption) }
        }.padding(.horizontal, 10).frame(minHeight: 39)
            .foregroundStyle(selected ? .white : Theme.blue)
            .background(selected ? Theme.blue : Theme.mist, in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
}

struct ChangePreview: View {
    var draft: Draft
    var before: Ledger
    var after: Ledger

    var body: some View {
        let was = before.usual(draft.metric)
        let now = after.usual(draft.metric)
        let window = Ledger.windows(draft.anchor, .month).first { $0.contains(draft.anchor) }!
        let month = Ledger.windows(draft.anchor, .month)
        let year = Ledger.windows(draft.anchor, .year)
        let monthWindow = Window(start: month.first!.start, end: month.last!.end, label: "")
        let yearWindow = Window(start: year.first!.start, end: year.last!.end, label: "")
        let relevant = before.records(draft.metric).last { $0.day >= draft.start && $0.day <= (draft.appliedEnd ?? .distantFuture) }
        return Card {
            VStack(alignment: .leading, spacing: 11) {
                Eyebrow(title: "What changes?")
                Text(draft.metric.stat).font(.headline)
                HStack(spacing: 8) {
                    score("Before", draft.metric.format(was.value), "\(was.used) \(draft.metric.units) counted", false)
                    Image(systemName: "arrow.right").font(.caption.bold()).foregroundStyle(Theme.slate)
                    score("After", draft.metric.format(now.value), "\(now.used) \(draft.metric.units) counted", true)
                }
                if let log = relevant {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Before: " + before.interpretation(log))
                        Text("After: " + after.interpretation(log))
                    }.font(.caption).foregroundStyle(Theme.slate)
                }
                VStack(alignment: .leading, spacing: 7) {
                    countLine("Tile · " + Days.range(window.start, window.end), window)
                    countLine(Days.text(draft.anchor, "MMMM") + " total", monthWindow)
                    countLine(Days.text(draft.anchor, "yyyy") + " total", yearWindow)
                }
                Text("Counts reflect records available on " + Days.text(before.state.day) + ". A future log can change these totals.")
                    .font(.caption2).foregroundStyle(Theme.slate)
                Divider()
                Eyebrow(title: "What stays?")
                Text(draft.metric.rawName + " stay in your history. Other adjustments and source signals remain visible.")
                    .font(.caption).foregroundStyle(Theme.slate)
                Divider()
                Eyebrow(title: "Coaching and reminders")
                let sampleDay = max(draft.start, min(before.state.day, draft.appliedEnd ?? before.state.day))
                Text(after.coaching(draft.metric, day: sampleDay)).font(.caption).foregroundStyle(Theme.slate)
                Text(draft.metric.prompt + ": " + setting(before, sampleDay) + " → " + setting(after, sampleDay))
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func score(_ title: String, _ value: String, _ note: String, _ updated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.slate)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(note).font(.caption2).foregroundStyle(Theme.slate)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(9)
            .background(updated ? Theme.green.opacity(0.08) : Theme.canvas, in: RoundedRectangle(cornerRadius: 9))
    }

    private func countLine(_ name: String, _ window: Window) -> some View {
        let old = before.totals(draft.metric, in: window)
        let new = after.totals(draft.metric, in: window)
        return HStack(spacing: 5) {
            Text(name).font(.caption.weight(.medium))
            Spacer(minLength: 2)
            tally(old)
            Image(systemName: "arrow.right").font(.caption2)
            tally(new)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(name + ", unusual counted: \(old.counted) before, \(new.counted) after")
    }

    private func tally(_ stats: TrendCount) -> some View {
        Text(stats.records == 0 ? "—" : "\(stats.counted)")
            .font(.caption.monospacedDigit().bold())
            .foregroundStyle(stats.tier >= 3 ? .white : Theme.ink)
            .frame(width: 32, height: 23)
            .background(Theme.tierFills[stats.tier], in: RoundedRectangle(cornerRadius: 5))
    }

    private func setting(_ ledger: Ledger, _ day: Date) -> String { ledger.reminder(draft.metric, day) ? "Paused" : "On" }
}

struct ScopeTimeline: View {
    var draft: Draft
    var before: Ledger
    var after: Ledger
    var adjustment: Adjustment? = nil

    private var effectiveEnd: Date? { adjustment?.effectiveEnd ?? draft.appliedEnd }
    private var shownEnd: Date { max(draft.start, draft.end ?? effectiveEnd ?? Days.add(max(before.state.day, draft.start), 5)) }

    private var dates: [Date] {
        if draft.metric == .cycle {
            let range = Window(start: draft.start, end: shownEnd, label: "")
            return Set([draft.start, shownEnd] + before.records(.cycle, in: range).map(\.day)).sorted()
        }
        let count = max(0, Days.calendar.dateComponents([.day], from: draft.start, to: shownEnd).day ?? 0)
        return (0...count).map { Days.add(draft.start, $0) }
    }

    var body: some View {
        let all = dates
        let limited = all.count > 18
        let displayed = limited ? Array(all.prefix(9)) + Array(all.suffix(9)) : all
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(title: adjustment?.undone == true ? "Previously selected dates" : "Which records are affected?")
                Text(Days.range(draft.start, effectiveEnd)).font(.headline)
                if adjustment?.undone == true {
                    Text("This adjustment is undone. Only other matching adjustments still apply.").font(.caption).foregroundStyle(Theme.slate)
                } else if let end = effectiveEnd {
                    Text("Includes \(Days.text(end)). New records count again from \(Days.text(Days.add(end, 1))) unless another adjustment applies.")
                        .font(.caption).foregroundStyle(Theme.slate)
                } else {
                    Text("Until you end it. The dates below show only the portion near the current demo day.").font(.caption).foregroundStyle(Theme.slate)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                    ForEach(displayed, id: \.self) { day in tile(day) }
                }
                if limited {
                    Text("\(all.count - displayed.count) dates between the first and last groups are also within the displayed date span.")
                        .font(.caption2).foregroundStyle(Theme.slate)
                }
                if draft.metric == .cycle {
                    Text("Cycle corrections attach to the dates of logged period starts.").font(.caption2).foregroundStyle(Theme.slate)
                }
            }
        }
    }

    private func tile(_ day: Date) -> some View {
        let log = after.on(draft.metric, day)
        let rules = after.adjustments(draft.metric, day)
        let other = rules.contains { $0.id != draft.id && $0.mode == .exclude }
        let setAside = rules.contains { $0.mode == .exclude }
        let label = log == nil && day <= before.state.day ? "No record" : other ? "Other rule" : setAside ? "Set aside" : "Counts"
        return VStack(alignment: .leading, spacing: 2) {
            Text(Days.text(day)).font(.caption.weight(.semibold))
            Text(log?.shown ?? (day > before.state.day ? "Future record" : "No log")).font(.caption2).lineLimit(1)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(setAside ? Theme.blue : Theme.green)
        }
        .frame(maxWidth: .infinity, minHeight: 49, alignment: .leading).padding(5)
        .background(setAside ? Theme.mist : Theme.canvas, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
    }
}
