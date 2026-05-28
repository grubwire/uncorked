# Session state — handoff at 2026-05-28 02:30 CDT

Snapshot of where the in-flight brief stands. Use this to decide whether to compact or start fresh.

## What's done (committed + pushed)

Latest shipped commit on `main`: **`c04e208` (Brief 2 / main window pass)** — the visual identity, naming, theme, library row redesign, and empty state are all green and validated as the new HEAD that's running in `/Applications/Crosswire.app`.

Earlier this session, **Brief 1 fully shipped** (commits `9ca8ccf` through `93a5425`): foundation bug fixes (#91, #92, #94, #95, #98), MainActor install guard, validation against fresh SWG + Notepad++ installs, killBottle after install + auto-launch.

## What's half-done (uncommitted, in working tree)

**Section 1 of the inline-navigation brief.** I'm in the middle of converting Settings from a separate window (SwiftUI Settings scene) to a full-bleed inline destination via the Battle.net pattern. The code compiles clean; it has NOT been runtime-tested yet. Files modified/added below.

### New files (added to pbxproj via `xcodeproj` Ruby gem)
- `Crosswire/Views/AppRoute.swift` — the top-level navigation enum (`.library / .settings / .entryDetail(UUID)`)
- `Crosswire/Views/Settings/InlineSettingsView.swift` — the new inline Settings panel. Battle.net layout: title bar, sidebar nav with 5 sections (General/Updates/Privacy/About/Advanced), content pane, footer with version chip left + blue Done button right. Content is wrapped via three group views (`SettingsGeneralGroup`, `SettingsUpdatesGroup`, `SettingsAboutGroup`) that preserve existing behavior — Section 3 of the brief is the content-cleanup pass that relabels the duplicate Crosswire/Engine updates toggles and rebuilds About.

### Modified files
- `Crosswire/Views/ContentView.swift` — added `@State var route: AppRoute = .library`, added `sparkleUpdater` parameter (passed from `CrosswireApp`), wrapped library content in `libraryRoot` computed var, added `ZStack` overlay branch for `.settings` route with slide-in `.transition(.move(edge: .trailing))`, replaced `SettingsLink` with `Button` that sets `route = .settings` (kept `Cmd+,` via `.keyboardShortcut(",", modifiers: .command)`), `swiftlint:disable file_length` added because the file passed 400.
- `Crosswire/Views/CrosswireApp.swift` — removed the `Settings { SettingsView(updater:) }` scene block (replaced with a comment explaining the inline conversion). Passes `updaterController.updater` to `ContentView`.
- `Crosswire.xcodeproj/project.pbxproj` — adds for `AppRoute.swift` + `InlineSettingsView.swift` via xcodeproj gem.

### Status
- ✅ Builds clean (`xcodebuild ... build` succeeds)
- ❓ **Not runtime-tested.** I built it but didn't deploy to `/Applications` or relaunch. Sparkle import is one of the SourceKit "no such module" warnings that always fires in indexer noise but compiles fine — but to be safe, runtime check before declaring Section 1 done.
- ⚠️ The `.keyboardShortcut(",", modifiers: .command)` interaction with the standard Mac Settings shortcut might conflict if the old `Settings` scene's auto-bound shortcut still lingers somehow. Worth verifying.
- ⚠️ The original `Crosswire/Views/Settings/SettingsView.swift` is **still on disk** (not deleted). It's no longer mounted as a scene; reference-only. Safe to remove later, but leaving for the Section 1 review.

## What's untouched from the current brief

All sections beyond Section 1:

- **Section 2 — per-entry inline detail.** No code touched. `AppSettingsSheet` is still a `.sheet(item:)` modal in `ContentView`. Brief calls for `.entryDetail(UUID)` route + back-chevron + same slide animation.
- **Section 3 — settings content cleanup.** Toggle labels, default-path "Show in Finder", About icon+versions+links, blue toggle tint (partially done — `SettingsGeneralGroup` and `SettingsUpdatesGroup` already have `.tint(CrosswireTheme.accent)`). Full About card rebuild not done.
- **Section 4 — per-entry detail content.** Blocked on Section 2.
- **Section 5 — single-instance enforcement.** No code touched. `Wine.runProgram` still allows arbitrary duplicate launches.
- **Section 6 — library row interaction.** Row currently runs on tap (shipped in `c04e208` as part of main-window pass). Brief calls for tap → detail nav, run-button → run. Two-line change in `AppRow.swift` + `ContentView.swift` once Section 2's `.entryDetail` route exists.
- **Section 7 — theme + animation consistency.** Largely already in place from Brief 2 main-window work; would need a small audit pass at the end.

## Files NOT modified this session beyond what's listed

The Brief 2 main-window surfaces (`AppRow`, `AppTileIcon`, `CrosswireTheme`) are at their `c04e208` shipped state. The original `SettingsView.swift` is unchanged. `AppSettingsSheet.swift` is at its post-Brief-1 state (no Brief 2 changes yet).

## To resume

1. Verify the WIP build runs and the inline Settings actually slides in over the library when the gear icon is clicked. If runtime issues, fix and re-commit before continuing.
2. Section 1 commit-and-review: ask the user to confirm the Settings slide-in feels right (sidebar layout, blue accent bar on selected item, Done button behavior, version chip) before going to Section 2.
3. Then Section 2 (per-entry detail) is the next chunk — should reuse the same `AppRoute` infrastructure + slide-in pattern from Section 1.

## Repo state

- Branch: `main`
- HEAD pre-WIP: `c04e208`
- WIP commit: see commit hash after this doc lands
- CI: green on `c04e208`
- Working tree: clean after the WIP commit lands
