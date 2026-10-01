import Charts
import SwiftUI

/// Shared «Traffic usage» card (Account + provider settings).
struct VPNTrafficUsageCard: View {
    var providers: [VPNProvider] = []
    /// When set, the card shows this provider only and hides the provider filter.
    var scopedProviderID: UUID? = nil
    /// Drops the card plate so a grouped list can supply the background and insets.
    var embedInForm = false
    /// Replaces the provider filter title when the card is scoped to one subscription.
    var heading: String? = nil
    /// Hides the title row. The period menu stays, so the chart can still change range.
    var showsHeading = true
    /// Hides the usage bars under the chart when a summary above already shows them.
    var showsUsageMeters = true

    @State private var focusedCategory: TrafficCategory?
    @State private var selectedProviderID: UUID?
    @State private var selectedPeriod: TrafficUsagePeriod = .thisWeek

    private enum TrafficCategory: String, CaseIterable, Identifiable {
        case bypassBlocks = "Bypass blocks"
        case russianSites = "Russian sites"
        case others = "Others"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .bypassBlocks:
                Color(red: 0 / 255, green: 122 / 255, blue: 135 / 255)
            case .russianSites:
                Color(red: 0 / 255, green: 168 / 255, blue: 181 / 255)
            case .others:
                Color(red: 140 / 255, green: 220 / 255, blue: 230 / 255)
            }
        }
    }

    private enum TrafficUsagePeriod: String, CaseIterable, Identifiable {
        case thisWeek = "This week"
        case thisMonth = "This month"

        var id: String { rawValue }
    }

    private struct DaySegment: Identifiable {
        var id: String { "\(dayIndex)-\(category.rawValue)" }
        let dayIndex: Int
        let category: TrafficCategory
        let gigabytes: Double
    }

    private struct TrafficUsageSnapshot {
        let periodTotalLabel: String
        let bypassTotalGB: Double
        let russianTotalGB: Double
        let othersTotalGB: Double
        let bypassDaily: [Double]
        let russianDaily: [Double]
        let othersDaily: [Double]
        let wifiUsedPercent: Int
        let wifiUsedDetail: String
        let lteUsedPercent: Int
        let lteUsedDetail: String
        let chartYMax: Double

        func legendTotal(for category: TrafficCategory) -> String {
            let value: Double
            switch category {
            case .bypassBlocks: value = bypassTotalGB
            case .russianSites: value = russianTotalGB
            case .others: value = othersTotalGB
            }
            return "\(TrafficUsageDemoData.formattedLegendGB(value)) GB"
        }

        func chartSegments(focusedCategory: TrafficCategory?) -> [DaySegment] {
            let categories = focusedCategory.map { [$0] } ?? TrafficCategory.allCases
            return (0..<7).flatMap { index in
                categories.map { category in
                    let gigabytes: Double
                    switch category {
                    case .bypassBlocks: gigabytes = bypassDaily[index]
                    case .russianSites: gigabytes = russianDaily[index]
                    case .others: gigabytes = othersDaily[index]
                    }
                    return DaySegment(dayIndex: index, category: category, gigabytes: gigabytes)
                }
            }
        }
    }

    private static let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var showsProviderFilter: Bool {
        scopedProviderID == nil && providers.count > 1
    }

    private var effectiveProviderFilterID: UUID? {
        scopedProviderID ?? selectedProviderID
    }

    private var trafficSnapshot: TrafficUsageSnapshot {
        TrafficUsageDemoData.snapshot(
            providerFilterID: effectiveProviderFilterID,
            period: selectedPeriod,
            providers: providers
        )
    }

    private var chartSegments: [DaySegment] {
        trafficSnapshot.chartSegments(focusedCategory: focusedCategory)
    }

    private var providerFilterLabel: String {
        guard let effectiveProviderFilterID,
              let name = providers.first(where: { $0.id == effectiveProviderFilterID })?.name else {
            return VPNFigmaSection550Copy.allProvidersUsageFilter
        }
        return VPNFigmaSection550Copy.providerUsageFilter(providerName: name)
    }

    private var scopedUsageFilterTitle: String {
        guard let scopedProviderID else {
            return VPNFigmaSection550Copy.allProvidersUsageFilter
        }
        let name = providers.first(where: { $0.id == scopedProviderID })?.name
            ?? VPNProvider.samples.first(where: { $0.id == scopedProviderID })?.name
            ?? "Provider"
        return VPNFigmaSection550Copy.providerUsageFilter(providerName: name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                if showsHeading {
                    if showsProviderFilter {
                        providerFilterMenu
                    } else {
                        Text(heading ?? scopedUsageFilterTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 8)
                } else {
                    Spacer(minLength: 0)
                }
                periodFilterMenu
            }

            Chart {
                ForEach(chartSegments) { segment in
                    BarMark(
                        x: .value("Day", segment.dayIndex),
                        y: .value("GB", segment.gigabytes),
                        width: .fixed(34)
                    )
                    .foregroundStyle(by: .value("Category", ui(segment.category.rawValue)))
                }
            }
            .chartForegroundStyleScale([
                ui(TrafficCategory.bypassBlocks.rawValue): TrafficCategory.bypassBlocks.color,
                ui(TrafficCategory.russianSites.rawValue): TrafficCategory.russianSites.color,
                ui(TrafficCategory.others.rawValue): TrafficCategory.others.color,
            ])
            .chartXScale(domain: -0.35...6.35)
            .chartYScale(domain: 0...trafficSnapshot.chartYMax)
            .chartXAxis {
                AxisMarks(values: Array(0...6)) { value in
                    if let index = value.as(Int.self), index < Self.weekdayLabels.count {
                        AxisValueLabel(Self.weekdayLabels[index])
                            .font(.caption2)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartLegend(.hidden)
            .chartPlotStyle { plot in
                plot
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(.horizontal, 4)
            }
            .animation(.easeInOut(duration: 0.25), value: focusedCategory)
            .animation(.easeInOut(duration: 0.25), value: effectiveProviderFilterID)
            .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
            .frame(height: 188)

            trafficCategoryLegend

            if showsUsageMeters {
                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    trafficUsageMeter(
                        percent: trafficSnapshot.wifiUsedPercent,
                        label: ui("basic traffic used"),
                        fraction: Double(trafficSnapshot.wifiUsedPercent) / 100,
                        detail: trafficSnapshot.wifiUsedDetail
                    )
                    trafficUsageMeter(
                        percent: trafficSnapshot.lteUsedPercent,
                        label: ui("LTE traffic used"),
                        fraction: Double(trafficSnapshot.lteUsedPercent) / 100,
                        detail: trafficSnapshot.lteUsedDetail
                    )
                }
            }
        }
        .padding(embedInForm ? 0 : 16)
        .background {
            if !embedInForm {
                Color(.secondarySystemGroupedBackground)
                    .clipShape(
                        RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous)
                    )
            }
        }
        .onChange(of: effectiveProviderFilterID) { _, _ in
            focusedCategory = nil
        }
        .onChange(of: selectedPeriod) { _, _ in
            focusedCategory = nil
        }
    }

    private var yAxisValues: [Double] {
        let maxValue = trafficSnapshot.chartYMax
        if maxValue <= 12 {
            return stride(from: 0, through: 12, by: 2).map { Double($0) }
        }
        let step = max(1, (maxValue / 6).rounded())
        return stride(from: 0.0, through: maxValue, by: step).map { $0 }
    }

    private var providerFilterMenu: some View {
        Menu {
            Picker(ui("Provider"), selection: $selectedProviderID) {
                Text(VPNFigmaSection550Copy.allProvidersUsageFilter).tag(UUID?.none)
                ForEach(providers) { provider in
                    Text(VPNFigmaSection550Copy.providerUsageFilter(providerName: provider.name))
                        .tag(Optional(provider.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            filterMenuLabel(title: providerFilterLabel, emphasis: .primary)
        }
        .accessibilityLabel(ui("Filter by provider"))
    }

    private var periodFilterMenu: some View {
        Menu {
            Picker(ui("Period"), selection: $selectedPeriod) {
                ForEach(TrafficUsagePeriod.allCases) { period in
                    Text(ui(period.rawValue)).tag(period)
                }
            }
            .pickerStyle(.inline)
        } label: {
            filterMenuLabel(title: ui(selectedPeriod.rawValue), emphasis: .secondary)
        }
        .accessibilityLabel(ui("Filter by period"))
    }

    private enum FilterMenuEmphasis {
        case primary
        case secondary
    }

    private func filterMenuLabel(title: String, emphasis: FilterMenuEmphasis) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(emphasis == .primary ? .body.weight(.semibold) : .subheadline)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(emphasis == .primary ? Color.primary : Color.secondary)
    }

    private var trafficCategoryLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            categoryLegendItem(.bypassBlocks)

            HStack(alignment: .firstTextBaseline, spacing: 28) {
                categoryLegendItem(.russianSites)
                categoryLegendItem(.others)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryLegendItem(_ category: TrafficCategory) -> some View {
        let isSelected = focusedCategory == category
        let isDimmed = focusedCategory != nil && !isSelected

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                focusedCategory = isSelected ? nil : category
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Capsule(style: .continuous)
                    .fill(category.color.opacity(isDimmed ? 0.35 : 1))
                    .frame(width: 3, height: 14)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ui(category.rawValue))
                        .foregroundStyle(isDimmed ? .secondary : .primary)
                    Text(trafficSnapshot.legendTotal(for: category))
                        .fontWeight(.semibold)
                        .foregroundStyle(isDimmed ? .secondary : .primary)
                }
            }
            .font(.body)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func trafficUsageMeter(
        percent: Int,
        label: String,
        fraction: Double,
        detail: String
    ) -> some View {
        let clamped = min(max(fraction, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(percent)%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(" \(label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(
                        cornerRadius: VelvetMetrics.statsStripProgressCornerRadius,
                        style: .continuous
                    )
                    .fill(VelvetTheme.statsStripProgressTrack)

                    RoundedRectangle(
                        cornerRadius: VelvetMetrics.statsStripProgressCornerRadius,
                        style: .continuous
                    )
                    .fill(VelvetTheme.trafficProgressTint)
                    .frame(width: geometry.size.width * clamped)
                }
            }
            .frame(height: VelvetMetrics.statsStripProgressHeight)
        }
    }

    private enum TrafficUsageDemoData {
        static let velvetProviderID = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
        static let nordProviderID = UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!
        static let surfsharkProviderID = UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!
        static let protonProviderID = UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!

        private struct Template {
            let bypassTotalGB: Double
            let russianTotalGB: Double
            let othersTotalGB: Double
            let bypassDaily: [Double]
            let russianDaily: [Double]
            let othersDaily: [Double]
            let wifiUsedPercent: Int
            let wifiUsedDetail: String
            let lteUsedPercent: Int
            let lteUsedDetail: String
        }

        private static let velvetWeek = Template(
            bypassTotalGB: 242,
            russianTotalGB: 23,
            othersTotalGB: 9,
            bypassDaily: [6, 8, 9, 10, 9, 7, 5],
            russianDaily: [1, 2, 2, 3, 2, 2, 1],
            othersDaily: [0.5, 1, 1, 1.5, 1, 0.5, 0.5],
            wifiUsedPercent: 13,
            wifiUsedDetail: "332 / 2 064 000 GB",
            lteUsedPercent: 62,
            lteUsedDetail: "32 GB / 40 GB"
        )

        static func snapshot(
            providerFilterID: UUID?,
            period: TrafficUsagePeriod,
            providers: [VPNProvider]
        ) -> TrafficUsageSnapshot {
            let template: Template
            if let providerFilterID {
                template = scaledTemplate(velvetWeek, factor: weight(for: providerFilterID))
            } else {
                let providerIDs = providers.isEmpty
                    ? [velvetProviderID, nordProviderID, surfsharkProviderID, protonProviderID]
                    : providers.map(\.id)
                let weighted = providerIDs.map { scaledTemplate(velvetWeek, factor: weight(for: $0)) }
                template = weighted.dropFirst().reduce(weighted.first ?? velvetWeek, combine)
            }

            let periodScale = period == .thisMonth ? 4.3 : 1.0
            let scaled = scaledTemplate(template, factor: periodScale)

            let totalGB = scaled.bypassTotalGB + scaled.russianTotalGB + scaled.othersTotalGB
            let periodTotalLabel = period == .thisMonth
                ? "\(formattedLegendGB(totalGB)) GB this month"
                : "\(formattedLegendGB(totalGB)) GB total"

            let dailyPeak = (0..<7).map { index in
                scaled.bypassDaily[index] + scaled.russianDaily[index] + scaled.othersDaily[index]
            }.max() ?? 12
            let chartYMax = max(12, (dailyPeak * 1.15 * 10).rounded() / 10)

            return TrafficUsageSnapshot(
                periodTotalLabel: periodTotalLabel,
                bypassTotalGB: scaled.bypassTotalGB,
                russianTotalGB: scaled.russianTotalGB,
                othersTotalGB: scaled.othersTotalGB,
                bypassDaily: scaled.bypassDaily,
                russianDaily: scaled.russianDaily,
                othersDaily: scaled.othersDaily,
                wifiUsedPercent: scaled.wifiUsedPercent,
                wifiUsedDetail: scaled.wifiUsedDetail,
                lteUsedPercent: scaled.lteUsedPercent,
                lteUsedDetail: scaled.lteUsedDetail,
                chartYMax: chartYMax
            )
        }

        static func formattedLegendGB(_ value: Double) -> String {
            if value >= 1000 {
                let terabytes = value / 1000
                if terabytes >= 10, terabytes.rounded() == terabytes {
                    return String(format: "%.0f TB", terabytes)
                }
                return String(format: "%.1f TB", terabytes)
            }
            if value >= 10, value.rounded() == value {
                return String(format: "%.0f", value)
            }
            return String(format: "%.1f", value)
        }

        private static func weight(for providerID: UUID) -> Double {
            switch providerID {
            case velvetProviderID: 1.0
            case nordProviderID: 0.36
            case surfsharkProviderID: 0.22
            case protonProviderID: 0.05
            default: 0.18
            }
        }

        private static func scaledTemplate(_ template: Template, factor: Double) -> Template {
            Template(
                bypassTotalGB: template.bypassTotalGB * factor,
                russianTotalGB: template.russianTotalGB * factor,
                othersTotalGB: template.othersTotalGB * factor,
                bypassDaily: template.bypassDaily.map { $0 * factor },
                russianDaily: template.russianDaily.map { $0 * factor },
                othersDaily: template.othersDaily.map { $0 * factor },
                wifiUsedPercent: min(100, max(0, Int((Double(template.wifiUsedPercent) * factor).rounded()))),
                wifiUsedDetail: template.wifiUsedDetail,
                lteUsedPercent: min(100, max(0, Int((Double(template.lteUsedPercent) * factor).rounded()))),
                lteUsedDetail: template.lteUsedDetail
            )
        }

        private static func combine(_ lhs: Template, _ rhs: Template) -> Template {
            Template(
                bypassTotalGB: lhs.bypassTotalGB + rhs.bypassTotalGB,
                russianTotalGB: lhs.russianTotalGB + rhs.russianTotalGB,
                othersTotalGB: lhs.othersTotalGB + rhs.othersTotalGB,
                bypassDaily: zip(lhs.bypassDaily, rhs.bypassDaily).map(+),
                russianDaily: zip(lhs.russianDaily, rhs.russianDaily).map(+),
                othersDaily: zip(lhs.othersDaily, rhs.othersDaily).map(+),
                wifiUsedPercent: min(100, max(lhs.wifiUsedPercent, rhs.wifiUsedPercent)),
                wifiUsedDetail: lhs.wifiUsedDetail,
                lteUsedPercent: min(100, max(lhs.lteUsedPercent, rhs.lteUsedPercent)),
                lteUsedDetail: lhs.lteUsedDetail
            )
        }
    }
}
