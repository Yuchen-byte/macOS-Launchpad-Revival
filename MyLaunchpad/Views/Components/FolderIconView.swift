//
//  FolderIconView.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/25.
//

import AppKit
import SwiftUI

struct FolderIconView: View {
    let name: String
    let apps: [AppInfo]
    var isHidden: Bool = false
    var isMergeTarget: Bool = false
    var isEditing: Bool = false
    var expandsToGridCell: Bool = true
    var onTap: (() -> Void)? = nil
    var onDragChanged: ((CGPoint) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    @State private var isJiggling: Bool = false

    private let folderPreviewColumns = Array(repeating: GridItem(.fixed(18), spacing: 4), count: 3)

    var body: some View {
        Group {
            if expandsToGridCell {
                interactiveContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                interactiveContent
            }
        }
    }

    @ViewBuilder
    private var interactiveContent: some View {
        if let onDragChanged, let onDragEnded {
            compactContent
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            onDragChanged(value.location)
                        }
                        .onEnded { _ in
                            onDragEnded()
                        }
                )
        } else {
            compactContent
        }
    }

    private var compactContent: some View {
        VStack {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(isMergeTarget ? 0.18 : 0.0))
                        .frame(width: 96, height: 96)

                    LazyVGrid(columns: folderPreviewColumns, alignment: .leading, spacing: 4) {
                        ForEach(0..<9, id: \.self) { index in
                            if index < previewApps.count {
                                Image(nsImage: previewApps[index].icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                            } else {
                                Color.clear
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .frame(width: 80, height: 80, alignment: .topLeading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .drawingGroup()
                    .rotationEffect(.degrees(isEditing ? (isJiggling ? -2.0 : 2.0) : 0))
                }
                .frame(width: 96, height: 96)
                .padding(12)
                .scaleEffect(isMergeTarget ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isMergeTarget)

                Text(name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .drawingGroup()
                    .padding(.bottom, 4)
            }
            .frame(height: 150, alignment: .top)
            .contentShape(Rectangle())
            .opacity(isHidden ? 0.0 : 1.0)
            .onTapGesture {
                onTap?()
            }
        }
        .onAppear {
            updateJiggleState(isEditingNow: isEditing)
        }
        .onChange(of: isEditing) { _, editing in
            updateJiggleState(isEditingNow: editing)
        }
    }

    private var previewApps: [AppInfo] {
        Array(apps.prefix(9))
    }

    private func updateJiggleState(isEditingNow: Bool) {
        if isEditingNow {
            withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                isJiggling = true
            }
        } else {
            withAnimation(.default) {
                isJiggling = false
            }
        }
    }
}
