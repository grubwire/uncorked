# Rename: Whisky → Uncorked

**Date:** 2026-05-21  
**Status:** Approved  

## Goal

Remove all remaining "Whisky" references from the Uncorked codebase. Uncorked is a maintained fork of Whisky and has already been renamed at the product level (bundle ID, app name, icon). This spec covers the remaining internal references visible in the GitHub repo and in code.

## Approach

Two-phase, each phase ending with a CI build verify before proceeding. Phase 1 has no build impact. Phase 2 is broken into sub-steps to keep `project.pbxproj` edits incremental and bisectable.

---

## Phase 1 — User-visible references

**Commit strategy:** single commit, push to `main`, confirm `build.yml` CI passes.

### 1.1 GPL license headers (~40 Swift files)

All Swift source files in `Whisky/`, `WhiskyKit/`, `WhiskyCmd/`, `WhiskyThumbnail/` contain:

```
//  This file is part of Whisky.
//  Whisky is free software: ...
//  Whisky is distributed in the hope that ...
//  ... along with Whisky.
```

Replace all four occurrences per file with "Uncorked".

### 1.2 `Whisky/Localizable.xcstrings` — English strings

Ten English-locale string values to update (exact keys):

| Key | Old value | New value |
|---|---|---|
| `install.cli` | "Install Whisky CLI..." | "Install Uncorked CLI..." |
| `settings.toggle.kill.on.terminate` | "Terminate Wine processes when Whisky closes" | "Terminate Wine processes when Uncorked closes" |
| `settings.toggle.whisky.updates` | "Automatically check for Whisky updates" | "Automatically check for Uncorked updates" |
| `settings.toggle.whiskywine.updates` | "Automatically check for WhiskyWine updates" | "Automatically check for UncorkedWine updates" |
| `setup.subtitle` | "Manage Whisky's required dependencies." | "Manage Uncorked's required dependencies." |
| `setup.welcome` | "Welcome to Whisky" | "Welcome to Uncorked" |
| `setup.whiskywine.download` | "Downloading WhiskyWine" | "Downloading UncorkedWine" |
| `setup.whiskywine.install` | "Installing WhiskyWine" | "Installing UncorkedWine" |
| `update.whiskywine.description` | "...WhiskyWine %@, but %@ is available..." | "...UncorkedWine %@, but %@ is available..." |
| `update.whiskywine.title` | "New Version of WhiskyWine Available" | "New Version of UncorkedWine Available" |

Non-English translations are left as-is and will drift until Crowdin syncs.

### 1.3 `.swiftlint.yml`

Update the GPL header template to match the updated header text.

### 1.4 `README.md`

- Keep: attribution line ("fork of [Whisky](https://github.com/Whisky-App/Whisky)") — factually accurate, good for discoverability
- Update: any phrasing that treats Uncorked and Whisky as the same project

### 1.5 `CONTRIBUTING.md` / `CODE_OF_CONDUCT.md`

Update Whisky references to Uncorked. Keep any links to upstream Whisky that are informational.

### 1.6 `.github/ISSUE_TEMPLATE/bug.yml`

- Field label: "What version of Whisky are you using?" → "What version of Uncorked are you using?"
- Field `id`: `whisky-version` → `uncorked-version`
- Any help text mentioning Whisky

### 1.7 `.github/workflows/wine-update-check.yml`

Update the checklist item in the auto-created issue body that references `WhiskyWineInstaller`.

---

## Phase 2 — Internal code identifiers

Each sub-step is its own commit + push. CI must pass before the next sub-step begins.

### Sub-step 2A — Swift type renames (in-file only)

No file moves, no project file changes. Pure symbol renames:

