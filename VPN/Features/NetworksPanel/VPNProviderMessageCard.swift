import SwiftUI

/// Tappable upsell shown inside the provider status block for third-party VPNs.
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

/// Session stats plus provider announcements. Collapsed: extra 8pt inset, no substrate.
/// Expanded: grouped card with white surface; extra rows reveal with panel progress.
struct VPNProviderMessageCard: View {
    let provider: VPNProvider
    let regionLabel: String
    let pingMs: Int
    let downloadRate: String
    let uploadRate: String
    let usageFraction: Double
    let usageTrailingLabel: String
    var revealProgress: CGFloat = 1
    var showsVelvetPromo: Bool = false
    var showsProvidersList: Bool = false
    var onStatsTap: (() -> Void)? = nil
    var onVelvetPromoTap: (() -> Void)? = nil
    var onOpenProvider: ((UUID) -> Void)? = nil

    @Bindable var providerStore: VPNProviderStore

    var body: some View {
        let detailsReveal = VelvetMotion.revealStep(revealProgress)

        VStack(alignment: .leading, spacing: VelvetMetrics.infoBlockSectionSpacing) {
            ConnectionStatsRevealShell(revealProgress: revealProgress) {
                ConnectionStatsStrip(
                    regionLabel: regionLabel,
                    pingMs: pingMs,
                    downloadRate: downloadRate,
                    uploadRate: uploadRate,
                    usageFraction: usageFraction,
                    sessionDataUsedText: usageTrailingLabel,
                    showsBackground: false,
                    usesContentPadding: false,
                    progressTint: detailsReveal > 0.45 ? .primary : VelvetTheme.accent,
                    onTap: onStatsTap
                )
            } details: {
                if hasExpandedDetailsContent {
                    expandedDetailsSectionLayout
                        .opacity(detailsReveal)
                        .scaleEffect(
                            x: 1,
                            y: max(detailsReveal, 0.001),
                            anchor: .top
                        )
                        .allowsHitTesting(detailsReveal > 0.85)
                }
            }

            if showsProvidersList, let onOpenProvider, detailsReveal > 0.01 {
                VPNCompactNetworksCard(
                    providerStore: providerStore,
                    showsBackground: true,
                    cornerRadius: VelvetMetrics.statsStripExpandedCardCornerRadius,
                    contentHorizontalPadding: VelvetMetrics.providersCardHorizontalPadding,
                    summaryTitle: "All \(providerStore.providers.count) providers",
                    onOpenProvider: onOpenProvider
                )
                .opacity(detailsReveal)
                .scaleEffect(
                    x: 1,
                    y: max(detailsReveal, 0.001),
                    anchor: .top
                )
                .allowsHitTesting(detailsReveal > 0.85)
            }
        }
        .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var hasExpandedDetailsContent: Bool {
        showsVelvetPromo || (provider.hasProviderMessage && provider.providerMessage != nil)
    }

    private var expandedDetailsSectionLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, VelvetMetrics.statsStripSectionPadding)

            expandedDetailsContent
                .padding(.horizontal, VelvetMetrics.statsStripSectionPadding)
                .padding(.bottom, VelvetMetrics.statsStripSectionPadding)
        }
    }

    @ViewBuilder
    private var expandedDetailsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
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
