import SwiftUI

enum VPNDNSMode: String, CaseIterable, Identifiable {
    case automatic
    case cloudflare
    case google
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: ui("Automatic")
        case .cloudflare: "Cloudflare"
        case .google: "Google"
        case .custom: ui("Custom")
        }
    }

    var servers: String {
        switch self {
        case .automatic: ui("Provider default")
        case .cloudflare: "1.1.1.1 · 1.0.0.1"
        case .google: "8.8.8.8 · 8.8.4.4"
        case .custom: ui("Not configured")
        }
    }
}

struct VPNDNSSettingsView: View {
    @AppStorage("velvet.dnsMode") private var dnsModeRaw = VPNDNSMode.automatic.rawValue
    @Environment(\.dismiss) private var dismiss

    private var dnsMode: Binding<VPNDNSMode> {
        Binding(
            get: { VPNDNSMode(rawValue: dnsModeRaw) ?? .automatic },
            set: { dnsModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(ui("DNS mode"), selection: dnsMode) {
                        ForEach(VPNDNSMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    LabeledContent(ui("Servers"), value: dnsMode.wrappedValue.servers)
                } footer: {
                    Text(ui("DNS settings are stored locally in this prototype. No resolver changes are applied."))
                }

                Section(ui("Custom DNS")) {
                    TextField(ui("Primary DNS"), text: .constant(""))
                        .disabled(dnsMode.wrappedValue != .custom)
                    TextField(ui("Secondary DNS"), text: .constant(""))
                        .disabled(dnsMode.wrappedValue != .custom)
                }
            }
            .navigationTitle(ui("DNS"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ui("Done")) { dismiss() }
                }
            }
        }
    }
}
