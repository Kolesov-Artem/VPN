import SwiftUI

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
    var detentMode: VPNPanelDetentMode = .stepped

    private var providers: [VPNProvider] { providerStore.providers }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @FocusState private var searchIsFocused: Bool

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
    @State private var cachedViewportHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let searchRevealProgress = searchRevealProgress(for: position)
            let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
                panelBottomMargin: max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
            )
            let viewportHeight = cachedViewportHeight > 0 ? cachedViewportHeight : proxy.size.height

            BottomPanelCurtain(
                position: $position,
                isPanelInteracting: $isPanelInteracting,
                showsSessionStats: connectionState == .connected,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                compactBarTitle: displayProvider.name,
                detentMode: detentMode,
                onDismissSearch: { searchIsFocused = false }
            ) { context in
                networksPanelHeader(context: context)
            } stats: {
                connectionStatsStrip
            } footer: {
                connectionButton
            } scrollContent: { context in
                networksAndLocationsContent(layout: context.layout)
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(width: proxy.size.width, height: viewportHeight)
                    .overlay(alignment: .bottom) {
                        if searchRevealProgress > 0.01 {
                            PanelLocationSearchControls(
                                query: $query,
                                isFocused: $searchIsFocused,
                                bottomMargin: searchScreenOffset,
                                safeAreaBottom: max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
                            )
                            .opacity(searchRevealProgress)
                            .allowsHitTesting(searchRevealProgress > 0.35)
                        }
                    }
            }
            .onAppear {
                cachedViewportHeight = proxy.size.height
            }
            .onChange(of: proxy.size.height) { _, height in
                cachedViewportHeight = height
            }
        }
        .onChange(of: position) { _, newValue in
            if newValue == .island {
                searchIsFocused = false
                query.text = ""
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

    private func searchRevealProgress(for position: BottomPanelPosition) -> CGFloat {
        switch position {
        case .expanded, .intermediate:
            1
        case .island:
            0
        }
    }

    @ViewBuilder
    private var connectionStatsStrip: some View {
        if position == .island {
            if connectionState == .connected {
                ConnectionStatsStrip(
                    regionLabel: statsRegionLabel,
                    pingMs: pingMs,
                    downloadRate: downloadRate,
                    uploadRate: uploadRate,
                    usageFraction: usageFraction,
                    sessionDataUsedText: sessionDataUsedText,
                    onTap: nil
                )
                .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
                .padding(.top, VelvetMetrics.collapsedSectionSpacing)
            }
        } else {
            providerStatusCard
                .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
                .padding(.top, VelvetMetrics.collapsedSectionSpacing)
        }
    }

    private var providerStatusCard: some View {
        VPNProviderMessageCard(
            provider: displayProvider,
            regionLabel: statsRegionLabel,
            pingMs: pingMs,
            downloadRate: downloadRate,
            uploadRate: uploadRate,
            usageFraction: usageFraction,
            usageTrailingLabel: usageTrailingLabel,
            showsVelvetPromo: displayProvider.kind == .imported,
            onStatsTap: { showsInfoSheet = true },
            onVelvetPromoTap: openVelvetPaywall
        )
    }

    private var usageTrailingLabel: String {
        switch connectionState {
        case .connected:
            sessionDataUsedText
        case .connecting:
            "Connecting…"
        case .disconnected:
            "Not connected"
        case .failed(let message):
            message
        }
    }

    private var statsRegionLabel: String {
        resolvedConnection?.location.name ?? selectedLocation.name
    }

    private func networksPanelHeader(context: BottomPanelCurtainContext) -> some View {
        Group {
            if context.position == .island {
                VPNIslandCollapsedHeader(
                    provider: displayProvider,
                    title: displayProvider.name,
                    subtitle: islandModeSubtitle,
                    activePreset: activeUseCaseChoice,
                    onPresetSelected: connectWithMenuChoice,
                    expandSystemName: "chevron.up",
                    onExpand: context.togglePosition
                )
            } else {
                HStack(spacing: 10) {
                    VPNProviderBrandIcon(provider: displayProvider)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayProvider.name)
                            .font(VelvetTypography.panelStatusTitle)
                            .foregroundStyle(VelvetTheme.mainTextDark)

                        Text(displayProvider.panelHeaderSubtitle)
                            .font(VelvetTypography.panelStatusSubtitle)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VPNConfigOptionsMenu(
                        showsDeleteConfirmation: $showsDeleteConfirmation,
                        showsProviderSettings: !providerStore.showsProviderPicker,
                        onAction: handleConfigMenuAction
                    ) {
                        VelvetPanelHeaderIcon(systemName: "ellipsis")
                    }

                    Button {
                        context.togglePosition()
                    } label: {
                        VelvetPanelHeaderIcon(
                            systemName: context.position == .island ? "chevron.up" : "chevron.down"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .fixedSize()
                    .accessibilityLabel(context.position == .island ? "Expand panel" : "Collapse panel")
                }
            }
        }
        .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
        .padding(.bottom, VelvetMetrics.collapsedHeaderBottomPadding)
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private func networksAndLocationsContent(layout: BottomPanelVisualState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if providerStore.showsProviderPicker {
                paddedSection {
                    networksCard
                }
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

    private var allLocationsCard: some View {
        VPNAllLocationsCard(
            providerStore: providerStore,
            locationSelection: $locationSelection,
            selectionSource: $selectionSource,
            query: $query,
            pingResults: pingResults,
            pingingIDs: pingingIDs,
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

    private func openVelvetPaywall() {
        openURL(VelvetTheme.paywallURL)
    }

    private func connectWithMenuChoice(_ choice: VPNUseCaseMenuChoice) {
        selectionSource = .useCase(choice)
        connectWithSelection(choice.locationSelection(scope: providerStore.providerScope))
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

    private func collapseToIsland() {
        searchIsFocused = false
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .island
        }
    }

    private func expandPanelForSearchIfNeeded(isFocused: Bool) {
        guard let target = position.expandedForActiveSearch(
            isFocused: isFocused,
            queryText: query.text,
            detentMode: detentMode
        ) else { return }

        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = target
        }
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
}
