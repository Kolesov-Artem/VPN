import SwiftUI

enum VPNDNSMode: String, CaseIterable, Identifiable {
    case automatic
    case cloudflare
    case google
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .cloudflare: "Cloudflare"
        case .google: "Google"
        case .custom: "Custom"
        }
    }

    var servers: String {
        switch self {
        case .automatic: "Provider default"
        case .cloudflare: "1.1.1.1 · 1.0.0.1"
        case .google: "8.8.8.8 · 8.8.4.4"
        case .custom: "Not configured"
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
                    Picker("DNS mode", selection: dnsMode) {
                        ForEach(VPNDNSMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    LabeledContent("Servers", value: dnsMode.wrappedValue.servers)
                } footer: {
                    Text("DNS settings are stored locally in this prototype. No resolver changes are applied.")
                }

                Section("Custom DNS") {
                    TextField("Primary DNS", text: .constant(""))
                        .disabled(dnsMode.wrappedValue != .custom)
                    TextField("Secondary DNS", text: .constant(""))
                        .disabled(dnsMode.wrappedValue != .custom)
                }
            }
            .navigationTitle("DNS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
