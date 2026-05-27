//
//  SettingsView.swift
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

struct SettingsView: View {
    @AppStorage("SUEnableAutomaticChecks") var crosswireUpdate = true
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("checkEngineUpdates") var checkEngineUpdates = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir

    /// Sparkle updater. Optional so #Preview can construct the view without it;
    /// when present, the Updates section renders an in-app Check for Updates
    /// button next to the macOS menu-bar entry.
    let updater: SPUUpdater?

    init(updater: SPUUpdater? = nil) {
        self.updater = updater
    }

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.toggle.kill.on.terminate", isOn: $killOnTerminate)
                ActionView(
                    text: "settings.path",
                    subtitle: defaultBottleLocation.prettyPath(),
                    actionName: "create.browse"
                ) {
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
            }
            Section("settings.updates") {
                Toggle("settings.toggle.Crosswire.updates", isOn: $crosswireUpdate)
                Toggle("settings.toggle.engine.updates", isOn: $checkEngineUpdates)
                if let updater {
                    HStack {
                        Text("Check now")
                        Spacer()
                        SparkleView(updater: updater)
                    }
                }
            }
            Section("About") {
                LabeledContent("App version", value: appVersionString)
                LabeledContent("Engine version", value: engineVersionString)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.medium)
    }

    private var appVersionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private var engineVersionString: String {
        guard let version = CrosswireEngine.engineVersion() else { return "Not installed" }
        return "\(version.major).\(version.minor).\(version.patch)"
    }
}

#Preview {
    SettingsView()
}
