import SwiftUI

// MARK: - Typography (Apple-aligned defaults)

enum VelvetTypography {
    static let rowTitle = Font.body
    static let rowTitleSelected = Font.body.weight(.semibold)
    static let rowSubtitle = Font.footnote
    static let sectionHeader = Font.footnote.weight(.semibold)
    static let metadataLabel = Font.footnote
    static let metadataValue = Font.subheadline.weight(.semibold)
    static let metadataValueNumeric = Font.subheadline.monospacedDigit().weight(.semibold)
    static let statsStripLabel = Font.footnote
    static let statsStripValue = Font.subheadline
    static let statsStripValueNumeric = Font.subheadline.monospacedDigit()
    static let panelStatusTitle = Font.body.weight(.semibold)
    static let panelStatusSubtitle = Font.footnote
    static let chipLabel = Font.footnote.weight(.medium)
    static let chevron = Font.footnote.weight(.semibold)
    static let pingLabel = Font.footnote.monospacedDigit()
    static let badgeLabel = Font.footnote.weight(.semibold)
    static let logsBody = Font.system(.footnote, design: .monospaced)
}

// MARK: - Layout metrics (Apple HIG-aligned)

enum VelvetMetrics {
    static let minTouchTarget: CGFloat = 44
    static let headerIconVisualSize: CGFloat = 36
    static let rowVerticalPadding: CGFloat = 14
    static let rowHorizontalPadding: CGFloat = 16
    static let listIconSlot: CGFloat = 32
    static let listDisclosureChevronWidth: CGFloat = 10
    static let primaryButtonHeight: CGFloat = 56
    static let searchControlHeight: CGFloat = 50
    static let statsStripPadding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    /// Outer inset for island card content (Figma: p-10).
    static let islandContentPadding: CGFloat = 10
    /// Inset around stats in the collapsed island (Figma: 8pt inside the panel).
    static let statsStripCollapsedInset: CGFloat = 8
    /// Padding inside the grouped stats card edge.
    static let statsStripExpandedCardPadding: CGFloat = 16
    static let statsStripExpandedCardCornerRadius: CGFloat = 24
    /// Padding inside each stats-card section (stats row + message block).
    static let statsStripSectionPadding: CGFloat = 4
    /// Space above and below the divider before provider info text.
    static let statsStripDividerPadding: CGFloat = 8
    /// Gap between the stats card and the providers card (Figma: 12pt).
    static let infoBlockSectionSpacing: CGFloat = 12
    /// Vertical inset around the info block — matches spacing between scroll sections.
    static let infoBlockTopSpacing: CGFloat = 16
    /// Horizontal padding inside the providers summary card (Figma: 24pt).
    static let providersCardHorizontalPadding: CGFloat = 24
    static let statsStripCornerRadius: CGFloat = 20
    /// Purple promo card outer shell — compact, aligned with content cards.
    static let promoCardOuterRadius: CGFloat = contentSurfaceCornerRadius + 2
    static let promoCardInnerRadius: CGFloat = contentSurfaceCornerRadius
    static let promoCardFramePadding: CGFloat = 2
    static let promoCardFooterPadding: CGFloat = 12
    static let contentSurfaceCornerRadius: CGFloat = 20
    /// Inset between a content-surface card edge and a nested block (e.g. stats strip).
    static let contentSurfaceInnerPadding: CGFloat = 8

    /// Concentric corner radius for a block nested inside a rounded card.
    static func nestedCornerRadius(outer: CGFloat, inset: CGFloat) -> CGFloat {
        max(outer - inset, 0)
    }

