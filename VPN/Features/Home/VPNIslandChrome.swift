import SwiftUI

// MARK: - Provider branding

struct VPNProviderBrandIcon: View {
    let provider: VPNProvider
    var size: CGFloat = VelvetMetrics.islandProviderIconSize
    /// Collapsed subscription chooser uses ink instead of the purple mark.
    var usesInkMark: Bool = false

    private var usesVelvetMark: Bool {
        provider.kind == .velvetFeatured || provider.name.contains("Velvet")
    }

    private var gradientColors: [Color] {
        if provider.status == .expired {
            [Color(red: 1, green: 0.45, blue: 0.42), VelvetTheme.errorTint]
        } else if usesInkMark || usesVelvetMark {
            usesInkMark
                ? [Color.black, Color.black]
                : [VelvetTheme.softPurple, VelvetTheme.accent]
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

            if provider.status == .expired {
                Text("V")
                    .font(iconFont)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: provider.iconSymbol)
                    .font(iconFont)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct VPNProviderBrandLogo: View {
    let provider: VPNProvider
    var size: CGFloat = VelvetMetrics.islandProviderIconSize
    var usesInkMark: Bool = false

    var body: some View {
        Group {
            if usesInkMark {
                VPNProviderBrandIcon(provider: provider, size: size, usesInkMark: true)
            } else if let assetName = VPNBrandCatalog.bundledAssetName(for: provider) {
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
                        VPNProviderBrandIcon(provider: provider, size: size, usesInkMark: usesInkMark)
                    @unknown default:
                        VPNProviderBrandIcon(provider: provider, size: size, usesInkMark: usesInkMark)
                    }
                }
            } else {
                VPNProviderBrandIcon(provider: provider, size: size, usesInkMark: usesInkMark)
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
    var usesInkMark: Bool = false

    private var overflowCount: Int {
        max(0, providers.count - maxVisible)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: -12) {
                ForEach(Array(providers.prefix(maxVisible).enumerated()), id: \.element.id) { index, provider in
                    VPNProviderBrandLogo(provider: provider, usesInkMark: usesInkMark)
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

struct VPNActiveProviderPickerPill: View {
    let providerName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Self.pickerLabel(providerName)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Active VPN, \(providerName)")
    }

    static func pickerLabel(_ providerName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.up.chevron.down")
                .font(.body)
            Text(providerName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(Color.primary)
        .tint(.primary)
        .padding(.horizontal, 14)
        .frame(height: VelvetMetrics.islandChromeButtonSize)
        .frame(maxWidth: 148)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

struct VPNActiveProviderPickerMenu: View {
    let providers: [VPNProvider]
    let activeProviderID: UUID?
    let onSelect: (UUID) -> Void

    private var activeName: String {
        let provider = providers.first(where: { $0.id == activeProviderID }) ?? providers.first
        return provider?.catalogDisplayName.withoutEmoji ?? "VPN"
    }

    var body: some View {
        Menu {
            ForEach(providers) { provider in
                Button {
                    onSelect(provider.id)
                } label: {
                    if provider.id == activeProviderID {
                        Label(provider.catalogDisplayName.withoutEmoji, systemImage: "checkmark")
                    } else {
                        Text(provider.catalogDisplayName.withoutEmoji)
                    }
                }
                .disabled(provider.status == .expired)
            }
        } label: {
            VPNActiveProviderPickerPill.pickerLabel(activeName)
        }
        .tint(.primary)
        .accessibilityLabel("Active VPN, \(activeName)")
    }
}

struct VPNIslandCollapsedHeader: View {
    enum Style {
        case standard
        case fastestMultiVPN
    }

    let provider: VPNProvider
    let title: String
    let subtitle: String
    var style: Style = .standard
    var providers: [VPNProvider] = []
    var showsMultiProviderSummary: Bool = false
    var activePreset: VPNUseCaseMenuChoice?
    var onPresetSelected: ((VPNUseCaseMenuChoice) -> Void)?
    var providerPickerProviders: [VPNProvider] = []
    var activeProviderID: UUID?
    var onSelectActiveProvider: ((UUID) -> Void)?
    var onSummaryTap: (() -> Void)?
    let expandSystemName: String
    let onExpand: () -> Void

    var body: some View {
        switch style {
        case .fastestMultiVPN:
            fastestMultiVPNBody
        case .standard:
            standardBody
        }
    }

    private var standardBody: some View {
        HStack(spacing: 12) {
            providerSummary

            if let onSelectActiveProvider, !providerPickerProviders.isEmpty {
                VPNActiveProviderPickerMenu(
                    providers: providerPickerProviders,
                    activeProviderID: activeProviderID,
                    onSelect: onSelectActiveProvider
                )
            }

            if let onPresetSelected {
                VPNUseCasePresetsMenu(activeChoice: activePreset, onSelect: onPresetSelected)
            }

            VPNIslandChromeButton(systemName: expandSystemName, action: onExpand)
        }
        .padding(8)
    }

    private var fastestMultiVPNBody: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ui(title.withoutEmoji))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(ui(subtitle.withoutEmoji))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onSelectActiveProvider, !providerPickerProviders.isEmpty {
                VPNActiveProviderPickerMenu(
                    providers: providerPickerProviders,
                    activeProviderID: activeProviderID,
                    onSelect: onSelectActiveProvider
                )
            }

            VPNIslandChromeButton(systemName: expandSystemName, action: onExpand)
        }
        .padding(8)
    }

    @ViewBuilder
    private var providerSummary: some View {
        let content = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ui(title.withoutEmoji))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(ui(subtitle.withoutEmoji))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let onSummaryTap {
            Button(action: onSummaryTap) { content }
                .buttonStyle(PressScaleButtonStyle())
        } else {
            content
        }
    }
}

// MARK: - Collapsed menu island

/// The two choosers from Bottom menu, used as the collapsed island.
struct VPNIslandMenuCollapsedHeader: View {
    let status: String
    let provider: VPNProvider
    let providerName: String
    let locationTitle: String
    var locationFlag: String?
    let onProvider: () -> Void
    let onLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status)
                .font(.title3.weight(.semibold))
                .foregroundStyle(VelvetTheme.mainTextDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                choice(
                    title: ui("VPN"),
                    detail: providerName,
                    label: ui("VPN") + ", \(providerName)",
                    action: onProvider
                ) {
                    VPNProviderBrandLogo(provider: provider, size: 28)
                }
                choice(
                    title: ui("Location"),
                    detail: locationTitle,
                    label: ui("Location") + ", \(locationTitle)",
                    action: onLocation
                ) {
                    if let locationFlag {
                        Text(locationFlag)
                            .font(.title3)
                    } else {
                        Image(systemName: "globe")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .frame(height: VelvetMetrics.menuIslandHeaderHeight, alignment: .top)
    }

    private func choice<Mark: View>(
        title: String,
        detail: String,
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder mark: () -> Mark
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                mark()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(ui(title))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ui(detail))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Primary connect action

struct VPNPrimaryConnectionButton: View {
    let title: String
    let connectionState: VPNConnectionState
    var size: ControlSize = .large
    var usesErrorTint = true
    var showsPowerIcon = true
    var isBusy = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if showsPowerIcon {
                        if connectionState == .connecting || isBusy {
                            ProgressView()
                                .controlSize(size)
                                .tint(.white)
                        } else {
                            Image(systemName: "power")
                                .font(size == .large ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                        }
                    } else if connectionState == .connecting || isBusy {
                        ProgressView()
                            .controlSize(size)
                            .tint(.white)
                    }
                }
                .contentTransition(.symbolEffect(.replace))

                Text(ui(title))
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
        .disabled(connectionState == .connecting || isBusy)
        .sensoryFeedback(.success, trigger: connectionState) { _, new in
            new.isConnected
        }
        .sensoryFeedback(.error, trigger: connectionState) { _, new in
            new.isFailed
        }
        .accessibilityHint(
            connectionState == .connected
                ? ui("Disconnects the demo VPN")
                : ui("Connects the demo VPN")
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

extension String {
    /// Drops pictographs so a subscription name reads as plain text.
    var withoutEmoji: String {
        let kept = unicodeScalars.filter { scalar in
            if scalar.value == 0xFE0F || scalar.value == 0x200D { return false }
            if scalar.properties.isEmojiPresentation { return false }
            if scalar.properties.isEmoji, scalar.value > 0x238C { return false }
            return true
        }
        return String(String.UnicodeScalarView(kept))
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
