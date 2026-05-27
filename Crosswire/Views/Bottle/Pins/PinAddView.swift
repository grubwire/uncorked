//
//  PinAddView.swift
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

/// "Add a pin" tile — matches PinView's dimensions so the grid stays even.
/// Dashed-stroke placeholder reads as "drop slot" without competing with
/// real app tiles.
struct PinAddView: View {
    let bottle: Bottle
    @State private var showingSheet = false
    @State private var hovered = false

    private let tileSide: CGFloat = 64

    var body: some View {
        VStack(spacing: 10) {
            Button {
                showingSheet = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(hovered ? 0.35 : 0.2),
                            style: StrokeStyle(lineWidth: 1.25, dash: [4, 3])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(hovered ? Color.primary.opacity(0.05) : Color.clear)
                        )
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: tileSide, height: tileSide)
                .scaleEffect(hovered ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            Text("pin.help")
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .foregroundStyle(.secondary)
        }
        .frame(width: 96)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .animation(.easeInOut(duration: 0.14), value: hovered)
        .onHover { hovered = $0 }
        .sheet(isPresented: $showingSheet) {
            PinCreationView(bottle: bottle)
        }
    }
}

#Preview {
    PinAddView(bottle: Bottle(bottleUrl: URL(filePath: "")))
}
