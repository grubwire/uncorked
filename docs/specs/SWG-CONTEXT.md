# SWG Legends Install — Current State (2026-05-26)

## What's been done

All CW patches from the research doc have been applied to the Wine source tree
at `/tmp/wine-build/wine-src` and rebuilt into the Crosswire engine.

### Patches applied (all verified working, engine already updated)
- CW HACK 24945 / 25719 — virtual.c mprotect toggles (W|X page faults)
- CW HACK 18947 — toggle_executable_pages_for_rosetta in NtWriteVirtualMemory
- CW HACK 22131 — fake STATUS_SUCCESS on debug-reg set under Rosetta
- CW HACK 20186 / 23427 / 24256 — signal_x86_64.c: emulate_xgetbv, is_rosetta2, MXCSR fix
- CW HACK 20760 — wow64cpu: replace ljmp with lretq for WoW64 32->64 transition (TODAY)

### Engine location
`~/Library/Application Support/app.Crosswire.Crosswire/Engine/`

### wow64cpu.dll status
- Patched wow64cpu.dll (119K, with lretq thunk) is LIVE in the engine
- Original backed up as: `.../lib/wine/x86_64-windows/wow64cpu.dll.gcenx.bak`
- Build tree: `/tmp/wine-build/wine-src/dlls/wow64cpu/x86_64-windows/wow64cpu.dll`

### What the headless test showed
- "Exception frame is not in stack limits" error: GONE (CW 20760 fixed it)
- Installer ran to exit code 0 but no SWG files installed
- Reason: headless run had no display — installer GUI never rendered

## What to do now

Run the installer through the Crosswire GUI so it has a real display.

1. Open the Crosswire app (already installed, engine already downloaded)
2. Create a new bottle: name "Star Wars Galaxies", Windows 10, 64-bit
3. Open the bottle, run: ~/Downloads/SWGLegendsSetup.exe
4. Let the installer wizard complete
5. Verify: bottle's drive_c/Program Files/Star Wars Galaxies/ has SWG files

## Key paths
- Installer: ~/Downloads/SWGLegendsSetup.exe
- Engine: ~/Library/Application Support/app.Crosswire.Crosswire/Engine/
- Wine source (patched): /tmp/wine-build/wine-src

## If you need to rebuild anything (e.g. wow64cpu)
Build PE DLLs with:
  PATH=/opt/homebrew/bin:$PATH make -C /tmp/wine-build/wine-src dlls/wow64cpu/x86_64-windows/wow64cpu.dll

## Patch scripts (in this repo, already applied)
- scripts/patch-wine-rosetta.py — CW 24945/25719/18947/23427/24256/20186
- scripts/patch-cw22131.py     — CW 22131
- scripts/patch-cw20760.py     — CW 20760 (lretq thunk, committed today)

## Rollback wow64cpu if needed
cp "~/Library/Application Support/app.Crosswire.Crosswire/Engine/lib/wine/x86_64-windows/wow64cpu.dll.gcenx.bak" \
   "~/Library/Application Support/app.Crosswire.Crosswire/Engine/lib/wine/x86_64-windows/wow64cpu.dll"
