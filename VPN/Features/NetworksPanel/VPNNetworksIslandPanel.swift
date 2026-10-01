import SwiftUI

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
    @Binding var providerSettingsID: UUID?

    var sessionStats: VPNSessionStatsModel

    let safeAreaBottom: CGFloat
    let safeAreaTop: CGFloat
    var detentMode: VPNPanelDetentMode = .stepped
    /// Collapsed card offers subscription and location before connect.
    var usesMenuCollapsedChrome: Bool = false

    static let locationsAnchor = "island.locations"

    private var providers: [VPNProvider] { providerStore.providers }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @FocusState private var searchIsFocused: Bool

    @State private var isFindingBest = false
    @State private var query = VPNLocationQuery()
    @State private var showsDeleteConfirmation = false
    @State private var showsInfoSheet = false
    @State private var showsSupportSheet = false
    @State private var showsEditSheet = false
    @State private var editProviderID: UUID?
    @State private var updateToastMessage: String?
    @State private var connectionNoticeMessage: String?
    @State private var pingResults: [String: Int] = [:]
    @State private var pingingIDs: Set<String> = []
    @State private var isRefreshingPing = false
    @State private var showsPingResultsSheet = false
    @State private var showsActiveProviderSwitch = false
    @State private var showsSubscriptionSettings = false
    @State private var providerContentLoadingID: UUID?
    @State private var providerLoadTask: Task<Void, Never>?
    @State private var connectTask: Task<Void, Never>?
    @State private var pendingLocationScroll = false

    @AppStorage(VPNFavouriteLocationsStore.storageKey) private var storedFavourites = ""
    @AppStorage(VPNFavouriteLocationsStore.seededKey) private var didSeedFavourites = false

    private var panelChromeMode: VPNPanelChromeMode {
        VPNPanelChromeMode.resolve(providerCount: providers.count)
    }

    private var showsMultiProviderHeader: Bool {
        panelChromeMode == .multiProvider
    }

    /// Multi + offline, and nothing specific is picked: the large «Fastest» chrome.
    private var showsFastestMultiCollapsedLayout: Bool {
        VPNReleaseProfile.isRelease1
            && panelChromeMode == .multiProvider
            && connectionState == .disconnected
            && !needsSubscriptionAction
            && !isManualSelection
    }

    private var showsMultiActiveProviderPicker: Bool {
        VPNReleaseProfile.isRelease1 && panelChromeMode == .multiProvider
    }

    private var collapsedPickerProviders: [VPNProvider] {
        providers.filter(\.status.isActive)
    }

    private var showsCollapsedProviderPicker: Bool {
        collapsedPickerProviders.count > 1
    }

    private var showsCollapsedSmartPreset: Bool {
        showsPresets && panelChromeMode == .singleProvider
    }

    private var collapsedIslandChromeStyle: VPNIslandCollapsedHeader.Style {
        showsFastestMultiCollapsedLayout ? .fastestMultiVPN : .standard
    }

    private var collapsedExpandSystemName: String {
        showsFastestMultiCollapsedLayout ? "chevron.forward" : "chevron.up"
    }

    private var figmaSearchPlaceholder: String {
        VPNReleaseProfile.isRelease1 ? VPNFigmaSection550Copy.locationSearchPlaceholder : ui("Country, city or type")
    }

    /// Release 1: always show the manually selected provider, not an icon stack.
    private var showsMultiProviderIconStack: Bool {
        !VPNReleaseProfile.isRelease1 && showsMultiProviderHeader && connectionState != .connected
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
        if VPNReleaseProfile.isRelease1 {
            return providerStore.activeProvider.includesPresets
        }
        return hasActiveVelvet && providerStore.activeProvider.kind == .velvetFeatured
    }

    private var isProviderContentLoading: Bool {
        providerContentLoadingID != nil
    }

    private var isLocationSwitching: Bool {
        isSwitchingServer && (connectionState == .connected || connectionState == .connecting)
    }

    private var isPanelContentLoading: Bool {
        isProviderContentLoading || isLocationSwitching
    }

    /// Name shown while a switch is still loading. Stats stay hidden until it finishes.
    private var chromeProvider: VPNProvider {
        if let providerContentLoadingID,
           let pending = providers.first(where: { $0.id == providerContentLoadingID }) {
            return pending
        }
        return displayProvider
    }

    var body: some View {
        panelWithLifecycle
        .sheet(isPresented: $showsPingResultsSheet) {
            VPNPingResultsView(providers: providers.filter { $0.status.isActive })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsInfoSheet) {
            SessionStatsConsumer(
                model: sessionStats,
                readsLiveValues: !VPNReleaseProfile.isRelease1
            ) { live in
                let stats = figmaDemoSessionStats(islandCollapsed: position == .island)
                let place = resolvedConnection?.location
                VPNConnectionInfoView(
                    resolvedConnection: resolvedConnection,
                    connectedAt: connectedAt,
                    mockPublicIP: mockPublicIP,
                    regionLabel: place?.name ?? stats?.region ?? statsRegionLabel,
                    pingMs: place?.ping ?? stats?.pingMs ?? live.pingMs,
                    downloadRate: stats?.downloadRate ?? live.downloadRate,
                    uploadRate: stats?.uploadRate ?? live.uploadRate,
                    usageFraction: displayUsageFraction(live: live),
                    sessionDataUsedText: usageTrailingLabel(live: live),
                    usageLeadingOverride: statsUsageLeadingLabel(live: live),
                    supplementalUsage: connectionInfoLTEUsageBar,
                    providerMessage: connectionInfoProviderMessage,
                    usesRelease1NavigationTitle: VPNReleaseProfile.isRelease1
                )
            }
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
        .alert(ui("Subscriptions updated"), isPresented: Binding(
            get: { updateToastMessage != nil },
            set: { if !$0 { updateToastMessage = nil } }
        )) {
            Button(ui("OK"), role: .cancel) {}
        } message: {
            Text(updateToastMessage ?? "")
        }
        .overlay {
            if showsActiveProviderSwitch {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        setProviderSwitchPresented(false)
                    }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if showsActiveProviderSwitch {
                VPNActiveProviderSwitchCard(
                    providers: providers,
                    activeProviderID: providerStore.activeProviderID,
                    showsAllSubscriptions: providerStore.showsAllSubscriptionsCatalog,
                    onSelectAll: switchToAllSubscriptions,
                    onSelect: switchActiveProvider,
                    onInfo: { id in
                        setProviderSwitchPresented(false)
                        providerSettingsID = id
                    },
                    onOpenSubscriptions: {
                        setProviderSwitchPresented(false)
                        showsSubscriptionSettings = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 72)
                .transition(VelvetMotion.popoverTransition(reduceMotion: reduceMotion))
            }
        }
        .sensoryFeedback(.selection, trigger: showsActiveProviderSwitch) { _, presented in
            presented
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: providerContentLoadingID) { old, new in
            new != nil && old != new
        }
        .overlay(alignment: .top) {
            if let connectionNoticeMessage {
                connectionNoticeToast(connectionNoticeMessage)
                    .padding(.top, 8)
                    .transition(VelvetMotion.importToast(reduceMotion: reduceMotion))
            }
        }
        .fullScreenCover(isPresented: $showsSubscriptionSettings) {
            VPNSubscriptionsPage(providerStore: providerStore, showsCloseButton: true) { id in
                showsSubscriptionSettings = false
                providerSettingsID = id
            }
        }
        .animation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion), value: connectionNoticeMessage)
        .confirmationDialog(ui("Delete this configuration?"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(ui("Delete"), role: .destructive) {
                deletePendingProvider()
            }
            Button(ui("Cancel"), role: .cancel) {}
        } message: {
            if let provider = providerStore.providerPendingDeletion(from: resolvedConnection) {
                Text("\(provider.name) will be removed from Networks and Smart-Auto.")
            }
        }
    }

    private var panelWithLifecycle: some View {
        panelCurtain
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
            .onChange(of: locationSelection) { _, _ in
                guard connectionState == .connected else { return }
                beginLocationSwitch()
            }
            .onChange(of: shouldAutoConnect) { _, value in
                guard value else { return }
                shouldAutoConnect = false
                handleConnectionTap()
            }
    }

    private var panelCurtain: some View {
        let searchBottomInset = LocationSearchChrome.panelSearchBottomInset(
            safeAreaBottom: safeAreaBottom
        )

        return BottomPanelCurtain(
            position: $position,
            isPanelInteracting: $isPanelInteracting,
            showsSessionStats: connectionState == .connected,
            safeAreaBottom: safeAreaBottom,
            safeAreaTop: safeAreaTop,
            compactBarTitle: panelCompactBarTitle,
            detentMode: detentMode,
            showsFavouriteStrip: !favouriteEntries.isEmpty,
            usesMenuCollapsedChrome: usesMenuCollapsedChrome,
            fadesScrollContentAsGroup: false,
            onDismissSearch: { searchIsFocused = false }
        ) { context in
            networksPanelHeader(context: context)
        } stats: { context in
            SessionStatsConsumer(
                model: sessionStats,
                readsLiveValues: !VPNReleaseProfile.isRelease1
            ) { live in
                connectionInfoBlock(context: context, live: live)
            }
        } footer: {
            connectionButton
        } scrollContent: { context in
            networksAndLocationsContent(context: context)
        } searchDock: {
            PanelLocationSearchControls(
                query: $query,
                searchPlaceholder: figmaSearchPlaceholder,
                isFocused: $searchIsFocused,
                bottomMargin: searchBottomInset,
                safeAreaBottom: searchBottomInset
            )
        } favouriteDock: {
            dockedFavouriteStrip
        }
    }

    @ViewBuilder
    private func connectionInfoBlock(
        context: BottomPanelCurtainContext,
        live: VPNSessionStatsSnapshot
    ) -> some View {
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
            let stats = resolvedStats(for: context, live: live)
            VStack(alignment: .leading, spacing: 0) {
                if showsRelease1ActiveMode {
                    let reveal = context.layout.revealProgress
                    let appearance = reduceMotion
                        ? reveal
                        : VelvetMotion.rowProgress(reveal, index: 0)
                    PanelRevealHeightClip(progress: appearance) {
                        VPNActiveSubscriptionRow(
                            title: activeSubscriptionTitle,
                            subtitle: activeSubscriptionSubtitle
                        ) {
                            setProviderSwitchPresented(true)
                        }
                        .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
                        .padding(.bottom, 12)
                    }
                }

                AnimatedPanelStatsReveal(context: context) { reveal in
                VPNProviderMessageCard(
                    provider: displayProvider,
                    regionLabel: stats.region,
                    pingMs: stats.pingMs,
                    downloadRate: stats.downloadRate,
                    uploadRate: stats.uploadRate,
                    usageFraction: displayUsageFraction(live: live),
                    usageTrailingLabel: usageTrailingLabel(live: live),
                    revealProgress: reveal,
                    showsConnectionStats: connectionState == .connected || isSingleProviderExpanded,
                    showsRenewalBanner: showsRenewalBanner,
                    selectionMismatch: showsMismatchGap ? selectionMismatch : nil,
                    showsVelvetStatsPromo: showsVelvetStatsPromo && !showsMismatchGap,
                    statsUsageLeadingOverride: statsUsageLeadingLabel(live: live),
                    supplementalUsage: context.layout.revealProgress > 0.45
                        ? connectionInfoLTEUsageBar
                        : nil,
                    onStatsTap: context.isStatsExpanded ? { openConnectionInfo() } : nil,
                    onVelvetPromoTap: openVelvetPaywall,
                    onUseSmartAuto: connectWithSmartAutoFallback,
                    onBrowseLocations: expandPanelForLocationBrowse,
                    onRenewSubscription: openRenewalWebsite,
                    onHideRenewalBanner: hideRenewalBanner,
                    providerStore: providerStore
                )
                .velvetLoadingShimmer(
                    isActive: isPanelContentLoading,
                    reduceMotion: reduceMotion,
                    index: 0
                )
            }
            }
        }
    }

    private func usageTrailingLabel(live: VPNSessionStatsSnapshot) -> String {
        switch connectionState {
        case .connected:
            if VPNReleaseProfile.isRelease1 {
                return VPNFigmaSection550Copy.demoTraffic(providerName: displayProvider.name).trailing
            }
            return live.dataUsedText
        case .connecting:
            return ui("Connecting…")
        case .disconnected:
            return needsSubscriptionAction ? ui("Renew to connect") : ui("Not connected")
        case .failed(let failure):
            if case .selectionMismatch(let mismatch) = failure {
                return mismatch.collapsedSubtitle
            }
            return needsSubscriptionAction ? ui("Renew to connect") : ui("Try another server")
        }
    }

    private var statsRegionLabel: String {
        resolvedConnection?.location.name ?? selectedLocation.name
    }

    private func figmaDemoSessionStats(islandCollapsed: Bool) -> VPNFigmaSection550Copy.DemoSessionStats? {
        guard VPNReleaseProfile.isRelease1, connectionState == .connected else { return nil }
        return VPNFigmaSection550Copy.demoSessionStats(
            providerName: displayProvider.name,
            islandCollapsed: islandCollapsed
        )
    }

    private func resolvedStats(
        for context: BottomPanelCurtainContext,
        live: VPNSessionStatsSnapshot
    ) -> (
        region: String,
        pingMs: Int,
        downloadRate: String,
        uploadRate: String
    ) {
        if let demo = figmaDemoSessionStats(islandCollapsed: context.position == .island) {
            let place = resolvedConnection?.location ?? selectedLocation
            return (place.name, place.ping, demo.downloadRate, demo.uploadRate)
        }
        return (statsRegionLabel, live.pingMs, live.downloadRate, live.uploadRate)
    }

    private func displayUsageFraction(live: VPNSessionStatsSnapshot) -> Double {
        if VPNReleaseProfile.isRelease1, connectionState == .connected {
            return VPNFigmaSection550Copy.demoTraffic(providerName: displayProvider.name).fraction
        }
        return live.usageFraction
    }

    private func networksPanelHeader(context: BottomPanelCurtainContext) -> some View {
        networksPanelHeaderRow(context: context)
            .padding(.horizontal, VelvetMetrics.rowHorizontalPadding * context.layout.revealProgress)
            .padding(.bottom, VelvetMetrics.collapsedHeaderBottomPadding * context.layout.revealProgress)
            .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
            .velvetLoadingShimmer(
                isActive: isLocationSwitching && context.layout.revealProgress > 0.08,
                reduceMotion: reduceMotion,
                index: 0
            )
    }

    @ViewBuilder
    private func networksPanelHeaderRow(context: BottomPanelCurtainContext) -> some View {
        if context.position == .island && context.layout.revealProgress < 0.08 {
            collapsedIslandHeader(context: context)
        } else if usesBrowsingLocationsHeader {
            browsingLocationsHeader(context: context)
        } else {
            expandedNetworksHeader(context: context)
        }
    }

    private func collapsedIslandHeader(context: BottomPanelCurtainContext) -> some View {
        if usesMenuCollapsedChrome {
            return AnyView(menuCollapsedHeader)
        }
        return AnyView(standardCollapsedHeader(context: context))
    }

    private var menuCollapsedHeader: some View {
        VPNIslandMenuCollapsedHeader(
            status: menuStatusText,
            provider: headerProvider,
            providerName: menuProviderName,
            locationTitle: menuLocationTitle,
            locationFlag: menuLocationFlag,
            onProvider: { setProviderSwitchPresented(true) },
            onLocation: openLocationsFromCollapsedIsland
        )
    }

    private var menuStatusText: String {
        if isSwitchingServer { return ui("Switching server…") }
        switch connectionState {
        case .connected:
            return uiFormat("Connected to %@", menuLocationTitle)
        case .connecting:
            return ui("Connecting…")
        case .disconnected:
            return ui("Not connected")
        case .failed(let failure):
            return failure.displayMessage
        }
    }

    private var menuProviderName: String {
        if showsAllSubscriptionsCatalog {
            return ui("All subscriptions")
        }
        return headerProvider.catalogDisplayName.withoutEmoji
    }

    private var menuLocationTitle: String {
        ui(activePlaceName.withoutEmoji.replacingOccurrences(of: "SMART-", with: ""))
    }

    private var menuLocationFlag: String? {
        switch locationSelection {
        case let .manual(location, _):
            return location.flag
        case .smartAuto, .smartJob:
            if connectionState == .connected || connectionState == .connecting {
                return resolvedConnection?.location.flag
            }
            return nil
        }
    }

    private func openLocationsFromCollapsedIsland() {
        pendingLocationScroll = true
        searchIsFocused = false
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .expanded
        }
    }

    private func standardCollapsedHeader(context: BottomPanelCurtainContext) -> some View {
        VPNIslandCollapsedHeader(
            provider: headerProvider,
            title: collapsedHeaderTitle,
            subtitle: collapsedHeaderSubtitle,
            style: collapsedIslandChromeStyle,
            providers: providers,
            showsMultiProviderSummary: showsMultiProviderIconStack,
            activePreset: showsCollapsedSmartPreset ? activeUseCaseChoice : nil,
            onPresetSelected: showsCollapsedSmartPreset ? connectWithMenuChoice : nil,
            providerPickerProviders: showsCollapsedProviderPicker ? collapsedPickerProviders : [],
            activeProviderID: providerStore.activeProviderID,
            onSelectActiveProvider: showsCollapsedProviderPicker ? { selectActiveProvider(id: $0) } : nil,
            onSummaryTap: panelChromeMode == .singleProvider ? context.togglePosition : nil,
            expandSystemName: collapsedExpandSystemName,
            onExpand: context.togglePosition
        )
    }

    private func expandedNetworksHeader(context: BottomPanelCurtainContext) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expandedHeaderTitle.withoutEmoji)
                    .font(VelvetTypography.panelStatusTitle)
                    .foregroundStyle(VelvetTheme.mainTextDark)
                    .lineLimit(1)

                Text(expandedHeaderSubtitle.withoutEmoji)
                    .font(VelvetTypography.panelStatusSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
                    .animation(
                        VelvetMotion.contentCrossfade(reduceMotion: reduceMotion),
                        value: expandedHeaderSubtitle
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VPNConfigOptionsMenu(
                showsDeleteConfirmation: $showsDeleteConfirmation,
                showsProviderSettings: panelChromeMode == .singleProvider,
                usesRelease1Copy: VPNReleaseProfile.isRelease1,
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
            .accessibilityLabel(context.position == .island ? ui("Expand panel") : ui("Collapse panel"))
        }
        .frame(height: VelvetMetrics.expandedPanelHeaderHeight)
    }

    private func networksAndLocationsContent(context: BottomPanelCurtainContext) -> some View {
        let reveal = context.layout.revealProgress
        let showsDisconnectedActiveMode = showsRelease1ActiveMode && connectionState != .connected
        let presetCount = showsPresets ? presetChoiceCount : 0
        let presetsHeaderIndex = showsDisconnectedActiveMode ? 1 : 0
        let locationsHeaderIndex = presetsHeaderIndex + (showsPresets ? 1 + presetCount : 0)

        return VStack(alignment: .leading, spacing: VelvetMetrics.panelScrollSectionSpacing) {
            if panelChromeMode == .multiProvider, !VPNReleaseProfile.isRelease1 {
                paddedSection {
                    multiProviderSummaryCard
                        .velvetPanelRowReveal(progress: reveal, index: 0, reduceMotion: reduceMotion)
                }
            }

            if showsDisconnectedActiveMode {
                paddedSection {
                    VPNActiveSubscriptionRow(
                        title: activeSubscriptionTitle,
                        subtitle: activeSubscriptionSubtitle
                    ) {
                        setProviderSwitchPresented(true)
                    }
                    .velvetPanelRowReveal(progress: reveal, index: 0, reduceMotion: reduceMotion)
                }
            }

            if showsPresets {
                paddedSection(spacing: VelvetMetrics.panelSectionHeaderSpacing) {
                    VPNPresetsStrip(
                        locationSelection: locationSelection,
                        selectionSource: selectionSource,
                        usesFigmaSection550Copy: VPNReleaseProfile.isRelease1,
                        staggerIndexOffset: 1,
                        hidesForLoading: isPanelContentLoading,
                        reduceMotion: reduceMotion,
                        panelRevealProgress: reveal,
                        panelStaggerIndexOffset: presetsHeaderIndex,
                        onSelect: connectWithMenuChoice
                    )
                }
            }

            paddedSection(spacing: VelvetMetrics.panelSectionHeaderSpacing) {
                LocationListScrollRequest(isPending: $pendingLocationScroll)
                if query.isDefault, !favouriteEntries.isEmpty {
                    favouriteLocationsStrip
                        .velvetPanelRowReveal(
                            progress: reveal,
                            index: locationsHeaderIndex,
                            reduceMotion: reduceMotion
                        )
                }
                if !usesMenuCollapsedChrome {
                    VPNPanelSectionHeader(title: ui("All locations"))
                        .velvetPanelRowReveal(
                            progress: reveal,
                            index: locationsHeaderIndex,
                            reduceMotion: reduceMotion
                        )
                }
                allLocationsCard(
                    panelRevealProgress: reveal,
                    panelStaggerIndexOffset: locationsHeaderIndex + 1
                )
            }
            .background {
                if usesMenuCollapsedChrome {
                    Color(.systemGroupedBackground)
                }
            }
            .overlay(alignment: .topLeading) {
                PanelScrollAnchor(name: Self.locationsAnchor)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var multiProviderSummaryCard: some View {
        VPNCompactNetworksCard(
            providerStore: providerStore,
            onOpenProvider: { providerSettingsID = $0 }
        )
    }

    private var showsRelease1ActiveMode: Bool {
        showsMultiActiveProviderPicker
    }

    private var showsAllSubscriptionsCatalog: Bool {
        showsMultiActiveProviderPicker && providerStore.showsAllSubscriptionsCatalog
    }

    private var activeSubscriptionTitle: String {
        if showsAllSubscriptionsCatalog {
            return VPNFigmaSection550Copy.allSubscriptionsLabel
        }
        return chromeProvider.catalogDisplayName.withoutEmoji
    }

    private var activeSubscriptionSubtitle: String? {
        if showsAllSubscriptionsCatalog {
            return VPNProvider.allSubscriptionsCaption(providers: providers)
        }
        let caption = chromeProvider.subscriptionIdentityCaption
        return caption.isEmpty ? nil : caption
    }

    private func setProviderSwitchPresented(_ isPresented: Bool) {
        withAnimation(VelvetMotion.popover(reduceMotion: reduceMotion)) {
            showsActiveProviderSwitch = isPresented
        }
    }

    private func switchToAllSubscriptions() {
        if providerStore.showsAllSubscriptionsCatalog {
            setProviderSwitchPresented(false)
            return
        }
        setProviderSwitchPresented(false)
        providerLoadTask?.cancel()
        providerContentLoadingID = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            providerStore.showAllSubscriptions()
            locationSelection = selectionMoved(locationSelection, to: .allNetworks)
        }
    }

    private func switchActiveProvider(id: UUID) {
        guard let provider = providers.first(where: { $0.id == id }), provider.status.isActive else { return }
        if id == providerStore.activeProviderID, case .provider = providerStore.providerScope {
            setProviderSwitchPresented(false)
            return
        }
        setProviderSwitchPresented(false)
        providerLoadTask?.cancel()
        providerContentLoadingID = id
        providerLoadTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            guard !Task.isCancelled, providerContentLoadingID == id else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                applySwitchedProvider(id: id)
            }
            await Task.yield()
            guard !Task.isCancelled, providerContentLoadingID == id else { return }
            providerContentLoadingID = nil
        }
    }

    private func applySwitchedProvider(id: UUID) {
        providerStore.setActiveProvider(id: id)
        let scope = VPNProviderScope.provider(id)
        if let provider = providers.first(where: { $0.id == id }), provider.includesPresets {
            locationSelection = .smartAuto(scope: scope)
            selectionSource = .useCase(.smart)
        } else {
            locationSelection = selectionMoved(locationSelection, to: scope)
        }
        guard connectionState == .connected else { return }
        guard let resolved = VPNConnectionPlanner.resolve(
            providers: providers,
            selection: locationSelection
        ) else { return }
        resolvedConnection = resolved
        selectedLocation = resolved.location
    }

    private func selectionMoved(
        _ selection: VPNLocationSelection,
        to scope: VPNProviderScope
    ) -> VPNLocationSelection {
        switch selection {
        case .smartAuto:
            return .smartAuto(scope: scope)
        case let .smartJob(job, _):
            return .smartJob(job, scope: scope)
        case let .manual(location, providerID):
            if case .allNetworks = scope {
                return .manual(location: location, providerID: providerID)
            }
            guard case let .provider(scopedID) = scope,
                  let provider = providers.first(where: { $0.id == scopedID }),
                  let match = provider.servers.first(where: {
                      $0.name == location.name && $0.city == location.city && $0.kind != .smart
                  })
            else {
                return .smartAuto(scope: scope)
            }
            return .manual(location: match, providerID: scopedID)
        }
    }

    private func selectActiveProvider(id: UUID) {
        applySwitchedProvider(id: id)
    }

    private var isManualSelection: Bool {
        if case .manual = locationSelection { return true }
        return false
    }

    /// The place or mode the card should name, in both the collapsed and expanded headers.
    private var activePlaceName: String {
        if connectionState == .connected || connectionState == .connecting,
           let name = resolvedConnection?.location.name {
            return name
        }
        switch locationSelection {
        case let .manual(location, _):
            return location.name
        case .smartAuto:
            return VPNFigmaSection550Copy.collapsedFastestTitle
        case let .smartJob(job, _):
            return job.title
        }
    }

    /// How that place was chosen, plus the subscription it belongs to.
    private var activeModeCaption: String {
        let providerName = (resolvedConnection?.provider ?? chromeProvider).catalogDisplayName.withoutEmoji
        switch locationSelection {
        case .smartAuto:
            if connectionState == .disconnected {
                return VPNFigmaSection550Copy.smartAutoTrafficSubtitle
            }
            return uiFormat("Smart · %@", providerName)
        case let .smartJob(job, _):
            return "\(job.title) · \(providerName)"
        case let .manual(location, _):
            if connectionState == .connected || connectionState == .connecting {
                return providerName
            }
            return location.city
        }
    }

    private var panelCompactBarTitle: String {
        if VPNReleaseProfile.isRelease1, panelChromeMode == .multiProvider {
            return VPNHomeFormat.networksAndLocations.title
        }
        return displayProvider.name
    }

    private var usesBrowsingLocationsHeader: Bool {
        guard VPNReleaseProfile.isRelease1, panelChromeMode == .multiProvider else { return false }
        return searchIsFocused || !query.isDefault
    }

    private func browsingLocationsHeader(context: BottomPanelCurtainContext) -> some View {
        HStack(spacing: 10) {
            Text(VPNHomeFormat.networksAndLocations.title)
                .font(VelvetTypography.panelStatusTitle)
                .foregroundStyle(VelvetTheme.mainTextDark)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            VPNConfigOptionsMenu(
                showsDeleteConfirmation: $showsDeleteConfirmation,
                showsProviderSettings: panelChromeMode == .singleProvider,
                usesRelease1Copy: VPNReleaseProfile.isRelease1,
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
            .accessibilityLabel(context.position == .island ? ui("Expand panel") : ui("Collapse panel"))
        }
        .frame(height: VelvetMetrics.expandedPanelHeaderHeight)
    }

    private func statsUsageLeadingLabel(live: VPNSessionStatsSnapshot) -> String? {
        if VPNReleaseProfile.isRelease1, connectionState == .connected {
            return VPNFigmaSection550Copy.demoTraffic(providerName: displayProvider.name).leading
        }
        guard displayProvider.showsDetailMessage else { return nil }
        let fraction = min(max(live.usageFraction, 0), 1)
        let percent = Int((fraction * 100).rounded())
        return uiFormat("%lld%% basic traffic left", percent)
    }

    private var connectionInfoLTEUsageBar: ConnectionStatsStrip.SupplementalUsageBar? {
        if VPNReleaseProfile.isRelease1, connectionState == .connected {
            return ConnectionStatsStrip.SupplementalUsageBar(
                leading: VPNFigmaSection550Copy.lteTrafficLeading,
                trailing: VPNFigmaSection550Copy.lteSessionDelta,
                fraction: VPNFigmaSection550Copy.lteTrafficFraction
            )
        }
        guard displayProvider.showsDetailMessage else { return nil }
        return ConnectionStatsStrip.SupplementalUsageBar(
            leading: VPNFigmaSection550Copy.lteTrafficLeading,
            trailing: VPNFigmaSection550Copy.lteSessionDelta,
            fraction: VPNFigmaSection550Copy.lteTrafficFraction
        )
    }

    private func paddedSection<Content: View>(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VelvetTheme.horizontalPadding)
    }

    private var presetChoiceCount: Int {
        VPNReleaseProfile.isRelease1
            ? VPNFigmaSection550Copy.expandedPresetChoices.count
            : VPNUseCaseMenuChoice.allCases.count
    }

    private var favouriteEntries: [VPNFavouriteLocationEntry] {
        VPNFavouriteLocationsStore.load(from: storedFavourites)
    }

    private var selectedFavouriteID: String? {
        guard case let .location(selection) = selectionSource,
              case let .manual(location, providerID) = selection
        else { return nil }
        return VPNFavouriteLocationEntry.id(providerID: providerID, persistenceKey: location.persistenceKey)
    }

    private var favouriteLocationsStrip: some View {
        favouriteStrip(horizontalInset: 0)
    }

    /// Full-width row under the card. Inset keeps the title lined up with the island.
    private var dockedFavouriteStrip: some View {
        favouriteStrip(horizontalInset: VelvetTheme.islandHorizontalInset)
    }

    private func favouriteStrip(horizontalInset: CGFloat) -> some View {
        VPNFavouriteLocationsStrip(
            entries: favouriteEntries,
            selectedID: selectedFavouriteID,
            horizontalInset: horizontalInset,
            onSelect: connectFavourite,
            onRemove: removeFavourite
        )
    }

    private func seedFavouritesIfNeeded() {
        guard !didSeedFavourites else { return }
        didSeedFavourites = true
        guard storedFavourites.isEmpty else { return }
        storedFavourites = VPNFavouriteLocationsStore.encode(
            VPNFavouriteLocationsStore.demoEntries(from: providers)
        )
    }

    private func toggleFavourite(_ location: VPNNetworkLocation) {
        storedFavourites = VPNFavouriteLocationsStore.toggled(location, in: storedFavourites)
    }

    private func removeFavourite(_ entry: VPNFavouriteLocationEntry) {
        let entries = favouriteEntries.filter { $0.id != entry.id }
        storedFavourites = VPNFavouriteLocationsStore.encode(entries)
    }

    private func connectFavourite(_ entry: VPNFavouriteLocationEntry) {
        guard let network = networkLocation(for: entry) else { return }
        connectManualLocation(network)
    }

    private func networkLocation(for entry: VPNFavouriteLocationEntry) -> VPNNetworkLocation? {
        if let provider = providers.first(where: { $0.id == entry.providerID }),
           let location = provider.servers.first(where: { $0.persistenceKey == entry.persistenceKey }) {
            return VPNNetworkLocation(location: location, provider: provider)
        }

        for provider in providers where provider.status.isActive {
            if let location = provider.servers.first(where: { $0.persistenceKey == entry.persistenceKey }) {
                return VPNNetworkLocation(location: location, provider: provider)
            }
            if let location = provider.servers.first(where: {
                $0.name == entry.name && $0.city == entry.city && $0.kind != .smart
            }) {
                return VPNNetworkLocation(location: location, provider: provider)
            }
        }
        return nil
    }

    private func allLocationsCard(
        panelRevealProgress: CGFloat,
        panelStaggerIndexOffset: Int
    ) -> some View {
        VPNAllLocationsCard(
            providerStore: providerStore,
            locationSelection: $locationSelection,
            selectionSource: $selectionSource,
            query: $query,
            pingResults: pingResults,
            pingingIDs: pingingIDs,
            hidesForLoading: isPanelContentLoading,
            staggerIndexOffset: showsPresets ? 4 : 1,
            reduceMotion: reduceMotion,
            panelRevealProgress: panelRevealProgress,
            panelStaggerIndexOffset: panelStaggerIndexOffset,
            favouriteIDs: Set(favouriteEntries.map(\.id)),
            showsPlate: !usesMenuCollapsedChrome,
            groupsAsPlates: usesMenuCollapsedChrome,
            prominentSectionHeaders: usesMenuCollapsedChrome,
            onSmartLocation: connectSmartLocation,
            onManualLocation: connectManualLocation,
            onToggleFavourite: toggleFavourite
        )
    }

    private var connectionButton: some View {
        VPNPrimaryConnectionButton(
            title: connectionButtonTitle,
            connectionState: connectionState,
            usesErrorTint: usesErrorConnectionTint,
            showsPowerIcon: {
                if case .disconnected = connectionState { return false }
                return true
            }(),
            isBusy: isLocationSwitching,
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
        if VPNReleaseProfile.isRelease1 {
            return providerStore.activeProvider
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
        if isSwitchingServer { return ui("Switching server…") }
        switch connectionState {
        case .connected:
            return resolvedConnection?.location.name ?? selectedLocation.name
        case .connecting:
            return ui("Connecting…")
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

    private var collapsedConnectedLocationTitle: String {
        uiPlace(activePlaceName)
    }

    private var collapsedHeaderTitle: String {
        switch connectionState {
        case .connected:
            return collapsedConnectedLocationTitle
        case .connecting:
            return uiPlace(activePlaceName)
        case .failed(let failure):
            if needsSubscriptionAction {
                return displayProvider.status == .expired ? ui("Subscription expired") : ui("No active VPN")
            }
            if case .selectionMismatch(let mismatch) = failure {
                return mismatch.collapsedTitle
            }
            return ui("Couldn't connect")
        case .disconnected:
            if needsSubscriptionAction {
                return displayProvider.status == .expired ? ui("Subscription expired") : ui("No active VPN")
            }
            return uiPlace(activePlaceName)
        }
    }

    private var collapsedHeaderSubtitle: String {
        if isSwitchingServer { return ui("Switching server…") }
        if connectionState == .connected || connectionState == .connecting {
            if connectionState == .connecting {
                return ui("Connecting…")
            }
            return activeModeCaption
        }
        if needsSubscriptionAction {
            return ui("Renew to connect")
        }
        if case .failed(let failure) = connectionState {
            if case .selectionMismatch(let mismatch) = failure {
                return mismatch.collapsedSubtitle
            }
            return ui("Try another server or check settings")
        }
        if showsFastestMultiCollapsedLayout || isManualSelection {
            return activeModeCaption
        }
        if let usageSummary = displayProvider.usageSummaryLabel, connectionState == .disconnected {
            return usageSummary
        }
        return islandModeSubtitle
    }

    private var expandedHeaderTitle: String {
        if VPNReleaseProfile.isRelease1 {
            return uiPlace(activePlaceName)
        }
        if showsMultiProviderHeader,
           connectionState == .disconnected,
           !VPNReleaseProfile.isRelease1 {
            switch locationSelection {
            case .smartAuto, .smartJob:
                return activeUseCaseChoice?.title ?? ui("Smart")
            case .manual:
                return displayProvider.name
            }
        }
        return displayProvider.name
    }

    private var expandedHeaderSubtitle: String {
        if VPNReleaseProfile.isRelease1 {
            return activeModeCaption
        }
        if connectionState == .connected {
            return resolvedConnection?.location.name ?? selectedLocation.name
        }
        return displayProvider.panelHeaderSubtitle
    }

    private var activeUseCaseChoice: VPNUseCaseMenuChoice? {
        VPNUseCaseMenuChoice.matching(locationSelection)
    }

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected:
            needsSubscriptionAction ? ui("Renew subscription") : ui("Connect")
        case .connecting:
            if isSwitchingServer {
                ui("Switching server…")
            } else {
                isFindingBest ? ui("Finding best connection…") : ui("Connecting…")
            }
        case .connected:
            isSwitchingServer ? ui("Switching server…") : ui("Connected")
        case .failed(let failure):
            if needsSubscriptionAction {
                ui("Renew subscription")
            } else if case .selectionMismatch = failure {
                ui("Browse locations")
            } else {
                ui("Retry")
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
        providerSettingsID = provider.id
    }

    private var connectionInfoProviderMessage: String? {
        let providerID = resolvedConnection?.provider.id ?? menuContextProvider?.id
        guard let providerID else { return nil }
        return providerStore.provider(id: providerID)?.displayedProviderMessage
    }

    private func connectWithMenuChoice(_ choice: VPNUseCaseMenuChoice) {
        if !VPNReleaseProfile.isRelease1 {
            providerStore.activateVelvetForPresetSelection()
        }
        selectionSource = .useCase(choice)
        connectWithSelection(choice.locationSelection(scope: providerStore.providerScope))
    }

    private func connectWithSelection(_ newSelection: VPNLocationSelection) {
        if usesMenuCollapsedChrome,
           connectionState != .connected,
           connectionState != .connecting {
            locationSelection = newSelection
            collapseToIsland()
            return
        }

        if connectionState == .connected {
            if newSelection == locationSelection { return }
            locationSelection = newSelection
            collapseToIsland()
            return
        }

        if connectionState == .connecting {
            locationSelection = newSelection
            collapseToIsland()
            return
        }

        locationSelection = newSelection
        collapseToIsland()
        handleConnectionTap()
    }

    private func connectManualLocation(_ networkLocation: VPNNetworkLocation) {
        VPNRecentLocationsStore.record(networkLocation)
        providerStore.setActiveProvider(
            id: networkLocation.provider.id,
            updatesCatalog: !providerStore.showsAllSubscriptionsCatalog
        )
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
        resolvedConnection?.provider ?? providerStore.activeProvider
    }

    private func syncLocationSelectionToActiveProvider() {
        locationSelection = VPNConnectionPlanner.reconcileSelection(
            locationSelection,
            providers: providers,
            storeScope: providerStore.providerScope
        )
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
            if VPNReleaseProfile.isRelease1 {
                showsPingResultsSheet = true
            } else {
                runInlinePingCheck()
            }
        case .edit:
            if let provider = menuContextProvider {
                editProviderID = provider.id
                showsEditSheet = true
            }
        case .providerSettings:
            if let provider = menuContextProvider {
                providerSettingsID = provider.id
            }
        }
    }

    private func runInlinePingCheck() {
        guard !isRefreshingPing else { return }
        isRefreshingPing = true
        pingResults = [:]

        let catalogScope = providerStore.providerScope
        let entries = VPNConnectionPlanner.inlinePingEntries(
            providers: providers,
            scope: catalogScope,
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
            expandPanelForLocationBrowse()
            return
        }

        if needsSubscriptionAction,
           connectionState == .disconnected || connectionState.isFailed {
            handleSubscriptionRenewalAction()
            return
        }

        if connectionState == .connected, !isSwitchingServer {
            connectTask?.cancel()
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

        connectTask?.cancel()

        if connectionState == .connected, isSwitchingServer {
            applyResolvedLocation(keepConnected: true)
            return
        }

        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .connecting
            isFindingBest = true
        }

        connectTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, connectionState == .connecting else { return }

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
                || VPNReleaseProfile.isRelease1

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
            guard !Task.isCancelled, connectionState == .connecting else { return }

            withAnimation(VelvetMotion.connectionLayout(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
                isSwitchingServer = false
                connectedAt = connectedAt ?? .now
            }
        }
    }

    /// Stay green while hopping cities. A reconnect flash would read as a wait, not a move.
    private func applyResolvedLocation(keepConnected: Bool) {
        var workingSelection = locationSelection
        var resolved = VPNConnectionPlanner.resolve(
            providers: providers,
            selection: workingSelection
        )

        if resolved == nil,
           !VPNReleaseProfile.isRelease1,
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
        }

        guard let resolved else {
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

        locationSelection = workingSelection
        resolvedConnection = resolved
        selectedLocation = resolved.location
        isFindingBest = false
        isSwitchingServer = false
        if keepConnected {
            connectionState = .connected
            connectedAt = connectedAt ?? .now
        }
    }

    /// Keep the green map. Stats and the button wait, so a hop still feels like work.
    private func beginLocationSwitch() {
        connectTask?.cancel()
        isSwitchingServer = true
        connectTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            guard !Task.isCancelled else { return }
            applyResolvedLocation(keepConnected: true)
        }
    }
}

/// Scrolls the open sheet to the location list after the collapsed location chooser is tapped.
private struct LocationListScrollRequest: View {
    @Binding var isPending: Bool
    @Environment(\.panelScrollViewHandle) private var panelScrollViewHandle

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear(perform: scrollIfNeeded)
            .onChange(of: isPending) { _, pending in
                if pending { scrollIfNeeded() }
            }
    }

    private func scrollIfNeeded() {
        guard isPending else { return }
        let handle = panelScrollViewHandle
        Task { @MainActor in
            for _ in 0..<12 {
                if handle.scrollToAnchor(VPNNetworksIslandPanel.locationsAnchor, animated: true) {
                    isPending = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            isPending = false
        }
    }
}
