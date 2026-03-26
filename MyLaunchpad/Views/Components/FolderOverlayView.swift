//
//  FolderOverlayView.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/25.
//

import AppKit
import SwiftUI

struct FolderOverlayView: View {
    let folder: LaunchpadItem
    let appManager: AppManager
    @Binding var isFolderEscaped: Bool
    @Binding var editingFolderName: String
    let onClose: () -> Void
    let onRename: (String) -> Void
    let onOpenApp: (AppInfo) -> Void
    let onExtractedAppDrag: (AppInfo, CGPoint) -> Void
    let onEscapedDragChanged: (CGPoint) -> Void
    let onEscapedDragEnded: () -> Void

    @State private var internalHoveredApp: AppInfo? = nil
    @State private var internalAppFrames: [UUID: CGRect] = [:]
    @State private var internalDraggedApp: AppInfo? = nil
    @State private var internalDragLocation: CGPoint? = nil
    @State private var overlayFrame: CGRect = .zero

    private let folderOverlayColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)

    var body: some View {
        switch folder {
        case .app:
            EmptyView()
        case .folder:
            folderContent
                .onPreferenceChange(FolderAppFramePreferenceKey.self) { frames in
                    internalAppFrames = frames
                }
                .onPreferenceChange(FolderOverlayFramePreferenceKey.self) { frame in
                    overlayFrame = frame
                }
        }
    }

    private var folderContent: some View {
        let apps = folderApps

        return ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()

            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 24) {
                TextField("", text: $editingFolderName)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .onSubmit {
                        onRename(editingFolderName)
                    }

                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: folderOverlayColumns, spacing: 24) {
                            ForEach(apps) { app in
                                FolderOverlayAppCell(
                                    app: app,
                                    isHidden: internalDraggedApp?.id == app.id,
                                    onTap: {
                                        onOpenApp(app)
                                    },
                                    onDragChanged: { value in
                                        handleInternalDragChanged(for: app, value: value)
                                    },
                                    onDragEnded: {
                                        handleInternalDragEnded()
                                    }
                                )
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: FolderAppFramePreferenceKey.self,
                                            value: [app.id: geometry.frame(in: .global)]
                                        )
                                    }
                                )
                            }
                        }
                        .padding(32)
                    }
                }
                .frame(width: 440, height: 420)
                .shadow(color: .black.opacity(0.22), radius: 28, y: 18)
            }

            internalFloatingClone
        }
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: FolderOverlayFramePreferenceKey.self,
                    value: geometry.frame(in: .global)
                )
            }
        )
    }

    @ViewBuilder
    private var internalFloatingClone: some View {
        if let app = internalDraggedApp, let loc = internalDragLocation {
            VStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)

                Text(app.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .drawingGroup()
            .position(
                x: loc.x - overlayFrame.minX,
                y: loc.y - overlayFrame.minY
            )
            .scaleEffect(1.05)
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .allowsHitTesting(false)
            .zIndex(10)
        }
    }

    private var folderApps: [AppInfo] {
        switch folder {
        case .app:
            return []
        case .folder(_, _, let apps):
            return apps
        }
    }

    private var folderID: UUID? {
        switch folder {
        case .app:
            return nil
        case .folder(let id, _, _):
            return id
        }
    }

    private func handleInternalDragChanged(for sourceApp: AppInfo, value: DragGesture.Value) {
        if isFolderEscaped {
            onEscapedDragChanged(value.location)
            return
        }

        // Track internal drag state for floating clone
        if internalDraggedApp?.id != sourceApp.id {
            internalDraggedApp = sourceApp
        }
        internalDragLocation = value.location

        if abs(value.translation.width) > 200 || abs(value.translation.height) > 200 {
            guard !isFolderEscaped else {
                onEscapedDragChanged(value.location)
                return
            }

            guard let folderID, let extractedApp = appManager.extractAppFromFolder(folderID: folderID, appID: sourceApp.id) else {
                return
            }

            internalHoveredApp = nil
            internalDraggedApp = nil
            internalDragLocation = nil
            onExtractedAppDrag(extractedApp, value.location)
            isFolderEscaped = true
            onEscapedDragChanged(value.location)
            return
        }

        guard folderApps.contains(where: { $0.id == sourceApp.id }) else {
            return
        }

        guard let folderID else {
            return
        }

        let target = internalHoveredTarget(for: sourceApp, location: value.location)

        guard target?.id != internalHoveredApp?.id else {
            return
        }

        internalHoveredApp = target

        if let target {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.08)) {
                appManager.moveAppInsideFolder(folderID: folderID, from: sourceApp, to: target)
            }
        }
    }

    private func handleInternalDragEnded() {
        internalHoveredApp = nil
        internalDraggedApp = nil
        internalDragLocation = nil

        if isFolderEscaped {
            onEscapedDragEnded()
        }
    }

    private func internalHoveredTarget(for sourceApp: AppInfo, location: CGPoint) -> AppInfo? {
        folderApps
            .filter { candidate in
                candidate.id != sourceApp.id && (internalAppFrames[candidate.id]?.contains(location) ?? false)
            }
            .min { lhs, rhs in
                distance(from: location, to: lhs) < distance(from: location, to: rhs)
            }
    }

    private func distance(from location: CGPoint, to app: AppInfo) -> CGFloat {
        guard let frame = internalAppFrames[app.id] else {
            return .greatestFiniteMagnitude
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        return sqrt((dx * dx) + (dy * dy))
    }
}

private struct FolderAppFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct FolderOverlayFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct FolderOverlayAppCell: View {
    let app: AppInfo
    let isHidden: Bool
    let onTap: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)

            Text(app.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        }
        .drawingGroup()
        .contentShape(Rectangle())
        .opacity(isHidden ? 0.0 : 1.0)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    onDragChanged(value)
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
        .onTapGesture(perform: onTap)
    }
}
