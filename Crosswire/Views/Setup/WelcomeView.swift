//
//  WelcomeView.swift
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
import CrosswireKit

struct WelcomeView: View {
    @State var rosettaInstalled: Bool?
    @State var engineInstalled: Bool?
    @State var shouldCheckInstallStatus: Bool = false
    @Binding var path: [SetupStage]
    @Binding var showSetup: Bool
    var firstTime: Bool

    var body: some View {
        VStack(spacing: 0) {
            heading
                .padding(.top, 8)
            Spacer(minLength: 16)
            VStack(spacing: 0) {
                InstallStatusView(isInstalled: $rosettaInstalled,
                                  shouldCheckInstallStatus: $shouldCheckInstallStatus,
                                  name: "Rosetta")
                Divider().opacity(0.5)
                InstallStatusView(isInstalled: $engineInstalled,
                                  shouldCheckInstallStatus: $shouldCheckInstallStatus,
                                  showUninstall: true,
                                  name: "Crosswire")
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .onAppear {
                checkInstallStatus()
            }
            .onChange(of: shouldCheckInstallStatus) {
                checkInstallStatus()
            }
            Spacer(minLength: 16)
            buttonRow
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .frame(width: 420, height: 320)
    }

    @ViewBuilder
    private var heading: some View {
        VStack(spacing: 6) {
            Text(firstTime ? "setup.welcome" : "setup.title")
                .font(.system(size: 22, weight: .semibold))
            Text(firstTime ? "setup.welcome.subtitle" : "setup.subtitle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var buttonRow: some View {
        HStack {
            if let rosettaInstalled = rosettaInstalled,
               let engineInstalled = engineInstalled {
                if !rosettaInstalled || !engineInstalled {
                    Button("setup.quit") {
                        exit(0)
                    }
                    .keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(rosettaInstalled && engineInstalled ? "setup.done" : "setup.next") {
                    if !rosettaInstalled {
                        path.append(.rosetta)
                        return
                    }
                    if !engineInstalled {
                        path.append(.engineSetup)
                        return
                    }
                    showSetup = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Spacer()
            }
        }
        .frame(height: 32)
    }

    func checkInstallStatus() {
        rosettaInstalled = Rosetta2.isRosettaInstalled
        engineInstalled = CrosswireEngine.isEnginePresent()
    }
}

struct InstallStatusView: View {
    @Binding var isInstalled: Bool?
    @Binding var shouldCheckInstallStatus: Bool
    @State var showUninstall: Bool = false
    @State var name: String
    @State var text: String = String(localized: "setup.install.checking")

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 22, height: 22)
            Text(String.init(format: text, name))
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
            if let installed = isInstalled, installed && showUninstall {
                Button("setup.uninstall") {
                    uninstall()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onChange(of: isInstalled) {
            if let installed = isInstalled {
                text = installed
                    ? String(localized: "setup.install.installed")
                    : String(localized: "setup.install.notInstalled")
            } else {
                text = String(localized: "setup.install.checking")
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let installed = isInstalled {
            Image(systemName: installed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(installed ? Color.green : Color.orange)
                .symbolRenderingMode(.hierarchical)
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }

    func uninstall() {
        if name == "Crosswire" {
            CrosswireEngine.uninstall()
        }
        shouldCheckInstallStatus.toggle()
    }
}
