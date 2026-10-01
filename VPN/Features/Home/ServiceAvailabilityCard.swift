import SwiftUI

/// Compact status pill for the home header. Opens the availability card.
struct ServiceAvailabilityPill: View {
    var model: ServiceAvailabilityModel
    var isVPNConnected: Bool
    var isExpanded: Bool
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var readings: [ServiceProbeReading] {
        model.readings(isVPNConnected: isVPNConnected)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label
                    .contentTransition(.opacity)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(height: VelvetMetrics.minTouchTarget)
            .background {
                AvailabilityGlass(
                    shape: Capsule(),
                    reduceTransparency: reduceTransparency,
                    fillOpacity: 0.78,
                    shadowRadius: 10,
                    shadowY: 4
                )
            }
            .environment(\.colorScheme, .light)
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion), value: isExpanded)
        .sensoryFeedback(.selection, trigger: isExpanded)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isExpanded ? ui("Hides the list") : ui("Shows how each site is responding"))
    }

    private var label: Text {
        if isExpanded {
            return Text(ui("Hide sites"))
        }
        if readings.isEmpty {
            return Text(ui("No sites"))
        }
        let slow = readings.filter(\.isSlow).count
        if slow == 0 {
            return Text(ui("All sites well"))
        }
        return Text(uiFormat("%lld slow", slow))
            .foregroundStyle(ServiceAvailabilityPalette.slowTitle)
    }

    private var accessibilityLabel: String {
        if isExpanded { return ui("Hide sites") }
        if readings.isEmpty { return ui("No sites") }
        let slow = readings.filter(\.isSlow).count
        if slow == 0 { return ui("All sites well") }
        return uiFormat("%lld slow", slow)
    }
}

/// Site list that grows out of the header pill.
struct ServiceAvailabilityCard: View {
    var model: ServiceAvailabilityModel
    var isVPNConnected: Bool
    /// When set, the header chevron collapses the card instead of opening site settings.
    var onCollapse: (() -> Void)? = nil
    /// Home expand is a plain white card. The island keeps the glass plate.
    var usesPlainChrome = false
    /// Outer corner of the white plate. The island glass plate is 32.
    var plateCornerRadius: CGFloat = 24
    /// Dashboard draws the list on the page, flush with the content column.
    var hidesPlate = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var spinDegrees = 0.0
    @State private var showsSettings = false
    @State private var rowsVisible = false

    private var readings: [ServiceProbeReading] {
        model.readings(isVPNConnected: isVPNConnected)
    }

    var body: some View {
        card
            .geometryGroup()
            .onAppear {
                guard !rowsVisible else { return }
                if reduceMotion {
                    rowsVisible = true
                    return
                }
                // Next turn, so the row stagger is not swallowed by the glass unfurl.
                Task { @MainActor in
                    rowsVisible = true
                }
            }
            .fullScreenCover(isPresented: $showsSettings) {
                ServiceWatchlistView(model: model)
            }
    }

