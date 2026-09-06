import SwiftUI

// MARK: - Provider branding

struct VPNProviderBrandIcon: View {
    let provider: VPNProvider

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            VelvetTheme.softPurple,
                            VelvetTheme.accent,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: provider.iconSymbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: VelvetMetrics.islandProviderIconSize, height: VelvetMetrics.islandProviderIconSize)
        .accessibilityHidden(true)
    }
}

// MARK: - Island chrome controls

struct VPNIslandChromeButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: VelvetMetrics.islandChromeButtonSize, height: VelvetMetrics.islandChromeButtonSize)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

struct VPNUseCasePresetsMenu: View {
    let activeChoice: VPNUseCaseMenuChoice?
    let onSelect: (VPNUseCaseMenuChoice) -> Void

    var body: some View {
        Menu {
            ForEach(VPNUseCaseMenuChoice.allCases) { choice in
                Button {
                    onSelect(choice)
                } label: {
                    if activeChoice == choice {
                        Label(choice.title, systemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.body)
                Text(activeChoice?.panelLabel ?? VPNUseCaseMenuChoice.smart.panelLabel)
                    .font(.body)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: VelvetMetrics.islandChromeButtonSize)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .accessibilityLabel("Connection preset, \(activeChoice?.title ?? VPNUseCaseMenuChoice.smart.title)")
    }
}

struct VPNIslandCollapsedHeader: View {
    let provider: VPNProvider
    let title: String
    let subtitle: String
    var activePreset: VPNUseCaseMenuChoice?
    var onPresetSelected: ((VPNUseCaseMenuChoice) -> Void)?
    var onProviderTap: (() -> Void)?
    let expandSystemName: String
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            providerSummary

            if let onPresetSelected {
                VPNUseCasePresetsMenu(activeChoice: activePreset, onSelect: onPresetSelected)
            }

            VPNIslandChromeButton(systemName: expandSystemName, action: onExpand)
        }
        .padding(8)
    }

    @ViewBuilder
    private var providerSummary: some View {
        let content = HStack(spacing: 12) {
            VPNProviderBrandIcon(provider: provider)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VelvetTheme.mainTextDark)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let onProviderTap {
            Button(action: onProviderTap) { content }
                .buttonStyle(PressScaleButtonStyle())
        } else {
            content
        }
    }
}

// MARK: - Primary connect action

struct VPNPrimaryConnectionButton: View {
    let title: String
    let connectionState: VPNConnectionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if connectionState == .connecting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "power")
                }

                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: VelvetMetrics.primaryButtonHeight)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(connectionState == .connecting)
        .accessibilityHint(
            connectionState == .connected
                ? "Disconnects the demo VPN"
                : "Connects the demo VPN"
        )
    }

    private var backgroundColor: Color {
        switch connectionState {
        case .connected:
            VelvetTheme.connectedTint
        case .failed:
            VelvetTheme.errorTint
        default:
            VelvetTheme.accent
        }
    }
}
