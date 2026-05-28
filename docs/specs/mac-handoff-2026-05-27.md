# Mac Claude handoff: GPTK + SWG Legends launcher direction

Date: 2026-05-27. Written from `dev-01` (Windows) for the Claude instance on
`nick-macbook`. Companion docs:
`docs/specs/crossover-applesilicon-research.md` and
`docs/specs/crossover-wine-research.md` already cover the CrossOver source
audit; this doc is the bridge from that research to "what to actually do on
the Mac next."

## 1. Bottom line up front

1. **Apple's Game Porting Toolkit is itself a fork of CrossOver's Wine.**
   GPTK 3.0-3 (latest, released 2026-03-03) ships Apple's D3DMetal layer plus
   a Wine source tree derived from CrossOver's. This means every CW HACK in
   our research doc is already present in GPTK. Apple's source is the
   `apple/homebrew-apple` formula at commit
   `2bc44284e24d39ed64d6f492a0e1f4c47a5ced08`; Gcenx mirrors and packages
   it at `github.com/Gcenx/game-porting-toolkit`.
2. **The Metal Developer Tools for Windows** on `dev-01` is NOT GPTK and is
   not useful here. It's a shader compiler + texture converter for
   cross-platform asset pipelines. Discard.
3. **Two paths forward, with different cost/coverage:**
   - **Path A (high coverage, license-constrained):** Use Gcenx's prebuilt
     GPTK 3.0-3 tar.xz as our engine source instead of Gcenx's regular
     wine-staging. We get every CrossOver Rosetta hack for free, plus
     D3DMetal for DX11/DX12 games. Cost: D3DMetal is under Apple's License
     (not freely redistributable), so we cannot bundle it in the DMG; we
     have to download it on first launch with a license-acceptance step,
     and we're constrained to macOS 14+.
   - **Path B (smaller surface, no license issue):** Stay on Gcenx
     wine-staging 11.9, continue porting the CrossOver patches we've
     written (`scripts/patch-*.py`), and wire CW HACK 22434 to dlopen
     `libd3dshared.dylib` from the user's GPTK install when present. For
     SWG Legends specifically (DX9 game), this is enough; D3DMetal isn't
     required.
4. **For SWG Legends specifically, Path B is the right play.** SWG is a
   2003 DX9 game, so D3DMetal isn't required. The Apple Silicon problem is
   the install-launch path, which our existing CW HACK 18947/24945/25719/
   20760/22131/23427/24256 patches address, plus 22434 once we wire it.
