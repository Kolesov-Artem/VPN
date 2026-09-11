import SwiftUI

enum VPNAttentionBannerMode: Equatable {
    case subscriptionRenewal(providerKind: VPNProvider.Kind, isExpired: Bool)
    case selectionMismatch(VPNSelectionMismatch)
}

struct VPNSubscriptionExpiryBanner: View {
    let mode: VPNAttentionBannerMode
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    /// When true, the parent promo card supplies the white surface and purple frame.
    var embeddedInPromoCard: Bool = false

    init(
        providerKind: VPNProvider.Kind,
        isExpired: Bool,
        onRenew: @escaping () -> Void,
        onHide: @escaping () -> Void,
        embeddedInPromoCard: Bool = false
    ) {
        mode = .subscriptionRenewal(providerKind: providerKind, isExpired: isExpired)
        onPrimary = onRenew
        onSecondary = onHide
        self.embeddedInPromoCard = embeddedInPromoCard
    }

    init(
        mismatch: VPNSelectionMismatch,
        onUseSmartAuto: @escaping () -> Void,
        onBrowseLocations: @escaping () -> Void,
        embeddedInPromoCard: Bool = false
    ) {
        mode = .selectionMismatch(mismatch)
        onPrimary = onUseSmartAuto
        onSecondary = onBrowseLocations
        self.embeddedInPromoCard = embeddedInPromoCard
    }

    private var isVelvetRenewal: Bool {
        if case let .subscriptionRenewal(providerKind, _) = mode {
            return providerKind == .velvetFeatured
        }
        return false
    }

    private var message: String {
        switch mode {
        case let .subscriptionRenewal(providerKind, isExpired):
            if providerKind == .velvetFeatured {
                if isExpired {
                    "Your Velvet subscription expired, renew to continue to use it"
                } else {
                    "Your Velvet subscription will end soon, renew to continue to use it"
                }
            } else if isExpired {
                "Your subscription expired, renew to continue to use it"
            } else {
                "Your subscription will end soon, renew to continue to use it"
            }

        case let .selectionMismatch(mismatch):
            mismatch.bannerMessage
        }
    }

    private var primaryTitle: String {
        switch mode {
        case .subscriptionRenewal: "Renew"
        case .selectionMismatch: "Use Smart Auto"
        }
    }

    private var secondaryTitle: String {
        switch mode {
        case .subscriptionRenewal: "Hide"
        case .selectionMismatch: "Browse locations"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Group {
                    if isVelvetRenewal {
                        Button(action: onPrimary) {
                            primaryButtonLabel
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    } else {
                        Button(action: onPrimary) {
                            primaryButtonLabel
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemFill), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(embeddedInPromoCard ? 0 : 16)
        .background {
            if !embeddedInPromoCard {
                RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous)
                    .fill(VelvetTheme.contentSurface)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private var primaryButtonLabel: some View {
        Text(primaryTitle)
            .font(.body.weight(isVelvetRenewal ? .semibold : .medium))
            .foregroundStyle(isVelvetRenewal ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isVelvetRenewal ? VelvetTheme.accent : Color(.secondarySystemFill),
                in: Capsule()
            )
    }
}
