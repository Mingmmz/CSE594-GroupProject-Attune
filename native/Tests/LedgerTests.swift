import Foundation

@main struct LedgerTests {
    static func main() throws {
        func date(_ day: Int) -> Date { Days.make(2026, 10, day) }
        let today = Days.start
        let before = Ledger(state: DemoState())
        let month = Ledger.windows(today, .year)[9]
        let year = Window(start: Days.first, end: Days.make(2026, 12, 31), label: "2026")
        let finalTile = Ledger.windows(today, .month).last!
        let log = before.on(.sleep, today)!
        let work = Draft(metric: .sleep, anchor: today, reason: .deadline, note: Reason.deadline.example,
                         start: date(26), end: date(30), pause: true)
        let after = before.adding(work)
        let oldMonth = before.totals(.sleep, in: month)
        let newMonth = after.totals(.sleep, in: month)
        precondition(log.value == 62 && log.note!.contains("5 hr 02 min") && after.on(.sleep, today) == log)
        precondition(oldMonth.counted - newMonth.counted == 4 && oldMonth.raw == newMonth.raw && oldMonth.records == newMonth.records)
        precondition(oldMonth.tier == 4 && newMonth.tier == 3, "October’s tile in Year must visibly change")
        precondition(before.totals(.sleep, in: finalTile).tier == 1 && after.totals(.sleep, in: finalTile).tier == 0)
        precondition(before.totals(.sleep, in: year).counted - after.totals(.sleep, in: year).counted == 4)
        precondition(after.usual(.sleep).used == before.usual(.sleep).used - 4)
        precondition(after.reminder(.sleep, today) && after.coaching(.sleep, day: today).contains("deadline"))
        print("✓ Original 62 stays intact. October counted unusual: \(oldMonth.counted) → \(newMonth.counted). Last tile: 1 → 0.")

        var later = after
        later.state.day = date(31)
        precondition(later.excluded(later.on(.sleep, date(30))!) && !later.excluded(later.on(.sleep, date(31))!))
        precondition(later.coaching(.sleep, day: date(31)).contains("New records count again"))
        precondition(Adjustment(work).status(on: date(31)) == .completed)
        print("✓ Inclusive end date covers newly revealed logs and resumes normal counting after it.")

        let travel = Draft(metric: .sleep, anchor: today, reason: .travel, start: date(28), end: date(30))
        let extended = Adjustment(work).revise(.extend(date(31)), on: today)!
        precondition(extended.contains(date(31)))
        precondition(extended.revise(.extend(date(28)), on: today) == nil)
        let ended = extended.revise(.end(resumeOn: today), on: today)!
        var overlap = after.adding(travel)
        overlap.state.adjustments[0] = ended
        precondition(ended.effectiveEnd == date(28) && ended.status(on: today) == .ended)
        precondition(overlap.adjustments(.sleep, date(27)).map(\.id) == [work.id])
        precondition(overlap.adjustments(.sleep, today).map(\.id) == [travel.id])
        precondition(!overlap.reminder(.sleep, today))
        overlap.state.adjustments[0] = ended.revise(.undo, on: today)!
        precondition(!overlap.excluded(overlap.on(.sleep, date(27))!) && overlap.excluded(log))
        print("✓ Extend, end early and undo respect boundaries and leave separate overlapping reasons intact.")

        var repeating = before
        for (a, b) in [(3, 5), (10, 12)] {
            repeating = repeating.adding(Draft(metric: .sleep, anchor: date(a), reason: .deadline, start: date(a), end: date(b)))
        }
        precondition(repeating.recurring(work))
        repeating.state.adjustments[1].askAgain = false
        precondition(!repeating.recurring(work))
        var keep = work
        keep.mode = .keep
        precondition(before.adding(keep).totals(.sleep, in: month) == oldMonth)
        precondition(before.adding(keep).interpretation(log).contains("Work deadline"))
        print("✓ Recurring matches require two distinct opted-in periods. Counting with a note keeps the trend count.")

        let active = Draft(metric: .activity, anchor: today, reason: .injury, note: Reason.injury.example,
                          start: today, end: nil, keepNote: true, pause: true)
        let cycleLog = before.records(.cycle).last!
        let cycle = Draft(metric: .cycle, anchor: cycleLog.day, reason: .routine, start: cycleLog.day, end: cycleLog.day)
        let combined = before.adding(active).adding(cycle)
        precondition(combined.on(.activity, today)?.value == 3_200 && combined.excluded(combined.on(.activity, today)!))
        precondition(combined.reminder(.activity, today) && combined.coaching(.activity, day: today).contains("recovery"))
        precondition(combined.records(.cycle) == before.records(.cycle) && combined.on(.cycle, cycleLog.day)?.value == 22)
        precondition(combined.totals(.cycle, in: month).counted + 1 == before.totals(.cycle, in: month).counted)
        precondition(combined.totals(.sleep, in: month) == oldMonth)
        print("✓ Activity and cycle corrections alter their own trends and preserve logged steps and period starts.")

        var flagged = active
        flagged.mode = .measurement
        flagged.note = "I walked 5,000 steps."
        flagged.keepNote = false
        let cue = before.measurementConflict(flagged)
        let flaggedState = before.adding(flagged)
        precondition(cue?.value == 3200 && flaggedState.state.adjustments[0].note == nil)
        precondition(flaggedState.totals(.activity, in: month) == before.totals(.activity, in: month))
        precondition(flaggedState.interpretation(cue!).contains("flagged"))
        precondition(Adjustment(active).revise(.clearNote, on: today)?.note == nil)
        let wire = try JSONEncoder().encode(DemoState(day: today, adjustments: combined.state.adjustments, drafts: [work]))
        let stored = try JSONDecoder().decode(DemoState.self, from: wire)
        precondition(stored.drafts == [work] && stored.adjustments == combined.state.adjustments)
        print("✓ Measurement flags do not alter the source. Drafts and saved wording choices survive a storage round-trip.")

        let yearWindows = Ledger.windows(today, .year)
        let november = before.totals(.sleep, in: yearWindows[10])
        precondition(november.records == 0 && november.counted == 0)
        precondition(before.totals(.cycle, in: Ledger.windows(today, .month)[0]).records == 1)
        precondition(yearWindows.reduce(TrendCount()) { $0 + before.totals(.sleep, in: $1) } == before.totals(.sleep, in: year))
        print("✓ The yearly totals match the sum of all 12 months. Future and no-log ranges stay distinct.")

        for zone in ["America/Chicago", "America/Los_Angeles", "Asia/Tokyo", "Pacific/Auckland"] {
            var local = Calendar(identifier: .gregorian)
            local.timeZone = TimeZone(identifier: zone)!
            let selection = Days.toPicker(date(30), using: local)
            precondition(local.component(.day, from: selection) == 30)
            precondition(Days.fromPicker(selection, using: local) == date(30))
        }
        print("✓ Date pickers preserve the same calendar day across negative and positive time zones.")
    }
}
