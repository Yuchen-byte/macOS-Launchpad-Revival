//
//  LaunchpadModels.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/25.
//

import Foundation
import AppKit

public struct AppInfo: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let path: String
    public let icon: NSImage

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
    }

    public nonisolated init(id: UUID = UUID(), name: String, path: String, icon: NSImage) {
        self.id = id
        self.name = name
        self.path = path
        self.icon = icon
    }

    public static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        icon = NSImage()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
    }
}

public enum LaunchpadItem: Identifiable, Hashable, Codable {
    case app(AppInfo)
    case folder(id: UUID, name: String, apps: [AppInfo])

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

    public var id: UUID {
        switch self {
        case .app(let app):
            return app.id
        case .folder(let id, _, _):
            return id
        }
    }

    public var name: String {
        switch self {
        case .app(let app):
            return app.name
        case .folder(_, let name, _):
            return name
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)

        switch type {
        case .app:
            let app = try container.decode(AppInfo.self, forKey: .app)
            self = .app(app)
        case .folder:
            let id = try container.decode(UUID.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let apps = try container.decode([AppInfo].self, forKey: .apps)
            self = .folder(id: id, name: name, apps: apps)
        }
    }

    public func encode(to encoder: Encoder) throws {
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
