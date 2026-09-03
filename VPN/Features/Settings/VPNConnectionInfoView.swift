import SwiftUI

struct VPNConnectionInfoView: View {
    let resolvedConnection: VPNResolvedConnection?
    let connectedAt: Date?
    let mockPublicIP: String

    @Environment(\.dismiss) private var dismiss

    private var durationText: String {
        guard let connectedAt else { return "—" }
        let interval = Int(Date.now.timeIntervalSince(connectedAt))
        let minutes = interval / 60
        let seconds = interval % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    LabeledContent("Status", value: resolvedConnection == nil ? "Disconnected" : "Protected")
                    LabeledContent("Duration", value: durationText)
                    LabeledContent("Your IP", value: mockPublicIP)
                }

                if let resolvedConnection {
                    Section("Route") {
                        LabeledContent("Provider", value: resolvedConnection.provider.name)
                        LabeledContent("Location", value: "\(resolvedConnection.location.flag) \(resolvedConnection.location.city)")
                        LabeledContent("Server", value: resolvedConnection.location.name)
                        LabeledContent("Latency", value: resolvedConnection.location.pingLabel)
                        LabeledContent("Protocol", value: "VLESS · TLS")
                    }

                    Section("Selection") {
                        LabeledContent("Mode", value: VPNSelectionSummary.selectionLabel(for: resolvedConnection.selection))
                        LabeledContent(
                            "Scope",
                            value: VPNSelectionSummary.scopeLabel(
                                for: resolvedConnection.selection.scope,
                                providers: [resolvedConnection.provider]
                            )
                        )
                    }
                }
            }
            .navigationTitle("Connection info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
