import SwiftUI

struct HomeView: View {
    @Binding var route: AppRoute

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var providerStore = VPNProviderStore()
    @State private var panelPosition = BottomPanelPosition.island
    @State private var connectionState = VPNConnectionState.disconnected
    @State private var selectedLocation = VPNLocation.samples[0]
    @State private var locationSelection: VPNLocationSelection = .smartAuto(scope: .allNetworks)
    @State private var selectionSource: VPNSelectionSource = .useCase(.smart)
    @State private var resolvedConnection: VPNResolvedConnection?
    @State private var showsSettings = false
    @State private var showsRoutingSettings = false
    @State private var showsConnectionInfo = false
    @State private var isPanelInteracting = false
    @State private var isAddingConfiguration = false
    @State private var isSwitchingServer = false
    @State private var importToastMessage: String?
    @State private var connectedAt: Date?
    @State private var mockPublicIP = "185.42.18.90"
    @State private var downloadRate = "0 KB/s"
    @State private var uploadRate = "0 KB/s"
    @State private var sessionBytesUsed: Int64 = 0
    @State private var livePingMs = 0
    @State private var shouldAutoConnect = false
    @State private var showsVPNPermissionRequest = false
    @State private var didAutoPresentRenewalPanel = false
    @State private var statsTask: Task<Void, Never>?
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.panelDetentMode") private var panelDetentMode = VPNPanelDetentMode.stepped
    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic
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
    }

    var body: some View {
        Group {
            if homeFormat == .networksAndLocations {
                networksIslandLayout
            } else {
                switch panelStyle {
                case .island:
                    islandLayout
                case .sheet:
                    sheetLayout
                }
            }
        }
        .id(homeFormat)
        .sheet(isPresented: $showsSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showsRoutingSettings) {
            VPNRoutingSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsConnectionInfo) {
            VPNConnectionInfoView(
                resolvedConnection: resolvedConnection,
                connectedAt: connectedAt,
                mockPublicIP: mockPublicIP,
                regionLabel: resolvedConnection?.location.name ?? selectedLocation.name,
                pingMs: livePingMs,
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                usageFraction: sessionUsageFraction,
                sessionDataUsedText: sessionDataUsedText,
                providerMessage: resolvedConnection.flatMap { connection in
                    providerStore.provider(id: connection.provider.id)?.providerMessage
                }
            )
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
                livePingMs = resolvedConnection?.location.ping ?? selectedLocation.ping
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
            } else {
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
            "\"Velvet\" Would Like to Add VPN Configurations",
            isPresented: $showsVPNPermissionRequest
        ) {
            Button("Don't Allow", role: .cancel) {}
            Button("Allow") {
                grantVPNPermissionAndConnect()
            }
        } message: {
            Text("All network activity may be filtered or monitored.")
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
        guard panelPosition == .island else { return }
        didAutoPresentRenewalPanel = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            panelPosition = .intermediate
        }
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
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                pingMs: livePingMs,
                usageFraction: sessionUsageFraction,
                sessionDataUsedText: sessionDataUsedText,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                detentMode: panelDetentMode
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
                downloadRate: downloadRate,
                uploadRate: uploadRate,
                pingMs: livePingMs,
                usageFraction: sessionUsageFraction,
                sessionDataUsedText: sessionDataUsedText,
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
                    isConnected: connectionState.isConnected,
                    isInteractive: route == .home,
                    autoRotates: route == .onboarding,
                    includesBottomContrast: route == .home,
                    onPickCoordinate: selectNearestServer
                )
                .animation(nil, value: panelPosition)

                VStack(spacing: 0) {
                    header
                    Spacer()
                }
                .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)

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
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
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

    private func handleClipboardImport(_ importedName: String) {
        homeFormat = .networksAndLocations
        importToastMessage = "✓  \(importedName) added from clipboard"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
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
            livePingMs: $livePingMs,
            downloadRate: $downloadRate,
            uploadRate: $uploadRate,
            sessionBytesUsed: $sessionBytesUsed,
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
        if let job = VPNUserJob(rawValue: defaultUserJobRaw) {
            providerStore.activateVelvetForPresetSelection()
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

    private let sessionDataLimitBytes: Int64 = 7_000_000_000

    private var sessionUsageFraction: Double {
        Double(sessionBytesUsed) / Double(sessionDataLimitBytes)
    }

    private var sessionDataUsedText: String {
        let megabytes = Double(sessionBytesUsed) / (1024 * 1024)
        if megabytes >= 1024 {
            return String(format: "%.1f GB this session", megabytes / 1024)
        }
        return String(format: "%.0f MB this session", megabytes)
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

                let down = Double.random(in: 8.0...24.0)
                let up = Double.random(in: 2.0...8.0)
                downloadRate = String(format: "%.0f MB/s", down)
                uploadRate = String(format: "%.0f MB/s", up)
                livePingMs = max(12, basePing + Int.random(in: -8...12))
                sessionBytesUsed += Int64((down + up) * 1024 * 1024 / 8)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopStatsTicker() {
        statsTask?.cancel()
        statsTask = nil
        downloadRate = "0 KB/s"
        uploadRate = "0 KB/s"
        livePingMs = 0
        sessionBytesUsed = 0
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
                .accessibilityLabel("Add VPN configuration")
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))

                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: VelvetMetrics.minTouchTarget, height: VelvetMetrics.minTouchTarget)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Settings")
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))
            }
        }
        .padding(.horizontal, VelvetTheme.islandHorizontalInset)
        .padding(.top, 12)
        .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
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
        importToastMessage = "✓  \(provider.name) added · \(provider.subtitle)"
        transitionAfterOnboardingSuccess(expanded: true)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                importToastMessage = nil
            }
        }
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
        } else if CommandLine.arguments.contains("--multi-provider") {
            providerStore.applyPrototypeScenario(.velvetPlusImported)
            homeFormat = .networksAndLocations
            panelPosition = .island
        }
    }
#endif
}
