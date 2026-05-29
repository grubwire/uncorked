# Session state — redesign loop finished (2026-05-29)

The HIG-aligned visual redesign (Task D) shipped, and this session closed out
three of the four follow-up items. Design source of truth:
`docs/specs/visual-design-direction.md`.

Standing constraint: **native bones, custom skin**. No user-facing strings
mention Wine / engine / wrappers / version numbers (CLAUDE.md naming rule —
overrides spec lines that mention "engine version").

## Shipped (all on `origin/main`)

**Task D — redesign (prior session):** spec amendments `8a67081`; accent
`cf35f24`; native toolbar `08967c3` (+ icon fixes `d6af693`, `3a24689`);
contained library + rows `e937c13`; row redesign + context menu `a86fa7e`;
inline detail + native Settings sidebar + materials `5ee41dd` (+ accent-bar
drop `0ad8662`); single-instance + a11y `fc0768b`; labeled "+ Install"
affordance `7f567c9`; Task-D doc `4006c3f`.

**This session (redesign-loop cleanup):**
- `1c8d18e` — **dead-code removed**: deleted `AppSettingsSheet.swift` +
  `SettingsView.swift` and their pbxproj entries (superseded by
  `EntryDetailView` / `InlineSettingsView`). Build green.
- `c2f67e5` — **Settings content cleanup**: real General (App Data Location
  with Show in Finder + Change…, no raw container path), Updates (second
  toggle relabeled "Windows compatibility updates" — no "engine" string,
  still its own key), About (icon + version + GitHub / Website / Report-an-
  Issue links; dropped the engine-version line). Replaced the thin shim
  group-views with finished content.

Theme tokens: `rowSurface`, `rowSurfaceHover`, `regionBorder`,
`Typography.sectionHeader`. All built clean and runtime-checked.

## Decisions worth remembering
- **Install affordance**: labeled "+ Install" toolbar button (blue primary,
  `.titleAndIcon`), suppressed when the library is empty (hero CTA is the
  single target there). Intentional — don't native-correct to a bare icon.
- **Sidebar selection**: native `.sidebar` blue pill, no custom accent bar.
- **No user-facing engine/version strings** anywhere (Updates toggle, About,
  detail Advanced all comply). NOTE: `DiagnosticsView` still has a
  `Section("Engine")` — diagnostics is developer-facing but worth a sweep.
- **Omitted on purpose**: "Change Icon…" (no backing), DLL-overrides editor
  (none exists), engine version in detail/About. Don't ship empty editors.

## "Launch re-runs the installer" — MISDIAGNOSED, not a Crosswire bug (2026-05-29)

Investigated and **cleared**. Last session I saw a `SWGLegendsSetup.exe`
process and inferred Crosswire's Launch ran the installer. Three independent
lines of evidence show that's wrong — Crosswire resolves/launches the correct
installed launcher every time:
1. Bottle `BD247FEE`'s persisted `primaryProgramURL` is the launcher
   (`…/SWG Legends/SWGLegendsLauncher.exe`), not the installer.
2. All five recent run logs show `start /unix …/SWGLegendsLauncher.exe`.
3. `updateInstalledPrograms` enumerates only `drive_c/Program Files[ (x86)]`
   inside the bottle, so `~/Downloads/SWGLegendsSetup.exe` can't ever be in the
   list `runPrimary` chooses from.

The `SWGLegendsSetup.exe` process was either a stale leftover from a prior
launcher run, or the SWG launcher's own child — the launcher re-invokes its
Downloads bootstrapper because the game is **not fully installed** (SWG dir is
only ~237 MB: launcher + a few patch `.tre` files + `hs_err_pid228.log`, the
#93 crash dump). That's downstream of #93 (patcher crash leaves the install
incomplete), not a primary-resolution bug. **No Crosswire fix needed here.**

## Single-instance — needs its own pass

Shipped (`fc0768b`) but **currently inert** (safe). Verified at runtime:
`Wine.runningProcessIDs` matches `WINEPREFIX=<prefix>` in `ps -E`, but macOS
**hides the environment of Crosswire's detached `wine start /unix` processes**
from `ps` (`ps -E -p <pid>` shows command only). So detection returns empty →
the guard never fires → it always falls through and spawns. The self-healing
design means launches are NOT broken, just un-deduped.

