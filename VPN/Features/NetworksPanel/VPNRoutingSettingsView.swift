import SwiftUI

struct VPNRoutingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var routesAllTraffic = VPNRoutingPreferences.routesAllTraffic
    @State private var bypassLocalNetworks = VPNRoutingPreferences.bypassLocalNetworks
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VPNConfirmedToggle(
                        title: "Route all traffic through VPN",
                        isOn: routesAllTrafficBinding,
                        confirmation: VPNSettingsConfirmations.routeAllTraffic
                    )
                    Toggle("Bypass local networks", isOn: bypassLocalNetworksBinding)
                } header: {
                    Text("Mode")
                } footer: {
                    Text("Bypass keeps local printers and home devices reachable while the VPN is active.")
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
                    Button("Reset to default", role: .destructive) {
                        showsResetConfirmation = true
                    }
                }
            }
            .navigationTitle("Routing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset routing rules?",
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    routesAllTraffic = true
                    bypassLocalNetworks = true
                    VPNRoutingPreferences.routesAllTraffic = true
                    VPNRoutingPreferences.bypassLocalNetworks = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All traffic will go through the VPN again and local network bypass will be turned on.")
            }
        }
    }

    private var routesAllTrafficBinding: Binding<Bool> {
        Binding(
            get: { routesAllTraffic },
            set: { newValue in
                routesAllTraffic = newValue
                VPNRoutingPreferences.routesAllTraffic = newValue
            }
        )
    }

    private var bypassLocalNetworksBinding: Binding<Bool> {
        Binding(
            get: { bypassLocalNetworks },
            set: { newValue in
                bypassLocalNetworks = newValue
                VPNRoutingPreferences.bypassLocalNetworks = newValue
            }
        )
    }
}
