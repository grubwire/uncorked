# CrossOver Apple Silicon Research

Source surveyed: `D:\crossover\wine\` (CrossOver 26.1.0 Wine source, derived from upstream Wine 11.0).
Upstream compared via raw.githubusercontent.com/wine-mirror/wine, tag `wine-11.0`.

## 1. Summary

Yes, CrossOver carries concrete, named patches that explain why their Wine survives on Apple Silicon where stock / Gcenx Wine does not. The most important ones are: (a) CW HACK 22434, which calls into Apple's private `libd3dshared.dylib` (part of the Game Porting Toolkit) to register every loaded PE module as a "non-native code region" so Rosetta correctly handles JITted x86 code; (b) signal-handler instruction emulation in `signal_x86_64.c` (CW HACKs 20186, 23427, 24256, 24265) that catches and emulates `xgetbv`, certain CET no-ops, and Rosetta's broken `MXCSR` propagation; (c) CW HACKs 24945 / 25719 in `virtual.c` that recover from Rosetta lying about write and execute faults on W|X pages by toggling the executable bit; (d) CW HACK 18947 in `NtWriteVirtualMemory` which forces Rosetta to flush its translation cache; and (e) CW HACK 20760 in `wow64cpu` which replaces the `ljmp` 32-to-64 thunk with `lretq` to avoid a Rosetta 2 SIGUSR1 race. These are real source-level workarounds, not just config. Some are backportable to a Gcenx wine-staging 11.9 tree (a). Some are completely tied to closed Apple infrastructure (the libd3dshared integration only works if Apple's GPTK is installed and `CX_APPLEGPTK_LIBD3DSHARED_PATH` points at it).

## 2. Signal-handler / instruction-emulation findings

All file paths relative to `D:\crossover\wine\`.

### `dlls/ntdll/unix/signal_x86_64.c`

- Lines 83-90: `is_rosetta2` and `sequoia_or_later` static flags. Cached at signal-handler init because `sysctlbyname` and `__builtin_available` are not async-signal-safe. (CW Hack 24256, 23427).
- Lines 1003-1009 (CW Hack 24256): inside `save_context`, when `is_rosetta2` is true, the handler re-reads `MXCSR` from the live register via inline `stmxcsr` because the signal context's MXCSR value is wrong under Rosetta. Quote: "mxcsr in signal contexts is incorrect in Rosetta. In Rosetta only, the actual value of the register from within the handler is correct".
- Lines 1148-1155 and 1377-1384 (CW HACK 22131): in `NtSetContextThread` and the wow64 variant, when the kernel returns `STATUS_UNSUCCESSFUL` for debug-register sets on Apple, fake `STATUS_SUCCESS`. Rosetta does not let you set DR0-DR7 cross-process.
- Lines 1937-1999 (CW HACK 20186) `handle_cet_nop`: walks instruction prefixes at the fault address and if the instruction is `0F 1E /xx` (RDSSPD / RDSSPQ, a CET no-op on non-CET CPUs), advances RIP past it. Rosetta on Big Sur was throwing `SIGILL` for these; native Intel hardware treats them as NOP.
- Lines 2001-2034 (CW HACK 23427) `emulate_xgetbv`: pattern-matches `0F 01 D0` with `ECX==0` at the fault address and emulates `XGETBV` for `XCR0` directly in the signal handler, returning `0x07` (FPU/MMX/SSE) on pre-Sequoia or `0xE7` (adds AVX, AVX-512) on macOS 15+. Rosetta refuses to translate `XGETBV` so this instruction triggers SIGILL; CrossOver synthesizes the answer.
- Lines 2515-2521: the SIGILL/PRIVINFLT case in `segv_handler` now calls `handle_cet_nop` and `emulate_xgetbv` before falling through to "EXCEPTION_ILLEGAL_INSTRUCTION".
- Lines 2794-2853 (CW Hack 24265): `__restore_mxcsr_thunk` and the `sigsys_handler` for SIGSYS (macOS 14+ Sonoma). When Rosetta-on-M3 keeps restoring an incorrect MXCSR from the signal context, the handler patches RIP to a thunk that reloads MXCSR from `amd64_thread_data()`. The SIGSYS handler itself is also gated to macOS 14 only and is required for the WOW64 syscall dispatcher under newer macOS, not strictly Apple Silicon, but is part of the same set.
- Lines 3002-3017: the init path captures `sysctl.proc_translated` and `macOS 15.0` availability into the cached statics before installing the SIGILL / SIGBUS / SIGSEGV / SIGSYS handlers.

Upstream wine-11.0 `signal_x86_64.c` does NOT contain `is_rosetta2`, `handle_cet_nop`, `emulate_xgetbv`, `__restore_mxcsr_thunk`, `sigsys_handler`, or `sequoia_or_later`. Confirmed via GitHub mirror fetch. Upstream only has the one passing reference saying "Setting debug registers is not supported under Rosetta" inside `NtSetContextThread`.

### `dlls/wow64cpu/cpu.c` (CW HACK 20760)

- Lines 43-72: a parallel `thunk_32to64_rosetta2_workaround` struct that builds an `lcall` + `lretq` based 32-to-64 transition instead of the upstream `ljmp`.
- Lines 86-94: `use_rosetta2_workaround` flag + `is_rosetta2()` detecting via `SystemProcessorBrandString`.
- Lines 250-340: inline assembly for `syscall_32to64` and `unix_call_32to64` checks `use_rosetta2_workaround` and branches to an alternate code path doing `lretq` instead of `ljmp *(%r14)`. Comment: "When running under Rosetta 2, use lretq instead of ljmp to work around a SIGUSR1 race condition."
- Lines 405-455: when initializing the thunk pages, the Rosetta variant is written instead.

Upstream wine-11.0 `wow64cpu/cpu.c` has none of this. WoW64 32-bit Windows installer support under Rosetta on Apple Silicon is therefore non-functional on stock Wine if the SIGUSR1 race triggers.

### `server/mach.c` and `dlls/wow64/virtual.c` (smaller items)

- `server/mach.c` lines 77-94: `is_rosetta()`. Lines 192-196 and 278-294: faking debug-register get/set as no-ops cross-process under Rosetta. Lines 446-516: ignoring `KERN_PROTECTION_FAILURE` for `mach_vm_write` when Rosetta has stripped W from an RWX page. None of these have upstream equivalents.
- `dlls/wow64/virtual.c` lines 781-790 (CW Hack 26470 / 26456): skip setting a 16-bit LDT under Rosetta because it hangs the translator.

## 3. Memory-layout findings

### `dlls/ntdll/unix/virtual.c`

- Lines 4556-4584 (in `virtual_handle_fault`, the Apple block):
  - 4557-4562: "Rosetta on Apple Silicon misreports certain write faults as read faults". If we get `EXCEPTION_READ_FAULT` on a readable page, retag it as `EXCEPTION_WRITE_FAULT` so we don't bail to the app as a phantom AV.
  - 4564-4573 (CW Hack 24945): on a write fault to a `W|X` page, mprotect-toggle the X bit off and back on. This is "exec fault but page is already writable" recovery, plausibly tied to how Rosetta caches translations or W^X enforcement on AS.
  - 4575-4583 (CW Hack 25719): on an execute fault to an `X` page, do the same mprotect toggle. Comment: "exec fault on executable page".
- Lines 6815-6863 (CW HACK 18947): `is_apple_silicon` (which actually checks `sysctl.proc_translated`, so same predicate as is_rosetta2) plus `toggle_executable_pages_for_rosetta`. After every `NtWriteVirtualMemory` cross-process write, mprotect-toggle the executable bit on the destination range to invalidate Rosetta's translation cache. Without this, code injected via `WriteProcessMemory` (e.g. anti-cheat thunks, DLL injectors, debugger trampolines) keeps executing stale translations.

Upstream wine-11.0 `virtual.c`: none of these are present. The `virtual_handle_fault` function has no `__APPLE__` block at all, no `EXCEPTION_READ_FAULT` -> `WRITE_FAULT` reclassification, no W|X toggle hacks. `toggle_executable_pages_for_rosetta` does not exist.

### Preloader / address-space layout

Upstream wine-11.0 `loader/preloader_mac.c` is byte-equivalent at the address-space level: same `.zerofill WINE_RESERVE` 0x1fffff000 ( ~8 GiB) at `0x1000`, same `0x7ff000000000` 32 MiB top-down reserve. CrossOver did NOT change the Apple address-space layout. The "try_map_free_area: errno=ENOMEM" failures you see in user logs are not solved by a different preloader layout in CrossOver; they are solved by the fault-handler hacks above (W|X toggle, read->write reclassification) that prevent those mmaps from happening in the first place when Rosetta returns inconsistent protections.

`loader/main.c` and the non-preloader path (lines 52-84) match upstream by intent.

## 4. Mach-O / winemac.drv findings

### Apple Game Porting Toolkit hook (the big one): CW HACK 22434

`dlls/ntdll/unix/loader.c` lines 1298-1369 and `dlls/ntdll/loader.c` lines 2357-2364:

- The PE loader, after mapping any non-builtin PE module, calls `unix_pe_module_loaded` with the module's address range.
- That unix-side function does a one-time `dlopen` of the path in env var `CX_APPLEGPTK_LIBD3DSHARED_PATH`, which is Apple's private `libd3dshared.dylib` shipped with the Game Porting Toolkit.
- It resolves `register_non_native_code_region` and `supports_non_native_code_regions` from that dylib.
- If supported (Sonoma or later), every loaded PE module is registered with Apple's `libd3dshared` as a "non-native code region". This appears to be Apple's mechanism for telling Rosetta which memory regions contain JIT'd / dynamically loaded x86 code that must be treated as PE-loaded code rather than pages reachable by some other path.

Without this, Rosetta on Sonoma+ can mistreat dynamically-loaded PE code (notably DRM stubs, packer thunks, and JIT-emitted code in installers using SmartAssembly / VMProtect / Themida-like protection). This is, by a wide margin, the single most likely root cause of why a Microsoft installer survives under CrossOver but trips `unsupported privilege level: 0` under Gcenx Wine.

This call goes through a per-process syscall slot (`unix_pe_module_loaded`) added to `dlls/ntdll/unix/unix_private.h`. Upstream has neither the syscall slot nor the dispatch.

### `dlls/winemac.drv/d3dmetal*.{c,m}`

These are 100% CrossOver-specific files. They implement a parallel `macdrv_functions_t` ABI that D3DMetal calls into. Not relevant to the Rosetta SIGILL problem we're researching; they're the Metal graphics bridge. Listing here for completeness because they prove CrossOver licenses or otherwise integrates with Apple's GPTK at a level Gcenx cannot easily reproduce.

### Other Mach-O specifics worth noting

- `loader/main.c` 41-48, 179-269 (CW Hack 13438): rewrites the bundle name in the Info.plist embedded in the Mach-O loader executable so the app menu title isn't always "wine". Pure cosmetics, not AS-related, but illustrates how deeply CrossOver patches the loader.
- `dlls/ntdll/unix/loader.c` 2240-2244: hooks `localtime` on Apple x86_64 because CrossOver pokes PEB at pthread TLS offset 0x60 (where localtime would otherwise stash data). Stack TLS layout hack, not directly AS-related but illustrative of the depth of Apple-only patches.

## 5. Backport feasibility (target: Gcenx wine-staging 11.9)

Effort rating: trivial (drop-in patch, isolated), moderate (some integration work), hard (touches central paths or needs a syscall slot), not-worth (proprietary dep / app-specific).

| # | CW Hack | Patch | Files | Effort | Notes |
|---|---|---|---|---|---|
| 1 | 24256 | MXCSR re-read in `save_context` under Rosetta | `signal_x86_64.c` | trivial | ~10 lines, gated by `is_rosetta2`. Self-contained. |
| 2 | 22131 | Fake-success debug-register set under Rosetta | `signal_x86_64.c` (x2) + `server/mach.c` | trivial | A few `if (ret == STATUS_UNSUCCESSFUL) ret = STATUS_SUCCESS;` blocks. |
| 3 | 20186 | `handle_cet_nop` for RDSSPD/RDSSPQ | `signal_x86_64.c` | trivial | One static function + one call site. Fixes Big Sur only (Monterey+ fixed in Rosetta upstream, but still good defensive code). |
| 4 | 23427 | `emulate_xgetbv` for XGETBV in SIGILL | `signal_x86_64.c` | trivial | This is the single highest-value, easiest-to-port patch. Likely fixes a major chunk of "rosetta error: unsupported instruction" cases on installers that probe `XCR0`. |
| 5 | 24265 | `__restore_mxcsr_thunk` and SIGSYS handler M3 fix | `signal_x86_64.c` | moderate | Depends on `__wine_syscall_dispatcher` layout. wine-staging 11.9 has the same dispatcher so probably clean. |
| 6 | 20760 | wow64cpu lcall/lretq Rosetta thunk | `wow64cpu/cpu.c` | moderate | Replaces the WoW64 32-to-64 transition for any 32-bit installer running through Rosetta. Self-contained but the assembly is gnarly; needs review. |
| 7 | n/a | RD-fault->WR-fault reclassification, virtual_handle_fault | `virtual.c` | trivial | ~5 lines inside the function. High value: this is exactly the kind of "phantom AV" failure we'd see. |
| 8 | 24945 | mprotect toggle on W|X write fault | `virtual.c` | trivial | ~10 lines. |
| 9 | 25719 | mprotect toggle on X exec fault | `virtual.c` | trivial | ~10 lines. |
| 10 | 18947 | `toggle_executable_pages_for_rosetta` after `NtWriteVirtualMemory` | `virtual.c` | trivial | ~25 lines + one call. Critical for any installer that uses WriteProcessMemory (most game installers do). |
| 11 | 26470 / 26456 | Skip 16-bit LDT under Rosetta | `dlls/wow64/virtual.c` | trivial | ~10 lines. |
| 12 | mach.c rosetta blocks | Faking debug regs + ignoring W-strip in mach_vm_write | `server/mach.c` | moderate | Wineserver patches; isolated functions. |
| 13 | 22434 | libd3dshared "register non-native code region" hook on every PE load | `dlls/ntdll/unix/loader.c`, `dlls/ntdll/loader.c`, `unix_private.h` (new syscall slot) | hard | Mechanically the patch is small (~70 lines), but it depends on Apple's `libd3dshared.dylib` (Apple Game Porting Toolkit). Requires the user to have GPTK installed and `CX_APPLEGPTK_LIBD3DSHARED_PATH` to point at it. Patch itself is portable; *functionality* is gated by Apple-shipped binary. |
| 14 | 22996 | `simulate_writecopy` env var hack | `loader.c` | trivial | One global + getenv. |
| 15 | d3dmetal.c / d3dmetal_objc.m files | D3DMetal bridge | `dlls/winemac.drv/d3dmetal*` | not-worth for this purpose | Solves graphics, not Rosetta. Tangential. |

The combination of items 1, 3, 4, 6, 7, 8, 9, 10, 11 (the "trivial" rows plus 6) covers nearly all the privileged-instruction / phantom-fault failure modes we'd hit on Apple Silicon, and is mechanically backportable to Gcenx wine-staging 11.9. None of those require Apple's GPTK. Item 13 is the only one that requires a closed Apple binary, and it primarily matters for code-injection-heavy installers; many Microsoft installers do not need it.

## 6. Final answer (under 200 words)

Most of the Apple Silicon win in CrossOver's Wine is in their source and is backportable to Gcenx wine-staging 11.9. The bulk of it is concentrated in five files: `dlls/ntdll/unix/signal_x86_64.c`, `dlls/ntdll/unix/virtual.c`, `dlls/wow64cpu/cpu.c`, `dlls/wow64/virtual.c`, and `server/mach.c`. The patches there emulate `xgetbv`, swallow CET no-ops, reload MXCSR after Rosetta stomps it, reclassify mis-reported faults, mprotect-toggle W|X pages to break Rosetta's translation cache, fake debug-register sets that Rosetta refuses, swap a WoW64 `ljmp` for `lretq` to avoid a SIGUSR1 race, and skip a 16-bit LDT path that hangs Rosetta. All of these are trivial to moderate to port and explain the headline `unsupported privilege level: 0` and `try_map_free_area` failure modes directly.

The one piece that is tied to CrossOver-specific infrastructure is CW HACK 22434, which `dlopen`s Apple's `libd3dshared.dylib` from the Game Porting Toolkit and registers every PE module as a non-native code region with Rosetta. The patch is portable; the dependency is Apple's closed binary.
