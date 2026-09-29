import SwiftUI

/// In-panel card for switching the active subscription. The current VPN stays on the home row.
struct VPNActiveProviderSwitchCard: View {
    let providers: [VPNProvider]
    let activeProviderID: UUID?
    var showsAllSubscriptions: Bool = false
    let onSelectAll: () -> Void
    let onSelect: (UUID) -> Void
    let onInfo: (UUID) -> Void
    let onOpenSubscriptions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(VPNFigmaSection550Copy.switchToTitle)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            allSubscriptionsRow

            ForEach(providers) { provider in
                switchRow(provider)
            }

            Button(action: onOpenSubscriptions) {
                Text(VPNFigmaSection550Copy.seeAllSubscriptions)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(VelvetTheme.contentSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
    }

    private var allSubscriptionsRow: some View {
        Button(action: onSelectAll) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(VPNFigmaSection550Copy.allSubscriptionsLabel)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(VPNProvider.allSubscriptionsCaption(providers: providers))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showsAllSubscriptions {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(VPNFigmaSection550Copy.allSubscriptionsLabel)
        .accessibilityAddTraits(showsAllSubscriptions ? .isSelected : [])
    }

    private func switchRow(_ provider: VPNProvider) -> some View {
        let isSelected = !showsAllSubscriptions && provider.id == activeProviderID
        let identity = provider.subscriptionIdentityCaption
        let subtitle = identity.isEmpty ? provider.networksListSubtitle : identity

        return HStack(spacing: 12) {
            Button {
                onSelect(provider.id)
            } label: {
                HStack(spacing: 12) {
                    VPNProviderBrandLogo(provider: provider, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.catalogDisplayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(provider.status == .expired ? VelvetTheme.errorTint : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(provider.status == .expired)
            .accessibilityLabel("Switch to \(provider.catalogDisplayName)")
            .accessibilityValue(subtitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button {
                onInfo(provider.id)
            } label: {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(provider.catalogDisplayName) info")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct VPNActiveSubscriptionRow: View {
    let title: String
    var subtitle: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(VPNFigmaSection550Copy.activeSubscriptionLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                        .animation(
                            VelvetMotion.contentCrossfade(reduceMotion: reduceMotion),
                            value: title
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                VelvetTheme.contentSurface,
                in: RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(VPNFigmaSection550Copy.activeSubscriptionLabel), \(title)")
        .accessibilityValue(subtitle ?? "")
    }
}

/// Full-screen list of every subscription. Hidden ones can be put back in the switch card.
struct VPNSubscriptionsPage: View {
    @Bindable var providerStore: VPNProviderStore
    /// Account pushes this page inside its own stack. The switch card presents it alone.
    var embedsNavigation = true
    var showsCloseButton = false
    let onOpenProvider: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    private var activeSubscriptions: [VPNProvider] {
        providerStore.providers.filter(\.status.isActive)
    }

    private var expiredSubscriptions: [VPNProvider] {
        providerStore.providers.filter { $0.status == .expired }
    }

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack { subscriptionsList }
            } else {
                subscriptionsList
            }
        }
    }

    private var subscriptionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(activeSubscriptions) { provider in
                    subscriptionRow(provider)
                }

                if !expiredSubscriptions.isEmpty {
                    Text(VPNFigmaSection550Copy.expiredSubscriptionsHeader)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 28)
                        .padding(.bottom, 8)

                    ForEach(expiredSubscriptions) { provider in
                        subscriptionRow(provider)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(VPNFigmaSection550Copy.subscriptionsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func subscriptionRow(_ provider: VPNProvider) -> some View {
        Button {
            onOpenProvider(provider.id)
        } label: {
            HStack(spacing: 12) {
                VPNProviderBrandLogo(provider: provider, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.catalogDisplayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(rowSubtitle(provider))
                        .font(.footnote)
                        .foregroundStyle(provider.status == .expired ? VelvetTheme.errorTint : .secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rowSubtitle(_ provider: VPNProvider) -> String {
        let identity = provider.subscriptionIdentityCaption
        return identity.isEmpty ? provider.networksListSubtitle : identity
    }
}

extension View {
    /// Fades this view with ease-out. Later indexes wait 50ms apart. Movement drops when Reduce Motion is on.
    func velvetStaggeredReveal(index: Int, isHidden: Bool, reduceMotion: Bool) -> some View {
        modifier(VelvetStaggeredReveal(index: index, isHidden: isHidden, reduceMotion: reduceMotion))
    }

    /// Placeholder copy of this view, with one linear highlight. Reveal uses ease-out and a per-item delay.
    func velvetLoadingShimmer(isActive: Bool, reduceMotion: Bool, index: Int = 0) -> some View {
        modifier(VelvetLoadingShimmer(isActive: isActive, reduceMotion: reduceMotion, index: index))
    }
}

private struct VelvetStaggeredReveal: ViewModifier {
    var index: Int
    var isHidden: Bool
    var reduceMotion: Bool

    private var offsetY: CGFloat {
        guard isHidden, !reduceMotion else { return 0 }
        return VelvetMotion.chipEntranceOffsetY
    }

    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? 0 : 1)
            .offset(y: offsetY)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
            .animation(
                VelvetMotion.staggeredReveal(index: index, isHidden: isHidden, reduceMotion: reduceMotion),
                value: isHidden
            )
    }
}

private struct VelvetLoadingShimmer: ViewModifier {
    var isActive: Bool
    var reduceMotion: Bool
    var index: Int

    /// Local flag so the fade starts from the current opacity. A delayed animation on the loading flag itself snaps for one frame.
    @State private var showsPlaceholder = false

    func body(content: Content) -> some View {
        content
            .opacity(showsPlaceholder ? 0 : 1)
            .overlay {
                content
                    .redacted(reason: .placeholder)
                    .overlay {
                        if showsPlaceholder, !reduceMotion {
                            VPNShimmerBand()
                        }
                    }
                    .opacity(showsPlaceholder ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(!showsPlaceholder)
            }
            .clipped()
            .allowsHitTesting(!showsPlaceholder)
            .onChange(of: isActive) { _, active in
                withAnimation(
                    VelvetMotion.staggeredReveal(index: index, isHidden: active, reduceMotion: reduceMotion)
                ) {
                    showsPlaceholder = active
                }
            }
    }
}

/// One linear pass across every placeholder. Wall-clock phase, so stats and the list stay in sync.
struct VPNShimmerBand: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1)
            Color.clear
                .overlay {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.55),
                                .white.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.42)
                        .visualEffect { content, _ in
                            content.offset(x: (CGFloat(progress) * 1.8 - 0.4) * proxy.size.width)
                        }
                    }
                }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }
}
