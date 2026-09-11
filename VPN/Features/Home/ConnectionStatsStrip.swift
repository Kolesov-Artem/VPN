import SwiftUI

/// Live session stats shown inside the collapsed island and pinned in the sheet.
struct ConnectionStatsStrip: View {
    let regionLabel: String
    let pingMs: Int
    let downloadRate: String
    let uploadRate: String
    var usageFraction: Double = 0
    var sessionDataUsedText: String = "0 MB this session"
    var showsBackground: Bool = false
    var usesContentPadding: Bool = true
    var cornerRadius: CGFloat = VelvetMetrics.statsStripCornerRadius
    var progressTint: Color = VelvetTheme.accent
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                content
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection stats. Tap for details.")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: VelvetMetrics.statsStripSectionSpacing) {
            usageSection
            statsRow
        }
        .padding(usesContentPadding ? VelvetMetrics.statsStripPadding : EdgeInsets())
        .background {
            if showsBackground {
                statsBackground
            }
        }
        .contentShape(Rectangle())
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(usagePercentText)
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                Text(sessionDataUsedText)
                    .contentTransition(.numericText())
            }
            .font(VelvetTypography.statsStripLabel)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)

            usageProgressBar
        }
    }

    private var usagePercentText: String {
        let percent = Int((usageFraction.clamped(to: 0...1) * 100).rounded())
        return "\(percent)% used"
    }

    private var usageProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: VelvetMetrics.statsStripProgressCornerRadius, style: .continuous)
                    .fill(VelvetTheme.statsStripProgressTrack)

                RoundedRectangle(cornerRadius: VelvetMetrics.statsStripProgressCornerRadius, style: .continuous)
                    .fill(progressTint)
                    .frame(width: geometry.size.width * usageFraction.clamped(to: 0...1))
            }
        }
        .frame(height: VelvetMetrics.statsStripProgressHeight)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            statColumn(title: "Location", value: regionLabel)

            Spacer(minLength: 8)

            metricColumn(
                title: "Ping",
                value: "\(pingMs)",
                unit: "ms",
                placeholder: VelvetMetrics.statsStripPingPlaceholder
            )

            Spacer(minLength: 8)

            rateColumn(title: "Upload", rate: uploadRate)

            Spacer(minLength: 8)

            rateColumn(title: "Download", rate: downloadRate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsBackground: some View {
        VelvetTheme.statsStripBackground
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VelvetTypography.statsStripLabel)
                .foregroundStyle(.secondary)

            Text(value)
                .font(VelvetTypography.statsStripValue)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func metricColumn(
        title: String,
        value: String,
        unit: String,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VelvetTypography.statsStripLabel)
                .foregroundStyle(.secondary)

            reservedValueLine(
                value: value,
                unit: unit,
                placeholder: placeholder
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func rateColumn(title: String, rate: String) -> some View {
        let parts = splitRate(rate)

        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VelvetTypography.statsStripLabel)
                .foregroundStyle(.secondary)

            reservedValueLine(
                value: parts.value,
                unit: parts.unit,
                placeholder: VelvetMetrics.statsStripRatePlaceholder
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func reservedValueLine(value: String, unit: String, placeholder: String) -> some View {
        ZStack(alignment: .leading) {
            Text(placeholder)
                .font(VelvetTypography.statsStripValueNumeric)
                .foregroundStyle(.clear)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                Text(value)
                    .font(VelvetTypography.statsStripValueNumeric)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                if !unit.isEmpty {
                    Text(" \(unit)")
                        .font(VelvetTypography.statsStripValue)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func splitRate(_ rate: String) -> (value: String, unit: String) {
        let parts = rate.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return (rate, "") }
        return (String(parts[0]), String(parts[1]))
    }
}

/// Drives stats reveal with panel motion: always tracks live panel height so
/// content follows the finger and stays visible at intermediate detents.
struct AnimatedPanelStatsReveal<Content: View>: View {
    let context: BottomPanelCurtainContext
    @ViewBuilder let content: (CGFloat) -> Content

    private var activeReveal: CGFloat {
        let progress = context.layout.revealProgress
        if progress > 0.001 || context.isDraggingPanel {
            return progress
        }
        return context.isStatsExpanded ? 1 : 0
    }

    var body: some View {
        content(activeReveal)
    }
}

private struct PanelRevealMeasuredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Grows from zero height with panel progress so reveal doesn't pop content in.
struct PanelRevealHeightClip<Content: View>: View {
    var progress: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var measuredHeight: CGFloat = 0

    private var clampedProgress: CGFloat {
        progress.clamped(to: 0...1)
    }

    private var usesNaturalHeight: Bool {
        clampedProgress >= 1
    }

    private var revealedHeight: CGFloat? {
        guard !usesNaturalHeight else { return nil }
        return measuredHeight * clampedProgress
    }

    var body: some View {
        ZStack(alignment: .top) {
            content()
                .fixedSize(horizontal: false, vertical: true)
                .opacity(clampedProgress > 0.01 ? clampedProgress : 0)
        }
        .frame(height: revealedHeight, alignment: .top)
        .clipped()
        .allowsHitTesting(clampedProgress > 0.01)
        .background {
            content()
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .accessibilityHidden(true)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: PanelRevealMeasuredHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                }
        }
        .onPreferenceChange(PanelRevealMeasuredHeightKey.self) { measuredHeight = $0 }
    }
}

/// Morphs stats padding and substrate with panel reveal (island → intermediate).
///
/// Collapsed: 8pt inset, no card. Expanded: 12pt card padding with white surface,
/// each section inset 8pt (Figma grouped table view).
struct ConnectionStatsRevealShell<Details: View>: View {
    var revealProgress: CGFloat = 0
    @ViewBuilder var stats: () -> ConnectionStatsStrip
    @ViewBuilder var details: () -> Details

    var body: some View {
        let reveal = VelvetMotion.revealStep(revealProgress)
        let cardPadding = VelvetMetrics.statsStripCollapsedInset * (1 - reveal)
            + VelvetMetrics.statsStripExpandedCardPadding * reveal
        let sectionPadding = VelvetMetrics.statsStripSectionPadding * reveal

        VStack(alignment: .leading, spacing: 0) {
            stats()
                .padding(
                    EdgeInsets(
                        top: sectionPadding,
                        leading: sectionPadding,
                        bottom: reveal > 0.01 ? VelvetMetrics.statsStripDividerPadding : sectionPadding,
                        trailing: sectionPadding
                    )
                )

            PanelRevealHeightClip(progress: reveal) {
                details()
            }
        }
        .padding(cardPadding)
        .background {
            RoundedRectangle(
                cornerRadius: VelvetMetrics.contentSurfaceCornerRadius,
                style: .continuous
            )
            .fill(VelvetTheme.contentSurface)
            .opacity(reveal)
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
