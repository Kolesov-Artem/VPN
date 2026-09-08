import SwiftUI

/// Shared context passed to chrome and scroll content builders inside the curtain.
struct BottomPanelCurtainContext {
    let layout: BottomPanelVisualState
    let detents: BottomPanelDetents
    let position: BottomPanelPosition
    let isDraggingPanel: Bool
    let scrollEdgeProgress: CGFloat

    let collapseExpanded: () -> Void
    let togglePosition: () -> Void
}

/// Unified bottom panel shell: grip resize, fixed chrome, coordinated scroll, footer slot.
struct BottomPanelCurtain<Header: View, Stats: View, Footer: View, ScrollContent: View>: View {
    @Binding var position: BottomPanelPosition
    @Binding var isPanelInteracting: Bool

    let showsSessionStats: Bool
    let safeAreaBottom: CGFloat
    let safeAreaTop: CGFloat
    var compactBarTitle: String = "Velvet VPN"
    var detentMode: VPNPanelDetentMode = .stepped
    var onDismissSearch: (() -> Void)?

    @ViewBuilder let header: (BottomPanelCurtainContext) -> Header
    @ViewBuilder let stats: () -> Stats
    @ViewBuilder let footer: () -> Footer
    @ViewBuilder let scrollContent: (BottomPanelCurtainContext) -> ScrollContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingPanel = false
    @State private var isPositionAnimating = false
    @State private var positionAnimationTask: Task<Void, Never>?
    @State private var isScrollAtTop = true
    @State private var scrollEdgeProgress: CGFloat = 0
    @State private var scrollResetToken = UUID()

    var body: some View {
        GeometryReader { proxy in
            let detents = BottomPanelDetents.makeIsland(
                screenHeight: proxy.size.height + safeAreaBottom,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                showsSessionStats: showsSessionStats
            )
            let layout = BottomPanelInterpolator.displayLayout(
                detents: detents,
                position: position,
                dragTranslation: dragTranslation,
                isDragLite: isDraggingPanel
            )
            let panelInteracting = isDraggingPanel || isPositionAnimating
            let expandedTopInset = max(safeAreaTop - VelvetTheme.expandedTopInsetReduction, 0)
            let context = makeContext(detents: detents, layout: layout)
            let scrollBottomInset = LocationSearchChrome.scrollBottomPadding(
                revealProgress: listRevealProgress(layout: layout),
                bottomMargin: LocationSearchChrome.screenBottomOffset(
                    panelBottomMargin: detents.bottomMargin
                ),
                contentInset: detents.contentBottomInset
            )

            Color.clear
                .allowsHitTesting(false)
                .overlay(alignment: .bottom) {
                    curtainCard(
                        detents: detents,
                        layout: layout,
                        context: context,
                        expandedTopInset: expandedTopInset,
                        scrollBottomInset: scrollBottomInset
                    )
                }
                .onChange(of: panelInteracting) { _, interacting in
                    isPanelInteracting = interacting
                }
                .onAppear {
                    isPanelInteracting = panelInteracting
                }
        }
        .sensoryFeedback(.selection, trigger: position)
        .onChange(of: position) { _, newValue in
            if newValue != .expanded {
                scrollEdgeProgress = 0
            }
            if newValue != .expanded {
                scrollResetToken = UUID()
            }
        }
    }

    private func makeContext(
        detents: BottomPanelDetents,
        layout: BottomPanelVisualState
    ) -> BottomPanelCurtainContext {
        BottomPanelCurtainContext(
            layout: layout,
            detents: detents,
            position: position,
            isDraggingPanel: isDraggingPanel,
            scrollEdgeProgress: scrollEdgeProgress,
            collapseExpanded: collapseExpandedPanel,
            togglePosition: togglePosition
        )
    }

    private func listRevealProgress(layout: BottomPanelVisualState) -> CGFloat {
        switch position {
        case .expanded, .intermediate:
            1
        case .island:
            layout.listProgress
        }
    }

