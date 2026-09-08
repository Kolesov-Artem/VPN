import CoreGraphics
import Foundation

enum BottomPanelPosition: Equatable {
    case island
    case intermediate
    case expanded

    /// Half-height detents should grow to full screen once search becomes active.
    func expandedForActiveSearch(
        isFocused: Bool,
        queryText: String,
        detentMode: VPNPanelDetentMode = .stepped
    ) -> BottomPanelPosition? {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isFocused || !trimmed.isEmpty else { return nil }
        guard self != .expanded else { return nil }

        switch detentMode {
        case .stepped:
            guard self == .intermediate else { return nil }
            return .expanded
        case .direct:
            return .expanded
        }
    }

    /// Chevron / compact-bar target one step lower than the current detent.
    func collapsedByOneStep(detentMode: VPNPanelDetentMode) -> BottomPanelPosition {
        switch detentMode {
        case .stepped:
            nextLower
        case .direct:
            .island
        }
    }

    /// Chevron target one step higher than the current detent.
    func expandedByOneStep(detentMode: VPNPanelDetentMode) -> BottomPanelPosition {
        switch detentMode {
        case .stepped:
            nextHigher
        case .direct:
            .expanded
        }
    }

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
    /// Status bar / Dynamic Island clearance for the full-screen sheet.
    let topMargin: CGFloat

    /// Visual height of the drag-indicator capsule and its padding.
    static let expandedGripBandHeight: CGFloat = 8 + 5 + 6
    /// Touch target for the drag handle — wider than the visible capsule.
    static let expandedGripHitHeight: CGFloat = 52

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
        isAccessibilitySize: Bool,
        showsSessionStats: Bool = false
    ) -> BottomPanelDetents {
        let expandedHeight = screenHeight * 0.92
        let rawIntermediateHeight = screenHeight * (isAccessibilitySize ? 0.64 : 0.56)
        let heights = orderedDetentHeights(
            expandedHeight: expandedHeight,
            rawIntermediateHeight: rawIntermediateHeight,
            showsSessionStats: showsSessionStats,
            isAccessibilitySize: isAccessibilitySize
        )

        return BottomPanelDetents(
            expandedHeight: expandedHeight,
            intermediateHeight: heights.intermediate,
            islandHeight: heights.island,
            bottomMargin: max(safeAreaBottom, VelvetTheme.minimumBottomMargin),
            topMargin: 0
        )
    }

    /// Heights for the hand-built floating island. Like Find My, it grows from a
    /// small inset card through a half-height detent to a full-screen sheet.
    static func makeIsland(
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat,
        safeAreaTop: CGFloat,
        isAccessibilitySize: Bool,
        showsSessionStats: Bool = false
    ) -> BottomPanelDetents {
        let topMargin = max(safeAreaTop - VelvetTheme.expandedTopInsetReduction, 0)
        let expandedHeight = screenHeight - topMargin
        let rawIntermediateHeight = screenHeight * (isAccessibilitySize ? 0.64 : 0.50)
        let heights = orderedDetentHeights(
            expandedHeight: expandedHeight,
            rawIntermediateHeight: rawIntermediateHeight,
            showsSessionStats: showsSessionStats,
            isAccessibilitySize: isAccessibilitySize
        )

        return BottomPanelDetents(
            expandedHeight: expandedHeight,
            intermediateHeight: heights.intermediate,
            islandHeight: heights.island,
            bottomMargin: max(safeAreaBottom, VelvetTheme.minimumBottomMargin),
            topMargin: topMargin
        )
    }

    /// Keeps island < intermediate < expanded even when the connected island
    /// grows taller than the nominal half-screen detent on short viewports.
    private static func orderedDetentHeights(
        expandedHeight: CGFloat,
        rawIntermediateHeight: CGFloat,
        showsSessionStats: Bool,
        isAccessibilitySize: Bool
    ) -> (island: CGFloat, intermediate: CGFloat) {
        let minGap: CGFloat = 8
        let rawIsland = VelvetCollapsedIslandLayout.islandHeight(
            showsSessionStats: showsSessionStats,
            isAccessibilitySize: isAccessibilitySize
        )
        var intermediate = max(rawIntermediateHeight, rawIsland + minGap)
        intermediate = min(intermediate, expandedHeight - minGap)
        let island = min(rawIsland, intermediate - minGap)
        return (island, intermediate)
    }

    func summaryBottomPadding(for position: BottomPanelPosition) -> CGFloat {
        let bottomGap: CGFloat = switch position {
        case .island: bottomMargin
        case .intermediate: VelvetTheme.islandHalfMargin
        case .expanded: 0
        }
        return height(for: position) + bottomGap + 24
    }
}

struct BottomPanelVisualState {
    let panelHeight: CGFloat
    let horizontalInset: CGFloat
    let bottomInset: CGFloat
    let bottomCornerRadius: CGFloat
    /// Island → intermediate: list reveal and bottom margin clearance.
    let revealProgress: CGFloat
    /// Intermediate → expanded: edge-to-edge sheet morph.
    let sheetMorphProgress: CGFloat
    let collapsedContentOpacity: CGFloat
    let listProgress: CGFloat
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat
}

