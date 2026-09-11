import SwiftUI

struct VPNConnectionInfoView: View {
    let resolvedConnection: VPNResolvedConnection?
    let connectedAt: Date?
    let mockPublicIP: String
    var regionLabel: String = "—"
    var pingMs: Int = 0
    var downloadRate: String = "0 KB/s"
    var uploadRate: String = "0 KB/s"
    var usageFraction: Double = 0
    var sessionDataUsedText: String = "0 MB this session"
    var providerMessage: String?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("velvet.killSwitch") private var killSwitch = false

    @State private var showsHandshakeInfo = false

    private var durationText: String {
        guard let connectedAt else { return "—" }
        let interval = Int(Date.now.timeIntervalSince(connectedAt))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var sessionUsageText: String {
        sessionDataUsedText.replacingOccurrences(of: " this session", with: "")
    }

    private var sessionLocationText: String {
        guard let resolvedConnection else { return "—" }
        return "\(resolvedConnection.location.city), \(resolvedConnection.location.name)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ConnectionStatsStrip(
                        regionLabel: regionLabel,
                        pingMs: pingMs,
                        downloadRate: downloadRate,
                        uploadRate: uploadRate,
                        usageFraction: usageFraction,
                        sessionDataUsedText: sessionDataUsedText,
                        showsBackground: false,
                        usesContentPadding: false,
                        progressTint: .primary
                    )
                    .padding(.vertical, 4)
                }

                if let providerMessage, !providerMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text(providerMessage)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("Session") {
                    LabeledContent("Status", value: resolvedConnection == nil ? "Disconnected" : "Connected")
                    LabeledContent("Duration", value: durationText)
                    LabeledContent("Location", value: sessionLocationText)
                    LabeledContent("IP address", value: mockPublicIP)
                    LabeledContent("Session usage", value: sessionUsageText)
                    LabeledContent("Ping", value: resolvedConnection == nil ? "—" : "\(pingMs) ms")
                }

                if resolvedConnection != nil {
                    Section("Route") {
                        LabeledContent("Provider", value: resolvedConnection?.provider.name ?? "—")
                        LabeledContent("Protocol", value: VPNConnectionRouteDetails.protocolLabel)
                        LabeledContent("Server", value: resolvedConnection.map(VPNConnectionRouteDetails.serverID(for:)) ?? "—")
                        LabeledContent("Port", value: VPNConnectionRouteDetails.portLabel)
                        LabeledContent("Encryption", value: VPNConnectionRouteDetails.encryptionLabel)
                        LabeledContent("DNS", value: VPNConnectionRouteDetails.dnsLabel)

                        Button {
                            showsHandshakeInfo = true
                        } label: {
                            HStack {
                                Text("Handshake")
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Text(VPNConnectionRouteDetails.handshakeLabel(since: connectedAt))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        VPNConfirmedToggle(
                            title: "Kill Switch",
                            isOn: $killSwitch,
                            confirmation: VPNSettingsConfirmations.killSwitch
                        )
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Connection info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Handshake", isPresented: $showsHandshakeInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("WireGuard last rekeyed \(VPNConnectionRouteDetails.handshakeLabel(since: connectedAt).lowercased()).")
            }
        }
    }
}

enum VPNConnectionRouteDetails {
    static let protocolLabel = "WireGuard"
    static let portLabel = "51820"
    static let encryptionLabel = "AES-256-GCM"
    static let dnsLabel = "10.8.8.1"

    static func serverID(for connection: VPNResolvedConnection) -> String {
        let country = connection.location.name
            .split(separator: " ")
            .first?
            .prefix(2)
            .lowercased() ?? "nl"
        let city = connection.location.city
            .split(separator: " ")
            .first?
            .prefix(3)
            .lowercased() ?? "ams"
        return "\(country)-\(city)-wg-301"
    }

    static func handshakeLabel(since connectedAt: Date?) -> String {
        guard let connectedAt else { return "—" }
        let minutes = max(1, Int(Date.now.timeIntervalSince(connectedAt) / 60) % 5 + 1)
        return "\(minutes) min ago"
    }
}
