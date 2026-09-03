import SwiftUI

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() {
            value = next
        }
    }
}

/// The hand-built floating island: it keeps its own drag gesture and height
/// interpolation, so it can sit inset from the screen edges the way a system
/// sheet never can. Scrolling stays inside the location list.
struct VPNIslandPanel: View {
    @Binding var position: BottomPanelPosition
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation
    @Binding var isPanelInteracting: Bool
    var onShowConnectionInfo: (() -> Void)? = nil

    let mockPublicIP: String
    let downloadRate: String
    let uploadRate: String
    let sessionDurationText: String

    let safeAreaBottom: CGFloat
    let safeAreaTop: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var dragTranslation: CGFloat = 0
    @State private var scrollChromeMinY: CGFloat?
    @State private var scrollRestMinY: CGFloat?
    @State private var scrollEdgeProgress: CGFloat = 0
    @State private var isScrollAtTop = true
    @State private var isDraggingPanel = false
    @State private var isCollapsingFromScroll = false
    @State private var isPositionAnimating = false
    @FocusState private var searchIsFocused: Bool
    @State private var query = VPNLocationQuery()
    @State private var showsDeleteConfirmation = false

    var body: some View {
        GeometryReader { proxy in
            let detents = BottomPanelDetents.makeIsland(
                screenHeight: proxy.size.height + safeAreaBottom,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let layout = BottomPanelInterpolator.layout(
                detents: detents,
                position: position,
                dragTranslation: dragTranslation
            )
            let panelInteracting = isDraggingPanel || isCollapsingFromScroll || isPositionAnimating
            let expandedTopInset = max(safeAreaTop - VelvetTheme.expandedTopInsetReduction, 0)
            let searchRevealProgress = locationSearchRevealProgress(layout: layout)
            let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
                panelBottomMargin: detents.bottomMargin
            )
            let viewportHeight = min(
                proxy.size.height,
                max(0, UIScreen.main.bounds.maxY - proxy.frame(in: .global).minY)
            )

            Color.clear
                .allowsHitTesting(false)
                .overlay(alignment: .bottom) {
                    panelCard(
                        detents: detents,
                        layout: layout,
                        expandedTopInset: expandedTopInset
                    )
                }
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(
                            width: proxy.size.width,
                            height: viewportHeight
                        )
                        .overlay(alignment: .bottom) {
                            if searchRevealProgress > 0.01 {
                                PanelLocationSearchControls(
                                    query: $query,
                                    isFocused: $searchIsFocused,
                                    bottomMargin: searchScreenOffset,
                                    safeAreaBottom: detents.bottomMargin
                                )
                                .opacity(searchRevealProgress)
                                .allowsHitTesting(searchRevealProgress > 0.35)
                            }
                        }
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
            if newValue == .island {
                searchIsFocused = false
                query.text = ""
            }
            if newValue != .expanded {
                isScrollAtTop = true
                scrollEdgeProgress = 0
                isCollapsingFromScroll = false
            }
        }
        .onChange(of: searchIsFocused) { _, focused in
            expandPanelForSearchIfNeeded(isFocused: focused)
        }
        .onChange(of: query.text) { _, _ in
            expandPanelForSearchIfNeeded(isFocused: searchIsFocused)
        }
        .confirmationDialog(
            "Delete this configuration?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                connectionState = .disconnected
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The prototype keeps the demo configuration, so nothing is removed.")
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if reduceTransparency {
            Color(.systemBackground)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    private func panelShape(layout: BottomPanelVisualState) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: VelvetTheme.panelRadius,
            bottomLeadingRadius: layout.bottomCornerRadius,
            bottomTrailingRadius: layout.bottomCornerRadius,
            topTrailingRadius: VelvetTheme.panelRadius
        )
    }

    private func panelCard(
        detents: BottomPanelDetents,
        layout: BottomPanelVisualState,
        expandedTopInset: CGFloat
    ) -> some View {
        let shape = panelShape(layout: layout)
        let searchRevealProgress = locationSearchRevealProgress(layout: layout)
        let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
            panelBottomMargin: detents.bottomMargin
        )

        return ZStack(alignment: .top) {
            locationsScrollBody(
                detents: detents,
                layout: layout,
                searchRevealProgress: searchRevealProgress,
                searchScreenOffset: searchScreenOffset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(spacing: 10) {
                connectionButton
            }
            .padding(.horizontal, 16)
            .padding(.top, panelChromeHeight + 8)
            .opacity(layout.collapsedContentOpacity)
            .allowsHitTesting(layout.collapsedContentOpacity > 0.5)
        }
        .frame(height: layout.panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            panelBackground
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
        .contentShape(Rectangle())
        .gesture(
            panelResizeGesture(detents: detents),
            including: position != .expanded ? .all : .subviews
        )
    }

    private var panelChromeHeight: CGFloat {
        let headerHeight = BottomPanelDetents.expandedGripBandHeight + 44
        guard connectionState == .connected else { return headerHeight }
        return headerHeight + 58
    }

    @ViewBuilder
    private var connectionStatsStrip: some View {
        if connectionState == .connected {
            ConnectionStatsStrip(
                mockPublicIP: mockPublicIP,
                regionLabel: selectedLocation.name,
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                durationText: sessionDurationText,
                onTap: onShowConnectionInfo
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Keeps search pinned at full opacity in expanded and intermediate detents.
    private func locationSearchRevealProgress(layout: BottomPanelVisualState) -> CGFloat {
        switch position {
        case .expanded, .intermediate:
            1
        case .island:
            layout.listProgress
        }
    }

    /// One pinned bar is shared by every detent. On iOS 26 `safeAreaBar`
    /// registers it with the system scroll-edge renderer.
    private func panelTopBar(detents: BottomPanelDetents) -> some View {
        VStack(spacing: 0) {
            systemDragIndicator
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .frame(height: BottomPanelDetents.expandedGripBandHeight)
                .contentShape(Rectangle())
                .gesture(
                    sheetCollapseGesture(detents: detents),
                    including: isScrollAtTop ? .all : .subviews
                )

            ZStack {
                panelHeader
                    .opacity(1 - scrollEdgeProgress)
                    .allowsHitTesting(scrollEdgeProgress < 0.5)

                ExpandedSheetCompactBar(
                    scrollEdgeProgress: scrollEdgeProgress,
                    onCollapse: collapseExpandedPanel
                )
            }
            .frame(height: 44)

            connectionStatsStrip
        }
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    /// Single scroll container for island, intermediate, and expanded so the
    /// list never remounts when snapping between detents.
    private func locationsScrollBody(
        detents: BottomPanelDetents,
        layout: BottomPanelVisualState,
        searchRevealProgress: CGFloat,
        searchScreenOffset: CGFloat
    ) -> some View {
        let isExpanded = position == .expanded
        let canScroll = isExpanded && !isPositionAnimating && !isCollapsingFromScroll

        return ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    scrollTopAnchor
                        .background {
                            scrollChromeTracker
                        }

                    floatingListContent(
                        detents: detents,
                        progress: 1,
                        animateRows: false,
                        embedListInScrollView: false
                    )
                    .opacity(layout.listProgress)
                    .allowsHitTesting(layout.listProgress > 0.5)
                    .padding(.top, 12)
                }
                .padding(
                    .bottom,
                    LocationSearchChrome.scrollBottomPadding(
                        revealProgress: searchRevealProgress,
                        bottomMargin: searchScreenOffset,
                        contentInset: detents.contentBottomInset
                    )
                )
                .animation(nil, value: dragTranslation)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .panelScrollEdgeBar(scrollEdgeProgress: scrollEdgeProgress) {
                panelTopBar(detents: detents)
            }
            .coordinateSpace(name: "islandScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
                updateScrollAtTop(chromeMinY: minY)
            }
            .scrollDisabled(!canScroll)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                sheetCollapseGesture(detents: detents),
                including: isExpanded && isScrollAtTop ? .all : .subviews
            )
            .onChange(of: position) { _, newValue in
                isScrollAtTop = true
                scrollEdgeProgress = 0
                guard newValue != .expanded else { return }
                scrollChromeMinY = nil
                scrollProxy.scrollTo("scrollTop", anchor: .top)
            }
        }
    }

    private var scrollTopAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id("scrollTop")
    }

    private var scrollChromeTracker: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("islandScroll")).minY
                )
        }
        .frame(height: 0)
    }

    private func updateScrollAtTop(chromeMinY: CGFloat?) {
        guard let chromeMinY else { return }

        if scrollRestMinY == nil {
            scrollRestMinY = chromeMinY
        }

        let restMinY = scrollRestMinY ?? chromeMinY
        let scrollOffset = restMinY - chromeMinY
        let newAtTop = scrollOffset <= 1
        let newProgress = min(max(scrollOffset / 28, 0), 1)

        if let previous = scrollChromeMinY,
           abs(previous - chromeMinY) < 0.5,
           newAtTop == isScrollAtTop,
           abs(newProgress - scrollEdgeProgress) < 0.02 {
            return
        }

        scrollChromeMinY = chromeMinY
        isScrollAtTop = newAtTop
        scrollEdgeProgress = newProgress
    }

    /// Capsule drag indicator matching the system sheet presentation style.
    private var systemDragIndicator: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.42))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Drag to resize panel")
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            if position == .island {
                ConnectionStatusLabels(
                    connectionState: connectionState,
                    selectedLocation: selectedLocation,
                    onTap: onShowConnectionInfo
                )
            } else {
                ZStack {
                    Circle()
                        .fill(VelvetTheme.accent.opacity(0.13))
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(VelvetTheme.accent)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Velvet VPN")
                        .font(.subheadline.weight(.semibold))
                    Text("99% traffic · 933 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 4)
            }

            moreMenu
                .fixedSize()

            Button {
                togglePosition()
            } label: {
                headerIcon(position == .island ? "chevron.up" : "chevron.down")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleButtonStyle())
            .fixedSize()
            .accessibilityLabel(position == .island ? "Expand panel" : "Collapse panel")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private var moreMenu: some View {
        Menu {
            ControlGroup {
                Button {} label: {
                    Label("Info", systemImage: "info.circle")
                }

                Button {} label: {
                    Label("Support", systemImage: "paperplane")
                }
            }
            .controlGroupStyle(.compactMenu)

            Section {
                Button {} label: {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }

                Button {} label: {
                    Label("Update subscription", systemImage: "arrow.clockwise.circle")
                }

                Button {} label: {
                    Label("Check ping", systemImage: "speedometer")
                }

                Button {} label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }

            Section {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            headerIcon("ellipsis")
        }
        .accessibilityLabel("More options")
    }

    private func headerIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(Color(.tertiarySystemFill), in: Circle())
    }

    private var connectionButton: some View {
        Button {
            handleConnectionTap()
        } label: {
            HStack {
                if connectionState == .connecting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: connectionState == .connected ? "checkmark.shield.fill" : "power")
                }
                Text(connectionButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(connectionState == .connected ? Color.green : VelvetTheme.accent)
        .disabled(connectionState == .connecting)
        .accessibilityHint(
            connectionState == .connected
                ? "Disconnects the demo VPN"
                : "Connects the demo VPN"
        )
    }

    private func floatingListContent(
        detents: BottomPanelDetents,
        progress: CGFloat,
        animateRows: Bool,
        embedListInScrollView: Bool
    ) -> some View {
        VStack(spacing: 10) {
            if !query.isDefault && !isDraggingPanel {
                activeFilterChips
                    .transition(VelvetMotion.filterChip(reduceMotion: reduceMotion))
            }

            if embedListInScrollView {
                ScrollView {
                    locationListContent(
                        detents: detents,
                        progress: progress,
                        animateRows: animateRows,
                        usesNestedScroll: true
                    )
                }
                .scrollDisabled(true)
                .scrollIndicators(.hidden)
            } else {
                locationListContent(
                    detents: detents,
                    progress: progress,
                    animateRows: animateRows,
                    usesNestedScroll: false
                )
            }
        }
        .animation(
            isDraggingPanel ? nil : VelvetMotion.queryChange(reduceMotion: reduceMotion),
            value: query
        )
    }

    private func locationListContent(
        detents: BottomPanelDetents,
        progress: CGFloat,
        animateRows: Bool,
        usesNestedScroll: Bool
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            let smartResults = results.filter { $0.kind == .smart }
            let otherResults = results.filter { $0.kind != .smart }

            if results.isEmpty {
                emptyState
            } else {
                if !smartResults.isEmpty {
                    locationSection(
                        title: "Recommended",
                        locations: smartResults,
                        startIndex: 0,
                        progress: progress,
                        animateRows: animateRows
                    )
                }

                if !otherResults.isEmpty {
                    locationSection(
                        title: listSectionTitle,
                        locations: otherResults,
                        startIndex: smartResults.count,
                        progress: progress,
                        animateRows: animateRows
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, usesNestedScroll ? detents.contentBottomInset : 0)
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(query.activeChips) { chip in
                    Button {
                        query.clear(chip)
                    } label: {
                        HStack(spacing: 4) {
                            Text(chip.title)
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VelvetTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VelvetTheme.accent.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove filter: \(chip.title)")
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No servers found")
                .font(.subheadline.weight(.semibold))
            Text("Try another country, or reset the filters from the menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func locationSection(
        title: String,
        locations: [VPNLocation],
        startIndex: Int,
        progress: CGFloat,
        animateRows: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(locations.count)")
                    .font(.footnote.monospacedDigit())
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(locations.enumerated()), id: \.element.id) { offset, location in
                    let appearance = animateRows
                        ? VelvetMotion.rowProgress(progress, index: startIndex + offset)
                        : 1

                    Button {
                        selectLocation(location)
                    } label: {
                        locationRow(location)
                    }
                    .buttonStyle(.plain)
                    .opacity(appearance)
                    .offset(y: animateRows ? 20 * (1 - appearance) : 0)

                    if offset < locations.count - 1 {
                        Divider()
                            .padding(.leading, 58)
                            .opacity(appearance)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func locationRow(_ location: VPNLocation) -> some View {
        HStack(spacing: 12) {
            Text(location.flag)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .foregroundStyle(.primary)
                Text(location.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            Group {
                if selectedLocation.id == location.id {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelvetTheme.accent)
                } else {
                    Image(systemName: "cellularbars", variableValue: signalLevel(location.signal))
                        .font(.subheadline)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(signalColor(location.signal))
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), \(location.subtitle), \(location.ping) milliseconds")
        .accessibilityAddTraits(selectedLocation.id == location.id ? [.isSelected] : [])
    }

    private func signalColor(_ signal: VPNLocation.Signal) -> Color {
        switch signal {
        case .excellent: .green
        case .good: .yellow
        case .fair: .red
        }
    }

    private func signalLevel(_ signal: VPNLocation.Signal) -> Double {
        switch signal {
        case .excellent: 1
        case .good: 0.67
        case .fair: 0.34
        }
    }

    private var results: [VPNLocation] {
        VPNLocation.matching(query)
    }

    private var listSectionTitle: String {
        query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "All locations"
            : "Search results"
    }

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected:
            "Connect"
        case .connecting:
            "Connecting…"
        case .connected:
            "Connected"
        case .failed:
            "Retry"
        }
    }

    private func sheetCollapseGesture(detents: BottomPanelDetents) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard position == .expanded, isScrollContentAtTop else { return }
                guard value.translation.height > 4 else { return }
                guard value.translation.height > abs(value.translation.width) else { return }

                isCollapsingFromScroll = true
                isDraggingPanel = true
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                guard position == .expanded, isCollapsingFromScroll else {
                    isCollapsingFromScroll = false
                    isDraggingPanel = false
                    return
                }

                guard isScrollContentAtTop else {
                    isCollapsingFromScroll = false
                    isDraggingPanel = false
                    dragTranslation = 0
                    return
                }

                snapPanel(
                    detents: detents,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height
                )
                isCollapsingFromScroll = false
            }
    }

    private var isScrollContentAtTop: Bool {
        guard let chromeMinY = scrollChromeMinY else { return isScrollAtTop }
        guard let scrollRestMinY else { return isScrollAtTop }
        return chromeMinY >= scrollRestMinY - 1
    }

    private func panelResizeGesture(detents: BottomPanelDetents) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard position != .expanded else { return }
                if !isDraggingPanel {
                    searchIsFocused = false
                }
                isDraggingPanel = true
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                guard position != .expanded else {
                    isDraggingPanel = false
                    return
                }
                snapPanel(
                    detents: detents,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height
                )
            }
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
            detents: detents
        )
        isDraggingPanel = false
        isCollapsingFromScroll = false
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = target
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func schedulePositionAnimationEnd() {
        let delay = VelvetMotion.panelSettleDelay(reduceMotion: reduceMotion)
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            isPositionAnimating = false
        }
    }

    private func collapseExpandedPanel() {
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .intermediate
            dragTranslation = 0
            isScrollAtTop = true
            isCollapsingFromScroll = false
            isDraggingPanel = false
        }
        schedulePositionAnimationEnd()
    }

    private func expandPanelForSearchIfNeeded(isFocused: Bool) {
        guard let target = position.expandedForActiveSearch(
            isFocused: isFocused,
            queryText: query.text
        ) else { return }

        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = target
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func togglePosition() {
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            switch position {
            case .island:
                position = .intermediate
            case .intermediate:
                position = .expanded
            case .expanded:
                position = .island
            }
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func selectLocation(_ location: VPNLocation) {
        selectedLocation = location
        searchIsFocused = false

        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .island
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func handleConnectionTap() {
        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState.handlePrimaryAction()
        }

        guard connectionState == .connecting else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
            }
        }
    }
}
