//
//  ContentView.swift
//  Crosswire
//
//  This file is part of Crosswire.
//
//  Crosswire is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Crosswire is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Crosswire.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import AppKit
import CrosswireKit
import SemanticVersion
import Sparkle

// swiftlint:disable type_body_length file_length
struct ContentView: View {
    @AppStorage("checkEngineUpdates") var checkEngineUpdates = true
    @EnvironmentObject var bottleVM: BottleVM
    @Binding var showSetup: Bool
    let sparkleUpdater: SPUUpdater?

    @State var bottlesLoaded: Bool = false
    @State var searchText: String = ""
    @State var openedFileURL: URL?
    @State var setupStartingStage: SetupStage?

    /// Top-level navigation. Library is the default; Settings + per-entry
    /// detail are full-bleed inline destinations that slide in over the
    /// library view. See `AppRoute` for the full rationale.
    @State var route: AppRoute = .library

    /// Retained for compatibility with the install flow's existing alerts;
    /// the per-entry settings sheet is no longer driven by this (now it's
    /// navigation via `route = .entryDetail(bottle.id)`).
    @State var settingsBottle: Bottle?
    @State var provisioningMessage: String?
    @State var runtimesPrompt: RuntimesPrompt?

    @FocusState private var searchFocused: Bool

    init(showSetup: Binding<Bool>, sparkleUpdater: SPUUpdater? = nil) {
        self._showSetup = showSetup
        self.sparkleUpdater = sparkleUpdater
    }

    var body: some View {
        ZStack {
            // Library is the always-present base layer. Settings + per-entry
            // detail overlay it with slide-in transitions. Library doesn't
            // animate out — the overlay just covers it.
            libraryRoot

            if route == .settings {
                InlineSettingsView(updater: sparkleUpdater) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .library
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CrosswireTheme.backgroundGradient.ignoresSafeArea())
        .sheet(item: $settingsBottle) { bottle in
            // Per-entry settings still uses .sheet for this commit. Section 2
            // of the brief converts it to inline routing via .entryDetail.
            AppSettingsSheet(bottle: bottle, onDelete: {
                settingsBottle = nil
            })
        }
        .sheet(item: $openedFileURL) { url in
            FileOpenView(fileURL: url,
                         currentBottle: nil,
                         bottles: bottleVM.bottles)
        }
        .sheet(item: $runtimesPrompt) { prompt in
            DetectedRuntimesSheet(
                exeName: prompt.exeName,
                detected: prompt.detected,
                bottle: prompt.bottle
            ) { installed in
                prompt.continuation.resume(returning: installed)
                runtimesPrompt = nil
            }
        }
        .sheet(isPresented: $showSetup, onDismiss: { setupStartingStage = nil }, content: {
            SetupView(startingStage: setupStartingStage, showSetup: $showSetup, firstTime: false)
        })
        .overlay {
            if let message = provisioningMessage {
                ProvisioningOverlay(message: message)
            }
        }
        .handlesExternalEvents(preferring: [], allowing: ["*"])
        .onOpenURL { url in
            openedFileURL = url
        }
        .task {
            await onAppearTask()
        }
    }

    // MARK: - Library root (composes header + action row + content)

    /// The library view as a single composed surface. Sits at the base of
    /// the ZStack; the Settings (and per-entry, Section 2) overlays slide
    /// in over it. Extracted as its own var so the body-level ZStack stays
    /// readable.
    private var libraryRoot: some View {
        VStack(spacing: 0) {
            header
            actionRow
            content
        }
    }

    // MARK: - Header

    /// "Crosswire" wordmark, gear-icon settings entry on the right. Gear now
    /// routes to the inline `.settings` destination (was SettingsLink → a
    /// separate macOS window); Cmd+, kept via `.keyboardShortcut` so the
    /// standard Mac affordance still works.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Crosswire")
                .font(CrosswireTheme.Typography.display)
                .foregroundStyle(CrosswireTheme.textPrimary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    route = .settings
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(CrosswireTheme.textSecondary)
                    .contentShape(Rectangle())
                    .padding(4)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    // MARK: - Action row (CTA + search)

    /// Primary CTA "Install a Game or App" + library search. The CTA is the
    /// most important affordance in the app (it's how anything gets into
    /// the library at all); it gets the accent blue, the + glyph, and the
    /// bigger height so it reads as obvious-and-primary.
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: installWindowsApp) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Install a Game or App")
                        .font(CrosswireTheme.Typography.buttonPrimary)
                }
                .foregroundStyle(CrosswireTheme.textOnAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CrosswireTheme.accent)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Install a Windows game or app")