    private var card: some View {
        VStack(spacing: 16) {
            headerRow
                .padding(.horizontal, hidesPlate ? 0 : 16)

            if readings.isEmpty {
                Text(ui("Add a link to start checking."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, hidesPlate ? 0 : 16)
            } else {
                grid
                    .padding(.horizontal, hidesPlate ? 0 : 8)
            }
        }
        .padding(.top, hidesPlate ? 0 : 16)
        .padding(.bottom, hidesPlate ? 0 : 8)
        .background {
            if !hidesPlate {
                chrome
            }
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var chrome: some View {
        if usesPlainChrome {
            RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                .fill(Color.white)
        } else {
            AvailabilityGlass(
                shape: RoundedRectangle(cornerRadius: 32, style: .continuous),
                reduceTransparency: reduceTransparency,
                shadowRadius: reduceMotion ? 20 : 0,
                shadowY: reduceMotion ? 8 : 0
            )
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                titleText
                    .font(.body)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(measurement, value: measurementToken)

                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            refreshButton
            settingsButton
        }
    }

    private var titleText: Text {
        if readings.isEmpty {
            return Text(ui("No sites yet"))
        }
        let slow = readings.filter(\.isSlow).count
        if slow == 0 {
            return Text(ui("All sites works well"))
        }
        return Text(uiFormat("%lld works slow", slow))
            .foregroundStyle(ServiceAvailabilityPalette.slowTitle)
    }

    @ViewBuilder
    private var subtitle: some View {
        TimelineView(.periodic(from: model.updatedAt, by: 1)) { context in
            Text(model.updatedLabel(at: context.date))
        }
    }

    private var refreshButton: some View {
        Button(action: refresh) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .semibold))
                .rotationEffect(.degrees(spinDegrees))
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(ui("Refresh"))
    }

    private var settingsButton: some View {
        Button {
            if let onCollapse {
                onCollapse()
            } else {
                showsSettings = true
            }
        } label: {
            Image(systemName: onCollapse == nil ? "gearshape" : "chevron.up")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(onCollapse == nil ? ui("Sites") : ui("Hide sites"))
    }

    @ViewBuilder
    private var grid: some View {
        let content = gridRows
            .animation(measurement, value: measurementToken)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        if readings.count > 10 {
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: 220)
        } else {
            content
        }
    }

    private var gridRows: some View {
        VStack(spacing: 1) {
            ForEach(Array(probeRows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 1) {
                    cell(row.leading)
                    if let trailing = row.trailing {
                        cell(trailing)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .opacity(reduceMotion || rowsVisible ? 1 : 0)
                .offset(y: reduceMotion || rowsVisible ? 0 : VelvetMotion.chipEntranceOffsetY)
                .animation(
                    VelvetMotion.staggeredReveal(
                        index: index,
                        isHidden: !rowsVisible,
                        reduceMotion: reduceMotion
                    ),
                    value: rowsVisible
                )
            }
        }
    }

    private func cell(_ reading: ServiceProbeReading) -> some View {
        HStack(spacing: 8) {
            Text(reading.name)
                .font(.system(size: 14))
                .foregroundStyle(reading.isSlow ? ServiceAvailabilityPalette.inverseText : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            Text("\(reading.latencyMs) ms")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(reading.isSlow ? ServiceAvailabilityPalette.inverseText : Color.secondary)
                .contentTransition(reduceMotion ? .opacity : .numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(reading.isSlow ? ServiceAvailabilityPalette.slowFill : Color(.secondarySystemFill))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reading.name), \(reading.latencyMs) milliseconds")
        .accessibilityValue(reading.isSlow ? ui("Slow") : ui("Responding"))
    }

    private var probeRows: [ProbeRow] {
        var rows: [ProbeRow] = []
        var index = 0
        while index < readings.count {
            let leading = readings[index]
            let trailing = index + 1 < readings.count ? readings[index + 1] : nil
            rows.append(ProbeRow(id: leading.id, leading: leading, trailing: trailing))
            index += 2
        }
        return rows
    }

    private var measurementToken: String {
        let latencies = readings.map(\.latencyMs)
        return "\(isVPNConnected)-\(latencies)"
    }

    private var measurement: Animation {
        VelvetMotion.contentCrossfade(reduceMotion: reduceMotion)
    }

    private func refresh() {
        withAnimation(VelvetMotion.contentCrossfade(reduceMotion: reduceMotion)) {
            model.refresh()
        }
        guard !reduceMotion else { return }
        withAnimation(VelvetMotion.easeOut(duration: VelvetMotion.quickDuration)) {
            spinDegrees += 360
        }
    }
}

private struct AvailabilityGlass<S: Shape>: View {
    var shape: S
    var reduceTransparency: Bool
    var fillOpacity: Double = 0.6
    var shadowRadius: CGFloat = 20
    var shadowY: CGFloat = 8

    var body: some View {
        shape
            .fill(reduceTransparency ? AnyShapeStyle(Color.white) : AnyShapeStyle(.ultraThinMaterial))
            .overlay {
                if !reduceTransparency {
                    shape.fill(Color.white.opacity(fillOpacity))
                }
            }
            .shadow(color: .black.opacity(0.12), radius: shadowRadius, y: shadowY)
    }
}

private struct ProbeRow: Identifiable {
    let id: UUID
    let leading: ServiceProbeReading
    let trailing: ServiceProbeReading?
}

enum ServiceAvailabilityPalette {
    static let slowTitle = Color(red: 189 / 255, green: 75 / 255, blue: 0)
    static let slowFill = Color(red: 209 / 255, green: 127 / 255, blue: 27 / 255)
    static let inverseText = Color(red: 252 / 255, green: 252 / 255, blue: 252 / 255)
}
