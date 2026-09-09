import SwiftUI

/// Live session stats shown inside the collapsed island and pinned in the sheet.
struct ConnectionStatsStrip: View {
    let regionLabel: String
    let pingMs: Int
    let downloadRate: String
    let uploadRate: String
    var usageFraction: Double = 0
    var sessionDataUsedText: String = "0 MB this session"
    var showsBackground: Bool = true
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
                Spacer(minLength: 8)
                Text(sessionDataUsedText)
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

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