            librarySearchField
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }

    /// Search field with the theme's surface fill and a blue focus ring that
    /// honors the Crosswire accent instead of the user's system accent
    /// (which could be orange and clash with the icon).
    private var librarySearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CrosswireTheme.textTertiary)
            TextField("Search your library…", text: $searchText)
                .textFieldStyle(.plain)
                .font(CrosswireTheme.Typography.body)
                .foregroundStyle(CrosswireTheme.textPrimary)
                .focused($searchFocused)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CrosswireTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    searchFocused ? CrosswireTheme.accent : CrosswireTheme.surfaceStroke,
                    lineWidth: searchFocused ? 1.5 : 1
                )
        )
        .frame(maxWidth: .infinity)
        .animation(CrosswireTheme.Motion.hover, value: searchFocused)
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if !bottlesLoaded {
            loadingState
        } else if bottleVM.bottles.isEmpty {
            emptyState
        } else if filteredBottles.isEmpty {
            noMatchState
        } else {
            library
        }
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noMatchState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(CrosswireTheme.textTertiary)
            Text("Nothing in your library matches “\(searchText)”")
                .font(CrosswireTheme.Typography.body)
                .foregroundStyle(CrosswireTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// The library list. Section label sits above the rows so the user
    /// understands what they're looking at — and it gives the surface a
    /// header anchor instead of floating rows on a gradient.
    private var library: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Library")
                    .font(CrosswireTheme.Typography.title)
                    .foregroundStyle(CrosswireTheme.textPrimary)
                Spacer()
                Text("^[\(filteredBottles.count) item](inflect: true)")
                    .font(CrosswireTheme.Typography.entryMeta)
                    .foregroundStyle(CrosswireTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredBottles) { bottle in
                        AppRow(
                            bottle: bottle,
                            onPrimaryAction: { runPrimary(for: bottle) },
                            onRun: { runPrimary(for: bottle) },
                            onRunSpecific: { program in
                                run(program: program, bottle: bottle)
                            },
                            onOpenSettings: { settingsBottle = bottle }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .animation(.default, value: bottleVM.bottles)
            .animation(.default, value: searchText)
        }
    }

    /// First-launch / empty-library state. Uses the app's own icon (single
    /// source of truth — if the icon changes, so does this view), the
    /// brand tagline, and the same blue CTA that drives the action row.
    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 128, height: 128)
                .shadow(color: CrosswireTheme.accent.opacity(0.25), radius: 24, x: 0, y: 8)
            VStack(spacing: 8) {
                Text("Your Windows library, on Mac.")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CrosswireTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Drop a Windows .exe to install your first game or app.")
                    .font(CrosswireTheme.Typography.body)
                    .foregroundStyle(CrosswireTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: installWindowsApp) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Install a Game or App")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(CrosswireTheme.textOnAccent)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(CrosswireTheme.accent)
                )
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Derived

    var filteredBottles: [Bottle] {
        let sorted = bottleVM.bottles.sorted()
        if searchText.isEmpty { return sorted }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Lifecycle

    @MainActor
    private func onAppearTask() async {
        bottleVM.loadBottles()
        bottlesLoaded = true

        if !CrosswireEngine.isEnginePresent() {
            setupStartingStage = nil
            showSetup = true
            return
        }

        let updateInfo = await CrosswireEngine.shouldUpdateEngine()
        guard checkEngineUpdates, updateInfo.0 else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "update.engine.title")
        alert.informativeText = String(format: String(localized: "update.engine.description"),
                                       String(CrosswireEngine.engineVersion()
                                              ?? SemanticVersion(0, 0, 0)),
                                       String(updateInfo.1))
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "update.engine.update"))
        alert.addButton(withTitle: String(localized: "button.removeAlert.cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            CrosswireEngine.uninstall()
            setupStartingStage = .engineSetup
            showSetup = true
        }
    }
}

// swiftlint:enable type_body_length

/// Modal overlay shown while a new app is being provisioned.
struct ProvisioningOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text(message)
                    .font(CrosswireTheme.Typography.body)
                    .foregroundStyle(CrosswireTheme.textPrimary)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CrosswireTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(CrosswireTheme.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
        }
    }
}

#Preview {
    ContentView(showSetup: .constant(false))
        .environmentObject(BottleVM.shared)
}
