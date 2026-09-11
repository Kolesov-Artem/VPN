import SwiftUI

/// Footer row inside the purple promo card shell.
private struct VelvetPromoBannerFooter: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Or try Velvet VPN, it's better")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(VelvetMetrics.promoCardFooterPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Or try Velvet VPN, it's better")
        .accessibilityHint("Opens the Velvet VPN website")
    }
}

/// Figma promo shell: purple frame, white content block, tappable Velvet upsell footer.
struct VelvetPromoCard<Content: View>: View {
    let onPromoTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(VelvetMetrics.statsStripExpandedCardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelvetMetrics.promoCardInnerRadius, style: .continuous)
                        .fill(VelvetTheme.contentSurface)
                )

            VelvetPromoBannerFooter(action: onPromoTap)
        }
        .padding(VelvetMetrics.promoCardFramePadding)
        .background(
            RoundedRectangle(cornerRadius: VelvetMetrics.promoCardOuterRadius, style: .continuous)
                .fill(VelvetTheme.accent)
        )
    }
}

/// Session stats, renewal, promo shell, and providers list.
struct VPNProviderMessageCard: View {
    let provider: VPNProvider
    let regionLabel: String
    let pingMs: Int
    let downloadRate: String
    let uploadRate: String
    let usageFraction: Double
    let usageTrailingLabel: String
    var revealProgress: CGFloat = 1
    var showsConnectionStats: Bool = false
    var showsRenewalBanner: Bool = false
    var showsVelvetStatsPromo: Bool = false
    var showsProvidersList: Bool = false
    var onStatsTap: (() -> Void)? = nil
    var onVelvetPromoTap: (() -> Void)? = nil
    var onRenewSubscription: ((UUID) -> Void)? = nil
    var onHideRenewalBanner: ((UUID) -> Void)? = nil
    var onOpenProvider: ((UUID) -> Void)? = nil

    @Bindable var providerStore: VPNProviderStore

    private var liveProvider: VPNProvider {
        providerStore.provider(id: provider.id) ?? provider
    }

    private var velvetRenewalProvider: VPNProvider? {
        VPNProviderAvailabilitySummary.velvetNeedingRenewal(
            in: providerStore.providers,
            hiddenBannerIDs: providerStore.hiddenRenewalBannerIDs
        )
    }

    private var detailsReveal: CGFloat {
        VelvetMotion.revealStep(revealProgress)
    }

    private var chromeHorizontalPadding: CGFloat {
        VelvetMetrics.rowHorizontalPadding * detailsReveal
    }

    private var statsEmbeddedInPromo: Bool {
        showsVelvetStatsPromo && !showsRenewalBanner
    }

    private var showsExpandedChrome: Bool {
        detailsReveal > 0.01
    }

    private var showsProviderDetailMessage: Bool {
        if providerStore.providers.count == 1 {
            return liveProvider.hasProviderMessage
        }
        return liveProvider.showsDetailMessage
    }

    private var isSingleProviderExpandedCard: Bool {
        providerStore.providers.count == 1 && showsExpandedChrome
    }

    private var showsPromoShell: Bool {
        statsEmbeddedInPromo && showsExpandedChrome && !isSingleProviderExpandedCard
    }

    private var showsSecondaryCard: Bool {
        if showsConnectionStats { return true }
        if isSingleProviderExpandedCard { return true }
        if statsEmbeddedInPromo && !showsExpandedChrome { return true }
        if showsRenewalBanner { return showsExpandedChrome }
        if velvetRenewalProvider != nil && velvetRenewalProvider?.id != liveProvider.id {
            return showsExpandedChrome
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VelvetMetrics.infoBlockSectionSpacing) {
            if showsExpandedChrome {
                if let velvet = velvetRenewalProvider, velvet.id != liveProvider.id {
                    clippedRenewalBanner(for: velvet)
                }

                if showsRenewalBanner {
                    clippedRenewalBlock
                } else if showsPromoShell, let onVelvetPromoTap {
                    VelvetPromoCard(onPromoTap: onVelvetPromoTap) {
                        promoStatsContent
                    }
                }
            }

            if showsSecondaryCard {
                statsBlock
            }

            if showsProvidersList, let onOpenProvider, detailsReveal > 0.01 {
                VPNCompactNetworksCard(
                    providerStore: providerStore,
                    showsBackground: true,
                    summaryTitle: "All \(providerStore.providers.count) providers",
                    onOpenProvider: onOpenProvider
                )
            }
        }
        .padding(.horizontal, chromeHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var clippedRenewalBlock: some View {
        PanelRevealHeightClip(progress: detailsReveal) {
            renewalBanner(for: liveProvider)
        }
    }

    @ViewBuilder
    private func clippedRenewalBanner(for renewalProvider: VPNProvider) -> some View {
        PanelRevealHeightClip(progress: detailsReveal) {
            renewalBanner(for: renewalProvider)
        }
    }

    @ViewBuilder
    private func renewalBanner(for renewalProvider: VPNProvider) -> some View {
        if let onRenewSubscription, let onHideRenewalBanner {
            if VPNProviderAvailabilitySummary.showsVelvetRenewalPromoShell(for: renewalProvider),
               let onVelvetPromoTap {
                VelvetPromoCard(onPromoTap: onVelvetPromoTap) {
                    VPNSubscriptionExpiryBanner(
                        providerKind: renewalProvider.kind,
                        isExpired: renewalProvider.status == .expired,
                        onRenew: { onRenewSubscription(renewalProvider.id) },
                        onHide: { onHideRenewalBanner(renewalProvider.id) },
                        embeddedInPromoCard: true
                    )
                }
            } else {
                VPNSubscriptionExpiryBanner(
                    providerKind: renewalProvider.kind,
                    isExpired: renewalProvider.status == .expired,
                    onRenew: { onRenewSubscription(renewalProvider.id) },
                    onHide: { onHideRenewalBanner(renewalProvider.id) }
                )
            }
        }
    }

    @ViewBuilder
    private var statsBlock: some View {
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
            if showsProviderDetailMessage, let message = liveProvider.providerMessage {
                expandedMessageSection(message)
            }
        }
    }

    private var promoStatsContent: some View {
        ConnectionStatsStrip(
            regionLabel: regionLabel,
            pingMs: pingMs,
            downloadRate: downloadRate,
            uploadRate: uploadRate,
            usageFraction: usageFraction,
            sessionDataUsedText: usageTrailingLabel,
            showsBackground: false,
            usesContentPadding: false,
            progressTint: VelvetTheme.accent,
            onTap: onStatsTap
        )
    }

    private func expandedMessageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, VelvetMetrics.statsStripDividerPadding)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(
                    EdgeInsets(
                        top: 0,
                        leading: VelvetMetrics.statsStripSectionPadding,
                        bottom: VelvetMetrics.statsStripSectionPadding,
                        trailing: VelvetMetrics.statsStripSectionPadding
                    )
                )
        }
    }

    private var accessibilityLabel: String {
        var parts = ["Connection stats"]
        if showsRenewalBanner || velvetRenewalProvider != nil {
            parts.append("Your subscription needs renewal")
        }
        if showsVelvetStatsPromo {
            parts.append("Or try Velvet VPN, it's better")
        }
        if let message = liveProvider.providerMessage, showsProviderDetailMessage {
            parts.append(message)
        }
        return parts.joined(separator: ". ")
    }
}
