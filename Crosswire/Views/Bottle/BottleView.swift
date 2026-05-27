//
//  BottleView.swift
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
import UniformTypeIdentifiers
import CrosswireKit

enum BottleStage {
    case config
    case programs
    case processes
}

struct BottleView: View {
    @ObservedObject var bottle: Bottle
    @State private var path = NavigationPath()
    @State private var programLoading: Bool = false
    @State private var showWinetricksSheet: Bool = false

    // Tile width 96 + 12pt gap; LazyVGrid handles centering.
    private let gridLayout = [GridItem(.adaptive(minimum: 108, maximum: 140), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    librarySection
                    Divider().opacity(0.4)
                    navSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .bottomBar { utilityBar }
            .onAppear {
                updateStartMenu()
            }
            .disabled(!bottle.isAvailable)
            .navigationTitle(bottle.settings.name)
            .sheet(isPresented: $showWinetricksSheet) {
                WinetricksView(bottle: bottle)
            }
            .onChange(of: bottle.settings) { oldValue, newValue in
                guard oldValue != newValue else { return }
                // Trigger a reload
                BottleVM.shared.bottles = BottleVM.shared.bottles
            }
            .navigationDestination(for: BottleStage.self) { stage in
                switch stage {
                case .config:
                    ConfigView(bottle: bottle)
                case .programs:
                    ProgramsView(
                        bottle: bottle, path: $path
                    )
                case .processes:
                    RunningProcessesView(bottle: bottle)
                }
            }
            .navigationDestination(for: Program.self) { program in
                ProgramView(program: program)
            }
        }
    }

    // MARK: - Sections

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Library")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                let count = bottle.pinnedPrograms.count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            LazyVGrid(columns: gridLayout, alignment: .leading, spacing: 4) {
                ForEach(bottle.pinnedPrograms, id: \.id) { pinnedProgram in
                    PinView(
                        bottle: bottle, program: pinnedProgram.program, pin: pinnedProgram.pin, path: $path
                    )
                }
                PinAddView(bottle: bottle)
            }
        }
    }

    private var navSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            navRow(label: "tab.programs", systemImage: "list.bullet", value: BottleStage.programs)
            Divider()
                .padding(.leading, 44)
            navRow(label: "tab.config", systemImage: "gearshape", value: BottleStage.config)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func navRow(label: LocalizedStringKey, systemImage: String, value: BottleStage) -> some View {
        NavigationLink(value: value) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var utilityBar: some View {
        HStack(spacing: 10) {
            utilityButton(label: "button.cDrive", systemImage: "folder") {
                bottle.openCDrive()
            }
            utilityButton(label: "button.terminal", systemImage: "terminal") {
                bottle.openTerminal()
            }
            utilityButton(label: "button.winetricks", systemImage: "wrench.and.screwdriver") {
                showWinetricksSheet.toggle()
            }
            Spacer()
            Button {
                pickAndRunExe()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("button.run")
                }
                .frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(programLoading)
            if programLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func utilityButton(
        label: LocalizedStringKey, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12))
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private func pickAndRunExe() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.exe,
            UTType(exportedAs: "com.microsoft.msi-installer"),
            UTType(exportedAs: "com.microsoft.bat")
        ]
        panel.directoryURL = bottle.url.appending(path: "drive_c")
        panel.begin { result in
            programLoading = true
            Task(priority: .userInitiated) {
                if result == .OK, let url = panel.urls.first {
                    do {
                        if url.pathExtension == "bat" {
                            try await Wine.runBatchFile(url: url, bottle: bottle)
                        } else {
                            try await Wine.runProgram(at: url, bottle: bottle)
                        }
                    } catch {
                        print("Failed to run external program: \(error)")
                    }
                }
                programLoading = false
                updateStartMenu()
            }
        }
    }

    private func updateStartMenu() {
        bottle.updateInstalledPrograms()

        let startMenuPrograms = bottle.getStartMenuPrograms()
        for startMenuProgram in startMenuPrograms {
            for program in bottle.programs where
            // For some godforsaken reason "foo/bar" != "foo/Bar" so...
            program.url.path().caseInsensitiveCompare(startMenuProgram.url.path()) == .orderedSame {
                program.pinned = true
                guard !bottle.settings.pins.contains(where: { $0.url == program.url }) else { return }
                bottle.settings.pins.append(PinnedProgram(
                    name: program.url.deletingPathExtension().lastPathComponent,
                    url: program.url
                ))
            }
        }
    }
}
