import SwiftUI

private struct NetworksScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

/// Multi-provider panel: one Connect button in island mode, Networks + Locations
/// when expanded. Mirrors the island drag/scroll mechanics from `VPNIslandPanel`.
private struct ProviderDetailRoute: Identifiable {
    let id: UUID
}

struct VPNNetworksIslandPanel: View {
    @Bindable var providerStore: VPNProviderStore

    @Binding var position: BottomPanelPosition
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation
    @Binding var locationSelection: VPNLocationSelection
    @Binding var selectionSource: VPNSelectionSource
    @Binding var resolvedConnection: VPNResolvedConnection?
    @Binding var isSwitchingServer: Bool
    @Binding var isPanelInteracting: Bool
    @Binding var showsRoutingSettings: Bool
    @Binding var connectedAt: Date?
    @Binding var shouldAutoConnect: Bool

    let downloadRate: String
    let uploadRate: String
    let pingMs: Int
    let usageFraction: Double
    let sessionDataUsedText: String

    let safeAreaBottom: CGFloat
    let safeAreaTop: CGFloat

    private var providers: [VPNProvider] { providerStore.providers }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var dragTranslation: CGFloat = 0
    @State private var cachedViewportHeight: CGFloat = 0
    @State private var scrollChromeMinY: CGFloat?
    @State private var scrollRestMinY: CGFloat?
    @State private var scrollEdgeProgress: CGFloat = 0
    @State private var isScrollAtTop = true
    @State private var isDraggingPanel = false
    @State private var isCollapsingFromScroll = false
    @State private var isPositionAnimating = false
    @State private var positionAnimationTask: Task<Void, Never>?
    @State private var isFindingBest = false
    @State private var query = VPNLocationQuery()
    @State private var showsDeleteConfirmation = false
    @State private var pendingReconnectSelection: VPNLocationSelection?
    @State private var showsReconnectConfirmation = false
    @State private var detailProviderID: ProviderDetailRoute?
    @State private var showsInfoSheet = false
    @State private var showsSupportSheet = false
    @State private var showsEditSheet = false
    @State private var editProviderID: UUID?
    @State private var updateToastMessage: String?
    @State private var pingResults: [String: Int] = [:]
    @State private var pingingIDs: Set<String> = []
    @State private var isRefreshingPing = false
    @State private var recentLocations: [VPNRecentLocationEntry] = []
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let showsSessionStats = connectionState == .connected
                && !isPositionAnimating
                && !isDraggingPanel
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
            let panelInteracting = isDraggingPanel || isCollapsingFromScroll || isPositionAnimating
            let expandedTopInset = max(safeAreaTop - VelvetTheme.expandedTopInsetReduction, 0)
            let searchRevealProgress = locationSearchRevealProgress(layout: layout)
            let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
                panelBottomMargin: detents.bottomMargin
            )
            let viewportHeight = cachedViewportHeight > 0 ? cachedViewportHeight : proxy.size.height

            Color.clear
                .allowsHitTesting(false)
                .overlay(alignment: .bottom) {
                    panelCard(detents: detents, layout: layout, expandedTopInset: expandedTopInset)
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
                    cachedViewportHeight = proxy.size.height
                }
                .onChange(of: proxy.size.height) { _, height in
                    cachedViewportHeight = height
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
        .onChange(of: shouldAutoConnect) { _, value in
            guard value else { return }
            shouldAutoConnect = false
            handleConnectionTap()
        }
        .onAppear {
            recentLocations = VPNRecentLocationsStore.load()
        }
        .sheet(item: $detailProviderID) { route in
            VPNProviderDetailView(providerStore: providerStore, providerID: route.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsInfoSheet) {
            VPNConnectionInfoView(
                resolvedConnection: resolvedConnection,
                connectedAt: connectedAt,
                mockPublicIP: mockPublicIP
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsSupportSheet) {
            VPNSupportView(providerName: menuContextProvider?.name)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsEditSheet) {
            if let editProviderID {
                VPNProviderEditView(providerStore: providerStore, providerID: editProviderID)
            }
        }
        .alert("Subscriptions updated", isPresented: Binding(
            get: { updateToastMessage != nil },
            set: { if !$0 { updateToastMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(updateToastMessage ?? "")
        }
        .confirmationDialog(
            "Delete this configuration?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePendingProvider()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let provider = providerStore.providerPendingDeletion(from: resolvedConnection) {
                Text("\(provider.name) will be removed from Networks and Smart-Auto.")
            }
        }
        .confirmationDialog(
            "Switch server?",
            isPresented: $showsReconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reconnect") {
                applyPendingReconnect()
            }
            Button("Cancel", role: .cancel) {
                pendingReconnectSelection = nil
            }
        } message: {
            Text("You are connected. Changing location will reconnect using the new selection.")
        }
    }

    private func deletePendingProvider() {
        guard let provider = providerStore.providerPendingDeletion(from: resolvedConnection) else { return }

        if resolvedConnection?.provider.id == provider.id {
            connectionState = .disconnected
            resolvedConnection = nil
        }

        providerStore.remove(id: provider.id)
    }

    private func applyPendingReconnect() {
        guard let pendingReconnectSelection else { return }
        locationSelection = pendingReconnectSelection
        self.pendingReconnectSelection = nil
        resolvedConnection = nil
        collapseToIsland()
        isSwitchingServer = true
        handleConnectionTap()
    }

    @ViewBuilder
    private func panelBackground(isDragLite: Bool) -> some View {
        VelvetPanelBackground(prefersSolidFill: isDragLite)
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
        let mountsScrollContent = position != .island
            || isDraggingPanel
            || isPositionAnimating
            || dragTranslation != 0

        return ZStack(alignment: .top) {
            if mountsScrollContent {
                expandedScrollBody(
                    detents: detents,
                    layout: layout,
                    searchRevealProgress: searchRevealProgress,
                    searchScreenOffset: searchScreenOffset
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                islandRestingChrome(detents: detents)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                connectionButton
                    .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
                    .padding(.bottom, VelvetMetrics.collapsedBottomPadding)
            }
            .padding(.top, VelvetCollapsedIslandLayout.chromeHeight(
                showsSessionStats: connectionState == .connected
                    && !isPositionAnimating
                    && !isDraggingPanel
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(layout.collapsedContentOpacity)
            .allowsHitTesting(layout.collapsedContentOpacity > 0.5)
            .animation(
                isDraggingPanel ? nil : VelvetMotion.connectionState(reduceMotion: reduceMotion),
                value: connectionState
            )
        }
        .frame(height: layout.panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background { panelBackground(isDragLite: isDraggingPanel) }
        .clipShape(shape)
        .shadow(color: .black.opacity(layout.shadowOpacity), radius: layout.shadowRadius, y: layout.shadowY)
        .padding(.top, expandedTopInset * layout.sheetMorphProgress)
        .padding(.horizontal, layout.horizontalInset)
        .padding(.bottom, layout.bottomInset)
        .contentShape(Rectangle())
        .gesture(
            panelResizeGesture(detents: detents),
            including: position != .expanded ? .all : .subviews
        )
    }

    private func islandRestingChrome(detents: BottomPanelDetents) -> some View {
        panelTopBar(detents: detents)
    }

    @ViewBuilder
    private var connectionStatsStrip: some View {
        if connectionState == .connected, !isPositionAnimating, !isDraggingPanel {
            ConnectionStatsStrip(
                regionLabel: statsRegionLabel,
                pingMs: pingMs,
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                usageFraction: usageFraction,
                sessionDataUsedText: sessionDataUsedText,
                onTap: { showsInfoSheet = true }
            )
            .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
            .transition(VelvetMotion.statsStrip(reduceMotion: reduceMotion))
        }
    }

    private var statsRegionLabel: String {
        resolvedConnection?.location.name ?? selectedLocation.name
    }

    private func locationSearchRevealProgress(layout: BottomPanelVisualState) -> CGFloat {
        switch position {
        case .expanded, .intermediate:
            1
        case .island:
            layout.listProgress
        }
    }

    private func connectWithMenuChoice(_ choice: VPNUseCaseMenuChoice) {
        selectionSource = .useCase(choice)
        connectWithSelection(choice.locationSelection(scope: providerStore.providerScope))
    }

    private func connectWithJob(_ job: VPNUserJob) {
        if job == .whitelistForeign {
            VPNRoutingPreferences.bypassLocalNetworks = true
        }
        connectWithSelection(.smartJob(job, scope: providerStore.providerScope))
    }

    private func connectWithSelection(_ newSelection: VPNLocationSelection) {
        if connectionState == .connected {
            if newSelection == locationSelection { return }
            pendingReconnectSelection = newSelection
            showsReconnectConfirmation = true
            return
        }

        locationSelection = newSelection
        collapseToIsland()
        handleConnectionTap()
    }

    private func panelTopBar(detents: BottomPanelDetents) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.42))
                .frame(width: 36, height: 5)
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
                networksPanelHeader
                    .opacity(1 - scrollEdgeProgress)
                    .allowsHitTesting(scrollEdgeProgress < 0.5)

                ExpandedSheetCompactBar(
                    title: "Networks & locations",
                    scrollEdgeProgress: scrollEdgeProgress,
                    onCollapse: collapseExpandedPanel
                )
            }
            .frame(height: VelvetMetrics.panelHeaderRowHeight)

            connectionStatsStrip
                .padding(.top, connectionState == .connected ? VelvetMetrics.collapsedSectionSpacing : 0)
        }
    }

    private var networksPanelHeader: some View {
        Group {
            if position == .island {
                VPNIslandCollapsedHeader(
                    provider: displayProvider,
                    title: displayProvider.name,
                    subtitle: islandModeSubtitle,
                    activePreset: activeUseCaseChoice,
                    onPresetSelected: connectWithMenuChoice,
                    onProviderTap: { showsInfoSheet = true },
                    expandSystemName: "chevron.up",
                    onExpand: togglePosition
                )
            } else {
                HStack(spacing: 10) {
                    Text("Networks & locations")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    VPNConfigOptionsMenu(
                        showsDeleteConfirmation: $showsDeleteConfirmation,
                        showsProviderSettings: !providerStore.showsProviderPicker,
                        onAction: handleConfigMenuAction
                    ) {
                        headerIcon("ellipsis")
                    }

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
            }
        }
        .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
        .padding(.bottom, VelvetMetrics.collapsedHeaderBottomPadding)
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private var displayProvider: VPNProvider {
        resolvedConnection?.provider
            ?? providers.first(where: \.isEligibleForAutoConnect)
            ?? providers.first
            ?? VPNProvider.samples[0]
    }

    private var islandModeSubtitle: String {
        if isSwitchingServer { return "Switching server…" }
        switch connectionState {
        case .connected:
            return resolvedConnection?.location.name ?? selectedLocation.name
        case .connecting:
            return "Connecting…"
        case .failed(let message):
            return message
        case .disconnected:
            return VPNSelectionSummary.subtitle(
                selection: locationSelection,
                providers: providers,
                connectionState: connectionState,
                resolvedConnection: resolvedConnection,
                homeFormat: .networksAndLocations,
                selectedLocation: selectedLocation,
                isSwitchingServer: isSwitchingServer
            )
        }
    }

    private var activeUseCaseChoice: VPNUseCaseMenuChoice? {
        VPNUseCaseMenuChoice.matching(locationSelection)
    }

    private func headerIcon(_ systemName: String) -> some View {
        VelvetPanelHeaderIcon(systemName: systemName)
    }

    private func expandedScrollBody(
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
                    Color.clear
                        .frame(height: 1)
                        .id("scrollTop")
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: NetworksScrollOffsetKey.self,
                                    value: geometry.frame(in: .named("networksScroll")).minY
                                )
                            }
                            .frame(height: 0)
                        }

                    networksAndLocationsContent
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
            }
            .background(Color.clear)
            .panelScrollEdgeBar(scrollEdgeProgress: scrollEdgeProgress) {
                panelTopBar(detents: detents)
            }
            .coordinateSpace(name: "networksScroll")
            .onPreferenceChange(NetworksScrollOffsetKey.self) { minY in
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
                scrollRestMinY = nil
                scrollProxy.scrollTo("scrollTop", anchor: .top)
            }
        }
    }

    private var networksAndLocationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if providerStore.showsProviderPicker {
                paddedSection {
                    networksCard
                }
            } else if let soleProvider = providerStore.soleProvider, soleProvider.hasProviderMessage {
                paddedSection {
                    VPNProviderMessageCard(provider: soleProvider)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                paddedSection {
                    VPNPanelSectionHeader(title: "Use cases")
                }
                useCaseCardsCard
            }

            VStack(alignment: .leading, spacing: 8) {
                paddedSection {
                    VPNPanelSectionHeader(title: "All locations")
                    allLocationsCard
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(VelvetMotion.contentCrossfade(reduceMotion: reduceMotion), value: providerStore.showsProviderPicker)
    }

    private func paddedSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, VelvetTheme.horizontalPadding)
    }

    private var networksCard: some View {
        VPNCompactNetworksCard(providerStore: providerStore) { providerID in
            detailProviderID = ProviderDetailRoute(id: providerID)
        }
    }

    private var useCaseCardsCard: some View {
        VPNUseCaseCardsCard(
            locationSelection: locationSelection,
            selectionSource: selectionSource,
            scope: providerStore.providerScope,
            onUseCaseConnect: connectWithMenuChoice
        )
    }

    private var allLocationsCard: some View {
        VPNAllLocationsCard(
            providerStore: providerStore,
            locationSelection: $locationSelection,
            selectionSource: $selectionSource,
            query: $query,
            pingResults: pingResults,
            pingingIDs: pingingIDs,
            isDraggingPanel: isDraggingPanel,
            onSmartLocation: connectSmartLocation,
            onManualLocation: connectManualLocation
        )
    }

    private var connectionButton: some View {
        VPNPrimaryConnectionButton(
            title: connectionButtonTitle,
            connectionState: connectionState,
            action: handleConnectionTap
        )
    }

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected:
            "Connect"
        case .connecting:
            if isSwitchingServer {
                "Switching server…"
            } else {
                isFindingBest ? "Finding best connection…" : "Connecting…"
            }
        case .connected:
            "Connected"
        case .failed:
            "Retry"
        }
    }

    private func connectManualLocation(_ networkLocation: VPNNetworkLocation) {
        VPNRecentLocationsStore.record(networkLocation)
        recentLocations = VPNRecentLocationsStore.load()
        let selection = VPNLocationSelection.manual(
            location: networkLocation.location,
            providerID: networkLocation.provider.id
        )
        selectedLocation = networkLocation.location
        selectionSource = .location(selection)
        connectWithSelection(selection)
    }

    private func connectSmartLocation(_ job: VPNUserJob) {
        let selection = VPNLocationSelection.smartJob(job, scope: providerStore.providerScope)
        selectionSource = .location(selection)
        connectWithSelection(selection)
    }

    private var menuContextProvider: VPNProvider? {
        resolvedConnection?.provider
            ?? providers.first(where: \.isEligibleForAutoConnect)
            ?? providers.first
    }

    private var mockPublicIP: String {
        guard let resolvedConnection else { return "185.42.18.90" }
        let suffix = abs(resolvedConnection.location.ping) % 200
        return "185.42.\(suffix).\(18 + resolvedConnection.provider.name.count % 40)"
    }

    private func handleConfigMenuAction(_ action: VPNConfigMenuAction) {
        switch action {
        case .info:
            showsInfoSheet = true
        case .support:
            showsSupportSheet = true
        case .routing:
            showsRoutingSettings = true
        case .updateSubscription:
            Task {
                let count = await providerStore.refreshAllActiveSubscriptions()
                updateToastMessage = count == 0
                    ? "No active subscriptions to update."
                    : "Updated \(count) active subscriptions."
            }
        case .checkPing:
            runInlinePingCheck()
        case .edit:
            if let provider = menuContextProvider {
                editProviderID = provider.id
                showsEditSheet = true
            }
        case .providerSettings:
            if let provider = menuContextProvider {
                detailProviderID = ProviderDetailRoute(id: provider.id)
            }
        }
    }

    private func runInlinePingCheck() {
        guard !isRefreshingPing else { return }
        isRefreshingPing = true
        pingResults = [:]

        let entries = VPNConnectionPlanner.inlinePingEntries(
            providers: providers,
            scope: providerStore.providerScope,
            query: query
        )
        pingingIDs = Set(entries.map(\.id))

        Task { @MainActor in
            for entry in entries {
                try? await Task.sleep(for: .milliseconds(120))
                pingResults[entry.id] = entry.ping
                pingingIDs.remove(entry.id)
            }
            isRefreshingPing = false
            VPNLogsStore.shared.append("Ping check completed (\(entries.count) servers)")
        }
    }

    private func collapseToIsland() {
        searchIsFocused = false
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .island
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func handleConnectionTap() {
        if connectionState == .connected, !isSwitchingServer {
            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState = .disconnected
                resolvedConnection = nil
                connectedAt = nil
            }
            VPNLogsStore.shared.append("Disconnected")
            return
        }

        if case .failed = connectionState {
            isSwitchingServer = false
        }

        let eligibleProviders = providers.filter(\.isEligibleForAutoConnect)
        if eligibleProviders.isEmpty {
            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState = .failed(message: "No active subscriptions")
                isSwitchingServer = false
            }
            return
        }

        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .connecting
            isFindingBest = !isSwitchingServer
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard connectionState == .connecting else { return }

#if DEBUG
            let shouldFail = CommandLine.arguments.contains("--connect-fail")
#else
            let shouldFail = false
#endif

            if shouldFail || VPNConnectionPlanner.resolve(providers: providers, selection: locationSelection) == nil {
                isFindingBest = false
                isSwitchingServer = false
                withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                    connectionState = .failed(message: "Check subscriptions or try manual")
                }
                return
            }

            if let resolved = VPNConnectionPlanner.resolve(providers: providers, selection: locationSelection) {
                resolvedConnection = resolved
                selectedLocation = resolved.location
            }

            isFindingBest = false

            try? await Task.sleep(for: .milliseconds(500))
            guard connectionState == .connecting else { return }

            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
                isSwitchingServer = false
                connectedAt = connectedAt ?? .now
            }
        }
    }

    private func updateScrollAtTop(chromeMinY: CGFloat?) {
        guard let chromeMinY else { return }
        if scrollRestMinY == nil { scrollRestMinY = chromeMinY }

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
}