    private func curtainCard(
        detents: BottomPanelDetents,
        layout: BottomPanelVisualState,
        context: BottomPanelCurtainContext,
        expandedTopInset: CGFloat,
        scrollBottomInset: CGFloat
    ) -> some View {
        let shape = panelShape(layout: layout)
        let footerOpacity = footerVisibility(for: layout)
        let listOpacity = layout.listProgress
        let listAcceptsTaps = position != .island && !isDraggingPanel
        let allowsContentScroll = position == .expanded

        return VStack(spacing: 0) {
            gripBand(detents: detents)

            ZStack {
                header(context)
                    .opacity(1 - scrollEdgeProgress)
                    .allowsHitTesting(!isDraggingPanel && scrollEdgeProgress < 0.5)

                ExpandedSheetCompactBar(
                    title: compactBarTitle,
                    scrollEdgeProgress: scrollEdgeProgress,
                    onCollapse: collapseExpandedPanel
                )
            }
            .frame(height: VelvetMetrics.panelHeaderRowHeight)
            .allowsHitTesting(!isDraggingPanel)
            .modifier(PanelChromeDragModifier(
                isActive: !allowsContentScroll,
                gesture: gripDragGesture(detents: detents)
            ))

            stats()
                .modifier(PanelChromeDragModifier(
                    isActive: !allowsContentScroll,
                    gesture: gripDragGesture(detents: detents)
                ))

            PanelScrollCoordinator(
                isScrollEnabled: allowsContentScroll,
                bottomContentInset: scrollBottomInset,
                isScrollAtTop: $isScrollAtTop,
                scrollEdgeProgress: $scrollEdgeProgress,
                onPanelDragChanged: { translation in
                    beginPanelDragIfNeeded()
                    dragTranslation = translation
                },
                onPanelDragEnded: { translation, predicted in
                    snapPanel(
                        detents: detents,
                        translation: translation,
                        predictedEndTranslation: predicted
                    )
                }
            ) {
                scrollContent(context)
                    .opacity(listOpacity)
                    .allowsHitTesting(listAcceptsTaps)
                    .padding(.top, 12)
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
            .id(scrollResetToken)

            if footerOpacity > 0.01 {
                footer()
                    .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
                    .padding(.bottom, VelvetMetrics.collapsedBottomPadding)
                    .opacity(footerOpacity)
                    .allowsHitTesting(footerOpacity > 0.5 && !isDraggingPanel)
            }
        }
        .frame(height: layout.panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            VelvetPanelBackground()
        }
        .clipShape(shape)
        .shadow(
            color: .black.opacity(layout.shadowOpacity),
            radius: layout.shadowRadius,
            y: layout.shadowY
        )
        .padding(.top, expandedTopInset * layout.sheetMorphProgress)
        .padding(.horizontal, layout.horizontalInset)
        .padding(.bottom, layout.bottomInset)
    }

    private func footerVisibility(for layout: BottomPanelVisualState) -> CGFloat {
        if position == .island, dragTranslation == 0, !isDraggingPanel {
            return 1
        }
        return layout.collapsedContentOpacity
    }

    private func panelShape(layout: BottomPanelVisualState) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: VelvetTheme.panelRadius,
            bottomLeadingRadius: layout.bottomCornerRadius,
            bottomTrailingRadius: layout.bottomCornerRadius,
            topTrailingRadius: VelvetTheme.panelRadius
        )
    }

    private func gripBand(detents: BottomPanelDetents) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.42))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Drag to resize panel")
            .bottomPanelDragHandle(
                gesture: gripDragGesture(detents: detents)
            )
    }

    private func gripDragGesture(detents: BottomPanelDetents) -> some Gesture {
        DragGesture(minimumDistance: BottomPanelDragMetrics.minimumDistance)
            .onChanged { value in
                beginPanelDragIfNeeded()
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                snapPanel(
                    detents: detents,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height
                )
            }
    }

    private func beginPanelDragIfNeeded() {
        if !isDraggingPanel {
            onDismissSearch?()
        }
        isDraggingPanel = true
    }

    private func snapPanel(
        detents: BottomPanelDetents,
        translation: CGFloat,
        predictedEndTranslation: CGFloat
    ) {
        let target = BottomPanelSnapResolver.resolve(
            current: position,
            translation: translation,
            predictedEndTranslation: predictedEndTranslation,
            detents: detents,
            mode: detentMode
        )
        isDraggingPanel = false
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = target
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func schedulePositionAnimationEnd() {
        positionAnimationTask?.cancel()
        let delay = VelvetMotion.panelSettleDelay(reduceMotion: reduceMotion)
        positionAnimationTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            isPositionAnimating = false
        }
    }

    private func collapseExpandedPanel() {
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .intermediate
            dragTranslation = 0
            isDraggingPanel = false
        }
        schedulePositionAnimationEnd()
    }

    private func togglePosition() {
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            switch position {
            case .island:
                position = detentMode == .direct ? .expanded : .intermediate
            case .intermediate:
                position = .expanded
            case .expanded:
                position = detentMode == .direct ? .island : .intermediate
            }
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }
}

private struct PanelChromeDragModifier<G: Gesture>: ViewModifier {
    let isActive: Bool
    let gesture: G

    func body(content: Content) -> some View {
        if isActive {
            content
                .contentShape(Rectangle())
                .gesture(gesture)
        } else {
            content
        }
    }
}
