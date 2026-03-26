//
//  SettingsView.swift
//  MyLaunchpad
//
//  Created by yuchen on 2026/3/26.
//

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var appManager: AppManager

    var body: some View {
        TabView {
            GeneralTab(appManager: appManager)
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            HiddenAppsTab(appManager: appManager)
                .tabItem {
                    Label("隐藏管理", systemImage: "eye.slash")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    var appManager: AppManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, _ in
                        do {
                            if SMAppService.mainApp.status == .enabled {
                                try SMAppService.mainApp.unregister()
                            } else {
                                try SMAppService.mainApp.register()
                            }
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section {
                Button("重置所有布局") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)
            } footer: {
                Text("将所有应用恢复为默认的字母排序布局，文件夹将被解散。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .alert("确定要重置所有布局吗？", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                appManager.resetLayout()
            }
        } message: {
            Text("此操作将清除所有自定义排序和文件夹，恢复为默认的字母排序。")
        }
    }
}

// MARK: - Hidden Apps Tab

private struct HiddenAppsTab: View {
    var appManager: AppManager

    var body: some View {
        Group {
            if appManager.hiddenApps.isEmpty {
                ContentUnavailableView(
                    "这里静悄悄的",
                    systemImage: "eye",
                    description: Text("没有隐藏任何应用。\n在启动台中按住 Option 键进入编辑模式，点击 \"-\" 按钮即可隐藏应用。")
                )
            } else {
                List {
                    Section {
                        Button {
                            appManager.restoreHiddenApps()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("恢复所有隐藏的应用")
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    Section {
                        ForEach(appManager.hiddenApps, id: \.path) { app in
                            HStack(spacing: 12) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)

                                Text(app.name)
                                    .lineLimit(1)

                                Spacer()

                                Button("恢复显示") {
                                    appManager.unhideApp(at: app.path)
                                }
                                .controlSize(.small)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}
