# Session briefs — 2026-05-28 (visual-direction pass)

This file is the working plan for the current session. Execute tasks in order.
Stop at every numbered stop point. Do not auto-chase. If a stop reveals an
issue, report and wait — do not silently fix and proceed.

`docs/superpowers/` is owned by the superpowers plugin. Do not touch.

---

## Task A — Repo doc cleanup (do this first, ~15 min)

The repo has markdown sprawl. Consolidate. `docs/superpowers/` is owned by
the superpowers plugin — do not touch it.

1. Audit every `.md` file in repo root and in `docs/` (excluding
   `docs/superpowers/`). List with one-line descriptions.
2. Proposed moves (execute after approval):
   - Root keeps only GitHub-standard files: README.md, LICENSE,
     CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CLAUDE.md
   - Everything else moves under `docs/` with these subdirs:
     - `docs/sessions/` — dated session notes (OVERNIGHT-2026-05-27,
       SESSION-2026-05-27, HANDOFF renamed to HANDOFF-2026-05-27,
       SESSION-BRIEFS, SESSION-STATE)
     - `docs/milestones/` — milestone docs (CHECKPOINT-D-SHIPPED,
       MILESTONE-SWG-LAUNCHER)
     - `docs/specs/` — research and specs (existing files plus
       SWG-CONTEXT and crosswire-implementation-plan)
3. Report proposed moves before executing.
4. After approval: execute as a single commit with `git mv` to preserve
   history. Update internal cross-references in the same commit. Update
   CLAUDE.md if it references doc paths.

**Stop point:** report moves, wait for approval before executing.

**Status:** shipped in commit `5cbb2a6` — 9 files moved via `git mv`,
100% rename detection, cross-references verified.

---

## Task B — Write the design direction spec

Save the design spec as `docs/specs/visual-design-direction.md`. Commit it.
This is the source of truth for Task D.

**Stop point:** confirm the spec is committed before moving to Task C.

---

## Task C — Pre-flight diagnostics

Before any build pass, do these and report findings. Do not fix anything yet.

1. **WIP build verification.** Per `docs/sessions/SESSION-STATE.md`, the
   previous session left inline Settings code compiling but runtime-untested.
   Run the WIP build, verify the inline Settings actually slides in within
   the main window when the gear icon is clicked. If issues, report them.
2. **Icon extraction diagnosis.** The SWG Legends Launcher entry on bottle
   `7F4FF523` shows "SW" monogram tile instead of an extracted icon.
   Investigate:
   - Did the icon extraction code build into the binary? Confirm the
     function exists in the compiled app.
   - Did it run on this entry's install? Check whatever cache/storage
     location it writes to.
   - If it ran and failed silently, what was the failure?
   - Report findings.
3. **App name source.** Per-app sheet shows "Star Wars Galaxies Legends"
   but the library row shows "SWG Legends Launcher" (or similar
   inconsistency). Identify the source of each name: VERSIONINFO
   ProductName, Start Menu shortcut, or filename. Report.
4. **Detached settings window.** Identify which Swift file/view powers the
   per-app settings detached window (currently shown in Image 2 from this
   morning). Report the file path. This will be replaced in Task D.

**Stop point:** report all four pre-flight findings. Wait before proceeding
to Task D.

---

## Task D — The build pass

Six commits in order. Stop where indicated.

### Commit 1: Project accent color fix

- Change `Assets.xcassets/AccentColor.colorset/Contents.json` (or wherever
  project accent lives) from orange to Crosswire blue. Match the blue used
  in `CrosswireTheme.swift`.
- Verify: relaunch app, open Sparkle's "Check for Updates" → "You're up to
  date" dialog. OK button MUST be blue. If still orange, search the
  codebase for other accent sources and fix.

**Stop point 1:** report Sparkle dialog state. Confirm blue before
continuing.

### Commit 2: Header restructure

Per spec "Header / chrome" section. Specifically:

- Remove "Crosswire" wordmark from main window. Window title bar empty.
- Add Crosswire icon top-left with chevron dropdown menu.
- Add "Library" tab control (designed to support future tabs).
- Add three icons top-right: sparkle (placeholder, non-functional), bell
  (placeholder, non-functional), gear (wires to existing inline Settings).
