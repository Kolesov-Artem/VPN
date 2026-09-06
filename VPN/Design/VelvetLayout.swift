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
    static let primaryButtonHeight: CGFloat = 50
    static let searchControlHeight: CGFloat = 50
    static let statsStripPadding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    static let statsStripCornerRadius: CGFloat = 20
    static let contentSurfaceCornerRadius: CGFloat = 20
    static let statsStripSectionSpacing: CGFloat = 12
    static let statsStripProgressHeight: CGFloat = 6
    static let statsStripProgressCornerRadius: CGFloat = 3
    static let statsStripPingPlaceholder = "000 ms"
    static let statsStripRatePlaceholder = "000 MB/s"
    static let statsStripCollapsedHeight: CGFloat = 106
    static let statsStripEstimatedHeight: CGFloat = statsStripCollapsedHeight
    static let panelHeaderRowHeight: CGFloat = 44
    static let collapsedHeaderBottomPadding: CGFloat = 8
    static let collapsedSectionSpacing: CGFloat = 8
    static let collapsedBottomPadding: CGFloat = 16
    static let islandProviderIconSize: CGFloat = 40
    static let islandChromeButtonSize: CGFloat = 36
    static let islandCollapsedHeaderHeight: CGFloat = 56
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
}

// MARK: - Collapsed island layout

enum VelvetCollapsedIslandLayout {
    /// Top chrome: grip, status header, and optional stats strip.
    static func chromeHeight(showsSessionStats: Bool) -> CGFloat {
        let headerBlock = BottomPanelDetents.expandedGripBandHeight
            + VelvetMetrics.panelHeaderRowHeight
            + VelvetMetrics.collapsedHeaderBottomPadding
        guard showsSessionStats else { return headerBlock }
        return headerBlock
            + VelvetMetrics.collapsedSectionSpacing
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
