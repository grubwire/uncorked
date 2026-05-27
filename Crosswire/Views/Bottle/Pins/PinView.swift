//
//  PinView.swift
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

/// A pinned-program tile in the bottle library grid. Single-click runs it
/// (matches Finder/Launchpad expectations for app tiles); context menu
/// exposes everything else.
struct PinView: View {
    @ObservedObject var bottle: Bottle
    @ObservedObject var program: Program
    @State var pin: PinnedProgram
    @Binding var path: NavigationPath

    @State private var image: Image?
    @State private var showRenameSheet = false
    @State private var name: String = ""
    @State private var opening: Bool = false
    @State private var hovered: Bool = false

    private let tileSide: CGFloat = 64

    var body: some View {
        VStack(spacing: 10) {
            iconBlock
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .foregroundStyle(.primary)
        }
        .frame(width: 96)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeInOut(duration: 0.14), value: hovered)
        .onHover { hovered = $0 }
        .onTapGesture { runProgram() }
        .contextMenu {
            ProgramMenuView(program: program, path: $path)
            Divider()
            Button("button.rename", systemImage: "pencil.line") {
                showRenameSheet.toggle()
            }
            .labelStyle(.titleAndIcon)
            Button("button.showInFinder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([program.url])
            }
            .labelStyle(.titleAndIcon)
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameView("rename.pin.title", name: name) { newName in
                name = newName
            }
        }
        .task {
            name = pin.name
            guard let peFile = program.peFile else { return }
            let task = Task.detached {
                guard let image = peFile.bestIcon() else { return nil as Image? }
                return Image(nsImage: image)
            }
            self.image = await task.value
        }
        .onChange(of: name) {
            if let index = bottle.settings.pins.firstIndex(where: {
                let exists = FileManager.default.fileExists(atPath: pin.url?.path(percentEncoded: false) ?? "")
                return $0.url == pin.url && exists
            }) {
                bottle.settings.pins[index].name = name
            }
        }
    }

    @ViewBuilder
    private var iconBlock: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: tileSide, height: tileSide)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                AppTileIcon(name: name.isEmpty ? pin.name : name, side: tileSide)
            }
            // Press-feedback: subtle scale-and-fade out at run time
        }
        .scaleEffect(opening ? 0.92 : (hovered ? 1.02 : 1.0))
        .opacity(opening ? 0.0 : 1.0)
        .overlay(alignment: .bottomTrailing) {
            if hovered {
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.accentColor))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .offset(x: 4, y: 4)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
    }

    func runProgram() {
        withAnimation(.easeIn(duration: 0.18)) {
            opening = true
        } completion: {
            withAnimation(.easeOut(duration: 0.12)) {
                opening = false
            }
        }
        program.run()
    }
}