- The current prominent "Install a Game or App" button: move out of the
  top header. Becomes the empty-state CTA OR a "+" affordance inside the
  Library container header.

**Stop point 2:** show the new header. Confirm before continuing — this
is the riskiest visual change.

### Commit 3: Library container + row surfaces

Per spec "Library page" section. Container surface, section header chrome,
individual row surfaces, hover and selected states, transitions.

No stop point. Cosmetic refinement.

### Commit 4: Library row redesign + right-click context menu

Per spec "Library row structure" and "Row interactions" sections.

- Remove gear icon from row.
- Replace play arrow with discrete "Launch" button.
- Single-click row → inline per-app detail view (Commit 5).
- Right-click row → SwiftUI contextMenu with all items per spec.
- Context menu action wiring:
  - Launch / Show Details: existing code
  - Rename: existing inline rename logic
  - Change Icon...: NSOpenPanel filtered to image files (.png, .jpg, .icns,
    .ico), saves user choice to bottle metadata, displays in row
  - Check Dependencies: existing PE-imports detector pass
  - Show in Finder: reveal bottle's drive_c via NSWorkspace
  - Uninstall: existing confirmation dialog

**Stop point 3:** show the new row. Confirm before continuing.

### Commit 5: Inline per-app detail view

Per spec "Inline per-app detail view" section.

- Slide-in within main window. No detached window. No separate traffic
  lights.
- Delete the old per-app detached settings window (the file identified in
  Task C step 4). If shared with other surfaces, refactor instead of
  deleting.
- Same slide-in pattern as inline main Settings.

No stop point. Pattern established.

### Commit 6: Atmospheric polish + single-instance enforcement

Per spec "Atmospheric details" and "Single-instance enforcement" sections.

- Verify gradient background is actually visible (not flat).
- Apply hover transitions, slide transitions, shadows, borders per spec.
- Implement single-instance enforcement in Wine.runProgram.
- Add Advanced toggle "Allow multiple instances" defaulting off.

**Stop point 4:** final review of full pass before pushing.

---

## Task E — Post-build housekeeping

After Task D ships:

1. Update `CLAUDE.md` with:
   - Reference to `docs/specs/visual-design-direction.md` as the design
     source of truth
   - Updated current-state section noting which features shipped this
     session
   - Updated next-session queue
2. Update `docs/sessions/SESSION-STATE.md` with completion summary and any
   remaining WIP.
3. Confirm everything committed and pushed to main. CI green on latest
   commit.
4. List the top 3 things in the queue for the next session in priority
   order. Candidates:
   - Notifications panel + background installs (architectural pass,
     likely largest)
   - Light mode
   - Sentry crash reporting + onboarding flow
   - Bug #93 (SWG patcher crash, Wine-side investigation)
   - Bug #84 (pre-existing SWG post-login crash)
   - Icon extraction fix (separate from polish pass)

   Pick the top 3 based on what's most leveraged.

---

## Acceptance criteria for the full pass

- No "Crosswire" wordmark anywhere in main window
- No orange anywhere (Sparkle dialog OK button is the canary — must be blue)
- Library row has discrete Launch button, no gear icon
- Single-click row → inline detail view (no detached window)
- Right-click row → context menu with all listed items wired
- Inline per-app detail view replaces detached settings window
- Atmospheric depth visible (gradient + elevation + shadows)
- Single-instance enforcement prevents duplicate launches
- All UI surfaces feel like contained spaces, not floating elements on a
  page
- The app reads as a Mac launcher, not a website in a window
- All docs cleanly organized under `docs/` with `docs/superpowers/`
  untouched

## What's explicitly out of scope this session

- Notifications panel functionality (placeholders only)
- What's New panel functionality (placeholders only)
- Background install rework
- Light mode
- Icon extraction fix (diagnose only in Task C)
- Sentry crash reporting
- Bug #93 (SWG patcher crash)
- Bug #84 (SWG post-login crash)

## Final notes

- Read the spec (`docs/specs/visual-design-direction.md`) before each
  commit. It's the source of truth for what.
- Stop at every numbered stop point. Do not auto-chase.
- If a stop reveals an issue, report and wait. Do not silently fix and
  proceed.
- If the pass finishes with agent time/context remaining, do NOT start the
  next-session items. Stop cleanly.
