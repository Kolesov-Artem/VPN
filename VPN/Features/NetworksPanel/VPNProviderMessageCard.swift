import SwiftUI

/// Tappable upsell shown inside the provider status card for third-party VPNs.
struct VelvetPromoBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("Velvet VPN is better, try it")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                VelvetTheme.accent,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Try Velvet VPN")
        .accessibilityHint("Opens the Velvet VPN website")
    }
}

/// Unified provider status block for a single subscription: session stats plus
/// provider announcements in one white card (Figma curtain layout).
struct VPNProviderMessageCard: View {
    let provider: VPNProvider
    let regionLabel: String
    let pingMs: Int
    let downloadRate: String
    let uploadRate: String
    let usageFraction: Double
    let usageTrailingLabel: String
    var showsVelvetPromo: Bool = false
    var onStatsTap: (() -> Void)? = nil
    var onVelvetPromoTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConnectionStatsStrip(
                regionLabel: regionLabel,
                pingMs: pingMs,
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                usageFraction: usageFraction,
                sessionDataUsedText: usageTrailingLabel,
                showsBackground: true,
                usesContentPadding: true,
                cornerRadius: VelvetMetrics.nestedStatsStripCornerRadius,
                progressTint: .primary,
                onTap: onStatsTap
            )

            if showsVelvetPromo, let onVelvetPromoTap {
                VelvetPromoBanner(action: onVelvetPromoTap)
            }

            if provider.hasProviderMessage, let message = provider.providerMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VelvetMetrics.contentSurfaceInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            VelvetTheme.contentSurface,
            in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = ["Provider status"]
        if showsVelvetPromo {
            parts.append("Velvet VPN is better, try it")
        }
        if let message = provider.providerMessage {
            parts.append(message)
        }
        return parts.joined(separator: ". ")
    }
}
