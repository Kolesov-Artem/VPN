import SwiftUI

struct HomeSettingsView: View {
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic

    @Environment(\.dismiss) private var dismiss
    @State private var connectsAutomatically = true
    @State private var showsNotifications = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    Toggle("Auto-connect", isOn: $connectsAutomatically)
                    Toggle("Notifications", isOn: $showsNotifications)
                }

                Section {
                    Picker("Home layout", selection: $homeFormat) {
                        ForEach(VPNHomeFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                } header: {
                    Text("Panel content")
                } footer: {
                    Text("Networks & locations pings all active providers and picks the best server with one Connect tap.")
                }

                if homeFormat == .classic {
                    Section {
                        Picker("Panel", selection: $panelStyle) {
                            ForEach(VPNPanelStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                    } header: {
                        Text("Bottom panel")
                    } footer: {
                        Text("The island floats above the map. The sheet expands to full screen before the country list scrolls.")
                    }
                }

                Section("Prototype") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("VPN engine", value: "Demo")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
