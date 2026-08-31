import CoreGraphics
import Foundation

enum BottomPanelPosition: Equatable {
    case island
    case intermediate
    case expanded

    var nextHigher: BottomPanelPosition {
        switch self {
        case .island: .intermediate
        case .intermediate, .expanded: .expanded
        }
    }

    var nextLower: BottomPanelPosition {
        switch self {
        case .island, .intermediate: .island
        case .expanded: .intermediate
        }
    }
}

struct BottomPanelDetents {
    let expandedHeight: CGFloat
    let intermediateHeight: CGFloat
    let islandHeight: CGFloat
    /// Clearance the island keeps from the screen edge so it never sits under
    /// the home indicator, per Apple's layout guidance.
    let bottomMargin: CGFloat

    func height(for position: BottomPanelPosition) -> CGFloat {
        switch position {
        case .expanded:
            expandedHeight
        case .intermediate:
            intermediateHeight
        case .island:
            islandHeight
        }
    }

    /// Inner padding the expanded sheet needs so scrolled content stops above
    /// the home indicator instead of running underneath it.
    var contentBottomInset: CGFloat {
        bottomMargin + 12
    }

    static func make(
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat,
        isAccessibilitySize: Bool
    ) -> BottomPanelDetents {
        let expandedHeight = screenHeight * 0.92
        let intermediateHeight = screenHeight * (isAccessibilitySize ? 0.64 : 0.56)
        let islandHeight: CGFloat = isAccessibilitySize ? 210 : 154

        return BottomPanelDetents(
            expandedHeight: expandedHeight,
            intermediateHeight: intermediateHeight,
            islandHeight: islandHeight,
            bottomMargin: max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
        )
    }

    /// Heights for the hand-built floating island, which stops short of the top
    /// of the screen because it never becomes a full-screen sheet.
    static func makeIsland(
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat,
        isAccessibilitySize: Bool
    ) -> BottomPanelDetents {
        let expandedHeight = screenHeight * (isAccessibilitySize ? 0.78 : 0.68)
        let islandHeight: CGFloat = isAccessibilitySize ? 210 : 154

        return BottomPanelDetents(
            expandedHeight: expandedHeight,
            intermediateHeight: expandedHeight,
            islandHeight: islandHeight,
            bottomMargin: max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
        )
    }

    func summaryBottomPadding(for position: BottomPanelPosition) -> CGFloat {
        let bottomGap = position == .island ? bottomMargin : 0
        return height(for: position) + bottomGap + 24
    }
}

struct BottomPanelVisualState {
    let panelHeight: CGFloat
    let horizontalInset: CGFloat
    let bottomInset: CGFloat
    let bottomCornerRadius: CGFloat
    let expansionProgress: CGFloat
    let collapsedContentOpacity: CGFloat
    let listProgress: CGFloat
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat
}

/// Drives the floating island: it interpolates every visual property from the
/// live drag so the panel tracks the finger instead of snapping between states.
enum BottomPanelInterpolator {
    static func layout(
        detents: BottomPanelDetents,
        position: BottomPanelPosition,
        dragTranslation: CGFloat
    ) -> BottomPanelVisualState {
        let baseHeight = detents.height(for: position)
        let effectiveHeight = boundedHeight(
            base: baseHeight,
            translation: dragTranslation,
            lowerBound: detents.islandHeight,
            upperBound: detents.expandedHeight
        )
        let range = max(detents.expandedHeight - detents.islandHeight, 1)
        let progress = clamp(
            (effectiveHeight - detents.islandHeight) / range,
            lower: 0,
            upper: 1
        )
        let collapsedOpacity = 1 - smoothStep(progress, from: 0.08, to: 0.36)
        let listProgress = smoothStep(progress, from: 0.18, to: 0.92)

        let islandShadow = VelvetTheme.islandShadowOpacity
        let expandedShadow = VelvetTheme.expandedShadowOpacity
        let shadowOpacity = islandShadow + (expandedShadow - islandShadow) * progress

        return BottomPanelVisualState(
            panelHeight: effectiveHeight,
            horizontalInset: VelvetTheme.islandHorizontalInset * (1 - progress),
            bottomInset: detents.bottomMargin * (1 - progress),
            bottomCornerRadius: VelvetTheme.panelRadius * (1 - progress),
            expansionProgress: progress,
            collapsedContentOpacity: collapsedOpacity,
            listProgress: listProgress,
            shadowOpacity: shadowOpacity,
            shadowRadius: 20 + 4 * progress,
            shadowY: -4 - 4 * progress
        )
    }

    private static func boundedHeight(
        base: CGFloat,
        translation: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        let proposed = base - translation
        let dimension = upperBound - lowerBound

        if proposed < lowerBound {
            return lowerBound - rubberBand(lowerBound - proposed, dimension: dimension)
        }

        if proposed > upperBound {
            return upperBound + rubberBand(proposed - upperBound, dimension: dimension)
        }

        return proposed
    }

    private static func rubberBand(_ overshoot: CGFloat, dimension: CGFloat) -> CGFloat {
        let constant: CGFloat = 0.55
        return (overshoot * dimension * constant)
            / (dimension + constant * abs(overshoot))
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private static func smoothStep(_ value: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        let progress = clamp((value - from) / max(to - from, 0.001), lower: 0, upper: 1)
        return progress * progress * (3 - 2 * progress)
    }
}

struct BottomPanelSnapResolver {
    static let threshold: CGFloat = 72

    static func resolve(
        current: BottomPanelPosition,
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        detents: BottomPanelDetents
    ) -> BottomPanelPosition {
        let projectedTranslation =
            abs(predictedEndTranslation) > abs(translation)
            ? predictedEndTranslation
            : translation

        guard abs(projectedTranslation) >= threshold else {
            return current
        }

        let currentHeight = detents.height(for: current)
        let targetHeight = currentHeight - projectedTranslation
        let midpoint = (detents.islandHeight + detents.expandedHeight) / 2

        return targetHeight >= midpoint ? .expanded : .island
    }
}
