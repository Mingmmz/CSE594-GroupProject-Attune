# ATTUNE · Native Stage 3 prototype

Attune is a SwiftUI app for Mac and iPhone. It shows how someone's context changes the way a health assistant interprets sleep, activity, and cycle records over time. The prototype runs offline with local fictional data; it uses no browser, server, model API, or HealthKit connection.

## Run on an iPhone simulator

Open [Attune.xcodeproj](native/Attune.xcodeproj) in Xcode. Choose the **Attune** scheme and an **iPhone** from the run destination menu, then press **⌘R**. If no iPhone is listed, install an iOS runtime in **Xcode → Settings → Components**. The minimum is iOS 17. A simulator run does not need an Apple Developer account.

Or, from the repo root, build the app, open an available iPhone simulator, and install and launch Attune with one command:

```sh
./native/run-ios.sh
```

To choose a specific simulator, pass its UDID as the only argument. The script reuses a booted iPhone when possible and does not erase simulator data.

For a physical device, select your development team in Signing & Capabilities and choose the connected device.

## Run on a Mac

Open `Attune.app` from the packaged **macOS** build if available. To build from source, use Xcode 16 or later on macOS:

```sh
./native/build-mac.sh
open native/.attune-build/Build/Products/Debug/Attune.app
```

Run `./native/test.sh` for the Swift ledger, history, and calendar checks.

The earlier browser prototype remains in `app/` for comparison. It is not needed to run the native app.

## Five-minute demo

1. Start on **Overview → Month**. October shows **8 unusual sleep records** as of the fictional Oct 29. Click the **Sleep / 29–31** tile and open **Oct 29 · 62/100**. Verify the source still shows **5 hr 02 min**, a **2:10 a.m.** bedtime, one interruption, and **21%** deep sleep.
2. Choose **Not Typical → Don’t count in trends → Work deadline → Choose dates**. Keep **Oct 26–30 inclusive**. Optionally pause the bedtime reminder. The Oct 30 record is marked as future. Exact wording is opt-in.
3. Select **See AI-suggested changes**. Verify the proposed usual sleep score, interpretation, and coaching. The last October tile goes **1 → 0**, October goes **8 → 4**, and the year's count also falls by four. Apply and verify the same comparison in the receipt.
4. Go **Back to Home** and switch to **Year**; October is lighter and shows **4**. Use **After context** to switch back to the original heatmap. The original October tile still shows 8 and the 62 entry is still visible.
5. Open **Memory** to edit, extend, end early, or undo. An early end preserves effects before the resume date. Undo restores the original interpretation across the adjustment’s entire scope unless a separate matching adjustment still applies.
6. Try the example leg injury under **Activity** and the shorter Oct 24 interval under **Cycle**. Neither recorded steps nor period start dates change. The calendar chip advances the demo one day at a time or resets it; the bell opens the in-app follow-up inbox.

The heatmap counts unusually low sleep scores and step totals, or cycle intervals outside the fictional person's reference range. These are demo rules. A darker tile means more records still count as unusual in that time bucket. Labels distinguish a genuine zero from no logs. Date boundaries are inclusive; the app doesn't remove raw records or treat a user explanation as evidence of a medical cause.

See the [Stage 3 guide](docs/stage-3.md) for the Milestone II checklist, presentation flow, and user study protocol. No participant data should be added to this repository.

## Work on the app together

| Path | What to change |
| --- | --- |
| `native/Attune/Domain.swift` | Fictional records, time buckets, trend counts, coaching, and adjustment logic |
| `native/Attune/Overview.swift` | Overview, trend heatmap, Summary, Ask Attune, and Profile |
| `native/Attune/Correction.swift` | Record details, context, date scope, and preview/receipt |
| `native/Attune/Memory.swift` | Adjustment management, follow-ups, and demo controls |
| `native/Attune/AttuneApp.swift` | Native navigation, shared UI components, and persistence |
| `native/Tests/LedgerTests.swift` | Regression checks for dates, trends, and corrections |

To publish the source, create an empty private repository on [GitHub](https://github.com/new) with no generated README, license, or gitignore. In the local repo root:

```sh
git add .
git commit -m "Add native ATTUNE Stage 3 prototype"
git remote add origin https://github.com/YOUR-USERNAME/attune-prototype.git
git push -u origin main
```

Replace the URL if your repository has a different name. If you already configured `origin`, skip the `git remote add` line. Add your group in **Settings → Collaborators**. After cloning, teammates can create a branch, run `./native/test.sh`, push their changes, and open a pull request.
