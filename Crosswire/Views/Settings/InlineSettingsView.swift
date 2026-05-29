//
//  InlineSettingsView.swift
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
import Sparkle
import CrosswireKit
import AppKit

/// Full-bleed inline settings view shown when `AppRoute == .settings`. Slides
/// in over the library view; Done returns. Replaces the prior standalone
/// SwiftUI `Settings` scene (separate window). Battle.net pattern: left
/// sidebar with section nav, right content pane, version chip bottom-left,
/// Done button bottom-right.
///
/// Content stays largely the same as the prior `SettingsView` in this
/// commit — the per-section content polish (Section 3 of the brief) is a
/// follow-up commit that re-labels toggles, hides container paths,
/// rebuilds About, etc. This commit is purely the structural conversion.
struct InlineSettingsView: View {
    let updater: SPUUpdater?
    var onDone: () -> Void

    // Optional to satisfy `List(selection:)` single-selection binding. nil is
    // treated as `.general` when resolving content.
    @State private var selectedSection: SettingsSection? = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case updates = "Updates"
        case privacy = "Privacy"
        case about = "About"
        case advanced = "Advanced"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .updates: return "arrow.triangle.2.circlepath"
            case .privacy: return "lock.shield"
            case .about: return "info.circle"
            case .advanced: return "wrench.adjustable"
            }
        }
    }

    init(updater: SPUUpdater? = nil, onDone: @escaping () -> Void) {
        self.updater = updater
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                sidebar
                Divider().opacity(0.3)
                content
            }
            Divider().opacity(0.3)
            footer
        }
        // Transient overlay → material blur over the library shell, per the
        // materials-vs-branded-hex rule.
        .background(.regularMaterial)
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack {
            Text("Settings")
                .font(CrosswireTheme.Typography.title)
                .foregroundStyle(CrosswireTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    // MARK: - Sidebar

    /// Native sidebar `List` — inherits sidebar material + vibrancy, free
    /// keyboard navigation, resize and accessibility. The system renders the
    /// selection highlight, and since the project accent is Crosswire blue the
    /// selected row is already an on-brand blue pill — so we let the native
    /// selection stand on its own (no custom accent bar or background).
    private var sidebar: some View {
        List(selection: $selectedSection) {
            // `id: \.self` so each row's selection identity is the
            // `SettingsSection` value itself, matching the `SettingsSection?`
            // binding. Relying on `Identifiable.id` (a String here) would make
            // the selection type mismatch and silently never update.
            ForEach(SettingsSection.allCases, id: \.self) { section in
                sidebarRow(section: section)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: 200)
    }

    @ViewBuilder
    private func sidebarRow(section: SettingsSection) -> some View {
        Label {
            Text(section.rawValue)
                .font(CrosswireTheme.Typography.body)
        } icon: {
            Image(systemName: section.icon)
                .font(.system(size: 13, weight: .regular))
        }
    }

    // MARK: - Content pane

    @ViewBuilder
    private var content: some View {
        ScrollView {
            Group {
                switch selectedSection ?? .general {
                case .general:  generalSection
                case .updates:  updatesSection
                case .privacy:  privacySection
                case .about:    aboutSection
                case .advanced: advancedSection
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("General")
            SettingsGeneralGroup()
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Updates")
            SettingsUpdatesGroup(updater: updater)
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Privacy")
            Text(
                "Crash reporting and other privacy controls will live here in a "
                + "future release. None of your activity is shared today."
            )
            .font(CrosswireTheme.Typography.body)
            .foregroundStyle(CrosswireTheme.textSecondary)
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("About")
            SettingsAboutGroup()
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Advanced")
            Text(
                "Power-user controls coming soon. Per-app advanced settings "
                + "live in each app's detail view — click an app in your library."
            )
            .font(CrosswireTheme.Typography.body)
            .foregroundStyle(CrosswireTheme.textSecondary)
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(CrosswireTheme.textPrimary)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(versionString)
                .font(CrosswireTheme.Typography.entryMeta)
                .foregroundStyle(CrosswireTheme.textTertiary)
                .textSelection(.enabled)
            Spacer()
            Button("Done") { onDone() }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .foregroundStyle(CrosswireTheme.textOnAccent)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(CrosswireTheme.accent)
                )
                .font(CrosswireTheme.Typography.buttonPrimary)
                // Esc dismisses. Return is intentionally NOT bound — the
                // sidebar List below already owns Return for navigating
                // sections, and `.defaultAction` would let the List
                // intercept the Done shortcut first.
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "v\(short)" : "v\(short) (\(build))"
    }
}

// MARK: - Group views

/// General settings: quit-on-terminate behavior and the app-data location.
/// The raw container path is intentionally hidden — "Show in Finder" reveals
/// it instead, and "Change…" relocates where new apps install.
struct SettingsGeneralGroup: View {
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Quit running apps when Crosswire quits", isOn: $killOnTerminate)
                .tint(CrosswireTheme.accent)
                .font(CrosswireTheme.Typography.body)
                .foregroundStyle(CrosswireTheme.textPrimary)
            VStack(alignment: .leading, spacing: 8) {
                Text("App Data Location")
                    .font(CrosswireTheme.Typography.body)
                    .foregroundStyle(CrosswireTheme.textPrimary)
                Text("Where your installed apps and their files are kept.")
                    .font(CrosswireTheme.Typography.entryMeta)
                    .foregroundStyle(CrosswireTheme.textSecondary)
                HStack(spacing: 8) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([defaultBottleLocation])
                    }
                    .buttonStyle(.bordered)
                    Button("Change…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.canCreateDirectories = true
                        panel.directoryURL = BottleData.containerDir
                        panel.begin { result in
                            if result == .OK, let url = panel.urls.first {
                                defaultBottleLocation = url
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CrosswireTheme.surface)
            )
        }
        .frame(maxWidth: 480, alignment: .leading)
    }
}

/// Updates section: two independent toggles (distinct UserDefaults keys —
/// never collapse to one). The second covers the Windows-compatibility layer;
/// it deliberately avoids the word "engine" per the user-facing naming rule.
struct SettingsUpdatesGroup: View {
    @AppStorage("SUEnableAutomaticChecks") var crosswireUpdate = true
    @AppStorage("checkEngineUpdates") var checkEngineUpdates = true
    let updater: SPUUpdater?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Automatically check for Crosswire app updates", isOn: $crosswireUpdate)
                .tint(CrosswireTheme.accent)
                .font(CrosswireTheme.Typography.body)
                .foregroundStyle(CrosswireTheme.textPrimary)
            Toggle("Automatically check for Windows compatibility updates", isOn: $checkEngineUpdates)
                .tint(CrosswireTheme.accent)
                .font(CrosswireTheme.Typography.body)
                .foregroundStyle(CrosswireTheme.textPrimary)
            if let updater {
                HStack {
                    Text("Check now")
                        .font(CrosswireTheme.Typography.body)
                        .foregroundStyle(CrosswireTheme.textPrimary)
                    Spacer()
                    SparkleView(updater: updater)
                }
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
    }
}

/// About panel: app icon, name, version, and external links. The engine
/// version is intentionally NOT shown — no user-facing engine/version strings
/// (CLAUDE.md naming rule; overrides the spec line that listed it).
struct SettingsAboutGroup: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crosswire")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CrosswireTheme.textPrimary)
                    Text(appVersionString)
                        .font(CrosswireTheme.Typography.body)
                        .foregroundStyle(CrosswireTheme.textSecondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 10) {
                aboutLink("GitHub", "https://github.com/grubwire/Crosswire")
                aboutLink("Crosswire Website", "https://grubwire.io")
                aboutLink("Report an Issue", "https://github.com/grubwire/Crosswire/issues")
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
    }

    @ViewBuilder
    private func aboutLink(_ title: String, _ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                Text(title)
                    .font(CrosswireTheme.Typography.body)
            }
            .foregroundStyle(CrosswireTheme.accent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var appVersionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(short)" : "Version \(short) (\(build))"
    }
}