/// Drives the floating island: it interpolates every visual property from the
/// live drag so the panel tracks the finger instead of snapping between states.
/// Content reveal (list vs connect) finishes by the intermediate detent; card
/// morph (insets, corners, shadow) runs across the full island-to-expanded range,
/// matching Find My's half-height list and full-screen sheet.
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

        let revealRange = max(detents.intermediateHeight - detents.islandHeight, 1)
        let revealProgress = clamp(
            (effectiveHeight - detents.islandHeight) / revealRange,
            lower: 0,
            upper: 1
        )

        let sheetMorphRange = max(detents.expandedHeight - detents.intermediateHeight, 1)
        let sheetMorphProgress = clamp(
            (effectiveHeight - detents.intermediateHeight) / sheetMorphRange,
            lower: 0,
            upper: 1
        )

        let collapsedOpacity = 1 - smoothStep(revealProgress, from: 0.08, to: 0.82)
        let listProgress = smoothStep(revealProgress, from: 0.12, to: 0.88)

        let floatingHorizontalInset =
            VelvetTheme.islandHorizontalInset
            + (VelvetTheme.islandHalfMargin - VelvetTheme.islandHorizontalInset) * revealProgress
        let floatingBottomInset =
            detents.bottomMargin
            + (VelvetTheme.islandHalfMargin - detents.bottomMargin) * revealProgress

        let islandShadow = VelvetTheme.islandShadowOpacity
        let expandedShadow = VelvetTheme.expandedShadowOpacity
        let shadowOpacity = islandShadow + (expandedShadow - islandShadow) * sheetMorphProgress

        return BottomPanelVisualState(
            panelHeight: effectiveHeight,
            horizontalInset: floatingHorizontalInset * (1 - sheetMorphProgress),
            bottomInset: floatingBottomInset * (1 - sheetMorphProgress),
            bottomCornerRadius: VelvetTheme.panelRadius * (1 - sheetMorphProgress),
            revealProgress: revealProgress,
            sheetMorphProgress: sheetMorphProgress,
            collapsedContentOpacity: collapsedOpacity,
            listProgress: listProgress,
            shadowOpacity: shadowOpacity,
            shadowRadius: 20 + 4 * sheetMorphProgress,
            shadowY: -4 - 4 * sheetMorphProgress
        )
    }

    /// While dragging, height tracks the finger 1:1; only shadow is frozen to avoid shimmer.
    static func displayLayout(
        detents: BottomPanelDetents,
        position: BottomPanelPosition,
        dragTranslation: CGFloat,
        isDragLite: Bool
    ) -> BottomPanelVisualState {
        let layout = layout(
            detents: detents,
            position: position,
            dragTranslation: dragTranslation
        )
        guard isDragLite else { return layout }

        return BottomPanelVisualState(
            panelHeight: layout.panelHeight,
            horizontalInset: layout.horizontalInset,
            bottomInset: layout.bottomInset,
            bottomCornerRadius: layout.bottomCornerRadius,
            revealProgress: layout.revealProgress,
            sheetMorphProgress: layout.sheetMorphProgress,
            collapsedContentOpacity: layout.collapsedContentOpacity,
            listProgress: layout.listProgress,
            shadowOpacity: VelvetTheme.islandShadowOpacity,
            shadowRadius: 20,
            shadowY: -4
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

enum BottomPanelDragMetrics {
    static let minimumDistance: CGFloat = 8
    static let verticalDominancePadding: CGFloat = 4

    static func isVerticalDominant(translation: CGSize) -> Bool {
        abs(translation.height) > verticalDominancePadding
            && abs(translation.height) > abs(translation.width)
    }
}

struct BottomPanelSnapResolver {
    static let threshold: CGFloat = 52
    static let directFlingThreshold: CGFloat = 120

    static func resolve(
        current: BottomPanelPosition,
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        detents: BottomPanelDetents,
        mode: VPNPanelDetentMode = .stepped
    ) -> BottomPanelPosition {
        switch mode {
        case .stepped:
            resolveStepped(
                current: current,
                translation: translation,
                predictedEndTranslation: predictedEndTranslation
            )
        case .direct:
            resolveDirect(
                current: current,
                translation: translation,
                predictedEndTranslation: predictedEndTranslation,
                detents: detents
            )
        }
    }

    private static func resolveStepped(
        current: BottomPanelPosition,
        translation: CGFloat,
        predictedEndTranslation: CGFloat
    ) -> BottomPanelPosition {
        let projectedTranslation =
            abs(predictedEndTranslation) > abs(translation)
            ? predictedEndTranslation
            : translation

        guard abs(projectedTranslation) >= threshold else {
            return current
        }

        if projectedTranslation <= -threshold {
            return current.nextHigher
        }

        if projectedTranslation >= threshold {
            return current.nextLower
        }

        return current
    }

    private static func resolveDirect(
        current: BottomPanelPosition,
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        detents: BottomPanelDetents
    ) -> BottomPanelPosition {
        let projectedTranslation =
            abs(predictedEndTranslation) > abs(translation)
            ? predictedEndTranslation
            : translation

        let releaseHeight = detents.height(for: current) - translation
        let projectedHeight = detents.height(for: current) - projectedTranslation

        if projectedTranslation <= -directFlingThreshold,
           nearestPosition(to: projectedHeight, detents: detents) == .expanded {
            return .expanded
        }

        if projectedTranslation >= directFlingThreshold,
           nearestPosition(to: projectedHeight, detents: detents) == .island {
            return .island
        }

        if abs(projectedTranslation) < threshold {
            return current
        }

        return nearestPosition(to: releaseHeight, detents: detents)
    }

    private static func nearestPosition(
        to height: CGFloat,
        detents: BottomPanelDetents
    ) -> BottomPanelPosition {
        let candidates: [(BottomPanelPosition, CGFloat)] = [
            (.island, detents.islandHeight),
            (.intermediate, detents.intermediateHeight),
            (.expanded, detents.expandedHeight),
        ]

        return candidates.min { lhs, rhs in
            abs(lhs.1 - height) < abs(rhs.1 - height)
        }?.0 ?? .island
    }
}