    static var nestedStatsStripCornerRadius: CGFloat {
        nestedCornerRadius(outer: contentSurfaceCornerRadius, inset: contentSurfaceInnerPadding)
    }
    static let statsStripSectionSpacing: CGFloat = 12
    static let statsStripProgressHeight: CGFloat = 6
    static let statsStripProgressCornerRadius: CGFloat = 3
    static let statsStripPingPlaceholder = "000 ms"
    static let statsStripRatePlaceholder = "000 MB/s"
    /// Collapsed stats block: 8pt inset × 2 + usage/progress/grid content.
    static let statsStripCollapsedHeight: CGFloat =
        statsStripCollapsedInset * 2 + statsStripSectionSpacing + 32 + 39
    /// Hairline between island header and stats.
    static let islandSectionDividerHeight: CGFloat = 1
    static let statsStripEstimatedHeight: CGFloat = statsStripCollapsedHeight
    static let panelHeaderRowHeight: CGFloat = 44
    /// Scroll-edge chrome: grip band + compact title row.
    static let panelScrollChromeHeight: CGFloat = BottomPanelDetents.expandedGripBandHeight + panelHeaderRowHeight
    /// Extra blur feather below the compact bar when content scrolls underneath.
    static let panelScrollChromeBlurExtension: CGFloat = 48
    /// Total painted blur height for the top scroll edge.
    static let panelScrollChromeBlurHeight: CGFloat = panelScrollChromeHeight + panelScrollChromeBlurExtension
    static let expandedPanelHeaderHeight: CGFloat = 56
    static let collapsedHeaderBottomPadding: CGFloat = 8
    static let collapsedSectionSpacing: CGFloat = 16
    static let collapsedBottomPadding: CGFloat = 16
    static let islandProviderIconSize: CGFloat = 40
    static let islandChromeButtonSize: CGFloat = 36
    static let islandCollapsedHeaderHeight: CGFloat = 56
    /// Collapsed island header row (separator follows immediately in Figma).
    static var islandHeaderBlockHeight: CGFloat {
        islandCollapsedHeaderHeight
    }
    /// Intermediate detent header row plus the spacing below it.
    static var expandedPanelHeaderBlockHeight: CGFloat {
        expandedPanelHeaderHeight + collapsedHeaderBottomPadding
    }
    static let useCaseCardWidth: CGFloat = 148
    static let useCaseCardMinHeight: CGFloat = 148
    static let useCaseCardPadding: CGFloat = 16
    static let nestedDividerInset: CGFloat = 58
    static let panelHeaderIconSlot: CGFloat = 44
    static let favouritePlaceholderSize: CGFloat = 44
}

// MARK: - Shared chrome

struct VelvetPanelHeaderIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: VelvetMetrics.headerIconVisualSize, height: VelvetMetrics.headerIconVisualSize)
            .background(Color(.tertiarySystemFill), in: Circle())
            .frame(width: VelvetMetrics.panelHeaderIconSlot, height: VelvetMetrics.panelHeaderIconSlot)
            .contentShape(Rectangle())
    }
}

struct VelvetFilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .font(VelvetTypography.chipLabel)
            .foregroundStyle(VelvetTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: VelvetMetrics.minTouchTarget)
            .background(VelvetTheme.accent.opacity(VelvetTheme.selectionHighlightOpacity), in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Remove filter: \(title)")
    }
}

// MARK: - View helpers

extension View {
    func velvetHitTarget(
        width: CGFloat = VelvetMetrics.minTouchTarget,
        height: CGFloat = VelvetMetrics.minTouchTarget
    ) -> some View {
        frame(minWidth: width, minHeight: height)
            .contentShape(Rectangle())
    }

    func velvetSheetStyle() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }

    /// Visible grip band height with a larger invisible drag target centered on it.
    func bottomPanelDragHandle<G: Gesture>(gesture: G) -> some View {
        frame(maxWidth: .infinity)
            .frame(height: BottomPanelDetents.expandedGripBandHeight)
            .background(alignment: .center) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: BottomPanelDetents.expandedGripHitHeight)
                    .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
            .gesture(gesture)
    }
}

// MARK: - Collapsed island layout

enum VelvetCollapsedIslandLayout {
    /// Top chrome: grip, status header, and optional stats strip.
    static func chromeHeight(showsSessionStats: Bool) -> CGFloat {
        let headerBlock = BottomPanelDetents.expandedGripBandHeight
            + VelvetMetrics.islandHeaderBlockHeight
        guard showsSessionStats else { return headerBlock }
        return headerBlock
            + VelvetMetrics.islandSectionDividerHeight
            + VelvetMetrics.statsStripCollapsedHeight
    }

    /// Total floating card height at the island detent.
    static func islandHeight(showsSessionStats: Bool, isAccessibilitySize: Bool) -> CGFloat {
        let body = VelvetMetrics.collapsedSectionSpacing
            + VelvetMetrics.primaryButtonHeight
            + VelvetMetrics.collapsedBottomPadding
        let height = chromeHeight(showsSessionStats: showsSessionStats) + body
        return isAccessibilitySize ? height + 56 : height
    }
}
