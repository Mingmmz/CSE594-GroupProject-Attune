import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode = Grouping.active
    var open: (Screen) -> Void
    var close: () -> Void

    enum Grouping: String, CaseIterable, Identifiable {
        case active = "Active", past = "Past", learned = "Learned"
        var id: Self { self }
    }

    var body: some View {
        SheetFrame(title: "Memory", subtitle: "Manage adjustments", close: close) {
            Picker("Adjustments", selection: $mode) {
                ForEach(Grouping.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if mode == .learned {
                learned
            } else {
                adjustmentList
            }
            if !store.state.drafts.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(title: "Unfinished drafts")
                        ForEach(store.state.drafts) { draft in
                            Button { open(.correction(draft)) } label: {
                                HStack {
                                    MetricGlyph(metric: draft.metric)
                                    Text(draft.metric.title + " · " + Days.text(draft.anchor)).font(.subheadline)
                                    Spacer()
                                    Text("Resume").font(.caption.weight(.semibold)).foregroundStyle(Theme.blue)
                                    Chevron()
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var adjustmentList: some View {
        let rows = store.state.adjustments.filter { rule in
            let status = rule.status(on: store.state.day)
            return mode == .active ? status == .active || status == .scheduled : status != .active && status != .scheduled
        }.reversed()
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(title: mode == .active ? "Active and scheduled" : "Past adjustments")
                if rows.isEmpty {
                    Text(mode == .active ? "No active or scheduled adjustments. Start from an unusual record." : "Completed, ended and undone adjustments appear here.")
                        .font(.subheadline).foregroundStyle(Theme.slate)
                }
                ForEach(Array(rows)) { rule in
                    AdjustmentRow(rule: rule, day: store.state.day) { open(.adjustment(rule.id)) }
                }
            }
        }
    }

    private var learned: some View {
        let accepted = store.state.adjustments.filter { !$0.undone && $0.mode == .keep }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(title: "Keeps counting by your choice")
                Text("These records count toward your usual pattern with context. Similar future situations still need your approval.")
                    .font(.subheadline).foregroundStyle(Theme.slate)
                if accepted.isEmpty {
                    Text("No saved choices yet. Count a record with context or choose to keep a recurring situation in your usual pattern.")
                        .font(.caption).foregroundStyle(Theme.slate)
                }
                ForEach(accepted) { rule in AdjustmentRow(rule: rule, day: store.state.day) { open(.adjustment(rule.id)) } }
            }
        }
    }
}

struct AdjustmentRow: View {
    let rule: Adjustment
    let day: Date
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MetricGlyph(metric: rule.metric)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.reason.title).font(.subheadline.weight(.semibold))
                    Text(rule.metric.title + " · " + Days.range(rule.start, rule.effectiveEnd)).font(.caption2).foregroundStyle(Theme.slate)
                }
                Spacer(minLength: 4)
                Badge(rule.status(on: day).rawValue)
                Chevron()
            }.padding(7).background(Theme.canvas, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }
}

