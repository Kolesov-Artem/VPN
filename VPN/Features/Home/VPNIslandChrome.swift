import SwiftUI

// MARK: - Provider branding

struct VPNProviderBrandIcon: View {
    let provider: VPNProvider
    var size: CGFloat = VelvetMetrics.islandProviderIconSize

    private var gradientColors: [Color] {
        if provider.kind == .velvetFeatured {
            [VelvetTheme.softPurple, VelvetTheme.accent]
        } else {
            [
                VelvetTheme.providerAccent.opacity(0.55),
                VelvetTheme.providerAccent,
            ]
        }
    }

    private var iconFont: Font {
        if size <= VelvetMetrics.listIconSlot {
            .caption.weight(.semibold)
        } else {
            .body.weight(.semibold)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: provider.iconSymbol)
                .font(iconFont)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct VPNProviderBrandLogo: View {
    let provider: VPNProvider
    var size: CGFloat = VelvetMetrics.islandProviderIconSize

    var body: some View {
        Group {
            if let assetName = VPNBrandCatalog.bundledAssetName(for: provider) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else if let logoURL = VPNBrandCatalog.remoteLogoURL(for: provider) {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        VPNProviderBrandIcon(provider: provider, size: size)
                    @unknown default:
                        VPNProviderBrandIcon(provider: provider, size: size)
                    }
                }
            } else {
                VPNProviderBrandIcon(provider: provider, size: size)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.systemBackground), in: Circle())
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        }
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

struct VPNProviderIconStack: View {
    let providers: [VPNProvider]
    var maxVisible: Int = 3

    private var overflowCount: Int {
        max(0, providers.count - maxVisible)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: -12) {
                ForEach(Array(providers.prefix(maxVisible).enumerated()), id: \.element.id) { index, provider in
                    VPNProviderBrandLogo(provider: provider)
                        .overlay {
                            Circle()
                                .strokeBorder(VelvetTheme.contentSurface, lineWidth: 2)
                        }
                        .zIndex(Double(maxVisible - index))
                }
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                    .offset(x: 6, y: -4)
            }
        }
        .accessibilityHidden(true)
    }
}

struct VPNIslandCollapsedHeader: View {
    let provider: VPNProvider
    let title: String
    let subtitle: String
    var providers: [VPNProvider] = []
    var showsMultiProviderSummary: Bool = false
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
            if showsMultiProviderSummary {
                VPNProviderIconStack(providers: providers)
            } else {
                VPNProviderBrandLogo(provider: provider)
            }

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
    var size: ControlSize = .large
    var usesErrorTint = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if connectionState == .connecting {
                        ProgressView()
                            .controlSize(size)
                            .tint(.white)
                    } else {
                        Image(systemName: "power")
                            .font(size == .large ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                    }
                }
                .contentTransition(.symbolEffect(.replace))

                Text(title)
                    .font(size == .large ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                    .contentTransition(.interpolate)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: VelvetMetrics.primaryButtonHeight)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous))
            .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
        }
        .buttonStyle(PressScaleButtonStyle())
        .controlSize(size)
        .disabled(connectionState == .connecting)
        .sensoryFeedback(.success, trigger: connectionState) { _, new in
            new.isConnected
        }
        .sensoryFeedback(.error, trigger: connectionState) { _, new in
            new.isFailed
        }
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
            usesErrorTint ? VelvetTheme.errorTint : VelvetTheme.accent
        default:
            VelvetTheme.accent
        }
    }
}
