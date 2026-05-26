//
//  ContentView+Install.swift
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
import UniformTypeIdentifiers
import CrosswireKit

extension ContentView {
    func installWindowsApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType.exe,
            UTType(exportedAs: "com.microsoft.msi-installer"),
            UTType(exportedAs: "com.microsoft.bat")
        ]
        panel.begin { result in
            guard result == .OK, let pickedURL = panel.urls.first else { return }
            Task { @MainActor in
                await provisionAndInstall(pickedURL: pickedURL)
            }
        }
    }

    @MainActor
    func provisionAndInstall(pickedURL: URL) async {
        let bottleName = pickedURL.deletingPathExtension().lastPathComponent
        let defaultLocation = UserDefaults.standard.url(forKey: "defaultBottleLocation")
            ?? BottleData.defaultBottleDir

        provisioningMessage = "Setting up..."
        let newBottleURL = bottleVM.createNewBottle(
            bottleName: bottleName,
            winVersion: .win10,
            bottleURL: defaultLocation
        )

        let bottle = await waitForBottle(url: newBottleURL)
        guard let bottle else {
            provisioningMessage = nil
            showInstallAlert(
                title: "Could not create bottle",
                body: "Crosswire was unable to initialize a new wineprefix for \(bottleName). "
                    + "This is usually a Wine engine problem (memory mapping or a missing binary). "
                    + "See the latest log at ~/Library/Logs/app.Crosswire.Crosswire/."
            )
            return
        }

        provisioningMessage = "Running installer..."
        NSApp.miniaturizeAll(nil)
        var installerError: Error?
        do {
            try await Wine.runProgram(at: pickedURL, bottle: bottle)
        } catch {
            installerError = error
            print("Failed to run installer: \(error)")
        }
        bottle.finalizeAppIdentity()
        provisioningMessage = nil

        if let installerError {
            showInstallAlert(
                title: "Installer could not start",
                body: "\(installerError.localizedDescription)\n\n"
                    + "The bottle was created but the installer never ran. "
                    + "See the latest log at ~/Library/Logs/app.Crosswire.Crosswire/."
            )
            return
        }

        if bottle.userVisiblePrograms.isEmpty {
            showInstallAlert(
                title: "Installer finished but no apps were detected",
                body: "The installer ran, but Crosswire could not find anything to launch. "
                    + "On Apple Silicon this most often means the installer crashed mid-install "
                    + "(look for mmap errors in the log). "
                    + "Log: ~/Library/Logs/app.Crosswire.Crosswire/. "
                    + "You can delete the bottle from its settings panel."
            )
        }
    }

    private func showInstallAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    func waitForBottle(url: URL) async -> Bottle? {
        // createNewBottle spawns an inner Task; poll the published list until
        // the bottle flips out of inFlight. ~30s ceiling.
        for _ in 0..<300 {
            if let bottle = bottleVM.bottles.first(where: { $0.url == url }), !bottle.inFlight {
                return bottle
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return bottleVM.bottles.first(where: { $0.url == url })
    }

    func runPrimary(for bottle: Bottle) {
        guard bottle.isAvailable else { return }
        bottle.updateInstalledPrograms()
        let programs = bottle.programs
        guard !programs.isEmpty else { return }

        if let primaryURL = bottle.settings.primaryProgramURL,
           let primary = programs.first(where: { $0.url == primaryURL }) {
            run(program: primary, bottle: bottle)
            return
        }

        let visible = bottle.userVisiblePrograms
        if visible.count == 1 {
            run(program: visible[0], bottle: bottle)
        } else if visible.count > 1 {
            run(program: visible[0], bottle: bottle)
        } else if programs.count == 1 {
            run(program: programs[0], bottle: bottle)
        } else {
            // No detection has run and no primary is set; open settings
            // so the user can pick one explicitly.
            settingsBottle = bottle
        }
    }

    func run(program: Program, bottle: Bottle) {
        NSApp.miniaturizeAll(nil)
        Task(priority: .userInitiated) {
            do {
                try await Wine.runProgram(at: program.url, bottle: bottle)
            } catch {
                print("Failed to run program: \(error)")
            }
        }
    }
}
