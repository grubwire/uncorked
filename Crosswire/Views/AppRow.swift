//
//  AppRow.swift
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

/// One row in the main app list. Single-click opens settings (the more
/// discoverable target), double-click runs the primary program.
struct AppRow: View {
    @ObservedObject var bottle: Bottle
    let onPrimaryAction: () -> Void
    let onRun: () -> Void
    let onRunSpecific: (Program) -> Void
    let onOpenSettings: () -> Void

    @State private var showProgramMenu: Bool = false
    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            AppTileIcon(name: bottle.displayName, side: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(bottle.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if bottle.inFlight {
                    Text("Setting up...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .background(hovered ? Color.primary.opacity(0.07) : Color.clear)
        .animation(.easeInOut(duration: 0.12), value: hovered)
        .onHover { hovered = $0 }
        .onTapGesture(count: 2) { onRun() }
        .onTapGesture { onPrimaryAction() }
        .opacity(bottle.isAvailable ? 1.0 : 0.5)
        .onAppear {
            if bottle.isAvailable && bottle.programs.isEmpty {
                bottle.updateInstalledPrograms()
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 6) {
            playButton
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        // Stop the row's tap gestures from firing when the user clicks the
        // buttons directly.
        .onTapGesture {}
    }

    @ViewBuilder
    private var playButton: some View {
        let visible = bottle.userVisiblePrograms
        if visible.count > 1 {
            Button {
                showProgramMenu = true
            } label: {
                playLabel
            }
            .buttonStyle(.borderless)
            .help("Run")
            .popover(isPresented: $showProgramMenu, arrowEdge: .top) {
                programPickerPopover
            }
        } else {
            Button {
                onRun()
            } label: {
                playLabel
            }
            .buttonStyle(.borderless)
            .disabled(bottle.programs.isEmpty || !bottle.isAvailable)
            .help("Run")
        }
    }

    /// Play affordance. Subtle glyph at rest, accent-tinted fill on row
    /// hover so the primary action becomes obvious without competing for
    /// attention across every row simultaneously.
    @ViewBuilder
    private var playLabel: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(hovered ? Color.white : Color.secondary)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(hovered ? Color.accentColor : Color.primary.opacity(0.08))
            )
    }

    private var programPickerPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Run...")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(bottle.userVisiblePrograms) { program in
                Button {
                    showProgramMenu = false
                    onRunSpecific(program)
                } label: {
                    HStack {
                        Text(program.name.replacingOccurrences(of: ".exe", with: ""))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 4)
    }
}
