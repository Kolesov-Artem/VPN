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
                        title: ui("Route all traffic through VPN"),
                        isOn: routesAllTrafficBinding,
                        confirmation: VPNSettingsConfirmations.routeAllTraffic
                    )
                    Toggle(ui("Bypass local networks"), isOn: bypassLocalNetworksBinding)
                } header: {
                    Text(ui("Mode"))
                } footer: {
                    Text(ui("Bypass keeps local printers and home devices reachable while the VPN is active."))
                }

                Section {
                    ForEach(VPNRoutingDomainRule.samples) { rule in
                        LabeledContent(rule.domain, value: ui(rule.action))
                    }
                } header: {
                    Text(ui("Domain rules"))
                } footer: {
                    Text(ui("Sample rules are read-only in this prototype."))
                }

                Section {
                    Button(ui("Reset to default"), role: .destructive) {
                        showsResetConfirmation = true
                    }
                }
            }
            .navigationTitle(ui("Routing"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ui("Done")) { dismiss() }
                }
            }
            .confirmationDialog(ui("Reset routing rules?"),
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(ui("Reset"), role: .destructive) {
                    routesAllTraffic = true
                    bypassLocalNetworks = true
                    VPNRoutingPreferences.routesAllTraffic = true
                    VPNRoutingPreferences.bypassLocalNetworks = true
                }
                Button(ui("Cancel"), role: .cancel) {}
            } message: {
                Text(ui("All traffic will go through the VPN again and local network bypass will be turned on."))
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