struct AdjustmentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var task: Task?
    @State private var newDate = Days.start
    @State private var previous: Ledger?
    let id: UUID
    let open: (Screen) -> Void
    let close: () -> Void

    enum Task: String {
        case extend = "Extend", end = "End early", undo = "Undo", clear = "Remove saved wording"
    }

    var body: some View {
        if let rule = store.state.adjustments.first(where: { $0.id == id }) {
            SheetFrame(title: rule.reason.title, subtitle: rule.metric.title + " · " + rule.status(on: store.state.day).rawValue,
                       back: { open(.memory) }, close: close) {
                if let task { confirmation(rule, task) }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Eyebrow(title: "Saved context"); Spacer(); Badge(rule.status(on: store.state.day).rawValue) }
                        Text(rule.undone ? "Previously: " + rule.mode.short : rule.mode.short).font(.headline)
                        Text(rule.note.map { "“" + $0 + "”" } ?? "Only the reason category was retained.").font(.subheadline).foregroundStyle(Theme.slate)
                        if rule.undone {
                            Text("This adjustment no longer affects any record.").font(.caption.weight(.semibold)).foregroundStyle(Theme.green)
                        } else {
                            Text(rule.metric.prompt + (rule.paused ? ": paused during this range." : ": usual setting.") +
                                 (rule.askAgain ? " Reuse next time: Ask." : " Reuse next time: Off."))
                                .font(.caption).foregroundStyle(Theme.slate)
                        }
                    }
                }
                if let previous {
                    ChangePreview(draft: rule.editableDraft(), before: previous, after: store.ledger)
                }
                actionList(rule)
                ScopeTimeline(draft: rule.editableDraft(), before: store.ledger, after: store.ledger, adjustment: rule)
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(title: "Overlapping reasons")
                        let neighbors = store.ledger.overlapping(rule)
                        if neighbors.isEmpty {
                            Text("No other adjustments overlap the effective dates.").font(.caption).foregroundStyle(Theme.slate)
                        }
                        ForEach(neighbors) { item in
                            AdjustmentRow(rule: item, day: store.state.day) { open(.adjustment(item.id)) }
                        }
                        if !neighbors.isEmpty {
                            Text("Each reason has its own dates. Changing this one keeps the others in place.").font(.caption).foregroundStyle(Theme.slate)
                        }
                    }
                }
            }
            .id(task?.rawValue ?? "details")
        } else {
            SheetFrame(title: "Adjustment unavailable", subtitle: "Memory", close: close) {
                Text("You can return to Memory to view saved adjustments.")
                ActionButton(title: "Open Memory", icon: "tray.full") { open(.memory) }
            }
        }
    }

    private func actionList(_ rule: Adjustment) -> some View {
        let current = rule.status(on: store.state.day)
        return VStack(spacing: 8) {
            if !rule.undone {
                ActionButton(title: "Edit", icon: "pencil") { open(.correction(store.edit(rule))) }
                if (current == .active || current == .scheduled), let end = rule.end, end < Days.lastEditable {
                    ActionButton(title: "Extend", icon: "calendar.badge.plus", secondary: true) {
                        newDate = min(Days.lastEditable, Days.add(end, 7)); task = .extend
                    }
                }
                if canEnd(rule) {
                    ActionButton(title: "End early", icon: "stop.circle", secondary: true) {
                        newDate = min(rule.end ?? Days.lastEditable, Days.add(store.state.day, 1)); task = .end
                    }
                }
                ActionButton(title: "Undo correction", icon: "arrow.uturn.backward", secondary: true) { task = .undo }
            }
            if rule.note != nil {
                Button("Remove saved wording", role: .destructive) { task = .clear }.font(.caption).frame(minHeight: 30)
            }
        }
    }

    private func canEnd(_ rule: Adjustment) -> Bool {
        rule.status(on: store.state.day) == .active && (rule.end.map { $0 > store.state.day } ?? true)
    }

    private func confirmation(_ rule: Adjustment, _ choice: Task) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(title: "Confirm change")
                Text(choice.rawValue).font(.headline)
                switch choice {
                case .extend:
                    if let end = rule.end {
                        DatePicker("New end date (included)", selection: dateSelection,
                                   in: Days.toPicker(Days.add(end, 1))...Days.toPicker(Days.lastEditable), displayedComponents: .date)
                        Text("The existing context and reminder setting also apply to the added dates.").font(.caption).foregroundStyle(Theme.slate)
                    }
                case .end:
                    let first = max(Days.add(rule.start, 1), store.state.day)
                    let last = min(Days.add(store.state.day, 1), rule.end ?? Days.lastEditable)
                    Picker("Resume usual settings on", selection: $newDate) {
                        if first < last { Text(Days.text(first) + " · includes today’s log").tag(first) }
                        Text(Days.text(last) + " · after today’s log").tag(last)
                    }
                    Text("Records through " + Days.text(Days.add(newDate, -1)) + " stay affected. Starting " + Days.text(newDate) + ", only other adjustments still apply.")
                        .font(.caption).foregroundStyle(Theme.slate)
                case .undo:
                    Text("All dates go back to their original handling except where another adjustment still applies. The history entry remains visible as undone.")
                        .font(.caption).foregroundStyle(Theme.slate)
                case .clear:
                    Text("Remove your exact wording from this device. The reason category and dates remain.").font(.caption).foregroundStyle(Theme.slate)
                }
                ActionButton(title: choice == .extend ? "Save new end date" : "Confirm " + choice.rawValue.lowercased(), icon: "checkmark") {
                    resolve(rule, choice)
                }
                Button("Cancel") { task = nil }.font(.caption.weight(.semibold))
            }
        }
    }

    private func resolve(_ rule: Adjustment, _ choice: Task) {
        let action: ManagementAction
        switch choice {
        case .extend: action = .extend(Days.normalized(newDate))
        case .end: action = .end(resumeOn: Days.normalized(newDate))
        case .undo: action = .undo
        case .clear: action = .clearNote
        }
        guard let next = rule.revise(action, on: store.state.day) else { return }
        if choice != .clear { previous = store.ledger }
        store.revise(next)
        task = nil
    }

    private var dateSelection: Binding<Date> {
        Binding(get: { Days.toPicker(newDate) }, set: { newDate = Days.fromPicker($0) })
    }
}

