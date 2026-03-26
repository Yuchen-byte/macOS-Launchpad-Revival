//
//  AppIconView.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/25.
//

import AppKit
import SwiftUI

struct AppIconView: View {
    let app: AppInfo
    var isHidden: Bool = false
    var isMergeTarget: Bool = false
    var isEditing: Bool = false
    var expandsToGridCell: Bool = true
    var onTap: (() -> Void)? = nil
    var onDragChanged: ((CGPoint) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    var onUninstall: (() -> Void)? = nil
    var onHide: (() -> Void)? = nil

    @State private var isJiggling: Bool = false

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

                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                        .drawingGroup()
                        .scaleEffect(isMergeTarget ? 1.05 : 1.0)
                        .rotationEffect(.degrees(isEditing ? (isJiggling ? -2.0 : 2.0) : 0))

                    if isEditing {
                        ZStack {
                            Button {
                                onUninstall?()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, .red)
                                    .background(Circle().fill(Color.white).scaleEffect(0.8))
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain)
                            .position(x: 4, y: 4)

                            Button {
                                onHide?()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, .gray)
                                    .background(Circle().fill(Color.white).scaleEffect(0.8))
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain)
                            .position(x: 76, y: 4)
                        }
                        .frame(width: 80, height: 80)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 96, height: 96)
                .padding(12)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isMergeTarget)

                Text(app.name)
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
                if !isEditing {
                    onTap?()
                }
            }
        }
        .onAppear {
            updateJiggleState(isEditingNow: isEditing)
        }
        .onChange(of: isEditing) { _, editing in
            updateJiggleState(isEditingNow: editing)
        }
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
