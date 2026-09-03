import SwiftUI

struct VPNRoutingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var routesAllTraffic = VPNRoutingPreferences.routesAllTraffic
    @State private var bypassLocalNetworks = VPNRoutingPreferences.bypassLocalNetworks

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Toggle("Route all traffic through VPN", isOn: $routesAllTraffic)
                        .onChange(of: routesAllTraffic) { _, value in
                            VPNRoutingPreferences.routesAllTraffic = value
                        }
                    Toggle("Bypass local networks", isOn: $bypassLocalNetworks)
                        .onChange(of: bypassLocalNetworks) { _, value in
                            VPNRoutingPreferences.bypassLocalNetworks = value
                        }
                }

                Section {
                    ForEach(VPNRoutingDomainRule.samples) { rule in
                        LabeledContent(rule.domain, value: rule.action)
                    }
                } header: {
                    Text("Domain rules")
                } footer: {
                    Text("Sample rules are read-only in this prototype.")
                }

                Section {
                    Button("Reset to default") {
                        routesAllTraffic = true
                        bypassLocalNetworks = true
                        VPNRoutingPreferences.routesAllTraffic = true
                        VPNRoutingPreferences.bypassLocalNetworks = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Routing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
