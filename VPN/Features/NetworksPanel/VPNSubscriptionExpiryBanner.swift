import SwiftUI

struct VPNSubscriptionExpiryBanner: View {
    let providerKind: VPNProvider.Kind
    let isExpired: Bool
    let onRenew: () -> Void
    let onHide: () -> Void
    /// When true, the parent promo card supplies the white surface and purple frame.
    var embeddedInPromoCard: Bool = false

    private var isVelvet: Bool {
        providerKind == .velvetFeatured
    }

    private var message: String {
        if isVelvet {
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
                    if isVelvet {
                        Button(action: onRenew) {
                            renewButtonLabel
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    } else {
                        Button(action: onRenew) {
                            renewButtonLabel
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: onHide) {
                    Text("Hide")
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

    private var renewButtonLabel: some View {
        Text("Renew")
            .font(.body.weight(isVelvet ? .semibold : .medium))
            .foregroundStyle(isVelvet ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isVelvet ? VelvetTheme.accent : Color(.secondarySystemFill),
                in: Capsule()
            )
    }
}