- **Lead fix candidate: match by argv, not env.** The wine process's argv IS
  visible (`Z:\…\X.exe` / `C:\Program Files…\X.exe`) even when env isn't. Map
  the bottle's program URL → its Windows path/basename and match.
- **Weak spot that approach must solve:** basename collisions across bottles
  (two bottles with the same exe name). Needs to disambiguate (e.g. full
  Windows path, or correlate with the launched program), not just basename.
- Confirming winemac.drv GUI apps surface as `NSRunningApplication` with
  `.regular` policy is still unverified (the installer, not a GUI app, was
  what launched during the test — see the bug above).

## Observability state (diagnosed 2026-05-29)

- **Local logging: yes.** Each wine launch writes a timestamped file to
  `~/Library/Logs/app.Crosswire.Crosswire/<ISO8601>.log` (`Wine.makeFileHandle`):
  app + bottle header, process info (args/exe/cwd/env), then every stdout
  (`Logger.wineKit.info`) and stderr (`.warning`) line + the exit status.
  Dual-logged to os.log (Console.app). Logs auto-pruned after 7 days.
- **Crash surfacing:** `FailureWatcher` shows a "stopped unexpectedly" dialog
  (Report… → prefilled GitHub issue with log + engine version + bottle config /
  View Log / Not Now) on `crosswireProgramDidExit` when `isAbnormal`
  (`exitCode != 0`), debounced 30s/exe. **Manual reporter, not telemetry.**
- **⚠️ The gap that matters:** launches use detached `wine start /unix`. The
  captured process is the `start` invocation, which exits ~immediately (status
  0) after handing off to wineserver; at that point `drainPipesAtTermination`
  clears the readers and **closes the log handle**. So the per-run log captures
  only the launch + first seconds — the long-running app's later output
  (crash-time Wine/JVM stderr) is NOT captured, and FailureWatcher never fires
  (start exited 0). **GUI-app crashes (#84/#93 class) are invisible to
  Crosswire's own logs** — the only crash evidence is the JVM's `hs_err_pid*`
  dumps written into the bottle dir.
- **Sentry: not wired** (zero references; no dependency). The Privacy pane's
  "crash reporting in a future release" is pure placeholder text.
- **Notifications: pure placeholder.** The bell is a non-functional button; no
  event model, store, or view behind it.

## Next-session queue (priority order)
(The former #1 "Launch-runs-installer" item was investigated and cleared —
see the misdiagnosis section above. Not a Crosswire bug.)
1. **Observability follow-up** — capture the detached app's *full-lifetime*
   stdout/stderr (keep a per-launch log open for the app's life, or a debug
   launch path without `start` detachment, or `WINEDEBUG` channels tee'd to a
   persistent file). **Prerequisite for #84/#93** — they're currently
   undebuggable via Crosswire's own logs (see Observability state above). Do
   this before attacking the engine bugs.
2. **Single-instance pass** — argv-matching, solve basename collisions, verify
   `.regular` policy + focus end-to-end.
3. **Light mode** — parallel light palette in `CrosswireTheme` for the
   persistent branded-hex shell (materials already adapt; hex doesn't).
4. Minor: sweep `DiagnosticsView`'s `Section("Engine")` wording.

## Out of scope (designed-for, not built)
Notifications panel (bell placeholder), What's New panel (sparkle
placeholder), background-install rework, icon extraction, Sentry.

## Open issues
- **#84 / #93** — SWG launcher JavaFX crashes (login click; mid-Update). Engine
  (Wine-fork) level, not app code — need CrossOver patch diff or newer Gcenx
  Wine. (#90 and #92 closed this cycle.)

## Repo state
- Branch `main`. Latest work: toolbar spacing polish (`2cfca28`) + this
  observability diagnosis. All redesign-loop items (dead-code, Settings
  cleanup) shipped earlier this session.
- CI: confirm green on the latest commit.
- Working tree clean after the SESSION-STATE commit lands.
