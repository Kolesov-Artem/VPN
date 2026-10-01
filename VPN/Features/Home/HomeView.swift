import SwiftUI

struct HomeView: View {
    @Binding var route: AppRoute

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.ru
    @State private var providerStore = VPNProviderStore()
    @State private var panelPosition = BottomPanelPosition.island
    @State private var connectionState = VPNConnectionState.disconnected
    @State private var selectedLocation = VPNLocation.samples[0]
    @State private var locationSelection: VPNLocationSelection = .smartAuto(scope: .allNetworks)
    @State private var selectionSource: VPNSelectionSource = .useCase(.smart)
    @State private var resolvedConnection: VPNResolvedConnection?
    @State private var showsAccount = false
#if DEBUG
    @State private var showsSettings = false
#endif
    @State private var showsRoutingSettings = false
    @State private var showsConnectionInfo = false
    @State private var isPanelInteracting = false
    @State private var isAddingConfiguration = false
    @State private var isSwitchingServer = false
    @State private var importToastMessage: String?
    @State private var connectedAt: Date?
    @State private var mockPublicIP = "185.42.18.90"
    @State private var sessionStats = VPNSessionStatsModel()
    @State private var serviceAvailability = ServiceAvailabilityModel()
    @State private var isServiceListExpanded = CommandLine.arguments.contains("--sites-open")
    @State private var shouldAutoConnect = false
    @State private var showsVPNPermissionRequest = false
    @State private var importedProviderPendingPrimary: VPNProvider?
    @State private var providerSettingsID: UUID?
    @State private var didAutoPresentRenewalPanel = false
    @State private var statsTask: Task<Void, Never>?
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.panelDetentMode") private var panelDetentMode = VPNPanelDetentMode.stepped
    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic
    @AppStorage(VPNHomeChrome.storageKey) private var homeChrome = VPNHomeChrome.island
    @AppStorage("velvet.autoConnect") private var autoConnect = false
    @AppStorage("velvet.connectLastLocation") private var connectLastLocation = true
    @AppStorage("velvet.defaultUserJob") private var defaultUserJobRaw = VPNUserJob.streaming.rawValue

    init(route: Binding<AppRoute>) {
        _route = route
#if DEBUG
        if CommandLine.arguments.contains("--panel-sheet") {
            UserDefaults.standard.set(VPNPanelStyle.sheet.rawValue, forKey: "velvet.panelStyle")
        } else if CommandLine.arguments.contains("--panel-island") {
            UserDefaults.standard.set(VPNPanelStyle.island.rawValue, forKey: "velvet.panelStyle")
        }

        let initialPanelPosition: BottomPanelPosition =
            if CommandLine.arguments.contains("--show-expanded") {
                .expanded
            } else if CommandLine.arguments.contains("--show-intermediate") {
                .intermediate
            } else {
                .island
            }
#else
        let initialPanelPosition = BottomPanelPosition.island
#endif
        _panelPosition = State(initialValue: initialPanelPosition)
        _isServiceListExpanded = State(
            initialValue: CommandLine.arguments.contains("--availability-open")
        )
    }

