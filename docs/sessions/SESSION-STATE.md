# Session state — redesign loop finished (2026-05-29)

The HIG-aligned visual redesign (Task D) shipped, and this session closed out
three of the four follow-up items. Design source of truth:
`docs/specs/visual-design-direction.md`.

Standing constraint: **native bones, custom skin**. No user-facing strings
mention Wine / engine / wrappers / version numbers (CLAUDE.md naming rule —
overrides spec lines that mention "engine version").

## ✅ RESOLVED: SWG #84/#93 — JVM safepoint fix (2026-05-29)

The SWG launcher's login crash (#84) and patcher crash (#93) are **fixed**
(`3fad7e6`). The root cause was **not** Wine networking, certs, or a Wine-fork
gap we had to patch — it was a **JVM↔Wine thread-suspension bug**: HotSpot
crashes with `Illegal threadstate encountered: 6` (`safepoint.cpp:712`), and
faults in Wine's `ntdll`, when it suspends a thread mid native↔VM transition to
reach a safepoint. It hit hardest on the launcher's **network/Finalizer
threads** closing TLS connections — which is exactly why content/patch-check
appeared to "hang on the network" (connections in `CLOSE_WAIT`) and the patcher
died ~392 MB in. (TLS itself was always fine: 14 successful handshakes, no cert
errors; the cacerts even has ISRG Root X1.)

**Fix:** extend the seeded `_JAVA_OPTIONS` for bundled-JRE launchers to suppress
the avoidable safepoints — `-XX:-UseBiasedLocking`,
`-XX:+UnlockDiagnosticVMOptions -XX:GuaranteedSafepointInterval=0`,
`-XX:-UsePerfData` (in `JavaAppDetector.recommendedJavaOptions`; also written
into the SWG bottle's per-program plist so it applies now).

**Verified live:** login works → launcher content + news load → "Update"
becomes available → patcher downloads **past 1.8 GB** with zero crashes (it
died at ~392 MB before). How we found it: `javax.net.debug` capture (via a
shell launch with stderr→file, since the JVM does its own TLS, not Wine's
schannel) caught the fatal safepoint error firing on the URL-Loader/Finalizer
threads. Follow-ups: minimize the flag set, verify/close the GitHub issues.

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

## Brief 1 — engine diagnostics findings (2026-05-29)

Exercised the `captureDiagnostics` path (built `91998ab` + `c9ffd6f`) against
SWG for the first time. Results:

- **The capture path does NOT work for SWG (or any re-exec'ing launcher).**
  `SWGLegendsLauncher.exe` is a stub that re-execs as a *detached*
  `javaw.exe -jar … (ppid=1)`. The direct-`wine` foreground process exits at
  ~5s when the stub forks javaw, so the per-launch log closed with **only the
  794-byte header — zero app output**, and `presentDiagnostics` fired at that
  5s stub-exit, long before any crash. Same blind spot as `start /unix`, just
  moved to "stub exits". **This is the thing to fix.**
  - Achievable fix: don't end the diagnostics run at foreground-process exit —
    **poll until the bottle is idle** (no wine procs for the prefix), *then*
    scan for + reveal `hs_err_pid*.log`. Delivers the JVM crash dump (the real
    #84/#93 evidence) reliably even without live stdout.
  - Hard part (defer): live stdout/stderr of detached, re-exec'd Wine children
    across the wineserver boundary — same class of problem as the original.
- **SWG install is incomplete** (237 MB: launcher + bundled JRE + 2 patch
  `.tre` fragments; no base game data). Launcher runs; game never downloaded.
- **#84 is currently worked around.** With `dwrite=builtin` + `prism.order=j2d`
  + `-Xint`, **login SUCCEEDS** (verified live — reached the post-login screen,
  "Update Required — 571 patches"). The reachable crash is #93 (the patcher),
  which needs the full multi-hundred-MB download (not driven — long + corrupts
  state, and the capture path can't catch it anyway).
- **Crash read (from `hs_err_pid228.log`, the real on-disk data):**
  `EXCEPTION_ACCESS_VIOLATION` at **`ntdll.dll+0x52070`** (Wine builtin ntdll),
  near-null deref (`ecx=0x107`), on a daemon thread `_thread_blocked_trans`,
  **during a JVM safepoint** (VM `synchronizing`; VMThread holds
  `Safepoint_lock`+`Threads_lock`). Loaded: glass/dwrite/opengl/**wined3d**
  (no DXVK). **This signature matches neither documented issue** (#84
  `pc=0x7bf2800b` BitSet.equals; #93 `pc=0xfffffcc8` vtable) — it's a third
  signature: a Wine-ntdll fault during JVM thread-suspension for a safepoint.
- **Leading fix direction for #84/#93:** Wine-fork ntdll thread-suspension /
  SEH gap (NtSuspendThread / NtSetContextThread / exception dispatch) —
  CrossOver-patches-vs-Gcenx-11.9. **Not** app-level, **not** DXVK/Vulkan,
  **not** Crosswire config (env/plist/dwrite all correct; login works).
  Engine-level effort; out of scope per the brief.

## Next-session queue (priority order)
(Done this session: capture-path fix `72f07be`; SWG #84/#93 fix `3fad7e6`.)
1. **Verify + close #84/#93 on GitHub**, and let the SWG patch download finish
   / launch the game to confirm in-game works end-to-end.
2. **Minimize the safepoint flag set** — `3fad7e6` ships the full working combo
   (`-XX:-UseBiasedLocking -XX:GuaranteedSafepointInterval=0 -XX:-UsePerfData`);
   confirm which are actually load-bearing (likely `-UseBiasedLocking`) so the
   shipped default for *all* Java apps is minimal.
3. **Single-instance pass** — argv-matching, solve basename collisions, verify
   `.regular` policy + focus end-to-end.
4. **Light mode** — parallel light palette in `CrosswireTheme` for the
   persistent branded-hex shell (materials already adapt; hex doesn't).
5. Minor: sweep `DiagnosticsView`'s `Section("Engine")` wording.
6. (Optional) diagnostics "hard part" — live stdout/stderr capture of detached
   re-exec'd children (the capture-path fix surfaces `hs_err`, not live output).

## Out of scope (designed-for, not built)
Notifications panel (bell placeholder), What's New panel (sparkle
placeholder), background-install rework, icon extraction, Sentry.

## Open issues
- **#84 / #93 — RESOLVED 2026-05-29** by the JVM safepoint flags (`3fad7e6`,
  see the ✅ section near the top). SWG logs in, loads content, and downloads
  the game past 1.8 GB with no crash. Should be verified + closed on GitHub.
  (#90 and #92 closed earlier.)

## Repo state
- Branch `main`. This session shipped: inline-panel **consistency pass**
  (`b1cc1dd`, `b184252`, `4717593`); diagnostics **capture-path fix**
  (`72f07be`); **SWG #84/#93 fix** (`3fad7e6`); docs.
- The SWG bottle's per-program plist `_JAVA_OPTIONS` was also updated in place
  (data, not committed) so Crosswire's normal Launch uses the new flags now.
- A shell-launched SWG instance is **still downloading the game** (left running
  on purpose) — safe to let finish or quit.
- CI: green through `4717593`; confirm on `3fad7e6`/this doc.
- Working tree clean after the SESSION-STATE commit lands.
