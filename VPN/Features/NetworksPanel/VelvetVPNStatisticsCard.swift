import Charts
import SwiftUI

private enum VelvetProtectionCategory: String {
    case protected = "Protected"
    case offline = "Offline"
}

private struct VelvetDailyProtectionSegment: Identifiable {
    let id = UUID()
    let weekday: String
    let category: VelvetProtectionCategory
    let hours: Double
}

/// Weekly VPN protection chart for Velvet provider details.
struct VelvetVPNStatisticsCard: View {
    let providerMessage: String?
    var messageUpdatedAt: Date?
    var liveStats: VPNProviderLiveStats?
    var embedInForm = false

    private static let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private static let weeklySegments: [VelvetDailyProtectionSegment] = {
        let protectedHours: [Double] = [14, 19, 21, 22, 20, 9, 0]
        let offlineHours: [Double] = [10, 5, 3, 2, 4, 3, 0]

        return weekdayLabels.enumerated().flatMap { index, label in
            [
                VelvetDailyProtectionSegment(
                    weekday: label,
                    category: .protected,
                    hours: protectedHours[index]
                ),
                VelvetDailyProtectionSegment(
                    weekday: label,
                    category: .offline,
                    hours: offlineHours[index]
                ),
            ]
        }
    }()

    private var protectedTotal: Int {
        Int(Self.weeklySegments
            .filter { $0.category == .protected }
            .reduce(0) { $0 + $1.hours })
    }

    private var offlineTotal: Int {
        Int(Self.weeklySegments
            .filter { $0.category == .offline }
            .reduce(0) { $0 + $1.hours })
    }

    private var averageProtectedHours: Int {
        let protectedDays = Self.weeklySegments.filter { $0.category == .protected && $0.hours > 0 }
        guard !protectedDays.isEmpty else { return 0 }
        let total = protectedDays.reduce(0) { $0 + $1.hours }
        return Int((total / Double(protectedDays.count)).rounded())
    }

    var body: some View {
        let sectionSpacing: CGFloat = embedInForm ? 12 : 16

        VStack(alignment: .leading, spacing: sectionSpacing) {
            if let liveStats, liveStats.isConnected {
                ConnectionStatsStrip(
                    regionLabel: liveStats.regionLabel,
                    pingMs: liveStats.pingMs,
                    downloadRate: liveStats.downloadRate,
                    uploadRate: liveStats.uploadRate,
                    usageFraction: liveStats.usageFraction,
                    sessionDataUsedText: liveStats.sessionDataUsedText,
                    showsBackground: false,
                    usesContentPadding: false,
                    progressTint: .primary
                )

                if providerMessage != nil {
                    Divider()
                        .padding(.vertical, VelvetMetrics.statsStripDividerPadding)
                }
            }

            if let providerMessage {
                Text(providerMessage)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if providerMessage != nil {
                Divider()
                    .padding(.vertical, VelvetMetrics.statsStripDividerPadding)
            }

            protectionChart

            chartLegend

            if let messageUpdatedAt {
                Text("Updated \(messageUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(embedInForm ? EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0) : EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !embedInForm {
                VelvetTheme.contentSurface
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: VelvetMetrics.contentSurfaceCornerRadius,
                            style: .continuous
                        )
                    )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Velvet VPN statistics")
    }

    private var protectionChart: some View {
        Chart {
            ForEach(Self.weeklySegments) { segment in
                BarMark(
                    x: .value("Day", segment.weekday),
                    y: .value("Hours", segment.hours)
                )
                .foregroundStyle(by: .value("Category", segment.category.rawValue))
            }

            RuleMark(y: .value("Average", Double(averageProtectedHours)))
                .foregroundStyle(Color(.systemBlue).opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartForegroundStyleScale([
            VelvetProtectionCategory.protected.rawValue: AnyShapeStyle(Color(.systemBlue)),
            VelvetProtectionCategory.offline.rawValue: AnyShapeStyle(Color(.systemGray5)),
        ])
        .chartYScale(domain: 0...24)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [24]) { _ in
                AxisValueLabel("24h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)
        }
        .frame(height: embedInForm ? 112 : 132)
    }

    private var chartLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                legendPill(
                    title: "\(protectedTotal)h Protected",
                    color: Color(.systemBlue)
                )
                legendPill(
                    title: "\(offlineTotal)h Offline",
                    color: Color(.systemGray3)
                )
                legendPill(
                    title: "avg \(averageProtectedHours)h",
                    color: Color(.systemBlue).opacity(0.7)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    legendPill(
                        title: "\(protectedTotal)h Protected",
                        color: Color(.systemBlue)
                    )
                    legendPill(
                        title: "\(offlineTotal)h Offline",
                        color: Color(.systemGray3)
                    )
                }
                legendPill(
                    title: "avg \(averageProtectedHours)h",
                    color: Color(.systemBlue).opacity(0.7)
                )
            }
        }
    }

    private func legendPill(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}
