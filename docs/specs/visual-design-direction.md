# Crosswire Visual Design Direction

## Reference

Battle.net launcher (macOS) is the reference for structural and atmospheric 
patterns. Not a literal clone — the energy, not the details.

## Principles

1. The app's identity lives in chrome (icon + tabs + header), not in 
   wordmark headlines.
2. Every UI region is a contained surface with its own elevation, padding, 
   and chrome.
3. Depth via subtle elevation, not heavy decoration.
4. Background work surfaces through notifications, not blocking dialogs.

## Header / chrome

- Top-left: Crosswire icon ~28pt. No "Crosswire" wordmark text. Chevron 
  next to icon opens dropdown (Settings, About, Check for Updates, Quit).
- Top tabs: "Library" is the only real tab. Header is designed to support 
  future tabs but only Library is implemented.
- Top-right (in order): sparkle icon (What's New, future), bell icon 
  (Notifications, future), gear icon (Settings, wired).
- Window title bar is empty (no app name text). Just macOS chrome.

## Library page

- Library is a contained surface: background #1f232b (one step lighter 
  than page #1a1d24), rounded 12px corners, subtle 1px border at #262b34 
  OR inset 0 1px 0 #262b34 inner highlight (pick consistently).
- Section header "Library" inside the container top-left, 11pt SemiBold 
  uppercase tracking, 60% opacity.
- "+" install button top-right inside the container (Battle.net favorites-
  bar pattern). When library is empty, the empty-state CTA is the primary 
  "Install a Game or App" button.
- Each row is its own surface at #262b34, rounded 8px.
- Row hover: surface lifts to #2a2f38, 1.01x scale, 150ms ease.
- Row selected: blue-tinted background at ~10% opacity.

## Library row structure

- Left: monogram tile (4-color cycle) OR extracted icon, ~48pt rounded 
  square.
- Center: entry name 16pt SemiBold + metadata line 12pt regular 60% opacity 
  ("Last played 2h ago" / "Never launched").
- Right: discrete "Launch" button — blue background, white ▶ icon + 
  "Launch" text, rounded 6px, padding, hover state.
- No gear icon on the row.

## Row interactions

- Single-click row → navigates to inline per-app detail view.
- Click Launch button → runs program (subject to single-instance check).
- Right-click / two-finger click row → contextMenu:
  - Launch
  - Show Details
  - Rename
  - Change Icon...
  - Check Dependencies
  - Show in Finder
  - --- (separator)
  - Uninstall... (red, destructive)

## Inline Settings

- Opens within main window (no new window chrome, no separate traffic 
  lights). Slide-in from right, 200ms ease.
- Layout: left sidebar nav (General / Updates / Privacy / About / Advanced), 
  right content pane. Sidebar selected item has blue left-edge bar + 
  lighter background.
- Footer: version chip bottom-left (muted text), Done button bottom-right 
  (blue primary).
- Updates section: TWO toggles — "Automatically check for Crosswire app 
  updates" and "Automatically check for Engine updates". Each binds to its 
  own UserDefaults key (do not collapse to one).
- General section: "App Data Location" with Show in Finder button (not 
  raw container path).
- About section: small Crosswire icon, app version, engine version, links 
  to GitHub / Crosswire website / "Report an Issue".

## Inline per-app detail view

- Opens within main window, slide-in from right (same pattern as Settings).
- Replaces the existing detached per-app settings window entirely.
- Back chevron + "Library" top-left.
- Content: large app icon + name (editable inline), category line, big 
  blue Launch button, secondary actions (Uninstall in red, Check 
  Dependencies, Show in Finder), Advanced disclosure (prefix path, 
  Windows version, DLL overrides, engine version).

## Colors

All in centralized `CrosswireTheme.swift` AND `Assets.xcassets/AccentColor`. 
No hardcoded hex in views.

- Page background: gradient #1a1d24 (top) → #13161c (bottom)
- Region surface: #1f232b
- Row surface: #262b34
- Row hover: #2a2f38
- Row selected: accent blue at ~10% opacity
- Primary accent: Crosswire blue, sampled from app icon, used everywhere
- Project AccentColor in Assets.xcassets: SAME Crosswire blue (NOT orange)
- Tile fallback colors: 4 colors from icon (yellow, green, red, blue)
- Text primary: #FFFFFF
- Text secondary: #FFFFFF at 60% opacity
- Text muted: #FFFFFF at 40% opacity

## Typography

- Tab labels: 14pt SemiBold
- Section headers: 11pt SemiBold uppercase tracking, 60% opacity
- Row name: 16pt SemiBold
- Row metadata: 12pt Regular, 60% opacity
- Button labels: 14pt Medium
- Body: 14pt Regular

## Atmospheric details

- Hover transitions: 150ms ease
- Slide-in transitions: 200ms ease from right
- Monogram tile shadow: 1px y-offset, 4px blur, 8% black
- Surface separation via 1px borders or 1px inner highlight (pick one, 
  use everywhere)
- No gratuitous animation

## Single-instance enforcement

- When user clicks Launch on a program that's already running, bring the 
  existing window to front instead of spawning a new process.
- Track by bottle UUID + primary exe path.
- Add Advanced toggle "Allow multiple instances" defaulting off.

## Future panels (designed for, NOT in current build pass)

### Notifications panel
Bell icon top-right opens anchored dropdown. Event types:
- Install started / progress / complete / failed
- Engine update available / installed
- App crashed (with View Details / Report actions)
- Dependencies installed
- App ready to launch

Empty state: "You're all caught up!" with sleeping bell icon.
Notifications persist across restarts until dismissed (UserDefaults).

### What's New panel
Sparkle icon top-right opens anchored dropdown. Crosswire-curated content:
- Crosswire release notes
- Engine update changelog
- Tips for known-good Windows apps

### Background installs
Click Install → sheet for picker → dismisses immediately after start →
install runs in background → notification shows progress → notification 
on completion ("[App] is ready to launch") or failure.

Replaces current foreground-blocking install pattern. Architectural change 
touching ContentView+Install.swift, Wine.swift, new Notifications.swift, 
new NotificationsView.swift.

## Out of scope for the current build pass

- Notifications panel implementation (just the bell icon placeholder)
- What's New panel implementation (just the sparkle icon placeholder)
- Background install rework
- Light mode (separate session)
- Icon extraction debug (diagnose-only this session)
- Sentry crash reporting integration
- The post-login SWG crash #84