5. **CXPatcher and its successor Procyon are the prior art.** Italo
   Mandara's tools patch a stock CrossOver install with D3DMetal/DXVK
   updates. Same problem space; different position (they require CrossOver
   to begin with, we don't). Worth reading for design inspiration.

## 2. What is already patched in-tree

All under `scripts/`. None have been wired into `engine-bundle.yml` yet, but
each is idempotent and takes a Wine source root as its only argument.

| Script | CW HACKs ported | Files touched |
|---|---|---|
| `patch-wine-rosetta.py` | 24945, 25719, 18947 (virtual.c), 23427, 24256, plus read->write fault reclassification | `dlls/ntdll/unix/virtual.c`, `dlls/ntdll/unix/signal_x86_64.c` |
| `patch-cw20760.py` | 20760 (WoW64 lretq thunk, SIGUSR1 race) | `dlls/wow64cpu/cpu.c` |
| `patch-cw22131.py` | 22131 (fake STATUS_SUCCESS on debug-register set) | `dlls/ntdll/unix/signal_x86_64.c` |

Not yet ported (priority order, from the CrossOver research doc):

| CW HACK | What | Cost | Priority |
|---|---|---|---|
| **22434** | dlopen `libd3dshared.dylib`, register every PE module as non-native code region | hard (new syscall slot, env-var plumbing, GPTK dependency) | **highest** |
| 24265 | M3 mxcsr SIGSYS thunk | moderate | medium |
| 26470/26456 | Skip 16-bit LDT under Rosetta (`dlls/wow64/virtual.c`) | trivial | medium |
| server/mach.c rosetta blocks | Fake debug regs cross-process, ignore W-strip in `mach_vm_write` | moderate | low |
| 20186 | `handle_cet_nop` | trivial | low (Big Sur only) |

## 3. Path A: switch engine source to Gcenx GPTK

If we want maximum compatibility (DX11/DX12 + all CrossOver hacks) and accept
the Apple license constraint:

**Asset:** `https://github.com/Gcenx/game-porting-toolkit/releases/download/Game-Porting-Toolkit-3.0-3/game-porting-toolkit-3.0-3.tar.xz`

- Size: 239,200,808 bytes (239 MB compressed)
- SHA256: `d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e`
- Apple Silicon only. macOS 14 Sonoma or later.
- Includes Gcenx-built `wine` plus Apple-supplied D3DMetal libs, plus
  GStreamer.framework v1.28.1.

**License issue.** Apple's D3DMetal binaries are subject to a separate
license (`License.pdf` in the GPTK distribution). We cannot mirror that
archive on R2 without violating the EULA. Two workable patterns:

1. **First-launch fetch from Gcenx releases.** User installs Crosswire (10
   MB DMG, no engine), launches it, gets a sheet saying "Crosswire uses
   Apple's Game Porting Toolkit to run Windows games. Click 'Accept and
   Download' to fetch it from Apple's distribution partner (239 MB)." Click
   pulls directly from Gcenx releases; we never host the archive ourselves.
   Manifest in our R2 still controls the SHA256/version pinning so we can
   roll back.
2. **Detect a system-installed GPTK and use it.** If the user has installed
   GPTK via `brew install --cask --no-quarantine apple/apple/game-porting-toolkit-beta`
   or Apple's official DMG, link against that install instead of fetching
   our own copy. Saves space and license re-acceptance.

Either way, the engine-bundle workflow gets simpler than the current one
because we no longer build wrappers + sign + repack from a raw Gcenx wine
tarball; we just verify hashes against the GPTK release manifest.

## 4. Path B: keep current engine, finish porting patches

If we want to ship sooner and avoid the license/macOS-14-only issue:

### 4a. Wire CW HACK 22434

GPTK ships `libd3dshared.dylib`. Even if we don't switch the whole engine
to GPTK, we can dlopen it from the user's GPTK install (if they have one)
and get the most valuable single CrossOver hack at minimum cost.

**Mac Claude steps:**

1. Install GPTK on `nick-macbook`. Easiest: download
   `game-porting-toolkit-3.0-3.tar.xz` from the Gcenx release and extract.
   Or use `brew install apple/apple/game-porting-toolkit-beta`.
2. Locate `libd3dshared.dylib`. Record absolute path.
3. `nm -gU <path>` to confirm both symbols exist:
   - `_register_non_native_code_region`
   - `_supports_non_native_code_regions`
4. Write `scripts/patch-cw22434.py` modeled on the existing patch scripts.
   CrossOver source to mirror: `docs/specs/crossover-applesilicon-research.md`
   section 4 "Apple Game Porting Toolkit hook." Three files change:
   `dlls/ntdll/unix/loader.c` (unix_pe_module_loaded body + symbol
   resolution), `dlls/ntdll/loader.c` (call site after each PE map), and
   `dlls/ntdll/unix/unix_private.h` (new syscall slot).
5. Rename env var `CX_APPLEGPTK_LIBD3DSHARED_PATH` to
   `CROSSWIRE_LIBD3DSHARED_PATH` in the patch.
6. App-side: add `CrosswireKit/Engine/GPTKDetection.swift` that probes
   standard GPTK install paths and exposes the resolved dylib path (or
   nil). `Wine.swift` threads it into the child environment when launching
   `Crosswire64`.

### 4b. The blocking workflow change

`engine-bundle.yml` currently ships pre-built Gcenx binaries unmodified.
None of our patches run. Minimum change to make the patches matter:

```
download Gcenx prebuilt
  -> clone Wine 11.9 source matching the Gcenx tag
  -> apply patch-wine-rosetta.py + patch-cw20760.py + patch-cw22131.py + patch-cw22434.py
  -> build *only* the patched .so/.dylib files (ntdll.so, wow64cpu.dll.so, etc.)
  -> swap them into the Gcenx tree
  -> sign, smoke test, pack
```

Selective rebuild is preferred over a full Wine-from-source build because
the full build is 30+ minutes on `macos-14` runners and the Gcenx tree
already ships a working baseline. `build-preloader.yml` is a working
example of the partial-build pattern; extend it.

## 5. SWG Legends launcher: stock Wine vs native macOS

User goal: SWG Legends runs reliably. Crosswire-the-general-app works in
parallel.

### Status quo (Wine launcher)

- The stock SWG Legends launcher is a Windows app; runs under Wine.
- Does login, patches, spawns `SwgClient_r.exe`.
- Whether it survives depends entirely on the patch set above. The
  launcher does HTTPS file fetching + spawning a child process; both are
  exactly what CW HACK 18947/22434/24945/25719/20760 are designed to fix.
- Pro: zero reverse-engineering. Con: every Wine-side AS bug shows up as
  "launcher crashes."

### Native macOS launcher option

- Reimplement the SWG Legends launcher as a Swift app on macOS.
- Implements: login (HTTPS), patch manifest fetch (HTTPS), patch download
  + verify (HTTPS + checksum), file management of the SWG install tree,
  spawning `SwgClient_r.exe` under our managed Wine.
- Pro: the launcher itself never runs under Wine. UI can be much nicer
  than the stock launcher. Gives us a real product story ("Star Wars
  Galaxies, native on Mac"). Procyon is the closest precedent; it
  implements a similar pattern for Steam.
- Con: we own a patcher protocol implementation that depends on what SWG
  Legends ships. If they change the patcher, we ship an update. The
  **game client itself** is still Windows-only DX9, so Wine is still
  required for the real workload.
- Effort estimate: 1-2 weeks for v1 if the patcher protocol is plain
  HTTP+checksum.

### Recommendation

Both, in this order:

1. **Land Path B first** (sections 4a + 4b). This either fixes the stock
   Wine launcher outright, or proves it can't be fixed that way. We'll
   know within a day of Mac Claude getting a patched bottle and trying
   the stock launcher.
2. **If the stock launcher still crashes after Path B**, spec the native
   launcher. Treat it as a separate product ("SWG Legends for Mac") that
   links CrosswireKit as a local Swift package and ships under its own
   identity. Same engine, different app bundle.
3. Either way: keep Crosswire general-purpose. A "game profile" layer
   (`Crosswire/Profiles/<game>.json` describing patcher URL, registry
   tweaks, default DLL overrides, install layout hints) eventually lets
   one codebase serve both "Crosswire, the Whisky-style app" and
   "Crosswire, the SWG launcher" without forking. Stage 3 work, not now.
4. **Defer Path A.** It opens the door to DX11/DX12 games for Crosswire
   later, but it constrains us to macOS 14+ and introduces an Apple
   license acceptance step. Not needed for SWG. Worth revisiting once
   SWG runs and we want to expand the game roster.

## 6. Prior art worth reading

- **Italo Mandara, CXPatcher** (`italomandara/CXPatcher`). 1.6k stars,
  patches stock CrossOver installs with updated DXVK + D3DMetal +
  MoltenVK. Operates at the bottle/install layer, not the engine-build
  layer. Useful for understanding how GPTK integrates with a Wine fork
  in practice. Has env vars worth knowing: `CXPATCHER_SKIP_NTDLLHACKS=1`
  (disable ntdll modifications), `NAS_DISABLE_UE4_HACK=1`,
  `NAS_TONEMAP_C=...` (color profile). Soon to be replaced by Procyon.
- **Italo Mandara, Procyon** (`italomandara/Procyon`). SwiftUI Steam game
  launcher for macOS, also CrossOver-based. Adds per-game launch options,
  rosettax87 for 32-bit performance, and per-game DX/Vulkan backend
  selection. This is the design template for the native SWG Legends
  launcher.
- **Lifeisawful, rosettax87**. Fixes x87 floating-point performance for
  32-bit games under Rosetta. Worth investigating if SWG turns out to be
  CPU-bottlenecked under Crosswire (SWG client is 32-bit DX9, so this
  applies).
- **Gcenx, game-porting-toolkit**. Releases page. Use this as the
  canonical fetch URL for GPTK in Path A or for `libd3dshared.dylib`
  extraction in Path B.

## 7. Specific things Mac Claude should NOT do

- Do not pull anything from `C:\Program Files\Metal Developer Tools` on
  `dev-01`. Wrong toolkit.
- Do not start the native launcher work before step 1 in section 5.
- Do not switch `engine-bundle.yml` to a full Wine-from-source build; do
  the selective rebuild described in section 4b.
- Do not commit `libd3dshared.dylib`, D3DMetal binaries, or any other
  Apple-licensed binary into the repo or into our R2. Resolve at runtime
  from the user's GPTK install or fetch directly from Gcenx releases.

## 8. Concrete next actions for Mac Claude

In rough order. Each is independently testable.

1. Install GPTK on `nick-macbook`. Either via Gcenx release tar.xz or
   `brew install apple/apple/game-porting-toolkit-beta`. Record dylib path
   + symbols in a session note.
2. Read `docs/specs/crossover-applesilicon-research.md` section 4 plus the
   existing `patch-cw*.py` scripts to internalize the patch-script pattern.
3. Write `scripts/patch-cw22434.py`. Apply to a fresh Wine 11.9 checkout;
   confirm the diff matches CrossOver source semantics.
4. Spike the partial-rebuild flow locally: download a Gcenx 11.9 archive,
   apply all four patch scripts to a Wine 11.9 source clone, build only
   the affected dylibs, swap them into the Gcenx tree, ad-hoc sign, run
   `wineboot` smoke test, then try the SWG Legends launcher in a fresh
   bottle.
5. If the launcher works: roll the partial-rebuild flow into
   `engine-bundle.yml`. Ship a beta engine. Update `engine-version.txt`.
6. If the launcher still crashes after Path B: capture crash report +
   Wine debug log (`WINEDEBUG=+seh,+tid,+module,+loader`), and we'll spec
   either Path A (switch to Gcenx GPTK) or the native launcher.

End of brief.
