//
//  ContentView.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/25.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @State var appManager = AppManager()
    @State private var currentPage: Int? = 0
    @State private var dragLocation: CGPoint? = nil
    @State private var lastPageTurnTime = Date()
    @State private var keyMonitor: Any?
    @State private var hoveredItem: LaunchpadItem? = nil
    @State private var mergeTarget: LaunchpadItem? = nil
    @State private var openedFolder: LaunchpadItem? = nil
    @State private var isFolderEscaped: Bool = false
    @State private var editingFolderName: String = ""
    @State private var itemFrames: [LaunchpadItem.ID: CGRect] = [:]
    @State private var rootFrame: CGRect = .zero
    @State private var isEditing: Bool = false
    @State private var optionTimer: Task<Void, Never>? = nil
    @State private var isOptionHandled: Bool = false
    @State private var flagsMonitor: Any? = nil
    @State private var appToUninstall: AppInfo? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    private let reorderAnimation = Animation.interactiveSpring(
        response: 0.3,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
    private let folderAnimation = Animation.spring(response: 0.35, dampingFraction: 0.85)

    private var activeOpenedFolder: LaunchpadItem? {
        guard let openedFolder else {
            return nil
        }

        if let liveFolder = appManager.items.first(where: { $0.id == openedFolder.id }) {
            return liveFolder
        }

        return isFolderEscaped ? openedFolder : nil
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissTopLayer()
                }

            VStack(spacing: 0) {
                launchpadPager
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                pageIndicator
            }

            if let folder = activeOpenedFolder {
                FolderOverlayView(
                    folder: folder,
                    appManager: appManager,
                    isFolderEscaped: $isFolderEscaped,
                    editingFolderName: $editingFolderName,
                    onClose: closeFolder,
                    onRename: { newName in
                        appManager.renameFolder(id: folder.id, newName: newName)
                    },
                    onOpenApp: openApp,
                    onExtractedAppDrag: beginFolderEscapeDrag,
                    onEscapedDragChanged: handleEscapedFolderDragChanged,
                    onEscapedDragEnded: finishEscapedFolderDrag
                )
                    .opacity(isFolderEscaped ? 0.0 : 1.0)
                    .allowsHitTesting(!isFolderEscaped)
                    .zIndex(1)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            floatingDraggedItem
        }
        .ignoresSafeArea()
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: RootFramePreferenceKey.self,
                    value: geometry.frame(in: .global)
                )
            }
        )
        .onAppear {
            appManager.fetchApps()
            installKeyMonitorIfNeeded()
            installFlagsMonitorIfNeeded()
        }
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            itemFrames = frames
        }
        .onPreferenceChange(RootFramePreferenceKey.self) { frame in
            rootFrame = frame
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchpadWillHide)) { _ in
            appToUninstall = nil
            withAnimation(folderAnimation) {
                openedFolder = nil
                isFolderEscaped = false
                isEditing = false
                editingFolderName = ""
                clearDragInteractionState()
            }
        }
        .onChange(of: appManager.pagedItems.count) { _, count in
            clampCurrentPage(for: count)
        }
        .onDisappear {
            removeKeyMonitor()
            removeFlagsMonitor()
            withAnimation(reorderAnimation) {
                isEditing = false
                openedFolder = nil
                isFolderEscaped = false
                editingFolderName = ""
                clearDragInteractionState()
            }
        }
        .alert("确定要卸载「\(appToUninstall?.name ?? "")」吗？", isPresented: Binding(
            get: { appToUninstall != nil },
            set: { if !$0 { appToUninstall = nil } }
        )) {
            Button("取消", role: .cancel) {
                appToUninstall = nil
            }
            Button("卸载", role: .destructive) {
                if let app = appToUninstall {
                    appManager.uninstallApp(app)
                }
                appToUninstall = nil
            }
        } message: {
            Text("此操作将把该应用移入废纸篓，该操作不可撤销。")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RestoreHiddenApps"))) { _ in
            appManager.restoreHiddenApps()
        }
    }

    private var launchpadPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(appManager.pagedItems.enumerated()), id: \.offset) { index, pageItems in
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(pageItems) { item in
                            itemCell(for: item)
                        }
                    }
                    .id(index)
                    .padding(20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollContentBackground(.hidden)
        .scrollPosition(id: $currentPage)
        .scrollTargetBehavior(.paging)
    }

    private func itemCell(for item: LaunchpadItem) -> some View {
        GeometryReader { geometry in
            itemContent(for: item)
                .scaleEffect(scaleEffect(for: item))
                .background(
                    Color.clear.preference(
                        key: ItemFramePreferenceKey.self,
                        value: [item.id: geometry.frame(in: .global)]
                    )
                )
                .animation(reorderAnimation, value: appManager.draggedItem?.id)
                .animation(reorderAnimation, value: hoveredItem?.id)
                .animation(reorderAnimation, value: appManager.items)
        }
        .frame(height: 150)
    }

    @ViewBuilder
    private func itemContent(for item: LaunchpadItem) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                isHidden: appManager.draggedItem?.id == item.id,
                isMergeTarget: mergeTarget?.id == item.id,
                isEditing: isEditing,
                onTap: {
                    openApp(app)
                },
                onDragChanged: { location in
                    handleDragChanged(for: item, at: location)
                },
                onDragEnded: {
                    handleDragEnded(for: item)
                },
                onUninstall: {
                    appToUninstall = app
                },
                onHide: {
                    appManager.hideApp(app)
                }
            )
        case .folder(_, let name, let apps):
            FolderIconView(
                name: name,
                apps: apps,
                isHidden: appManager.draggedItem?.id == item.id,
                isMergeTarget: mergeTarget?.id == item.id,
                isEditing: isEditing,
                onTap: {
                    openFolder(item, name: name)
                },
                onDragChanged: { location in
                    handleDragChanged(for: item, at: location)
                },
                onDragEnded: {
                    handleDragEnded(for: item)
                }
            )
        }
    }

    @ViewBuilder
    private var floatingDraggedItem: some View {
        if let draggedItem = appManager.draggedItem, let dragLocation {
            floatingDraggedItemView(for: draggedItem)
                .position(
                    x: dragLocation.x - rootFrame.minX,
                    y: dragLocation.y - rootFrame.minY
                )
                .scaleEffect(1.1)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                .allowsHitTesting(false)
                .zIndex(2)
        }
    }

    @ViewBuilder
    private var pageIndicator: some View {
        if !appManager.pagedItems.isEmpty {
            HStack(spacing: 12) {
                ForEach(0..<appManager.pagedItems.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                currentPage = index
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 90)
        }
    }

    private func scaleEffect(for item: LaunchpadItem) -> CGFloat {
        if mergeTarget?.id == item.id {
            return 1.0
        }

        if hoveredItem?.id == item.id {
            return 0.96
        }

        if appManager.draggedItem != nil {
            return 0.985
        }

        return 1.0
    }

    private func closeFolder() {
        withAnimation(folderAnimation) {
            openedFolder = nil
            isFolderEscaped = false
            editingFolderName = ""
        }
    }

    private func openFolder(_ item: LaunchpadItem, name: String) {
        editingFolderName = name
        withAnimation(folderAnimation) {
            isFolderEscaped = false
            openedFolder = item
        }
    }

    private func openApp(_ app: AppInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
    }

    private func requestHideLaunchpad() {
        NotificationCenter.default.post(name: .hideLaunchpad, object: nil)
    }

    private func dismissTopLayer() {
        if appToUninstall != nil {
            appToUninstall = nil
        } else if openedFolder != nil {
            withAnimation(folderAnimation) {
                openedFolder = nil
                isFolderEscaped = false
                editingFolderName = ""
            }
        } else if isEditing {
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditing = false
            }
        } else {
            requestHideLaunchpad()
        }
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                dismissTopLayer()
                return nil
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func installFlagsMonitorIfNeeded() {
        guard flagsMonitor == nil else {
            return
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let isOptionPressed = event.modifierFlags.contains(.option)

            if isOptionPressed {
                if optionTimer == nil && !isOptionHandled && appManager.draggedItem == nil {
                    optionTimer = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        guard !Task.isCancelled else { return }

                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing.toggle()
                        }
                        isOptionHandled = true
                    }
                }
            } else {
                optionTimer?.cancel()
                optionTimer = nil
                isOptionHandled = false
            }

            return event
        }
    }

    private func removeFlagsMonitor() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        optionTimer?.cancel()
        optionTimer = nil
    }

    private func handleDragChanged(for item: LaunchpadItem, at location: CGPoint) {
        if appManager.draggedItem?.id != item.id {
            appManager.draggedItem = item
        }

        dragLocation = location
        updatePageTurn(for: location)

        guard Date().timeIntervalSince(lastPageTurnTime) > 0.5 else {
            hoveredItem = nil
            mergeTarget = nil
            return
        }

        let target = hoveredTarget(for: item, location: location)
        let isOptionHeld = NSEvent.modifierFlags.contains(.option)

        if target == nil {
            hoveredItem = nil
            mergeTarget = nil

            let maxPages = appManager.pagedItems.count
            let isLastPage = (currentPage ?? 0) == (maxPages > 0 ? maxPages - 1 : 0)

            if isLastPage,
               let lastItem = appManager.items.last,
               lastItem.id != item.id,
               let lastFrame = itemFrames[lastItem.id] {
                let isAfterLastItem = (location.y > lastFrame.maxY + 40) ||
                    (location.y > lastFrame.minY && location.x > lastFrame.maxX + 40)

                if isAfterLastItem {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.08)) {
                        appManager.moveItemToEnd(item)
                    }
                    return
                }
            }

            return
        }

        if let target {
            if isOptionHeld {
                hoveredItem = target

                if mergeTarget?.id != target.id {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        mergeTarget = target
                    }
                }
            } else {
                let shouldMove = hoveredItem?.id != target.id || mergeTarget != nil
                hoveredItem = target
                mergeTarget = nil

                if shouldMove, let draggedItem = appManager.draggedItem {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.08)) {
                        appManager.moveItem(from: draggedItem, to: target)
                    }
                }
            }
        }
    }

    private func handleDragEnded(for item: LaunchpadItem) {
        let isOptionHeld = NSEvent.modifierFlags.contains(.option)

        if
            isOptionHeld,
            let draggedItem = appManager.draggedItem,
            draggedItem.id == item.id,
            let target = mergeTarget,
            target.id != item.id
        {
            withAnimation(folderAnimation) {
                appManager.mergeItem(draggedItem, into: target)
            }
        }

        clearDragInteractionState()
    }

    private func hoveredTarget(for draggedItem: LaunchpadItem, location: CGPoint) -> LaunchpadItem? {
        appManager.items
            .filter { $0.id != draggedItem.id }
            .min { centerDistance(from: location, to: $0) < centerDistance(from: location, to: $1) }
            .flatMap { closest in
                centerDistance(from: location, to: closest) < 100 ? closest : nil
            }
    }

    private func centerDistance(from location: CGPoint, to item: LaunchpadItem) -> CGFloat {
        guard let frame = itemFrames[item.id] else {
            return .greatestFiniteMagnitude
        }

        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        return sqrt(dx * dx + dy * dy)
    }

    private func updatePageTurn(for location: CGPoint) {
        let screenWidth = NSScreen.main?.frame.width ?? 1000
        let edgeThreshold: CGFloat = 80
        let now = Date()

        guard now.timeIntervalSince(lastPageTurnTime) > 0.5 else {
            return
        }

        if location.x <= edgeThreshold {
            if let currentPage, currentPage > 0 {
                withAnimation(.easeInOut(duration: 0.28)) {
                    self.currentPage = currentPage - 1
                }
                lastPageTurnTime = now
            }
        } else if location.x >= screenWidth - edgeThreshold {
            if let currentPage, currentPage < appManager.pagedItems.count - 1 {
                withAnimation(.easeInOut(duration: 0.28)) {
                    self.currentPage = currentPage + 1
                }
                lastPageTurnTime = now
            }
        }
    }

    private func beginFolderEscapeDrag(_ app: AppInfo, at location: CGPoint) {
        hoveredItem = nil
        mergeTarget = nil
        dragLocation = location
        appManager.draggedItem = .app(app)
    }

    private func handleEscapedFolderDragChanged(at location: CGPoint) {
        guard let draggedItem = appManager.draggedItem else {
            return
        }

        dragLocation = location
        handleDragChanged(for: draggedItem, at: location)
    }

    private func finishEscapedFolderDrag() {
        let isOptionHeld = NSEvent.modifierFlags.contains(.option)

        if let draggedItem = appManager.draggedItem {
            if isOptionHeld, let target = mergeTarget, target.id != draggedItem.id {
                withAnimation(folderAnimation) {
                    appManager.mergeItem(draggedItem, into: target)
                }
            }
        }

        DispatchQueue.main.async {
            clearDragInteractionState(preserveGhostFolder: true)
            openedFolder = nil
            isFolderEscaped = false
            editingFolderName = ""
        }
    }

    private func clearDragInteractionState(preserveGhostFolder: Bool = false) {
        hoveredItem = nil
        mergeTarget = nil
        dragLocation = nil
        if !preserveGhostFolder {
            isFolderEscaped = false
        }
        appManager.clearDragState()
    }

    private func clampCurrentPage(for count: Int) {
        guard count > 0 else {
            currentPage = nil
            return
        }

        if let currentPage {
            self.currentPage = min(currentPage, count - 1)
        } else {
            currentPage = 0
        }
    }

    @ViewBuilder
    private func floatingDraggedItemView(for item: LaunchpadItem) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                expandsToGridCell: false
            )
        case .folder(_, let name, let apps):
            FolderIconView(
                name: name,
                apps: apps,
                expandsToGridCell: false
            )
        }
    }
}

private struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [LaunchpadItem.ID: CGRect] = [:]

    static func reduce(value: inout [LaunchpadItem.ID: CGRect], nextValue: () -> [LaunchpadItem.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct RootFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
