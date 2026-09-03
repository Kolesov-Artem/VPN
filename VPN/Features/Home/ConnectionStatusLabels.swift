import SwiftUI

/// Compact two-line connection copy for the collapsed island header.
struct ConnectionStatusLabels: View {
    let connectionState: VPNConnectionState
    var homeFormat: VPNHomeFormat = .classic
    let selectedLocation: VPNLocation
    var locationSelection: VPNLocationSelection = .smartAuto(scope: .allNetworks)
    var providers: [VPNProvider] = []
    var resolvedConnection: VPNResolvedConnection?
    var isSwitchingServer: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { labels }
                    .buttonStyle(.plain)
            } else {
                labels
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.interpolate)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var title: String {
        VPNSelectionSummary.heroTitle(
            connectionState: connectionState,
            homeFormat: homeFormat,
            isSwitchingServer: isSwitchingServer
        )
    }

    private var subtitle: String {
        VPNSelectionSummary.subtitle(
            selection: locationSelection,
            providers: providers,
            connectionState: connectionState,
            resolvedConnection: resolvedConnection,
            homeFormat: homeFormat,
            selectedLocation: selectedLocation,
            isSwitchingServer: isSwitchingServer
        )
    }
}
