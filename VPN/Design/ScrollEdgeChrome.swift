import SwiftUI

/// Compact title row with Telegram bar blur flush to the top edge.
struct PanelCompactBarChrome: View {
    var title: String = "Velvet VPN"
    let scrollEdgeProgress: CGFloat
    let onCollapse: () -> Void
    var allowsHitTesting: Bool = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Color.clear
            .frame(height: VelvetMetrics.panelScrollChromeHeight)
            .allowsHitTesting(false)
            .background(alignment: .top) {
                if scrollEdgeProgress > 0.01 {
                    scrollEdgeBackground
                        .frame(height: VelvetMetrics.panelScrollChromeBlurHeight)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .overlay(alignment: .top) {
                ExpandedSheetCompactBar(
                    title: title,
                    scrollEdgeProgress: scrollEdgeProgress,
                    onCollapse: onCollapse
                )
                .padding(.top, BottomPanelDetents.expandedGripBandHeight)
                .allowsHitTesting(allowsHitTesting && scrollEdgeProgress > 0.5)
            }
    }

    @ViewBuilder
    private var scrollEdgeBackground: some View {
        if reduceTransparency {
            Color(.systemBackground)
                .opacity(scrollEdgeProgress)
        } else {
            TelegramScrollEdgeBackground(
                edge: .top,
                progress: scrollEdgeProgress,
                strength: .navigationBar
            )
        }
    }
}

/// Compact title row shown as scrolling content passes beneath the pinned bar.
struct ExpandedSheetCompactBar: View {
    var title: String = "Velvet VPN"
    let scrollEdgeProgress: CGFloat
    let onCollapse: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelvetTheme.accent)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                onCollapse()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Collapse panel")
        }
        .padding(.horizontal, VelvetTheme.horizontalPadding)
        .opacity(scrollEdgeProgress)
        .frame(height: VelvetMetrics.panelHeaderRowHeight)
        .allowsHitTesting(scrollEdgeProgress > 0.5)
    }
}

private struct PanelScrollEdgeBarModifier<Bar: View>: ViewModifier {
    let scrollEdgeProgress: CGFloat
    let showsScrollEdgeEffect: Bool
    let bar: Bar

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .safeAreaBar(edge: .top, spacing: 0) {
                    bar
                }
                .modifier(ConditionalScrollEdgeEffect(enabled: showsScrollEdgeEffect))
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    bar
                        .background(alignment: .top) {
                            if showsScrollEdgeEffect, scrollEdgeProgress > 0.01 {
                                if reduceTransparency {
                                    Color(.systemBackground)
                                } else {
                                    TelegramScrollEdgeBackground(edge: .top, progress: scrollEdgeProgress)
                                }
                            }
                        }
                }
        }
    }
}

@available(iOS 26.0, *)
private struct ConditionalScrollEdgeEffect: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

extension View {
    func panelScrollEdgeBar<Bar: View>(
        scrollEdgeProgress: CGFloat,
        showsScrollEdgeEffect: Bool = true,
        @ViewBuilder bar: () -> Bar
    ) -> some View {
        modifier(
            PanelScrollEdgeBarModifier(
                scrollEdgeProgress: scrollEdgeProgress,
                showsScrollEdgeEffect: showsScrollEdgeEffect,
                bar: bar()
            )
        )
    }

    /// Lets vertical panel drags run alongside child scroll views and carousels.
    func bottomPanelSimultaneousDrag<G: Gesture>(_ gesture: G) -> some View {
        simultaneousGesture(gesture, including: .all)
    }
}
