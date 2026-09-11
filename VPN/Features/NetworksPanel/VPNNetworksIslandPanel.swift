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
    @State private var detailProviderID: ProviderDetailRoute?
    @State private var showsInfoSheet = false
    @State private var showsSupportSheet = false
    @State private var showsEditSheet = false
    @State private var editProviderID: UUID?
    @State private var updateToastMessage: String?
    @State private var connectionNoticeMessage: String?
    @State private var pingResults: [String: Int] = [:]
    @State private var pingingIDs: Set<String> = []
    @State private var isRefreshingPing = false
    private var showsMultiProviderHeader: Bool {
        providerStore.showsProviderPicker
    }

    /// Stack of provider logos only when disconnected; connected state shows the active provider.
    private var showsMultiProviderIconStack: Bool {
        showsMultiProviderHeader && connectionState != .connected
    }

    private var headerProvider: VPNProvider {
        if connectionState == .connected, let resolvedConnection {
            return resolvedConnection.provider
        }
        return displayProvider
    }

    private var hasEligibleProviders: Bool {
        providers.contains(where: \.isEligibleForAutoConnect)
    }

    private var needsRenewalAttention: Bool {
        displayProvider.needsSubscriptionRenewal
    }

    private var showsRenewalBanner: Bool {
        VPNProviderAvailabilitySummary.showsRenewalAttention(
            for: displayProvider,
            hiddenBannerIDs: providerStore.hiddenRenewalBannerIDs
        )
    }

    private var needsSubscriptionAction: Bool {
        !hasEligibleProviders
            || (displayProvider.kind == .imported && needsRenewalAttention)
    }

    private var hasActiveVelvet: Bool {
        VPNProviderAvailabilitySummary.hasActiveVelvet(in: providers)
    }

    private var showsVelvetStatsPromo: Bool {
        displayProvider.kind == .imported
            && !showsRenewalBanner
            && VPNProviderAvailabilitySummary.showsVelvetStatsPromo(for: providers)
    }

    private var showsPresets: Bool {
        hasActiveVelvet
    }

    var body: some View {
        let searchBottomInset = LocationSearchChrome.panelSearchBottomInset(
            safeAreaBottom: safeAreaBottom
        )

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
        } stats: { context in
            connectionInfoBlock(context: context)
        } footer: {
            connectionButton
        } scrollContent: { context in
            networksAndLocationsContent(context: context)
        } searchDock: {
            PanelLocationSearchControls(
                query: $query,
                isFocused: $searchIsFocused,
                bottomMargin: searchBottomInset,
                safeAreaBottom: searchBottomInset
            )
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
        .sheet(item: $detailProviderID) { route in
            VPNProviderDetailView(
                providerStore: providerStore,
                providerID: route.id,
                isVPNConnected: connectionState == .connected,
                activeConnectionProviderID: resolvedConnection?.provider.id
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsInfoSheet) {
            VPNConnectionInfoView(
                resolvedConnection: resolvedConnection,
                connectedAt: connectedAt,
                mockPublicIP: mockPublicIP,
                regionLabel: statsRegionLabel,
                pingMs: pingMs,
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                usageFraction: usageFraction,
                sessionDataUsedText: usageTrailingLabel,
                providerMessage: connectionInfoProviderMessage
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
        .overlay(alignment: .top) {
            if let connectionNoticeMessage {
                connectionNoticeToast(connectionNoticeMessage)
                    .padding(.top, 8)
                    .transition(VelvetMotion.importToast(reduceMotion: reduceMotion))
            }
        }
        .animation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion), value: connectionNoticeMessage)
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
    }

    @ViewBuilder
    private func connectionInfoBlock(context: BottomPanelCurtainContext) -> some View {
        let showsVelvetRenewal = VPNProviderAvailabilitySummary.velvetNeedingRenewal(
            in: providers,
            hiddenBannerIDs: providerStore.hiddenRenewalBannerIDs
        ) != nil
        let renewalRevealThreshold: CGFloat = 0.25
        let showsRenewalContent = (showsRenewalBanner || showsVelvetRenewal)
            && (context.position != .island || context.layout.revealProgress > renewalRevealThreshold)
        let isSingleProviderExpanded = providers.count == 1
            && (context.position != .island || context.layout.revealProgress > renewalRevealThreshold)
        let showsSingleProviderInfo = isSingleProviderExpanded
        let selectionMismatch = activeSelectionMismatch
        let showsMismatchGap = selectionMismatch != nil
            && (context.position != .island || context.layout.revealProgress > renewalRevealThreshold)
        let showsBlock = connectionState == .connected || showsRenewalContent || showsSingleProviderInfo || showsMismatchGap

        if showsBlock {
            AnimatedPanelStatsReveal(context: context) { reveal in
                VPNProviderMessageCard(
                    provider: displayProvider,
                    regionLabel: statsRegionLabel,
                    pingMs: pingMs,
                    downloadRate: downloadRate,
                    uploadRate: uploadRate,
                    usageFraction: usageFraction,
                    usageTrailingLabel: usageTrailingLabel,
                    revealProgress: reveal,
                    showsConnectionStats: connectionState == .connected || isSingleProviderExpanded,
                    showsRenewalBanner: showsRenewalBanner,
                    selectionMismatch: showsMismatchGap ? selectionMismatch : nil,
                    showsVelvetStatsPromo: showsVelvetStatsPromo && !showsMismatchGap,
                    showsProvidersList: providerStore.showsProviderPicker,
                    onStatsTap: context.isStatsExpanded ? { openConnectionInfo() } : nil,
                    onVelvetPromoTap: openVelvetPaywall,
                    onUseSmartAuto: connectWithSmartAutoFallback,
                    onBrowseLocations: expandPanelForLocationBrowse,
                    onRenewSubscription: openRenewalWebsite,
                    onHideRenewalBanner: hideRenewalBanner,
                    onOpenProvider: { detailProviderID = ProviderDetailRoute(id: $0) },
                    providerStore: providerStore
                )
            }
        }
    }

    private var usageTrailingLabel: String {
        switch connectionState {
        case .connected:
            sessionDataUsedText
        case .connecting:
            "Connecting…"
        case .disconnected:
            needsSubscriptionAction ? "Renew to connect" : "Not connected"
        case .failed(let failure):
            if case .selectionMismatch(let mismatch) = failure {
                mismatch.collapsedSubtitle
            } else {
                needsSubscriptionAction ? "Renew to connect" : "Try another server"
            }
        }
    }

    private var statsRegionLabel: String {
        resolvedConnection?.location.name ?? selectedLocation.name
    }

    private func networksPanelHeader(context: BottomPanelCurtainContext) -> some View {
        Group {
            if context.position == .island && context.layout.revealProgress < 0.08 {
                VPNIslandCollapsedHeader(
                    provider: headerProvider,
                    title: collapsedHeaderTitle,
                    subtitle: collapsedHeaderSubtitle,
                    providers: providers,
                    showsMultiProviderSummary: showsMultiProviderIconStack,
                    activePreset: showsPresets ? activeUseCaseChoice : nil,
                    onPresetSelected: showsPresets ? connectWithMenuChoice : nil,
                    expandSystemName: "chevron.up",
                    onExpand: context.togglePosition
                )
            } else {
                HStack(spacing: 10) {
                    if showsMultiProviderIconStack {
                        VPNProviderIconStack(providers: providers)
                    } else {
                        VPNProviderBrandLogo(provider: headerProvider)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(expandedHeaderTitle)
                            .font(VelvetTypography.panelStatusTitle)
                            .foregroundStyle(VelvetTheme.mainTextDark)

                        Text(expandedHeaderSubtitle)
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
        .padding(.horizontal, VelvetMetrics.rowHorizontalPadding * context.layout.revealProgress)
        .padding(.bottom, VelvetMetrics.collapsedHeaderBottomPadding * context.layout.revealProgress)
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private func networksAndLocationsContent(context: BottomPanelCurtainContext) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsPresets {
                paddedSection {
                    VPNPresetsStrip(
                        locationSelection: locationSelection,
                        selectionSource: selectionSource,
                        addsTopSpacing: showsMultiProviderHeader,
                        onSelect: connectWithMenuChoice
                    )
                }
            }

            paddedSection {
                VPNPanelSectionHeader(title: "All locations")
                allLocationsCard
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paddedSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, VelvetTheme.horizontalPadding)
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
            usesErrorTint: usesErrorConnectionTint,
            action: handleConnectionTap
        )
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private var activeSelectionMismatch: VPNSelectionMismatch? {
        guard case let .failed(.selectionMismatch(mismatch)) = connectionState else { return nil }
        return mismatch
    }

    private var usesErrorConnectionTint: Bool {
        guard case let .failed(failure) = connectionState else { return true }
        return !failure.isSelectionMismatch
    }

    private var displayProvider: VPNProvider {
        if let connected = resolvedConnection?.provider {
            return connected
        }
        if let eligible = providers.first(where: \.isEligibleForAutoConnect) {
            return eligible
        }
        if let velvetRenewal = VPNProviderAvailabilitySummary.velvetNeedingRenewal(
            in: providers,
            hiddenBannerIDs: providerStore.hiddenRenewalBannerIDs
        ) {
            return velvetRenewal
        }
        if let renewalCandidate = providers.first(where: {
            $0.kind == .imported && $0.needsSubscriptionRenewal
        }) {
            return renewalCandidate
        }
        return providers.first ?? VPNProvider.samples[0]
    }

    private var islandModeSubtitle: String {
        if isSwitchingServer { return "Switching server…" }
        switch connectionState {
        case .connected:
            return resolvedConnection?.location.name ?? selectedLocation.name
        case .connecting:
            return "Connecting…"
        case .failed(let failure):
            return failure.displayMessage
        case .disconnected:
            if showsMultiProviderHeader {
                return VPNProviderAvailabilitySummary.subtitle(for: providers)
            }
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

    private var collapsedHeaderTitle: String {
        switch connectionState {
        case .connected:
            return resolvedConnection?.provider.name ?? displayProvider.name
        case .connecting:
            return "Connecting…"
        case .failed(let failure):
            if needsSubscriptionAction {
                return displayProvider.status == .expired ? "Subscription expired" : "No active VPN"
            }
            if case .selectionMismatch(let mismatch) = failure {
                return mismatch.collapsedTitle
            }
            return "Couldn't connect"
        case .disconnected:
            if needsSubscriptionAction {
                return displayProvider.status == .expired ? "Subscription expired" : "No active VPN"
            }
            if showsMultiProviderHeader {
                return "Disconnected"
            }
            return displayProvider.name
        }
    }

    private var collapsedHeaderSubtitle: String {
        if connectionState == .connected {
            return resolvedConnection?.location.name ?? selectedLocation.name
        }
        if needsSubscriptionAction {
            return "Renew to connect"
        }
        if case .failed(let failure) = connectionState {
            if case .selectionMismatch(let mismatch) = failure {
                return mismatch.collapsedSubtitle
            }
            return "Try another server or check settings"
        }
        if showsMultiProviderHeader {
            return VPNProviderAvailabilitySummary.subtitle(for: providers)
        }
        if let usageSummary = displayProvider.usageSummaryLabel, connectionState == .disconnected {
            return usageSummary
        }
        return islandModeSubtitle
    }

    private var expandedHeaderTitle: String {
        if showsMultiProviderHeader, connectionState == .disconnected {
            switch locationSelection {
            case .smartAuto, .smartJob:
                return activeUseCaseChoice?.title ?? "Smart"
            case .manual:
                return displayProvider.name
            }
        }
        return displayProvider.name
    }

    private var expandedHeaderSubtitle: String {
        if connectionState == .connected {
            return resolvedConnection?.location.name ?? selectedLocation.name
        }
        if showsMultiProviderHeader {
            return VPNProviderAvailabilitySummary.subtitle(for: providers)
        }
        return displayProvider.panelHeaderSubtitle
    }

    private var activeUseCaseChoice: VPNUseCaseMenuChoice? {
        VPNUseCaseMenuChoice.matching(locationSelection)
    }

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected:
            needsSubscriptionAction ? "Renew subscription" : "Connect"
        case .connecting:
            if isSwitchingServer {
                "Switching server…"
            } else {
                isFindingBest ? "Finding best connection…" : "Connecting…"
            }
        case .connected:
            "Connected"
        case .failed(let failure):
            if needsSubscriptionAction {
                "Renew subscription"
            } else if case .selectionMismatch = failure {
                "Use Smart Auto"
            } else {
                "Retry"
            }
        }
    }

    private func connectionNoticeToast(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    private func openVelvetPaywall() {
        openURL(VelvetTheme.paywallURL)
    }

    private func openRenewalWebsite(id: UUID) {
        guard let provider = providerStore.provider(id: id),
              let url = URL(string: provider.renewURL) else { return }
        openURL(url)
    }

    private func handleSubscriptionRenewalAction() {
        openRenewalWebsite(id: displayProvider.id)
    }

    private func hideRenewalBanner(id: UUID) {
        providerStore.hideRenewalBanner(for: id)
    }

    private func openConnectionInfo() {
        showsInfoSheet = true
    }

    private func openProviderInfo() {
        guard let provider = menuContextProvider else { return }
        detailProviderID = ProviderDetailRoute(id: provider.id)
    }

    private var connectionInfoProviderMessage: String? {
        let providerID = resolvedConnection?.provider.id ?? menuContextProvider?.id
        guard let providerID else { return nil }
        return providerStore.provider(id: providerID)?.providerMessage
    }

    private func connectWithMenuChoice(_ choice: VPNUseCaseMenuChoice) {
        providerStore.activateVelvetForPresetSelection()
        selectionSource = .useCase(choice)
        connectWithSelection(choice.locationSelection(scope: providerStore.providerScope))
    }

    private func connectWithSelection(_ newSelection: VPNLocationSelection) {
        if connectionState == .connected {
            if newSelection == locationSelection { return }
            locationSelection = newSelection
            resolvedConnection = nil
            collapseToIsland()
            isSwitchingServer = true
            handleConnectionTap()
            return
        }

        locationSelection = newSelection
        collapseToIsland()
        handleConnectionTap()
    }

    private func connectManualLocation(_ networkLocation: VPNNetworkLocation) {
        VPNRecentLocationsStore.record(networkLocation)
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
            if connectionState == .connected {
                openConnectionInfo()
            } else {
                openProviderInfo()
            }
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

    private func expandPanelForLocationBrowse() {
        searchIsFocused = false
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .expanded
        }
    }

    private func connectWithSmartAutoFallback() {
        guard let fallback = VPNConnectionPlanner.smartAutoFallbackSelection(
            providers: providers,
            preferredScope: locationSelection.scope,
            storeScope: providerStore.providerScope
        ) else { return }

        locationSelection = fallback
        selectionSource = .useCase(.smart)
        collapseToIsland()
        handleConnectionTap()
    }

    private func presentSelectionMismatch(_ mismatch: VPNSelectionMismatch) {
        isFindingBest = false
        isSwitchingServer = false
        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .failed(.selectionMismatch(mismatch))
        }
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            if position == .island {
                position = .intermediate
            }
        }
    }

    private func presentNetworkFailure(message: String) {
        isFindingBest = false
        isSwitchingServer = false
        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .failed(.network(message: message))
        }
    }

    private func showConnectionNotice(_ message: String) {
        connectionNoticeMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if connectionNoticeMessage == message {
                withAnimation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion)) {
                    connectionNoticeMessage = nil
                }
            }
        }
    }

    private func handleConnectionTap() {
        if case .failed(.selectionMismatch) = connectionState {
            connectWithSmartAutoFallback()
            return
        }

        if needsSubscriptionAction,
           connectionState == .disconnected || connectionState.isFailed {
            handleSubscriptionRenewalAction()
            return
        }

        if connectionState == .connected, !isSwitchingServer {
            withAnimation(VelvetMotion.connectionLayout(reduceMotion: reduceMotion)) {
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

        let reconciledSelection = VPNConnectionPlanner.reconcileSelection(
            locationSelection,
            providers: providers,
            storeScope: providerStore.providerScope
        )
        if reconciledSelection != locationSelection {
            locationSelection = reconciledSelection
        }

        let eligibleProviders = providers.filter(\.isEligibleForAutoConnect)
        if eligibleProviders.isEmpty {
            handleSubscriptionRenewalAction()
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
            let shouldFail = VPNDevFlags.connectShouldFail
#else
            let shouldFail = false
#endif

            var workingSelection = locationSelection
            var resolved = VPNConnectionPlanner.resolve(
                providers: providers,
                selection: workingSelection
            )

            let diagnosedMismatch = VPNConnectionPlanner.diagnoseSelectionFailure(
                providers: providers,
                selection: workingSelection
            )

            if resolved == nil,
               !shouldFail,
               let diagnosedMismatch,
               diagnosedMismatch.isPresetUnavailable {
                providerStore.importedOnlyDemoAwaitingMismatch = false
                presentSelectionMismatch(diagnosedMismatch)
                return
            }

            let skipSilentFallback = providerStore.importedOnlyDemoAwaitingMismatch

            if resolved == nil,
               !shouldFail,
               !skipSilentFallback,
               let fallback = VPNConnectionPlanner.smartAutoFallbackSelection(
                   providers: providers,
                   preferredScope: workingSelection.scope,
                   storeScope: providerStore.providerScope
               ),
               fallback != workingSelection {
                workingSelection = fallback
                locationSelection = fallback
                selectionSource = .useCase(.smart)
                resolved = VPNConnectionPlanner.resolve(providers: providers, selection: fallback)
                if resolved != nil {
                    showConnectionNotice("Switched to Smart Auto")
                }
            }

            if shouldFail {
                providerStore.importedOnlyDemoAwaitingMismatch = false
                presentNetworkFailure(message: "Try another server")
                return
            }

            guard let resolved else {
                providerStore.importedOnlyDemoAwaitingMismatch = false
                if let mismatch = VPNConnectionPlanner.diagnoseSelectionFailure(
                    providers: providers,
                    selection: locationSelection
                ) {
                    presentSelectionMismatch(mismatch)
                } else {
                    presentNetworkFailure(message: "Try another server")
                }
                return
            }

            providerStore.importedOnlyDemoAwaitingMismatch = false
            locationSelection = workingSelection
            resolvedConnection = resolved
            selectedLocation = resolved.location
            isFindingBest = false

            try? await Task.sleep(for: .milliseconds(500))
            guard connectionState == .connecting else { return }

            withAnimation(VelvetMotion.connectionLayout(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
                isSwitchingServer = false
                connectedAt = connectedAt ?? .now
            }
        }
    }
}
