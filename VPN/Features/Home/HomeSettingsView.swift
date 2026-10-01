import SwiftUI
import UIKit

struct HomeSettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.ru
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.panelDetentMode") private var panelDetentMode = VPNPanelDetentMode.stepped
    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic
    @AppStorage(VPNHomeChrome.storageKey) private var homeChrome = VPNHomeChrome.island
    @AppStorage("velvet.autoConnect") private var autoConnect = false
    @AppStorage("velvet.connectLastLocation") private var connectLastLocation = true
    @AppStorage("velvet.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("velvet.killSwitch") private var killSwitch = false
    @AppStorage("velvet.pingBeforeConnect") private var pingBeforeConnect = true
    @AppStorage("velvet.defaultUserJob") private var defaultUserJobRaw = VPNUserJob.streaming.rawValue
    @AppStorage("velvet.logLevel") private var logLevel = "Info"

    @Bindable var providerStore: VPNProviderStore
#if DEBUG
    var devRuntime: VPNDevRuntime? = nil
#endif

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showsDNS = false
    @State private var showsRouting = false
    @State private var showsLogs = false
    @State private var importMessage: String?
    @State private var showsResetConfirmation = false
    @State private var showsClearRecentConfirmation = false

    var onImportFromClipboard: ((VPNProvider) -> Void)?

    private var defaultUserJob: Binding<VPNUserJob> {
        Binding(
            get: { VPNUserJob(rawValue: defaultUserJobRaw) ?? .streaming },
            set: { defaultUserJobRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
#if DEBUG
                if let devRuntime {
                    Section {
                        NavigationLink(ui("Developer panel")) {
                            VPNDevPanelView(
                                providerStore: providerStore,
                                runtime: devRuntime
                            )
                        }
                    } header: {
                        Text(ui("Developer"))
                    } footer: {
                        Text(ui("Prototype states, demo scenarios, and debug flags."))
                    }
                }
#endif

                Section {
                    Picker(ui("Language"), selection: $appLanguage) {
                        Text(verbatim: "English").tag(AppLanguage.en)
                        Text(verbatim: "Русский").tag(AppLanguage.ru)
                    }
                }

                Section {
                    Toggle(ui("Auto-connect on launch"), isOn: $autoConnect)
                    Toggle(ui("Connect to last location"), isOn: $connectLastLocation)
                    Toggle(ui("Notifications"), isOn: $notificationsEnabled)
                    VPNConfirmedToggle(
                        title: ui("Kill switch"),
                        isOn: $killSwitch,
                        confirmation: VPNSettingsConfirmations.killSwitch
                    )
                } header: {
                    Text(ui("Connection"))
                } footer: {
                    Text(ui("Kill switch blocks internet access if the VPN disconnects unexpectedly."))
                }

                Section(ui("Networks")) {
                    Picker(ui("Default task on launch"), selection: defaultUserJob) {
                        ForEach(VPNUserJob.jobs(in: .everydayTasks) + VPNUserJob.jobs(in: .restrictedNetwork)) { job in
                            Text(job.title).tag(job)
                        }
                    }
                    Toggle(ui("Ping before connect"), isOn: $pingBeforeConnect)

                    Button(ui("Import from clipboard")) {
                        importFromClipboard()
                    }
                }

                Section(ui("DNS")) {
                    Button(ui("DNS settings")) { showsDNS = true }
                }

                Section(ui("Routing")) {
                    Button(ui("Routing rules")) { showsRouting = true }
                }

                Section {
                    Picker(ui("Log level"), selection: $logLevel) {
                        Text(ui("Info")).tag("Info")
                        Text(ui("Debug")).tag("Debug")
                        Text(ui("Verbose")).tag("Verbose")
                    }
                    Button(ui("View logs")) { showsLogs = true }
                    Button(ui("Clear recent locations")) {
                        showsClearRecentConfirmation = true
                    }
                    Button(ui("Reset all settings"), role: .destructive) {
                        showsResetConfirmation = true
                    }
                } header: {
                    Text(ui("Advanced"))
                }

                Section {
                    Picker(ui("Home"), selection: $homeChrome) {
                        ForEach(VPNHomeChrome.allCases) { chrome in
                            Text(chrome.title).tag(chrome)
                        }
                    }
                    Picker(ui("Home layout"), selection: $homeFormat) {
                        ForEach(VPNHomeFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                } header: {
                    Text(ui("Layout"))
                } footer: {
                    Text(ui("Island opens with a swipe. One page, Dashboard, and Bottom menu put a name on every action."))
                }

                if homeChrome == .island || homeChrome == .islandMenu {
                    Section {
                        if homeFormat == .classic {
                            Picker(ui("Panel"), selection: $panelStyle) {
                                ForEach(VPNPanelStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                        }

                        Picker(ui("Detent behavior"), selection: $panelDetentMode) {
                            ForEach(VPNPanelDetentMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    } header: {
                        Text(ui("Bottom panel"))
                    } footer: {
                        Text(panelDetentMode.subtitle)
                    }
                }

                Section(ui("About")) {
                    LabeledContent(ui("Version"), value: "1.0")
                    LabeledContent(ui("VPN engine"), value: ui("Velvet Core (demo)"))
                    LabeledContent(ui("Protocols"), value: "VLESS, VMess, Trojan, Shadowsocks")
                    Button(ui("Privacy policy")) {
                        openURL(URL(string: "https://velvet.vpn/privacy")!)
                    }
                    Button(ui("Terms of use")) {
                        openURL(URL(string: "https://velvet.vpn/terms")!)
                    }
                }
            }
            .navigationTitle(ui("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ui("Done")) { dismiss() }
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
            .alert(ui("Import"), isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button(ui("OK"), role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
            .confirmationDialog(ui("Reset all settings?"),
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(ui("Reset Settings"), role: .destructive) {
                    resetSettings()
                }
                Button(ui("Cancel"), role: .cancel) {}
            } message: {
                Text(ui("This restores connection, routing, and layout preferences to their defaults on this device."))
            }
            .confirmationDialog(ui("Clear recent locations?"),
                isPresented: $showsClearRecentConfirmation,
                titleVisibility: .visible
            ) {
                Button(ui("Clear"), role: .destructive) {
                    VPNRecentLocationsStore.clear()
                }
                Button(ui("Cancel"), role: .cancel) {}
            } message: {
                Text(ui("Recently used servers will be removed from the quick list."))
            }
        }
    }

    private func importFromClipboard() {
        guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty else {
            importMessage = ui("Clipboard is empty.")
            return
        }

        guard clipboard.lowercased().hasPrefix("http") else {
            importMessage = ui("No subscription URL found on clipboard.")
            return
        }

        switch providerStore.importFromURL(clipboard) {
        case let .success(provider):
            onImportFromClipboard?(provider)
            importMessage = uiFormat("%@ added from clipboard.", provider.name)
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
