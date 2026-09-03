import SwiftUI

struct ConnectionSummaryView: View {
    let connectionState: VPNConnectionState
    let homeFormat: VPNHomeFormat
    let selectedLocation: VPNLocation
    let resolvedConnection: VPNResolvedConnection?
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: connectionState == .connected ? "lock.shield.fill" : "shield")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(connectionState == .connected ? Color.green : Color.primary.opacity(0.72))
                .contentTransition(.symbolEffect(.replace))

            Text(title)
                .font(.title3.weight(.semibold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch connectionState {
        case .connecting:
            homeFormat == .networksAndLocations ? "Finding best connection…" : "Connecting…"
        case .connected:
            "Protected"
        case .disconnected:
            "Ready to connect"
        }
    }

    private var subtitle: String {
        if connectionState == .connected,
           let resolvedConnection,
           homeFormat == .networksAndLocations {
            return resolvedConnection.summarySubtitle
        }

        if homeFormat == .networksAndLocations {
            let quality = VPNConnectionPlanner.qualityLabel(for: .auto, providers: VPNProvider.samples)
            return "\(quality) · Smart-Auto across all networks"
        }

        return selectedLocation.name
    }
}
