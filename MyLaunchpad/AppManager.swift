//
//  AppManager.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/25.
//

import Foundation
import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
public final class AppManager {
    public let appsPerPage = 35
    public var items: [LaunchpadItem] = []
    public var draggedItem: LaunchpadItem? = nil
    public var hiddenAppPaths: Set<String> = []
    public var pagedItems: [[LaunchpadItem]] {
        guard !items.isEmpty else {
            return []
        }

        return stride(from: 0, to: items.count, by: appsPerPage).map { startIndex in
            let endIndex = min(startIndex + appsPerPage, items.count)
            return Array(items[startIndex..<endIndex])
        }
    }

    public init() {
        hiddenAppPaths = Self.loadHiddenPaths()
    }

    public func moveItem(from source: LaunchpadItem, to destination: LaunchpadItem) {
        guard
            let sourceIndex = items.firstIndex(of: source),
            let destinationIndex = items.firstIndex(of: destination),
            sourceIndex != destinationIndex
        else {
            return
        }

        let targetOffset = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        items.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetOffset)
        saveLayout()
    }

    public func moveItemToEnd(_ item: LaunchpadItem) {
        guard let index = items.firstIndex(of: item) else {
            return
        }

        guard index != items.count - 1 else {
            return
        }

        let removed = items.remove(at: index)
        items.append(removed)
        saveLayout()
    }

    public func moveAppInsideFolder(folderID: UUID, from sourceApp: AppInfo, to destApp: AppInfo) {
        guard let folderIndex = items.firstIndex(where: { item in
            guard case .folder(let id, _, _) = item else {
                return false
            }

            return id == folderID
        }) else {
            return
        }

        guard case .folder(_, let name, var apps) = items[folderIndex] else {
            return
        }

        guard
            let sourceIndex = apps.firstIndex(of: sourceApp),
            let destinationIndex = apps.firstIndex(of: destApp),
            sourceIndex != destinationIndex
        else {
            return
        }

        let targetOffset = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        apps.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetOffset)
        items[folderIndex] = .folder(id: folderID, name: name, apps: apps)
        saveLayout()
    }

    public func extractAppFromFolder(folderID: UUID, appID: UUID) -> AppInfo? {
        guard let folderIndex = items.firstIndex(where: { item in
            guard case .folder(let id, _, _) = item else {
                return false
            }

            return id == folderID
        }) else {
            return nil
        }

        guard case .folder(_, let name, var apps) = items[folderIndex] else {
            return nil
        }

        guard let appIndex = apps.firstIndex(where: { $0.id == appID }) else {
            return nil
        }

        let extractedApp = apps.remove(at: appIndex)
        let extractedItem = LaunchpadItem.app(extractedApp)

        switch apps.count {
        case 0:
            items.remove(at: folderIndex)
            items.insert(extractedItem, at: min(folderIndex, items.count))
        case 1:
            items[folderIndex] = .app(apps[0])
            items.insert(extractedItem, at: min(folderIndex + 1, items.count))
        default:
            items[folderIndex] = .folder(id: folderID, name: name, apps: apps)
            items.insert(extractedItem, at: min(folderIndex + 1, items.count))
        }

        saveLayout()
        return extractedApp
    }

    public func mergeItem(_ source: LaunchpadItem, into target: LaunchpadItem) {
        guard source != target, let sourceIndex = items.firstIndex(of: source) else {
            return
        }

        let sourceApps = apps(from: source)
        guard !sourceApps.isEmpty else {
            return
        }

        items.remove(at: sourceIndex)

        guard let targetIndex = items.firstIndex(of: target) else {
            return
        }

        switch items[targetIndex] {
        case .app(let targetApp):
            items[targetIndex] = .folder(
                id: UUID(),
                name: "新建文件夹",
                apps: [targetApp] + sourceApps
            )
        case .folder(let id, let name, let existingApps):
            items[targetIndex] = .folder(
                id: id,
                name: name,
                apps: existingApps + sourceApps
            )
        }

        saveLayout()
    }

    public func renameFolder(id: UUID, newName: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard case .folder(_, _, let apps) = items[index] else {
            return
        }

        items[index] = .folder(
            id: id,
            name: newName,
            apps: apps
        )
        saveLayout()
    }

    public func clearDragState() {
        draggedItem = nil
    }

    public func hideApp(_ app: AppInfo) {
        hiddenAppPaths.insert(app.path)
        saveHiddenPaths()
        removeAppFromItems(appID: app.id)
        saveLayout()
    }

    public func uninstallApp(_ app: AppInfo) {
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.recycle([url]) { [weak self] trashedURLs, error in
            DispatchQueue.main.async {
                guard let self, error == nil, !trashedURLs.isEmpty else {
                    return
                }

                self.removeAppFromItems(appID: app.id)
                self.saveLayout()
            }
        }
    }

    public func restoreHiddenApps() {
        hiddenAppPaths.removeAll()
        saveHiddenPaths()
        fetchApps()
    }

    private func removeAppFromItems(appID: UUID) {
        for (index, item) in items.enumerated() {
            switch item {
            case .app(let a) where a.id == appID:
                items.remove(at: index)
                return
            case .folder(let id, let name, let apps):
                let filtered = apps.filter { $0.id != appID }
                if filtered.count != apps.count {
                    if filtered.isEmpty {
                        items.remove(at: index)
                    } else if filtered.count == 1 {
                        items[index] = .app(filtered[0])
                    } else {
                        items[index] = .folder(id: id, name: name, apps: filtered)
                    }
                    return
                }
            default:
                break
            }
        }
    }

    public func saveLayout() {
        let storedItems = Self.storedItems(from: items)
        let fileURL = Self.layoutFileURL

        DispatchQueue.global(qos: .utility).async {
            do {
                try Self.ensureLayoutDirectoryExists(for: fileURL)

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                let data = try encoder.encode(storedItems)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Ignore persistence failures and keep the in-memory layout usable.
            }
        }
    }

    public func fetchApps() {
        let currentHiddenPaths = hiddenAppPaths
        Task(priority: .userInitiated) {
            let syncResult = await Task.detached(priority: .userInitiated) {
                Self.buildSyncedLayout(hiddenPaths: currentHiddenPaths)
            }.value

            let workspace = NSWorkspace.shared
            items = Self.launchpadItems(
                from: syncResult.items,
                discoveredApps: syncResult.discoveredApps,
                workspace: workspace
            )
            saveLayout()
        }
    }

    private struct DiscoveredApp: Sendable {
        let name: String
        let path: String
    }

    private struct StoredAppInfo: Codable, Sendable {
        let id: UUID
        let name: String
        let path: String
    }

    private enum StoredLaunchpadItem: Codable, Sendable {
        case app(StoredAppInfo)
        case folder(id: UUID, name: String, apps: [StoredAppInfo])

        private enum CodingKeys: String, CodingKey {
            case type
            case app
            case id
            case name
            case apps
        }

        private enum ItemType: String, Codable {
            case app
            case folder
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ItemType.self, forKey: .type)

            switch type {
            case .app:
                self = .app(try container.decode(StoredAppInfo.self, forKey: .app))
            case .folder:
                self = .folder(
                    id: try container.decode(UUID.self, forKey: .id),
                    name: try container.decode(String.self, forKey: .name),
                    apps: try container.decode([StoredAppInfo].self, forKey: .apps)
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .app(let app):
                try container.encode(ItemType.app, forKey: .type)
                try container.encode(app, forKey: .app)
            case .folder(let id, let name, let apps):
                try container.encode(ItemType.folder, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(apps, forKey: .apps)
            }
        }
    }

    private struct LayoutSyncResult: Sendable {
        let items: [StoredLaunchpadItem]
        let discoveredApps: [DiscoveredApp]
    }

    private func apps(from item: LaunchpadItem) -> [AppInfo] {
        switch item {
        case .app(let app):
            return [app]
        case .folder(_, _, let apps):
            return apps
        }
    }

    nonisolated private static var hiddenPathsFileURL: URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupportURL.appendingPathComponent("MyLaunchpad_HiddenApps.json", isDirectory: false)
    }

    private func saveHiddenPaths() {
        let paths = hiddenAppPaths
        let fileURL = Self.hiddenPathsFileURL

        DispatchQueue.global(qos: .utility).async {
            do {
                try Self.ensureLayoutDirectoryExists(for: fileURL)
                let data = try JSONEncoder().encode(Array(paths))
                try data.write(to: fileURL, options: .atomic)
            } catch {}
        }
    }

    nonisolated private static func loadHiddenPaths() -> Set<String> {
        let fileURL = hiddenPathsFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let paths = try JSONDecoder().decode([String].self, from: data)
            return Set(paths)
        } catch {
            return []
        }
    }

    nonisolated private static var layoutFileURL: URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupportURL.appendingPathComponent("MyLaunchpad_Layout.json", isDirectory: false)
    }

    nonisolated private static func ensureLayoutDirectoryExists(for fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    nonisolated private static func buildSyncedLayout(hiddenPaths: Set<String>) -> LayoutSyncResult {
        let allDiscoveredApps = discoverAppMetadata()
        let discoveredApps = allDiscoveredApps.filter { !hiddenPaths.contains($0.path) }
        let installedPaths = Set(discoveredApps.map(\.path))

        guard let storedItems = loadStoredLayout() else {
            let initialItems = discoveredApps.map {
                StoredLaunchpadItem.app(
                    StoredAppInfo(id: UUID(), name: $0.name, path: $0.path)
                )
            }

            return LayoutSyncResult(items: initialItems, discoveredApps: discoveredApps)
        }

        let storedPaths = flattenedPaths(in: storedItems)
        let syncedItems = removingMissingApps(from: storedItems, installedPaths: installedPaths)
        let newItems = discoveredApps
            .filter { !storedPaths.contains($0.path) }
            .map {
                StoredLaunchpadItem.app(
                    StoredAppInfo(id: UUID(), name: $0.name, path: $0.path)
                )
            }

        return LayoutSyncResult(
            items: syncedItems + newItems,
            discoveredApps: discoveredApps
        )
    }

    nonisolated private static func loadStoredLayout() -> [StoredLaunchpadItem]? {
        guard FileManager.default.fileExists(atPath: layoutFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: layoutFileURL)
            return try JSONDecoder().decode([StoredLaunchpadItem].self, from: data)
        } catch {
            return nil
        }
    }

    nonisolated private static func flattenedPaths(in items: [StoredLaunchpadItem]) -> Set<String> {
        Set(items.flatMap { item in
            switch item {
            case .app(let app):
                return [app.path]
            case .folder(_, _, let apps):
                return apps.map(\.path)
            }
        })
    }

    nonisolated private static func removingMissingApps(
        from items: [StoredLaunchpadItem],
        installedPaths: Set<String>
    ) -> [StoredLaunchpadItem] {
        items.compactMap { item in
            switch item {
            case .app(let app):
                guard installedPaths.contains(app.path) else {
                    return nil
                }

                return .app(app)
            case .folder(let id, let name, let apps):
                let filteredApps = apps.filter { installedPaths.contains($0.path) }

                guard !filteredApps.isEmpty else {
                    return nil
                }

                return .folder(id: id, name: name, apps: filteredApps)
            }
        }
    }

    nonisolated private static func launchpadItems(
        from storedItems: [StoredLaunchpadItem],
        discoveredApps: [DiscoveredApp],
        workspace: NSWorkspace
    ) -> [LaunchpadItem] {
        let discoveredAppsByPath = Dictionary(
            uniqueKeysWithValues: discoveredApps.map { ($0.path, $0) }
        )

        return storedItems.compactMap { item in
            switch item {
            case .app(let app):
                guard let hydratedApp = hydratedAppInfo(
                    from: app,
                    discoveredAppsByPath: discoveredAppsByPath,
                    workspace: workspace
                ) else {
                    return nil
                }

                return .app(hydratedApp)
            case .folder(let id, let name, let apps):
                let hydratedApps = apps.compactMap {
                    hydratedAppInfo(
                        from: $0,
                        discoveredAppsByPath: discoveredAppsByPath,
                        workspace: workspace
                    )
                }

                guard !hydratedApps.isEmpty else {
                    return nil
                }

                return .folder(id: id, name: name, apps: hydratedApps)
            }
        }
    }

    nonisolated private static func storedItems(from items: [LaunchpadItem]) -> [StoredLaunchpadItem] {
        items.map { item in
            switch item {
            case .app(let app):
                return .app(
                    StoredAppInfo(id: app.id, name: app.name, path: app.path)
                )
            case .folder(let id, let name, let apps):
                return .folder(
                    id: id,
                    name: name,
                    apps: apps.map {
                        StoredAppInfo(id: $0.id, name: $0.name, path: $0.path)
                    }
                )
            }
        }
    }

    nonisolated private static func hydratedAppInfo(
        from storedApp: StoredAppInfo,
        discoveredAppsByPath: [String: DiscoveredApp],
        workspace: NSWorkspace
    ) -> AppInfo? {
        guard let discoveredApp = discoveredAppsByPath[storedApp.path] else {
            return nil
        }

        return AppInfo(
            id: storedApp.id,
            name: discoveredApp.name,
            path: discoveredApp.path,
            icon: appIcon(forPath: discoveredApp.path, workspace: workspace)
        )
    }

    nonisolated private static func discoverAppMetadata() -> [DiscoveredApp] {
        let fileManager = FileManager.default
        let searchDirectories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]

        var discoveredApps: [DiscoveredApp] = []
        var seenPaths = Set<String>()

        for directoryURL in searchDirectories {
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let appURL as URL in enumerator {
                guard appURL.pathExtension == "app" else {
                    continue
                }

                let standardizedPath = appURL.standardizedFileURL.path
                guard seenPaths.insert(standardizedPath).inserted else {
                    continue
                }

                let appName = appName(for: appURL)
                let appInfo = DiscoveredApp(
                    name: appName,
                    path: standardizedPath
                )

                discoveredApps.append(appInfo)
            }
        }

        discoveredApps.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return discoveredApps
    }

    nonisolated private static func appName(for appURL: URL) -> String {
        if let bundle = Bundle(url: appURL) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !displayName.isEmpty {
                return displayName
            }

            if let bundleName = bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String,
               !bundleName.isEmpty {
                return bundleName
            }
        }

        return FileManager.default
            .displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    nonisolated private static func appIcon(forPath path: String, workspace: NSWorkspace) -> NSImage {
        let icon = (workspace.icon(forFile: path).copy() as? NSImage) ?? workspace.icon(forFile: path)
        icon.size = NSSize(width: 256, height: 256)
        return icon
    }
}