| Old | New | Location |
|---|---|---|
| `WhiskyApp` | `UncorkedApp` | `Whisky/Views/WhiskyApp.swift` |
| `WhiskyCmd` (class) | `UncorkedCmd` | `Whisky/Utils/WhiskyCmd.swift` |
| `struct Whisky` (CLI) | `struct Uncorked` | `WhiskyCmd/Main.swift` |
| `WhiskyWineInstaller` | `UncorkedWineInstaller` | `WhiskyKit/.../WhiskyWineInstaller.swift` |
| `WhiskyWineVersion` | `UncorkedWineVersion` | same file |
| `WhiskyWineDownloadView` | `UncorkedWineDownloadView` | `Whisky/Views/Setup/WhiskyWineDownloadView.swift` |
| `WhiskyWineInstallView` | `UncorkedWineInstallView` | `Whisky/Views/Setup/WhiskyWineInstallView.swift` |
| `whiskyBundleIdentifier` | `uncorkedBundleIdentifier` | `WhiskyKit/.../Bundle+Extensions.swift` + all call sites |

Also update `AppDelegate.swift` and any other call sites that reference these by their old names.

**Verify:** Push → CI `build.yml` green.

### Sub-step 2B — Source file renames + `project.pbxproj`

Rename files using `git mv`, then update every matching file reference in `Whisky.xcodeproj/project.pbxproj`:

| Old filename | New filename |
|---|---|
| `WhiskyApp.swift` | `UncorkedApp.swift` |
| `WhiskyCmd.swift` | `UncorkedCmd.swift` |
| `WhiskyWineDownloadView.swift` | `UncorkedWineDownloadView.swift` |
| `WhiskyWineInstallView.swift` | `UncorkedWineInstallView.swift` |
| `WhiskyWineInstaller.swift` | `UncorkedWineInstaller.swift` |
| `Whisky.entitlements` | **Delete** — `Uncorked.entitlements` already exists and is the one referenced by `CODE_SIGN_ENTITLEMENTS`. `Whisky.entitlements` is a dead file. Remove the stale `PBXFileReference` entry from `project.pbxproj` too. |
| `WhiskyThumbnail.entitlements` | `UncorkedThumbnail.entitlements` |
| `Whisky.xcscheme` | `Uncorked.xcscheme` (or remove if redundant with existing) |
| `WhiskyCmd.xcscheme` | `UncorkedCmd.xcscheme` |
| `WhiskyThumbnail.xcscheme` | `UncorkedThumbnail.xcscheme` |

Also update Xcode target names in `project.pbxproj`:
- Build phase "Embed WhiskyCmd" → "Embed UncorkedCmd"
- Bundle identifier `app.uncorked.UncorkCmd` → `app.uncorked.UncorkedCmd`
- Bundle identifier `app.uncorked.Uncorked.WhiskyThumbnail` → `app.uncorked.Uncorked.UncorkedThumbnail`

**Verify:** Push → CI green.

### Sub-step 2C — Package rename: `WhiskyKit` → `UncorkedKit`

1. `git mv WhiskyKit/ UncorkedKit/` (renames top-level directory)
2. Rename internal source paths: `Sources/WhiskyKit/` → `Sources/UncorkedKit/`, `WhiskyWine/` → `UncorkedWine/`
3. Update `UncorkedKit/Package.swift`: package name `"WhiskyKit"` → `"UncorkedKit"`, target names
4. Update all `import WhiskyKit` → `import UncorkedKit` across the codebase
5. Update `Whisky.xcodeproj/project.pbxproj`: package product dependency reference

**Verify:** Push → CI green.

### Sub-step 2D — Top-level directory renames

1. `git mv Whisky/ Uncorked/`
2. `git mv WhiskyCmd/ UncorkedCmd/`
3. `git mv WhiskyThumbnail/ UncorkedThumbnail/`
4. Update all path references in `project.pbxproj` (group paths, file references)
5. Update `crowdin.yml` source/translation path if it references `Whisky/`

**Verify:** Push → CI green.

---

## What is NOT renamed

- `whisky-upstream` git remote — points to the original Whisky repo, the name is intentional
- Attribution links in README to the original Whisky project
- Non-English translations in `Localizable.xcstrings` — left for Crowdin to sync

## Success criteria

- Zero occurrences of "Whisky" or "whisky" in Swift source files, workflows, docs, and config (excluding the upstream attribution line in README and the `whisky-upstream` remote)
- `build.yml` CI passes after each sub-step
- App installs and launches correctly (verified by the existing release workflow producing a valid DMG)
