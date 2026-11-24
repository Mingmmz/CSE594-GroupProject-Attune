# ATTUNE Stage 3: native demo and evaluation

The course handout calls for a working interactive prototype, an evaluation with at least five target users, and a report. The protocol below is ready to use; participants and results have not been filled in.

## How the native prototype addresses Milestone II

| Planned change | Where to try it |
| --- | --- |
| 1. Show concrete effects while preserving original values | From any record, use **Not Typical → See AI-suggested changes**. Preview and receipt show original measurement, before/after usual values and interpretations, the affected heatmap tile, monthly and yearly counts, and coaching. Sleep, activity, and cycle have distinct records and examples. |
| 2. Make the context and proposal directly editable | Context starts blank; examples are optional. Review shows what Attune understood and offers **Edit my explanation** and **Edit affected dates** without clearing the draft. The native text field can use the device’s dictation if enabled. |
| 3. Make affected dates and duration clear | Date pickers show an included end date and first day counting resumes. Scope, review, receipt, and Memory reuse a labeled timeline with same-sized tiles. Sleep uses nights, activity days or a week, and cycle attaches to logged period-start dates. |
| 4. Edit, extend, end early, undo, and save drafts | **Memory** separates active and previous adjustments. Edit changes dates/wording; extend adds future dates; end early keeps previous effects; undo restores original handling except where another rule applies. Drafts resume from Summary, the original record, or Memory. |
| 5. Manage overlap and repetition | Overlapping adjustments have separate IDs and show in Memory with their individual dates. Two separate opted-in prior periods trigger a check-in for a similar proposal. Continue temporarily, count it toward the usual pattern, or dismiss. There is no automatic future reuse. |
| 6. Show long-term feedback and offer optional reminders | **Overview → Month/Year** shows original vs counted records, recalculated color tiles, usual estimates, and contextual coaching. Activity acknowledges an injury without insisting on making up steps. The optional reminder switch and follow-up inbox update as the demo date advances. |
| 7. Clarify what is saved and simplify the flow | Review is organized by what changes, what stays, affected records, and duration. Raw records always stay visible. Optional exact wording defaults off, can be edited or removed later, and drafts can be discarded. Receipt uses **Back to Home**. |

The initial storyboard supplied with the task motivated the Oct 29 sleep record, three-row heatmap, Overview/Summary/Ask/Profile navigation, Not Typical cards, Memory tabs, and follow-up inbox. The first and second research presentations and research report motivate verification, lightweight context, editable scope, and a cue for conflicts with the original measurement. The old Figma correction workflow is represented in the native prototype, with actual recalculation across the month and year.

Attune runs from a synthetic ledger with deterministic proposals. It does not connect to HealthKit, send OS notifications, transcribe audio itself, or make diagnoses. A measurement flag preserves the source value and records a discrepancy for review.

## Live presentation (5 minutes)

| Time | What to show |
| --- | --- |
| 0:00–0:40 | A short night shows what happened. It does not show why or whether it belongs in the usual pattern. |
| 0:40–2:55 | In October, open the 62 sleep record, enter a deadline, keep Oct 26–30 inclusive, and preview the tile 1 → 0 and October 8 → 4. Apply, show Year and Original, and find the original log again. |
| 2:55–3:40 | Show **Memory → End early** and explain how that differs from Undo. Briefly switch to Activity or Cycle to show coverage beyond sleep. |
| 3:40–4:35 | Present the actual participant count, methods, observed outcomes, and a change informed by your study. |
| 4:35–5:00 | Explain what is simulated and what you would validate with more realistic data. |

Use the calendar chip to reset before each session. To reveal the future deadline night and the independent example signal, advance from Oct 29 to Oct 30 and open the bell. The handout asks for slides, the system or a recorded walkthrough, and the evaluation report in the Stage 3 tracking sheet.

## Study protocol

Recruit at least five target users who use wearable health tracking or have used an AI health assistant. Record relevant background using participant codes. Use fictional records only. Follow course consent procedures. Run a moderated think-aloud session for roughly 15 minutes.

1. Can participants explain what a tile counts and distinguish an empty period from a period with zero unusual records?
2. Can participants verify the effect of a correction in both monthly and annual views and find the preserved original record?
3. Can participants specify the intended scope, distinguish end from undo, and explain the persistence choices?

| Task | What to observe |
| --- | --- |
| Look at October, then explain what the darker tiles and the dash mean. | Whether participants understand that the numbers are counts, darker means more unusual records counted, 0 means logged with none unusual, and dash means no logs. |
| You have a deadline through Oct 30. Keep your original sleep log but set the temporary nights aside. | Whether participants can find the call to action, edit context, and correctly identify Oct 30 as inclusive. |
| Show where that changed the current month and year. Find the original 62 score again. | Whether they locate the 8 → 4 October change, use the Year and Original controls, and can return to the unchanged source record. |
| Imagine your deadline is over today. Keep older effects, but allow usual counting to resume. Explain how Undo would differ. | Whether participants find Memory, choose their intended resume date, and understand overlap and historical effects. |
| You have a temporary leg injury. Change the step goal reminder for this period without retaining your exact wording. | Whether they find Activity, understand the reminder scope, and verify what was stored. |

Record completion without help / with help / incomplete. Capture the explanation given, the relevant observed hesitation or wrong turn, and the level of confidence (1–5) that only intended dates changed. Report counts and representative observations with denominators, plus the edits those observations warrant. Do not interpret this study as measuring health outcomes.