    var body: some View {
        Group {
            if homeChrome == .island || homeChrome == .islandMenu {
                if homeChrome == .islandMenu || homeFormat == .networksAndLocations {
                    networksIslandLayout
                } else {
                    switch panelStyle {
                    case .island:
                        islandLayout
                    case .sheet:
                        sheetLayout
                    }
                }
            } else {
                simpleHome
            }
        }
        .sheet(isPresented: Binding(
            get: { providerSettingsID != nil },
            set: { if !$0 { providerSettingsID = nil } }
        )) {
            if let providerSettingsID {
                VPNProviderDetailView(
                    providerStore: providerStore,
                    providerID: providerSettingsID,
                    isVPNConnected: connectionState == .connected,
                    activeConnectionProviderID: resolvedConnection?.provider.id
                )
                .id(appLanguage)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(
            importedProviderPendingPrimary.map {
                VPNFigmaSection550Copy.makeMainVPNPromptTitle(providerName: $0.name)
            } ?? "",
            isPresented: Binding(
                get: { importedProviderPendingPrimary != nil },
                set: { if !$0 { importedProviderPendingPrimary = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(VPNFigmaSection550Copy.makeMainVPNConfirm) {
                confirmImportedProviderAsMain()
            }
            Button(VPNFigmaSection550Copy.makeMainVPNDecline, role: .cancel) {
                importedProviderPendingPrimary = nil
            }
        } message: {
            Text(VPNFigmaSection550Copy.makeMainVPNPromptMessage)
        }
        .id("\(homeFormat.rawValue)-\(appLanguage)")
        .fullScreenCover(isPresented: $showsAccount) {
            VPNAccountView(providerStore: providerStore) { id in
                showsAccount = false
                providerSettingsID = id
            }
            .id(appLanguage)
        }
#if DEBUG
        .sheet(isPresented: $showsSettings) {
            settingsSheet
                .id(appLanguage)
        }
#endif
        .sheet(isPresented: $showsRoutingSettings) {
            VPNRoutingSettingsView()
                .id(appLanguage)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsConnectionInfo) {
            SessionStatsConsumer(model: sessionStats, readsLiveValues: true) { live in
                VPNConnectionInfoView(
                    resolvedConnection: resolvedConnection,
                    connectedAt: connectedAt,
                    mockPublicIP: mockPublicIP,
                    regionLabel: resolvedConnection?.location.name ?? selectedLocation.name,
                    pingMs: live.pingMs,
                    downloadRate: live.downloadRate,
                    uploadRate: live.uploadRate,
                    usageFraction: live.usageFraction,
                    sessionDataUsedText: live.dataUsedText,
                    providerMessage: resolvedConnection.flatMap { connection in
                        providerStore.provider(id: connection.provider.id)?.displayedProviderMessage
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: homeFormat) { _, _ in
            panelPosition = .island
            resolvedConnection = nil
            connectionState = .disconnected
            connectedAt = nil
        }
        .onChange(of: panelDetentMode) { _, _ in
            panelPosition = .island
        }
        .onChange(of: locationSelection) { _, selection in
            persistLocationSelection(selection)
        }
        .onChange(of: connectionState) { _, newValue in
            switch newValue {
            case .connected:
                if connectedAt == nil {
                    connectedAt = .now
                }
                mockPublicIP = mockIP(for: resolvedConnection)
                sessionStats.pingMs = resolvedConnection?.location.ping ?? selectedLocation.ping
                startStatsTicker()
                VPNLogsStore.shared.append("Connected to \(resolvedConnection?.provider.name ?? "VPN")")
            case .disconnected, .failed:
                connectedAt = nil
                stopStatsTicker()
            case .connecting:
                break
            }
        }
        .onAppear {
#if DEBUG
            configurePromoDemoIfNeeded()
            if providerStore.activePrototypeScenario == .importedOnly {
                applyImportedOnlyDemoSelection()
            } else if providerStore.activePrototypeScenario != .velvetPlusImported {
                restoreLastLocationSelection()
            }
#else
            restoreLastLocationSelection()
#endif
            presentRenewalPanelIfNeeded()
            if route == .permission {
                route = .home
                requestVPNPermissionAfterImport()
            }
            guard autoConnect, route == .home, connectionState == .disconnected else { return }
            shouldAutoConnect = true
        }
        .onChange(of: route) { _, newRoute in
            if newRoute == .permission {
                route = .home
                requestVPNPermissionAfterImport()
            }
        }
        .alert(
            ui("\"Velvet\" Would Like to Add VPN Configurations"),
            isPresented: $showsVPNPermissionRequest
        ) {
            Button(ui("Don't Allow"), role: .cancel) {}
            Button(ui("Allow")) {
                grantVPNPermissionAndConnect()
            }
        } message: {
            Text(ui("All network activity may be filtered or monitored."))
        }
    }

    private func requestVPNPermissionAfterImport() {
        guard !providerStore.hasSeenVPNPermission else {
            shouldAutoConnect = true
            return
        }
        showsVPNPermissionRequest = true
    }

    private func grantVPNPermissionAndConnect() {
        providerStore.markVPNPermissionSeen()
        shouldAutoConnect = true
    }

    private func presentRenewalPanelIfNeeded() {
        guard route == .home else { return }
        guard !didAutoPresentRenewalPanel else { return }
        guard VPNProviderAvailabilitySummary.anyNeedsRenewalAttention(
            in: providerStore.providers,
            hiddenBannerIDs: providerStore.hiddenRenewalBannerIDs
        ) else {
            return
        }
        guard panelPosition == .island, homeChrome != .islandMenu else { return }
        didAutoPresentRenewalPanel = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            panelPosition = .intermediate
        }
    }

    private var simpleHome: some View {
        SimpleHomeHost(
            chrome: homeChrome,
            providerStore: providerStore,
            route: $route,
            connectionState: $connectionState,
            selectedLocation: $selectedLocation,
            locationSelection: $locationSelection,
            selectionSource: $selectionSource,
            resolvedConnection: $resolvedConnection,
            isSwitchingServer: $isSwitchingServer,
            connectedAt: $connectedAt,
            shouldAutoConnect: $shouldAutoConnect,
            showsAccount: $showsAccount,
            providerSettingsID: $providerSettingsID,
            isAddingConfiguration: $isAddingConfiguration,
            serviceAvailability: serviceAvailability,
            sessionStats: sessionStats,
            importToastMessage: importToastMessage,
            highlightedProvider: highlightedProvider,
            onImportSuccess: handleImportSuccess,
            onVelvetTrial: handleVelvetTrial,
            onImportCancel: handleImportCancel
        )
    }

    private var highlightedProvider: VPNProvider? {
        guard let highlightID = providerStore.highlightedProviderID else { return nil }
        return providerStore.provider(id: highlightID)
    }

    private var networksIslandLayout: some View {
        mapLayer { safeAreaBottom, safeAreaTop, _ in
            VPNNetworksIslandPanel(
                providerStore: providerStore,
                position: $panelPosition,
                connectionState: $connectionState,
                selectedLocation: $selectedLocation,
                locationSelection: $locationSelection,
                selectionSource: $selectionSource,
                resolvedConnection: $resolvedConnection,
                isSwitchingServer: $isSwitchingServer,
                isPanelInteracting: $isPanelInteracting,
                showsRoutingSettings: $showsRoutingSettings,
                connectedAt: $connectedAt,
                shouldAutoConnect: $shouldAutoConnect,
                providerSettingsID: $providerSettingsID,
                sessionStats: sessionStats,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                detentMode: panelDetentMode,
                usesMenuCollapsedChrome: homeChrome == .islandMenu
            )
        }
    }

    private var islandLayout: some View {
        mapLayer { safeAreaBottom, safeAreaTop, _ in
            VPNIslandPanel(
                position: $panelPosition,
                connectionState: $connectionState,
                selectedLocation: $selectedLocation,
                isPanelInteracting: $isPanelInteracting,
                onShowConnectionInfo: { showsConnectionInfo = true },
                sessionStats: sessionStats,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                detentMode: panelDetentMode
            )
        }
    }

    private var sheetLayout: some View {
        mapLayer { _, _, _ in EmptyView() }
            .sheet(isPresented: isHomePresented) {
                VPNBottomPanel(
                    position: $panelPosition,
                    connectionState: $connectionState,
                    selectedLocation: $selectedLocation,
                    detentMode: panelDetentMode
                )
                .presentationDetents(
                    sheetPresentationDetents,
                    selection: presentationDetent
                )
                .presentationContentInteraction(.resizes)
                .presentationBackgroundInteraction(
                    .enabled(upThrough: sheetBackgroundInteractionDetent)
                )
                .presentationBackground {
                    if reduceTransparency {
                        Color(.systemBackground)
                    } else {
                        Rectangle().fill(.ultraThickMaterial)
                    }
                }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(VelvetTheme.panelRadius)
                .interactiveDismissDisabled()
            }
    }

    private var isHomePresented: Binding<Bool> {
        Binding(
            get: { route == .home },
            set: { isPresented in
                if isPresented {
                    route = .home
                } else {
                    route = .onboarding
                }
            }
        )
    }

    private func mapLayer<Panel: View>(
        @ViewBuilder panel: @escaping (CGFloat, CGFloat, BottomPanelDetents) -> Panel
    ) -> some View {
        GeometryReader { proxy in
            let safeAreaBottom = proxy.safeAreaInsets.bottom
            let safeAreaTop = proxy.safeAreaInsets.top
            let detents = detents(
                screenHeight: proxy.size.height + safeAreaBottom,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop
            )

            ZStack(alignment: .bottom) {
                VelvetMapBackground(
                    selectedLocation: selectedLocation,
                    connectionState: connectionState,
                    isInteractive: route == .home,
                    autoRotates: route == .onboarding,
                    onPickCoordinate: selectNearestServer
                )
                .animation(nil, value: panelPosition)

                VStack(spacing: 0) {
                    header
                    if route == .home {
                        if isServiceListExpanded {
                            ServiceAvailabilityCard(
                                model: serviceAvailability,
                                isVPNConnected: connectionState.isConnected
                            )
                            .transition(
                                VelvetMotion.availabilityExpandTransition(reduceMotion: reduceMotion)
                            )
                            .padding(.horizontal, VelvetTheme.horizontalPadding)
                            .padding(.top, 14)
                        }

                        if let highlightID = providerStore.highlightedProviderID,
                           let highlightedProvider = providerStore.provider(id: highlightID) {
                            MapProviderHighlightCard(provider: highlightedProvider)
                                .padding(.horizontal, VelvetTheme.horizontalPadding)
                                .padding(.top, 8)
                                .transition(VelvetMotion.importToast(reduceMotion: reduceMotion))
                                .allowsHitTesting(false)
                        }
                    }
                    Spacer()
                }
                .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
                .animation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion), value: providerStore.highlightedProviderID)
                .animation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion), value: isServiceListExpanded)

                if route == .home {
                    panel(safeAreaBottom, safeAreaTop, detents)
                        .transition(VelvetMotion.homeContent(reduceMotion: reduceMotion))
                }

                if route == .onboarding {
                    onboardingOverlay(safeAreaBottom: safeAreaBottom)
                        .transition(VelvetMotion.onboardingContent(reduceMotion: reduceMotion))
                }

                if let importToastMessage {
                    importToast(importToastMessage)
                        .transition(VelvetMotion.importToast(reduceMotion: reduceMotion))
                        .zIndex(1)
                }
            }
            .animation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion), value: importToastMessage)
            .animation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion), value: providerStore.highlightedProviderID)
            .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func importToast(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, VelvetTheme.horizontalPadding)
                .padding(.vertical, 12)
                .background(.black.opacity(0.86), in: Capsule())
                .padding(.top, 8)
            Spacer()
        }
    }

    private func detents(
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat,
        safeAreaTop: CGFloat
    ) -> BottomPanelDetents {
        switch panelStyle {
        case .island:
            .makeIsland(
                screenHeight: screenHeight,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        case .sheet:
            .make(
                screenHeight: screenHeight,
                safeAreaBottom: safeAreaBottom,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        }
    }

    private var settingsSheet: some View {
        Group {
#if DEBUG
            HomeSettingsView(
                providerStore: providerStore,
                devRuntime: devRuntime,
                onImportFromClipboard: handleClipboardImport
            )
#else
            HomeSettingsView(
                providerStore: providerStore,
                onImportFromClipboard: handleClipboardImport
            )
#endif
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func handleClipboardImport(_ provider: VPNProvider) {
        homeFormat = .networksAndLocations
        importToastMessage = "✓  \(provider.name) added from clipboard"
        importedProviderPendingPrimary = provider
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(VelvetMotion.importToastAnimation(reduceMotion: reduceMotion)) {
                importToastMessage = nil
            }
        }
    }

#if DEBUG
    private var devRuntime: VPNDevRuntime {
        VPNDevRuntime(
            route: $route,
            panelPosition: $panelPosition,
            connectionState: $connectionState,
            resolvedConnection: $resolvedConnection,
            connectedAt: $connectedAt,
            livePingMs: Binding(
                get: { sessionStats.pingMs },
                set: { sessionStats.pingMs = $0 }
            ),
            downloadRate: Binding(
                get: { sessionStats.downloadRate },
                set: { sessionStats.downloadRate = $0 }
            ),
            uploadRate: Binding(
                get: { sessionStats.uploadRate },
                set: { sessionStats.uploadRate = $0 }
            ),
            sessionBytesUsed: Binding(
                get: { sessionStats.bytesUsed },
                set: { sessionStats.bytesUsed = $0 }
            ),
            isSwitchingServer: $isSwitchingServer,
            locationSelection: $locationSelection,
            selectionSource: $selectionSource,
            onDismissSettings: { showsSettings = false }
        )
    }
#endif

    private func applyImportedOnlyDemoSelection() {
        guard let demo = VPNPrototypeScenario.importedOnly.demoLocationSelection(
            scope: providerStore.providerScope
        ) else { return }
        locationSelection = demo
        selectionSource = .useCase(VPNUseCaseMenuChoice.matching(demo) ?? .smart)
    }

    private func restoreLastLocationSelection() {
        guard connectLastLocation else { return }
        providerStore.reconcileActiveProvider()
        if let job = VPNUserJob(rawValue: defaultUserJobRaw) {
            if providerStore.activeProvider.kind == .velvetFeatured {
                providerStore.activateVelvetForPresetSelection()
            }
            let selection = VPNLocationSelection.smartJob(job, scope: providerStore.providerScope)
            locationSelection = VPNConnectionPlanner.reconcileSelection(
                selection,
                providers: providerStore.providers,
                storeScope: providerStore.providerScope
            )
            selectionSource = .useCase(VPNUseCaseMenuChoice.matching(locationSelection) ?? .smart)
        }
    }

    private func persistLocationSelection(_ selection: VPNLocationSelection) {
        if case let .smartJob(job, _) = selection {
            defaultUserJobRaw = job.rawValue
        }
    }

    private func startStatsTicker() {
        statsTask?.cancel()
        statsTask = Task { @MainActor in
            let basePing = resolvedConnection?.location.ping ?? selectedLocation.ping
            while !Task.isCancelled {
                if isPanelInteracting {
                    try? await Task.sleep(for: .milliseconds(250))
                    continue
                }

                sessionStats.tick(basePing: basePing)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopStatsTicker() {
        statsTask?.cancel()
        statsTask = nil
        sessionStats.reset()
    }

    private func mockIP(for resolvedConnection: VPNResolvedConnection?) -> String {
        guard let resolvedConnection else { return "185.42.18.90" }
        let suffix = abs(resolvedConnection.location.ping) % 200
        return "185.42.\(suffix).\(18 + resolvedConnection.provider.name.count % 40)"
    }

    private var sheetPresentationDetents: Set<PresentationDetent> {
        [
            VPNPanelPresentation.island,
            VPNPanelPresentation.intermediate,
            .large,
        ]
    }

    private var sheetBackgroundInteractionDetent: PresentationDetent {
        VPNPanelPresentation.intermediate
    }

    private var presentationDetent: Binding<PresentationDetent> {
        Binding(
            get: {
                switch panelPosition {
                case .island: VPNPanelPresentation.island
                case .intermediate: VPNPanelPresentation.intermediate
                case .expanded: .large
                }
            },
            set: { detent in
                switch detent {
                case VPNPanelPresentation.island:
                    panelPosition = .island
                case VPNPanelPresentation.intermediate:
                    panelPosition = .intermediate
                default:
                    panelPosition = .expanded
                }
            }
        )
    }

    private func selectNearestServer(at coordinate: GeoCoordinate) {
        guard let match = VPNLocation.nearest(to: coordinate) else { return }
        guard match != selectedLocation else { return }

        selectedLocation = match

        let providerID = providerStore.activeProviderID
            ?? providerStore.providers.first(where: \.isEligibleForAutoConnect)?.id
        if let providerID {
            let selection = VPNLocationSelection.manual(location: match, providerID: providerID)
            locationSelection = selection
            selectionSource = .location(selection)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VelvetBrand()

            Spacer()

            if route == .home {
                Button {
                    withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                        isAddingConfiguration = true
                        route = .onboarding
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: VelvetMetrics.minTouchTarget, height: VelvetMetrics.minTouchTarget)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(ui("Add VPN configuration"))
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))

                Button {
                    showsAccount = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: VelvetMetrics.minTouchTarget, height: VelvetMetrics.minTouchTarget)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(ui("Account"))
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))
            }
        }
        .overlay {
            if route == .home {
                ServiceAvailabilityPill(
                    model: serviceAvailability,
                    isVPNConnected: connectionState.isConnected,
                    isExpanded: isServiceListExpanded,
                    action: toggleServiceList
                )
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))
            }
        }
        .padding(.horizontal, VelvetTheme.islandHorizontalInset)
        .padding(.top, 12)
        .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
    }

    private func toggleServiceList() {
        withAnimation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion)) {
            isServiceListExpanded.toggle()
        }
    }

    private func onboardingOverlay(safeAreaBottom: CGFloat) -> some View {
        ConnectVPNView(
            route: $route,
            providerStore: providerStore,
            isAddingConfiguration: isAddingConfiguration,
            onImportSuccess: handleImportSuccess,
            onVelvetTrial: handleVelvetTrial,
            onCancel: handleImportCancel
        )
        .padding(.horizontal, VelvetTheme.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, max(safeAreaBottom, VelvetTheme.minimumBottomMargin))
        .frame(maxWidth: .infinity)
        .background {
            OnboardingContentBackdrop()
        }
        .keyboardLift()
    }

    private func handleVelvetTrial() {
        providerStore.resetToVelvetOnly()
        providerStore.advancePrototypeCycle()
        homeFormat = .networksAndLocations
        isAddingConfiguration = false
        transitionAfterOnboardingSuccess()
    }

    private func handleImportSuccess(_ provider: VPNProvider) {
        providerStore.advancePrototypeCycle()
        homeFormat = .networksAndLocations
        isAddingConfiguration = false
        importedProviderPendingPrimary = provider
        transitionAfterOnboardingSuccess(expanded: false)
    }

    private func confirmImportedProviderAsMain() {
        guard let provider = importedProviderPendingPrimary else { return }
        providerStore.setActiveProvider(id: provider.id)
        if provider.includesPresets {
            locationSelection = .smartAuto(scope: providerStore.providerScope)
            selectionSource = .useCase(.smart)
            importedProviderPendingPrimary = nil
            return
        }
        locationSelection = VPNConnectionPlanner.reconcileSelection(
            locationSelection,
            providers: providerStore.providers,
            storeScope: providerStore.providerScope
        )
        importedProviderPendingPrimary = nil
    }

    private func transitionAfterOnboardingSuccess(expanded: Bool = false) {
        withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
            route = .home
            if expanded {
                panelPosition = .expanded
            }
        }
        requestVPNPermissionAfterImport()
    }

    private func handleImportCancel() {
        isAddingConfiguration = false
        withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
            route = .home
        }
    }

