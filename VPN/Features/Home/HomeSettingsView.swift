import SwiftUI
import UIKit

struct HomeSettingsView: View {
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic
    @AppStorage("velvet.autoConnect") private var autoConnect = false
    @AppStorage("velvet.connectLastLocation") private var connectLastLocation = true
    @AppStorage("velvet.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("velvet.killSwitch") private var killSwitch = false
    @AppStorage("velvet.pingBeforeConnect") private var pingBeforeConnect = true
    @AppStorage("velvet.defaultUserJob") private var defaultUserJobRaw = VPNUserJob.streaming.rawValue
    @AppStorage("velvet.logLevel") private var logLevel = "Info"

    @Bindable var providerStore: VPNProviderStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showsDNS = false
    @State private var showsRouting = false
    @State private var showsLogs = false
    @State private var importMessage: String?

    var onImportFromClipboard: ((String) -> Void)?

    private var defaultUserJob: Binding<VPNUserJob> {
        Binding(
            get: { VPNUserJob(rawValue: defaultUserJobRaw) ?? .streaming },
            set: { defaultUserJobRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-connect on launch", isOn: $autoConnect)
                    Toggle("Connect to last location", isOn: $connectLastLocation)
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    Toggle("Kill switch", isOn: $killSwitch)
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Kill switch is stored for demo purposes. No Network Extension is installed.")
                }

                Section("Networks") {
                    Picker("Default task on launch", selection: defaultUserJob) {
                        ForEach(VPNUserJob.jobs(in: .everydayTasks) + VPNUserJob.jobs(in: .restrictedNetwork)) { job in
                            Text(job.title).tag(job)
                        }
                    }
                    Toggle("Ping before connect", isOn: $pingBeforeConnect)

                    Button("Import from clipboard") {
                        importFromClipboard()
                    }
                }

                Section("DNS") {
                    Button("DNS settings") { showsDNS = true }
                }

                Section("Routing") {
                    Button("Routing rules") { showsRouting = true }
                }

                Section("Advanced") {
                    Picker("Log level", selection: $logLevel) {
                        Text("Info").tag("Info")
                        Text("Debug").tag("Debug")
                        Text("Verbose").tag("Verbose")
                    }
                    Button("View logs") { showsLogs = true }
                    Button("Clear recent locations") {
                        VPNRecentLocationsStore.clear()
                    }
                    Button("Reset all settings", role: .destructive) {
                        resetSettings()
                    }
                }

                Section {
                    Picker("Home layout", selection: $homeFormat) {
                        ForEach(VPNHomeFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                } header: {
                    Text("Layout")
                }

                if homeFormat == .classic {
                    Section("Bottom panel") {
                        Picker("Panel", selection: $panelStyle) {
                            ForEach(VPNPanelStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("VPN engine", value: "Velvet Core (demo)")
                    LabeledContent("Protocols", value: "VLESS, VMess, Trojan, Shadowsocks")
                    Button("Privacy policy") {
                        openURL(URL(string: "https://velvet.vpn/privacy")!)
                    }
                    Button("Terms of use") {
                        openURL(URL(string: "https://velvet.vpn/terms")!)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showsDNS) {
                VPNDNSSettingsView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsRouting) {
                VPNRoutingSettingsView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsLogs) {
                VPNLogsView()
                    .presentationDetents([.medium, .large])
            }
            .alert("Import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private func importFromClipboard() {
        guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty else {
            importMessage = "Clipboard is empty."
            return
        }

        guard clipboard.lowercased().hasPrefix("http") else {
            importMessage = "No subscription URL found on clipboard."
            return
        }

        switch providerStore.importFromURL(clipboard) {
        case let .success(provider):
            onImportFromClipboard?(provider.name)
            importMessage = "\(provider.name) added from clipboard."
        case let .failure(error):
            importMessage = error.localizedDescription
        }
    }

    private func resetSettings() {
        autoConnect = false
        connectLastLocation = true
        notificationsEnabled = true
        killSwitch = false
        pingBeforeConnect = true
        defaultUserJobRaw = VPNUserJob.streaming.rawValue
        logLevel = "Info"
        VPNRoutingPreferences.routesAllTraffic = true
        VPNRoutingPreferences.bypassLocalNetworks = true
        VPNRecentLocationsStore.clear()
        VPNLogsStore.shared.clear()
    }
}
