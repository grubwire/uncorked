# CrossOver Wine 11.0 research vs Gcenx wine-staging 11.9

Source examined: `D:\crossover\crossover-sources-26.1.0\sources\wine\` (Wine 11.0
base, CrossOver patches already applied). Upstream Wine 11.0 cross-checked via
the wine-mirror GitHub mirror at tag `wine-11.0`.

## 1. Summary

The named Inno Setup install-phase FIXMEs are all identical between CrossOver
Wine 11.0 and upstream Wine 11.0. Every one of them is either a non-fatal
warning that returns success and continues, or a stub that returns a benign
value. None of them are install crashes by themselves, so backporting changes
to them will not fix the Apple Silicon install crash. The real win in
CrossOver, in source terms, is a small cluster of Apple Silicon / Rosetta
patches in `dlls/ntdll/unix/virtual.c` and `dlls/ntdll/unix/signal_x86_64.c`
that handle Rosetta misbehavior on JIT pages, cross-process code writes, CET
instructions, and XGETBV. These are the only patches in the CrossOver source
tree that plausibly explain the install-phase difference. The much bigger
non-source factor is `send_to_cx_loader` plus CrossOver's macOS app host
("WineLoader.m"), which intercepts every Windows process spawn through a Unix
socket and launches the wineloader from a controlled Rosetta-aware parent.
That is architectural, not a patch, and is not backportable into Gcenx
wine-staging without shipping a CrossOver-style host app.

## 2. Per-fixme findings

For each named install-log FIXME: file path in the CrossOver tree, current
state, and what the code actually does compared to upstream Wine 11.0.

### `imagehlp:BindImageEx Image modification is not implemented`
`dlls/imagehlp/modify.c`, `BindImageEx`. **Still a FIXME, identical to
upstream.** When `flags & BIND_NO_UPDATE` is zero, it logs the FIXME, then
proceeds to map the image and call the user callback `cb` for each imported
module and procedure, then returns TRUE. Inno Setup calls this with
`BIND_NO_UPDATE` set, which silences the FIXME entirely, and the function
returns success either way. No CrossOver patch.

### `msi:ACTION_CustomAction msidbCustomActionTypeTSAware not handled`
`dlls/msi/custom.c` line 1463. **Still a FIXME, identical to upstream.** The
`TSAware` flag (Terminal Services aware) is logged and ignored; the actual
custom action runs anyway. This is a pure log line, not a behaviour change.
Inno Setup rarely sets this flag; even if it does, the custom action still
executes. No CrossOver patch.

### `heap:RtlSetHeapInformation HEAP_INFORMATION_CLASS 1 not implemented`
`dlls/ntdll/heap.c` line 2599. **Still a FIXME, identical to upstream.**
Class 0 is `HeapCompatibilityInformation` (LFH opt-in), and it is fully
implemented. Class 1 is `HeapEnableTerminationOnCorruption`. The FIXME path
returns `STATUS_SUCCESS`, so the caller sees a successful "turn on
termination-on-corruption" request. This is a no-op, not a failure. No
CrossOver patch.

### `ntdll:NtQuerySystemInformation info_class SYSTEM_PERFORMANCE_INFORMATION`
`dlls/ntdll/unix/system.c` line 3226. **Real implementation. Identical to
upstream.** `get_performance_info()` populates a full
`SYSTEM_PERFORMANCE_INFORMATION` struct from sysinfo / mach data. The FIXME
fires exactly once (gated by `fixme_written`), but the call returns
`STATUS_SUCCESS` with valid data. Inno Setup uses this for the "system info"
field; no functional impact. No CrossOver patch.

### `secur32:GetComputerObjectNameW NameFormat 7 not implemented`
`dlls/secur32/secur32.c` line 900. **Still a FIXME, identical to upstream.**
NameFormat 7 is `NameServicePrincipal`. CrossOver implements
`NameSamCompatible`, `NameFullyQualifiedDN`, and `NameDisplay`; the rest log
FIXME and return FALSE with `ERROR_CANT_ACCESS_DOMAIN_INFO`. Inno Setup
fetches this for its own diagnostics; it tolerates failure. No CrossOver
patch.

### `wintrust:SOFTPUB_VerifyImageHash Cannot verify hash for pszObjId`
`dlls/wintrust/softpub.c` line 308. **Still a FIXME, identical to upstream.**
When the indirect data uses an OID other than `SPC_PE_IMAGE_DATA_OBJID` (e.g.
catalog-signed installers), the code logs and returns `ERROR_SUCCESS`, i.e.
treats verification as successful. This is permissive, not strict; not a
crash source. No CrossOver patch.

### `advapi:DecryptFileW ... stub`
`dlls/advapi32/security.c` line 3017. **Still a stub returning TRUE,
identical to upstream.** Inno Setup occasionally calls `DecryptFileW` on its
working dir; the stub-returning-TRUE keeps it happy. No CrossOver patch.

### `clusapi:OpenCluster ... stub`
`dlls/clusapi/clusapi.c` line 68. **Still a stub returning `(HCLUSTER)
0xdeadbeef`, identical to upstream.** Inno Setup queries the cluster API for
fingerprinting and discards the result. Harmless. No CrossOver patch.

## 3. Apple Silicon / Rosetta specific patches

This is where CrossOver actually diverges from upstream. Found via a grep for
`CrossOver`, `CW HACK`, `CW Hack`, and `Rosetta` across the tree.

### `dlls/ntdll/unix/virtual.c` (HIGH VALUE for AS install issues)

**CW Hack 24945**: write fault on a writable+executable page in
`virtual_handle_fault`. Lines 4564-4573.

```c
/* CW Hack 24945 */
if (err == EXCEPTION_WRITE_FAULT &&
    ((get_unix_prot( vprot ) & (PROT_WRITE | PROT_EXEC)) == (PROT_WRITE | PROT_EXEC)))
{
    FIXME( "HACK: write fault on a w|x page, addr %p\n", addr );
    mprotect_range( page, page_size, 0, VPROT_EXEC );
    mprotect_range( page, page_size, VPROT_EXEC, 0 );
    ret = STATUS_SUCCESS;
    goto done;
}
```

Rosetta on Apple Silicon will occasionally raise a write fault on a page
that is already mapped writable+executable (W|X). This is the failure mode
that fires on JIT pages, including Inno Setup's runtime-decompressed code
and any installer custom action that uses a small JIT trampoline. The hack
mprotects the page off and back on to force Rosetta to retranslate, then
swallows the fault. **Not present in upstream Wine 11.0.**

**CW Hack 25719**: exec fault on an executable page. Lines 4575-4583.
Same shape as 24945 but for `EXCEPTION_EXECUTE_FAULT` on a page that is
already `PROT_EXEC`. Same Rosetta-retranslation workaround. **Not present in
upstream.**

**CW HACK 18947**: `toggle_executable_pages_for_rosetta` called from
`NtWriteVirtualMemory`. Lines 6835-6863. When wineserver writes to another
process's memory via `mach_vm_write`, Rosetta does not invalidate its
translation cache. CrossOver detects this is Apple Silicon (via
`sysctl.proc_translated`) and, after every cross-process write, toggles the
target page's executable protection off and on inside the target process to
force re-translation. **Not present in upstream Wine 11.0.** Note that
upstream's `NtWriteVirtualMemory` goes through the wineserver
`write_process_memory` request and does not use `mach_vm_write` at all, so a
straight backport needs to be paired with whatever path CrossOver uses for
the actual cross-process write, or limited to cases where wine-staging
already uses `mach_vm_write`.

The read-fault-as-write-fault hack (`Rosetta on Apple Silicon misreports
certain write faults as read faults`) is **already upstream**. CrossOver
adds only 24945 and 25719 on top of it. Note also the conditional `done:`
label at 4621 that the CrossOver hacks jump to; that label needs to come in
with the patch.

### `dlls/ntdll/unix/signal_x86_64.c` (MEDIUM VALUE)

**CW HACK 20186**: `handle_cet_nop`. Lines 1937-1999, called from
`TRAP_x86_PRIVINFLT` at 2515-2522. On Big Sur, Rosetta raises
`SIGILL` on Intel CET instructions (`RDSSPD`, `RDSSPQ`) instead of treating
them as NOPs. CrossOver decodes the instruction, advances RIP, and returns.
Comment says it is fixed in Monterey, so its blast radius is small. **Not
upstream.**

**CW HACK 23427**: `emulate_xgetbv`. Lines 2001-2034, also called from
`TRAP_x86_PRIVINFLT`. Rosetta does not implement `XGETBV` for xcr0; this
emulates it (returns `0x07` pre-Sequoia, `0xe7` for AVX/AVX-512 on Sequoia
and later). Some installers and almost everything that probes CPU features
will hit this. **Not upstream.**

**CW Hack 24256**: mxcsr correction in `save_context`. Lines 1003-1009.
In Rosetta, `FPU_sig(sigcontext)->MxCsr` is a stale default; CrossOver reads
the real value with `stmxcsr` and patches the context. **Not upstream.**

**CW Hack 24265**: mxcsr correction in `sigsys_handler`. Lines 2832-2851.
On M3, even patching the sigcontext is not enough; CrossOver redirects the
return-to-userspace path to a thunk (`__restore_mxcsr_thunk`) that reloads
mxcsr from per-thread data. **Not upstream.**

**CW HACK 22131**: `NtSetContextThread` failing when setting debug
registers under Rosetta. Lines 1148-1155. CrossOver swallows
`STATUS_UNSUCCESSFUL` and returns success. Low priority for installers but
trivial. **Not upstream.**

### `dlls/winemac.drv/display.c`

**CrossOver Hack #18576**: don't require `kDisplayModeSafeFlag` on Apple
Silicon (line 132). Some AS display modes don't set the flag. Display only,
not install-related.

**CrossOver Hack #20512**: Skyrim SE launcher special-case (line 61). Not
relevant.

### `dlls/ntdll/unix/process.c` (NOT backportable)

**CrossOver Hack 10523**: `send_to_cx_loader` (lines 91-718, called from
`spawn_process` at 862). Every Windows-process spawn checks for
`CX_ALT_LOADER_SOCKET` in the environment and, if set, hands the launch off
over a Unix socket to a CrossOver-side helper instead of forking inside
Wine. The Mac-side helper is in CrossOver's `WineLoader.m` and lives in the
shipping `CrossOver.app` bundle. This is how CrossOver dodges the
Rosetta-spawns-Rosetta problems for child processes (including all the
helper exes that Inno Setup runs during install). It cannot be backported as
a Wine patch; it requires the corresponding macOS host process. This is
likely the single biggest reason install workflows work in CrossOver and not
in a bare Gcenx bottle.

### `dlls/ntdll/loader.c`

**CW HACK 20810** (lines 3816-3830): block stub `wow64cpu.dll` and
`win32u.dll` from CrossOver-20/22 bottles. Bottle-template territory; not
useful for a fresh bottle.

### `loader/main.c`

**CrossOver Hack 13438**: rewrite `CFBundleName` in the embedded Info.plist
so the macOS menu bar shows the right name. Cosmetic.

### `dlls/ntdll/unix/file.c`

**CrossOver hack 14664**: workaround for Quicken Patch under pread/read.
Quicken-specific.

**CrossOver Hack for bug 15207**: hide files starting with `~$`. Office
temp file hiding. Not install-related.

## 4. Backport recommendation

Three patches look high-value and low-effort:

1. **CW Hack 24945** (write fault on W|X page) in
   `dlls/ntdll/unix/virtual.c::virtual_handle_fault`. About 10 lines plus
   adjusting the `done:` label. Catches the JIT-page case directly. This is
   the most likely fix for the install-phase crash.

2. **CW Hack 25719** (exec fault on executable page), same file, same
   function, same shape. Another 10 lines. Pair it with 24945.

3. **CW HACK 23427** (`emulate_xgetbv`) in
   `dlls/ntdll/unix/signal_x86_64.c`. About 35 lines including the
   `is_rosetta2` plumbing. Catches the case where an installer probes CPU
   features and gets a SIGILL on Apple Silicon. Lower priority than 24945
   and 25719 but completely self-contained.

Less worth it but easy if you want to be thorough: **CW HACK 20186**
(`handle_cet_nop`) is small but Monterey-and-later macOS does not need it,
and the user base on Big Sur is essentially zero in 2026.

**CW HACK 18947** (`toggle_executable_pages_for_rosetta`) is high-impact in
CrossOver but it is wired into a `NtWriteVirtualMemory` path that uses
`mach_vm_write`; upstream Wine 11.0 (and presumably wine-staging 11.9)
routes cross-process writes through the wineserver `write_process_memory`
request, which goes through `process_vm_writev` or `ptrace` rather than
Mach. Backporting this needs more work and a careful look at how
wine-staging 11.9 actually performs cross-process writes on macOS. Not in
the first wave.

The CET-NOP hack, mxcsr hacks (24256, 24265), and the debug-register hack
(22131) are real bugs but they fire on edge cases that an Inno Setup
installer almost certainly does not hit.

## 5. Final answer (under 200 words)

The CrossOver source gave us three usable, isolated patches: CW Hack 24945
and 25719 in `virtual_handle_fault` (write/exec fault on
already-writable-or-executable page, mprotect ping-pong to force Rosetta
retranslation), and CW Hack 23427 (`emulate_xgetbv` to satisfy CPU feature
probes under Rosetta). 24945 and 25719 are the strongest leads for the
Inno Setup install crash on Apple Silicon: the failure shape matches a JIT
page or a freshly-decompressed code page that Rosetta has cached stale, and
the install phase is exactly when Inno Setup decompresses and runs code in
new pages.

The much larger win in CrossOver is not a patch at all: it is the
`CX_ALT_LOADER_SOCKET` mechanism in `dlls/ntdll/unix/process.c` plus
CrossOver's macOS host (`WineLoader.m`). Every Windows process spawn during
the install is routed out of Wine into a CrossOver-controlled parent that
launches the wineloader with proper Rosetta context. That cannot be
backported to Gcenx as a Wine patch; it would require shipping our own host
binary, which is essentially what CrossOver's bottle-templating layer is.
Worth budgeting one day for 24945 + 25719 + 23427 and re-testing the
installer before deciding whether to invest more.