#if DEBUG
    private func configurePromoDemoIfNeeded() {
        guard CommandLine.arguments.contains("--show-home") else { return }

        if CommandLine.arguments.contains("--expiring-soon") {
            providerStore.applyPrototypeScenario(.importedExpired)
            homeFormat = .networksAndLocations
            panelPosition = .intermediate
        } else if CommandLine.arguments.contains("--promo-demo") {
            providerStore.applyPrototypeScenario(.importedOnly)
            homeFormat = .networksAndLocations
            panelPosition = .island
            applyImportedOnlyDemoSelection()
        } else if CommandLine.arguments.contains("--home-island-menu") {
            providerStore.applyPrototypeScenario(.velvetPlusImported)
            homeFormat = .networksAndLocations
            panelPosition = .island
            locationSelection = .smartAuto(scope: providerStore.providerScope)
            selectionSource = .useCase(.smart)
            providerStore.reconcileActiveProvider()
        } else if CommandLine.arguments.contains("--multi-provider")
            || (CommandLine.arguments.contains("--show-home") && !CommandLine.arguments.contains("--promo-demo")) {
            providerStore.applyPrototypeScenario(.velvetPlusImported)
            homeFormat = .networksAndLocations
            panelPosition = .expanded
            locationSelection = .smartAuto(scope: providerStore.providerScope)
            selectionSource = .useCase(.smart)
            providerStore.reconcileActiveProvider()
            shouldAutoConnect = true
        }
    }
#endif
}