struct InboxView: View {
    @EnvironmentObject private var store: AppStore
    var open: (Screen) -> Void
    var close: () -> Void

    var body: some View {
        SheetFrame(title: "Follow-ups", subtitle: "In-app demo reminders", close: close) {
            let log = store.ledger.records(.sleep).last!
            let excluded = store.ledger.excluded(log)
            if log.unusual && !store.state.dismissed.contains(log.id) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(title: "ATTUNE · " + Days.text(log.day))
                        Text("Sleep score \(log.value)" + (excluded ? " · set aside" : "")).font(.title3.bold())
                        if let note = log.note { Text(note).font(.caption).foregroundStyle(Theme.slate) }
                        if store.ledger.reminder(.sleep, store.state.day) {
                            Text("Your bedtime reminder is paused. The original log and its signals still appear here.").font(.caption).foregroundStyle(Theme.slate)
                        }
                        ActionButton(title: excluded ? "Review record" : "Not Typical", icon: excluded ? "doc.text" : "pencil.line") {
                            open(excluded ? .record(log) : .correction(store.draft(for: log)))
                        }
                        Button("Dismiss insight") { store.dismiss(log.id) }.font(.caption)
                    }
                }
            }
            ForEach(upcoming) { item in
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(title: item.reason.title)
                        Text("Back to your usual?").font(.title3.bold())
                        Text(summary(item)).font(.caption).foregroundStyle(Theme.slate)
                        if item.status(on: store.state.day) == .active {
                            ActionButton(title: "Review when records count again", icon: "calendar") { open(.adjustment(item.id)) }
                        } else {
                            ActionButton(title: "View past adjustment", icon: "tray.full", secondary: true) { open(.adjustment(item.id)) }
                        }
                        Button("Dismiss follow-up") { store.dismiss(key(item)) }.font(.caption)
                    }
                }
            }
            if (!log.unusual || store.state.dismissed.contains(log.id)) && upcoming.isEmpty {
                Card { Text("No follow-ups right now.").font(.subheadline).foregroundStyle(Theme.slate) }
            }
            Text("These cards are a demo inbox. Attune does not schedule system notifications.")
                .font(.caption).foregroundStyle(Theme.slate)
        }
    }

    private var upcoming: [Adjustment] {
        store.state.adjustments.filter { rule in
            guard !rule.undone, rule.mode == .exclude, rule.askAgain, let end = rule.effectiveEnd, !store.state.dismissed.contains(key(rule)) else { return false }
            return end <= Days.add(store.state.day, 1) && end >= Days.add(store.state.day, -3)
        }
    }
    private func key(_ rule: Adjustment) -> String { "followup-" + rule.id.uuidString + "-" + (rule.effectiveEnd.map { Days.text($0, "yyyy-MM-dd") } ?? "") }
    private func summary(_ rule: Adjustment) -> String {
        guard let end = rule.effectiveEnd else { return "" }
        if end < store.state.day { return "New records count again unless another adjustment applies. Earlier records stay in history." }
        return "This adjustment is set to run through " + Days.text(end) + ". You can extend it or review when your usual settings resume."
    }
}

struct DemoControls: View {
    @EnvironmentObject private var store: AppStore
    @State private var confirming = false
    var close: () -> Void
    var reset: () -> Void

    var body: some View {
        SheetFrame(title: "Demo controls", subtitle: "Fictional records · local only", close: close) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title: "Current demo day")
                    Text(Days.text(store.state.day, "EEEE, MMMM d")).font(.title3.bold())
                    Text("Advance to reveal the next day’s synthetic logs and try follow-ups, expiration, and future effects.")
                        .font(.subheadline).foregroundStyle(Theme.slate)
                    ActionButton(title: "Advance one day", icon: "arrow.right") { store.advance() }
                        .disabled(store.state.day >= Days.last).opacity(store.state.day >= Days.last ? 0.55 : 1)
                }
            }
            ActionButton(title: "Reset demo", icon: "arrow.counterclockwise", secondary: true) { confirming = true }
        }
        .alert("Reset demo to October 29?", isPresented: $confirming) {
            Button("Reset demo", role: .destructive) { store.reset(); reset() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes local drafts, adjustments and dismissed follow-ups.") }
    }
}
