import SwiftUI

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
    let bar: Bar

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .safeAreaBar(edge: .top, spacing: 0) {
                    bar
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    bar
                        .background(alignment: .top) {
                            if scrollEdgeProgress > 0.01 {
                                if reduceTransparency {
                                    Color(.systemBackground)
                                } else {
                                    ScrollEdgeSoftBackground(progress: scrollEdgeProgress)
                                }
                            }
                        }
                }
        }
    }
}

extension View {
    func panelScrollEdgeBar<Bar: View>(
        scrollEdgeProgress: CGFloat,
        @ViewBuilder bar: () -> Bar
    ) -> some View {
        modifier(
            PanelScrollEdgeBarModifier(
                scrollEdgeProgress: scrollEdgeProgress,
                bar: bar()
            )
        )
    }
}
