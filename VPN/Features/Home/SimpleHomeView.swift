import SwiftUI

/// Labeled home: one page of entry points, or a bottom menu.
/// Connection state stays on `HomeView`, so switching back to the island keeps the session.
struct SimpleHomeHost: View {
    var chrome: VPNHomeChrome

    @Bindable var providerStore: VPNProviderStore
    @Binding var route: AppRoute
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation
    @Binding var locationSelection: VPNLocationSelection
    @Binding var selectionSource: VPNSelectionSource
    @Binding var resolvedConnection: VPNResolvedConnection?
    @Binding var isSwitchingServer: Bool
    @Binding var connectedAt: Date?
    @Binding var shouldAutoConnect: Bool
    @Binding var showsAccount: Bool
    @Binding var providerSettingsID: UUID?
    @Binding var isAddingConfiguration: Bool

    var serviceAvailability: ServiceAvailabilityModel
    var sessionStats: VPNSessionStatsModel
    var importToastMessage: String?
    var highlightedProvider: VPNProvider?

    let onImportSuccess: (VPNProvider) -> Void
    let onVelvetTrial: () -> Void
    let onImportCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var tab = SimpleHomeTab.home
    @State private var showsLocations = false
    @State private var showsVPN = false
    @State private var showsSubscriptions = false
    @State private var showsProviderSwitch = false
    @State private var isServiceListExpanded = false
    @State private var showsSettings = false
    @State private var connectTask: Task<Void, Never>?

    private var providers: [VPNProvider] { providerStore.providers }

    var body: some View {
        Group {
            switch chrome {
            case .tabs:
                tabRoot
            case .board:
                boardRoot
            case .hero:
                heroRoot
            case .page, .island, .islandMenu:
                pageRoot
            }
        }
        .sheet(isPresented: $showsLocations) {
            SimpleHomeLocationsPage(
                providerStore: providerStore,
                locationSelection: $locationSelection,
                selectionSource: $selectionSource,
                showsDone: true,
                onSmartLocation: chooseSmart,
                onManualLocation: chooseManual
            )
        }
        .sheet(isPresented: $showsVPN) {
            SimpleHomeVPNPage(
                providerStore: providerStore,
                onSelectAll: selectAllSubscriptions,
                onSelect: selectProvider,
                onInfo: openProvider,
                onOpenSubscriptions: {
                    showsVPN = false
                    showsSubscriptions = true
                }
            )
        }
        .fullScreenCover(isPresented: $showsSubscriptions) {
            VPNSubscriptionsPage(providerStore: providerStore, showsCloseButton: true) { id in
                showsSubscriptions = false
                providerSettingsID = id
            }
        }
        .sheet(isPresented: $showsSettings) {
            HomeSettingsView(providerStore: providerStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear(perform: consumeAutoConnectIfNeeded)
        .onChange(of: shouldAutoConnect) { _, _ in
            consumeAutoConnectIfNeeded()
        }
    }

    private var pageRoot: some View {
        mapSurface(
            bottomCard: pageCard,
            showsAccountButton: true,
            padsForHomeIndicator: true
        )
    }

    private var heroRoot: some View {
        GeometryReader { proxy in
            ZStack {
                SimpleHomeHeroView(
                    providerStore: providerStore,
                    connectionState: connectionState,
                    isSwitchingServer: isSwitchingServer,
                    selectedLocation: selectedLocation,
                    locationSelection: $locationSelection,
                    selectionSource: $selectionSource,
                    displayProvider: displayProvider,
                    serviceAvailability: serviceAvailability,
                    sessionStats: sessionStats,
                    onConnect: handleConnectionTap,
                    onSelectPreset: chooseUseCase,
                    onSelectAllSubscriptions: selectAllSubscriptions,
                    onSelectProvider: selectProvider,
                    onProviderInfo: openProvider,
                    onOpenSubscriptions: { showsSubscriptions = true },
                    onAdd: {
                        withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                            isAddingConfiguration = true
                            route = .onboarding
                        }
                    },
                    onSmartLocation: chooseSmart,
                    onManualLocation: chooseManual
                )

                if route == .onboarding {
                    onboardingOverlay(safeAreaBottom: proxy.safeAreaInsets.bottom)
                }

                if let importToastMessage {
                    importToast(importToastMessage)
                }
            }
        }
    }

    /// Full page of entry points. Each fact appears once: state, place, subscription, sites.
    private var boardRoot: some View {
        GeometryReader { proxy in
            ZStack {
                VelvetTheme.pageWash
                    .ignoresSafeArea()

                if route == .home {
                    VStack(spacing: 0) {
                        boardHeader
                        ScrollView {
                            VStack(alignment: .leading, spacing: 28) {
                                ServiceAvailabilityCard(
                                    model: serviceAvailability,
                                    isVPNConnected: connectionState.isConnected,
                                    hidesPlate: true
                                )
                                boardLocation
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        }
                        boardStatus
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                    }
                }

                if showsProviderSwitch {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { setProviderSwitchPresented(false) }
                        .transition(.opacity)
                }

                if showsProviderSwitch {
                    VStack {
                        VPNActiveProviderSwitchCard(
                            providers: providers,
                            activeProviderID: providerStore.activeProviderID,
                            showsAllSubscriptions: providerStore.showsAllSubscriptionsCatalog,
                            onSelectAll: {
                                setProviderSwitchPresented(false)
                                selectAllSubscriptions()
                            },
                            onSelect: { id in
                                setProviderSwitchPresented(false)
                                selectProvider(id: id)
                            },
                            onInfo: { id in
                                setProviderSwitchPresented(false)
                                openProvider(id: id)
                            },
                            onOpenSubscriptions: {
                                setProviderSwitchPresented(false)
                                showsSubscriptions = true
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        Spacer()
                    }
                    .transition(VelvetMotion.popoverTransition(reduceMotion: reduceMotion))
                }

                if route == .onboarding {
                    onboardingOverlay(safeAreaBottom: proxy.safeAreaInsets.bottom)
                }

                if let importToastMessage {
                    importToast(importToastMessage)
                }
            }
        }
        .animation(VelvetMotion.popover(reduceMotion: reduceMotion), value: showsProviderSwitch)
        .sensoryFeedback(.selection, trigger: showsProviderSwitch) { _, presented in
            presented
        }
    }

    private var boardHeader: some View {
        HStack(spacing: 8) {
            Button {
                showsAccount = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VelvetTheme.mainTextDark)
                    .frame(width: 56, height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(ui("Account"))

            Button {
                setProviderSwitchPresented(true)
            } label: {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(boardProviderTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelvetTheme.mainTextDark)
                            .lineLimit(1)
                        Text(boardProviderCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .frame(height: 56)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Active VPN, \(boardProviderTitle)")

            Button {
                withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                    isAddingConfiguration = true
                    route = .onboarding
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VelvetTheme.mainTextDark)
                    .frame(width: 56, height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(ui("Add VPN configuration"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func setProviderSwitchPresented(_ isPresented: Bool) {
        withAnimation(VelvetMotion.popover(reduceMotion: reduceMotion)) {
            showsProviderSwitch = isPresented
        }
    }

    private var boardProviderTitle: String {
        if providerStore.showsAllSubscriptionsCatalog {
            return ui("All subscriptions")
        }
        return displayProvider.catalogDisplayName.withoutEmoji
    }

    private var boardProviderCaption: String {
        if providerStore.showsAllSubscriptionsCatalog {
            return VPNProvider.allSubscriptionsCaption(providers: providers)
        }
        return displayProvider.subscriptionIdentityCaption
    }

    private var boardStatus: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: handleConnectionTap) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(boardPowerFill)
                    .frame(width: 148, height: 148)
                    .overlay {
                        if connectionState == .connecting || isSwitchingServer {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "power")
                                    .font(.system(size: 36, weight: .semibold))
                                Text(boardPowerTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(connectionState == .connecting || isSwitchingServer)
            .accessibilityLabel(boardPowerTitle)
            .accessibilityHint(
                connectionState == .connected
                    ? ui("Disconnects the demo VPN")
                    : ui("Connects the demo VPN")
            )

            VStack(spacing: 8) {
                boardFact(boardStateTitle, showsDot: true)
                if connectionState == .connected {
                    boardClock
                }
                if let daysLeftLabel {
                    boardFact(daysLeftLabel, showsDot: false)
                }
            }
        }
    }

    private var boardClock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(sessionClock(at: context.date))
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel("Connected for \(sessionClock(at: .now))")
    }

    private func boardFact(_ title: String, showsDot: Bool) -> some View {
        HStack(spacing: 8) {
            if showsDot {
                Circle()
                    .fill(boardDot)
                    .frame(width: 8, height: 8)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var boardLocation: some View {
        VStack(alignment: .leading, spacing: 10) {
            boardSectionTitle(ui("Location"))
            HStack(spacing: 10) {
                boardChoice(
                    systemName: "bolt.fill",
                    title: ui("Smart"),
                    subtitle: ui("Picks the best server"),
                    isSelected: isFastestChoice
                ) {
                    chooseFastest()
                }
                boardChoice(
                    systemName: "mappin.and.ellipse",
                    title: countryChoiceTitle,
                    subtitle: countryChoiceSubtitle,
                    isSelected: !isFastestChoice
                ) {
                    showsLocations = true
                }
            }
        }
    }

    private func boardSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func boardChoice(
        systemName: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: systemName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? VelvetTheme.accent : .secondary)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(VelvetTheme.accent)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(
                isSelected ? VelvetTheme.accent.opacity(0.16) : Color.white,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(VelvetTheme.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tabRoot: some View {
        GeometryReader { proxy in
            ZStack {
                TabView(selection: $tab) {
                    mapSurface(
                        bottomCard: pageCard,
                        showsAccountButton: false,
                        padsForHomeIndicator: false,
                        includesOverlays: false
                    )
                    .tabItem { Label(ui("Home"), systemImage: "house") }
                    .tag(SimpleHomeTab.home)

                    SimpleHomeLocationsPage(
                        providerStore: providerStore,
                        locationSelection: $locationSelection,
                        selectionSource: $selectionSource,
                        showsDone: false,
                        onSmartLocation: chooseSmart,
                        onManualLocation: chooseManual
                    )
                    .tabItem { Label(ui("Locations"), systemImage: "globe") }
                    .tag(SimpleHomeTab.locations)

                    VelvetProductsPage(showsDone: false)
                    .tabItem { Label(ui("Products"), systemImage: "square.grid.2x2") }
                    .tag(SimpleHomeTab.products)

                    VPNAccountView(
                        providerStore: providerStore,
                        showsDismissButton: false
                    ) { id in
                        providerSettingsID = id
                    }
                    .tabItem { Label(ui("Account"), systemImage: "person.crop.circle") }
                    .tag(SimpleHomeTab.account)
                }

                if route == .onboarding {
                    onboardingOverlay(safeAreaBottom: proxy.safeAreaInsets.bottom)
                }

                if let importToastMessage {
                    importToast(importToastMessage)
                }
            }
        }
    }

    private func mapSurface<Card: View>(
        bottomCard: Card,
        showsAccountButton: Bool,
        padsForHomeIndicator: Bool,
        includesOverlays: Bool = true
    ) -> some View {
        GeometryReader { proxy in
            let bottomInset = padsForHomeIndicator
                ? max(proxy.safeAreaInsets.bottom, VelvetTheme.minimumBottomMargin)
                : 16

            ZStack(alignment: .bottom) {
                VelvetMapBackground(
                    selectedLocation: selectedLocation,
                    connectionState: connectionState,
                    isInteractive: route == .home,
                    autoRotates: route == .onboarding,
                    onPickCoordinate: selectNearestServer
                )

                VStack(spacing: 0) {
                    mapHeader(showsAccountButton: showsAccountButton)
                    if route == .home, showsMapPageChrome, isServiceListExpanded {
                        ServiceAvailabilityCard(
                            model: serviceAvailability,
                            isVPNConnected: connectionState.isConnected,
                            onCollapse: toggleServiceList
                        )
                        .transition(VelvetMotion.availabilityExpandTransition(reduceMotion: reduceMotion))
                        .padding(.horizontal, VelvetTheme.horizontalPadding)
                        .padding(.top, 14)
                    }
                    if route == .home, let highlightedProvider {
                        MapProviderHighlightCard(provider: highlightedProvider)
                            .padding(.horizontal, VelvetTheme.horizontalPadding)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    Spacer(minLength: 0)
                }
                .animation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion), value: isServiceListExpanded)

                if route == .home {
                    bottomCard
                        .padding(.horizontal, VelvetTheme.islandHorizontalInset)
                        .padding(.bottom, bottomInset)
                }

                if showsMapPageChrome, showsProviderSwitch {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { setProviderSwitchPresented(false) }
                        .transition(.opacity)
                }

                if showsMapPageChrome, showsProviderSwitch {
                    VStack {
                        VPNActiveProviderSwitchCard(
                            providers: providers,
                            activeProviderID: providerStore.activeProviderID,
                            showsAllSubscriptions: providerStore.showsAllSubscriptionsCatalog,
                            onSelectAll: {
                                setProviderSwitchPresented(false)
                                selectAllSubscriptions()
                            },
                            onSelect: { id in
                                setProviderSwitchPresented(false)
                                selectProvider(id: id)
                            },
                            onInfo: { id in
                                setProviderSwitchPresented(false)
                                openProvider(id: id)
                            },
                            onOpenSubscriptions: {
                                setProviderSwitchPresented(false)
                                showsSubscriptions = true
                            }
                        )
                        .padding(.horizontal, 16)
                        Spacer()
                    }
                    .padding(.top, 72)
                    .transition(VelvetMotion.popoverTransition(reduceMotion: reduceMotion))
                }

                if includesOverlays {
                    if route == .onboarding {
                        onboardingOverlay(safeAreaBottom: proxy.safeAreaInsets.bottom)
                    }
                    if let importToastMessage {
                        importToast(importToastMessage)
                    }
                }
            }
            .ignoresSafeArea(edges: padsForHomeIndicator ? .bottom : [])
            .animation(VelvetMotion.popover(reduceMotion: reduceMotion), value: showsProviderSwitch)
        }
    }

    private func mapHeader(showsAccountButton: Bool) -> some View {
        HStack(spacing: 12) {
            VelvetBrand()
            Spacer()
            if route == .home {
                if chrome == .tabs {
                    headerButton(systemName: "gearshape", label: ui("Settings")) {
                        showsSettings = true
                    }
                }
                headerButton(systemName: "plus", label: ui("Add VPN configuration")) {
                    withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                        isAddingConfiguration = true
                        route = .onboarding
                    }
                }
                if showsAccountButton {
                    headerButton(systemName: "person.crop.circle", label: ui("Account")) {
                        showsAccount = true
                    }
                }
            }
        }
        .overlay {
            if route == .home, showsMapPageChrome {
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
    }

    /// One page and Bottom menu share the map header and the bottom card.
    private var showsMapPageChrome: Bool {
        chrome == .page || chrome == .tabs
    }

    private func toggleServiceList() {
        withAnimation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion)) {
            isServiceListExpanded.toggle()
        }
    }

    private func headerButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: VelvetMetrics.minTouchTarget, height: VelvetMetrics.minTouchTarget)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private var pageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(VelvetTheme.mainTextDark)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                pageChoice(
                    title: ui("VPN"),
                    detail: vpnDetail,
                    mark: .provider(displayProvider),
                    label: "VPN, \(vpnDetail)"
                ) {
                    setProviderSwitchPresented(true)
                }
                pageChoice(
                    title: ui("Location"),
                    detail: placeName,
                    mark: locationMark,
                    label: "Location, \(placeName)"
                ) {
                    showsLocations = true
                }
            }

            VPNPrimaryConnectionButton(
                title: connectTitle,
                connectionState: connectionState,
                usesErrorTint: usesErrorConnectionTint,
                showsPowerIcon: true,
                isBusy: isSwitchingServer,
                action: handleConnectionTap
            )
        }
        .padding(16)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: VelvetTheme.panelRadius, style: .continuous))
    }

    private func pageChoice(
        title: String,
        detail: String,
        mark: SimpleHomeMark,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                mark.view
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func onboardingOverlay(safeAreaBottom: CGFloat) -> some View {
        ConnectVPNView(
            route: $route,
            providerStore: providerStore,
            isAddingConfiguration: isAddingConfiguration,
            onImportSuccess: onImportSuccess,
            onVelvetTrial: onVelvetTrial,
            onCancel: onImportCancel
        )
        .padding(.horizontal, VelvetTheme.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, max(safeAreaBottom, VelvetTheme.minimumBottomMargin))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background { OnboardingContentBackdrop() }
        .keyboardLift()
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
        .allowsHitTesting(false)
    }

    // MARK: - Copy

    private var placeName: String {
        if connectionState == .connected || connectionState == .connecting,
           let name = resolvedConnection?.location.name {
            return plainPlace(name)
        }
        switch locationSelection {
        case let .manual(location, _):
            return plainPlace(location.name)
        case .smartAuto:
            return ui("Smart")
        case let .smartJob(job, _):
            return job.title
        }
    }

    private func plainPlace(_ name: String) -> String {
        ui(name.withoutEmoji.replacingOccurrences(of: "SMART-", with: ""))
    }

    private var statusText: String {
        if isSwitchingServer { return ui("Switching server…") }
        switch connectionState {
        case .connected:
            return uiFormat("Connected to %@", ui(placeName))
        case .connecting:
            return ui("Connecting…")
        case .disconnected:
            return ui("Not connected")
        case .failed(let failure):
            return failure.displayMessage
        }
    }

    private var connectTitle: String {
        if isSwitchingServer { return ui("Switching…") }
        if case .failed(.selectionMismatch) = connectionState {
            return ui("Choose location")
        }
        if needsSubscriptionAction, connectionState == .disconnected || connectionState.isFailed {
            return ui("Renew subscription")
        }
        switch connectionState {
        case .disconnected:
            return ui("Connect")
        case .connecting:
            return ui("Connecting…")
        case .connected:
            return ui("Disconnect")
        case .failed:
            return ui("Try again")
        }
    }

    private var vpnDetail: String {
        if providerStore.showsAllSubscriptionsCatalog {
            return ui("All subscriptions")
        }
        return displayProvider.catalogDisplayName.withoutEmoji
    }

    private var locationMark: SimpleHomeMark {
        if case let .manual(location, _) = locationSelection {
            return .flag(location.flag)
        }
        return .symbol("globe")
    }

    private var isFastestChoice: Bool {
        if case .smartAuto = locationSelection { return true }
        return false
    }

    private var countryChoiceTitle: String {
        switch locationSelection {
        case .smartAuto:
            return ui("Country")
        case let .manual(location, _):
            return plainPlace(location.name)
        case let .smartJob(job, _):
            return job.title
        }
    }

    private var countryChoiceSubtitle: String {
        switch locationSelection {
        case .smartAuto:
            return ui("Choose a place")
        case let .manual(location, _):
            return location.city
        case .smartJob:
            return ui("Change place")
        }
    }

    private var boardStateTitle: String {
        if isSwitchingServer { return ui("Switching") }
        switch connectionState {
        case .connected: return ui("Connected")
        case .connecting: return ui("Connecting")
        case .disconnected: return ui("Not connected")
        case .failed: return ui("Couldn't connect")
        }
    }

    private var boardPowerTitle: String {
        connectionState == .connected ? "Выключить" : "Включить"
    }

    private var boardPowerFill: Color {
        switch connectionState {
        case .connected:
            VelvetTheme.connectedGreen
        case .connecting:
            VelvetTheme.softPurple
        case .failed:
            VelvetTheme.errorTint
        case .disconnected:
            VelvetTheme.accent
        }
    }

    private var boardDot: Color {
        switch connectionState {
        case .connected: VelvetTheme.connectedGreen
        case .connecting: VelvetTheme.warningTint
        case .failed: VelvetTheme.errorTint
        case .disconnected: Color(.systemGray3)
        }
    }

    private var daysLeftLabel: String? {
        guard let expiresAt = displayProvider.expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        if days < 0 { return ui("Expired") }
        return uiFormat("Days left: %lld", days)
    }

    private func sessionClock(at date: Date) -> String {
        guard let connectedAt else { return "00:00:00" }
        let interval = max(0, Int(date.timeIntervalSince(connectedAt)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var displayProvider: VPNProvider {
        if let connected = resolvedConnection?.provider {
            return connected
        }
        return providerStore.activeProvider
    }

    private var needsSubscriptionAction: Bool {
        let hasEligible = providers.contains(where: \.isEligibleForAutoConnect)
        if !hasEligible { return true }
        return displayProvider.kind == .imported && displayProvider.needsSubscriptionRenewal
    }

    private var usesErrorConnectionTint: Bool {
        guard case let .failed(failure) = connectionState else { return true }
        return !failure.isSelectionMismatch
    }

    // MARK: - Choices

    private func chooseManual(_ networkLocation: VPNNetworkLocation) {
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
        applyChoice(selection)
    }

    private func chooseUseCase(_ choice: VPNUseCaseMenuChoice) {
        selectionSource = .useCase(choice)
        applyChoice(choice.locationSelection(scope: providerStore.providerScope))
    }

    private func chooseFastest() {
        let selection = VPNLocationSelection.smartAuto(scope: providerStore.providerScope)
        selectionSource = .useCase(.smart)
        applyChoice(selection)
    }

    private func chooseSmart(_ job: VPNUserJob) {
        let selection = VPNLocationSelection.smartJob(job, scope: providerStore.providerScope)
        selectionSource = .location(selection)
        applyChoice(selection)
    }

    /// Remember the place. Connect only if a session is already up, so a tap means “use this country”.
    private func applyChoice(_ selection: VPNLocationSelection) {
        let wasConnected = connectionState == .connected
        if wasConnected, selection == locationSelection {
            showsLocations = false
            return
        }
        locationSelection = selection
        showsLocations = false
        if wasConnected {
            beginLocationSwitch()
        }
    }

    private func selectAllSubscriptions() {
        providerStore.showAllSubscriptions()
        locationSelection = selectionMoved(locationSelection, to: .allNetworks)
        showsVPN = false
        if connectionState == .connected {
            beginLocationSwitch()
        }
    }

    private func selectProvider(id: UUID) {
        guard let provider = providers.first(where: { $0.id == id }), provider.status.isActive else { return }
        providerStore.setActiveProvider(id: id)
        if provider.includesPresets {
            locationSelection = .smartAuto(scope: .provider(id))
            selectionSource = .useCase(.smart)
        } else {
            locationSelection = selectionMoved(locationSelection, to: .provider(id))
        }
        showsVPN = false
        if connectionState == .connected {
            beginLocationSwitch()
        }
    }

    private func openProvider(id: UUID) {
        showsVPN = false
        providerSettingsID = id
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

    private func selectNearestServer(at coordinate: GeoCoordinate) {
        guard let match = VPNLocation.nearest(to: coordinate) else { return }
        guard match != selectedLocation else { return }
        selectedLocation = match
        let providerID = providerStore.activeProviderID
            ?? providers.first(where: \.isEligibleForAutoConnect)?.id
        if let providerID {
            let selection = VPNLocationSelection.manual(location: match, providerID: providerID)
            locationSelection = selection
            selectionSource = .location(selection)
        }
    }

    // MARK: - Connection

    private func consumeAutoConnectIfNeeded() {
        guard shouldAutoConnect else { return }
        shouldAutoConnect = false
        handleConnectionTap()
    }

    private func handleConnectionTap() {
        if case .failed(.selectionMismatch) = connectionState {
            if chrome == .tabs {
                tab = .locations
            } else {
                showsLocations = true
            }
            return
        }

        if needsSubscriptionAction,
           connectionState == .disconnected || connectionState.isFailed {
            openRenewal()
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

        let reconciled = VPNConnectionPlanner.reconcileSelection(
            locationSelection,
            providers: providers,
            storeScope: providerStore.providerScope
        )
        if reconciled != locationSelection {
            locationSelection = reconciled
        }

        if providers.filter(\.isEligibleForAutoConnect).isEmpty {
            openRenewal()
            return
        }

        connectTask?.cancel()
        if connectionState == .connected, isSwitchingServer {
            applyResolvedLocation(keepConnected: true)
            return
        }

        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .connecting
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

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, connectionState == .connecting else { return }

            withAnimation(VelvetMotion.connectionLayout(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
                isSwitchingServer = false
                connectedAt = connectedAt ?? .now
            }
        }
    }

    private func beginLocationSwitch() {
        connectTask?.cancel()
        isSwitchingServer = true
        connectTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            guard !Task.isCancelled else { return }
            applyResolvedLocation(keepConnected: true)
        }
    }

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
        isSwitchingServer = false
        if keepConnected {
            connectionState = .connected
            connectedAt = connectedAt ?? .now
        }
    }

    private func presentSelectionMismatch(_ mismatch: VPNSelectionMismatch) {
        isSwitchingServer = false
        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .failed(.selectionMismatch(mismatch))
        }
    }

    private func presentNetworkFailure(message: String) {
        isSwitchingServer = false
        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .failed(.network(message: message))
        }
    }

    private func openRenewal() {
        guard let url = URL(string: displayProvider.renewURL) else { return }
        openURL(url)
    }
}

private enum SimpleHomeTab: Hashable {
    case home
    case locations
    case products
    case account
}

private enum SimpleHomeMark {
    case symbol(String)
    case flag(String)
    case provider(VPNProvider)

    @ViewBuilder
    var view: some View {
        switch self {
        case let .symbol(name):
            Image(systemName: name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        case let .flag(flag):
            Text(flag)
                .font(.title3)
        case let .provider(provider):
            VPNProviderBrandLogo(provider: provider, size: 28)
        }
    }
}

// MARK: - Locations

struct SimpleHomeLocationsPage: View {
    @Bindable var providerStore: VPNProviderStore
    @Binding var locationSelection: VPNLocationSelection
    @Binding var selectionSource: VPNSelectionSource
    var showsDone: Bool
    let onSmartLocation: (VPNUserJob) -> Void
    let onManualLocation: (VPNNetworkLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(VPNFavouriteLocationsStore.storageKey) private var storedFavourites = ""
    @AppStorage(VPNFavouriteLocationsStore.seededKey) private var didSeedFavourites = false
    @State private var query = VPNLocationQuery()

    private var providers: [VPNProvider] { providerStore.providers }

    private var favouriteEntries: [VPNFavouriteLocationEntry] {
        VPNFavouriteLocationsStore.load(from: storedFavourites)
    }

    private var selectedFavouriteID: String? {
        guard case let .location(selection) = selectionSource,
              case let .manual(location, providerID) = selection
        else { return nil }
        return VPNFavouriteLocationEntry.id(providerID: providerID, persistenceKey: location.persistenceKey)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if query.isDefault, !favouriteEntries.isEmpty {
                        VPNFavouriteLocationsStrip(
                            entries: favouriteEntries,
                            selectedID: selectedFavouriteID,
                            onSelect: { entry in
                                guard let network = networkLocation(for: entry) else { return }
                                onManualLocation(network)
                            },
                            onRemove: removeFavourite
                        )
                    }

                    VPNAllLocationsCard(
                        providerStore: providerStore,
                        locationSelection: $locationSelection,
                        selectionSource: $selectionSource,
                        query: $query,
                        reduceMotion: reduceMotion,
                        panelRevealProgress: 1,
                        favouriteIDs: Set(favouriteEntries.map(\.id)),
                        showsPlate: false,
                        groupsAsPlates: true,
                        prominentSectionHeaders: true,
                        onSmartLocation: onSmartLocation,
                        onManualLocation: onManualLocation,
                        onToggleFavourite: toggleFavourite
                    )
                }
                .padding(.horizontal, VelvetTheme.horizontalPadding)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(ui("Locations"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query.text, prompt: ui("Country or city"))
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(ui("Done")) { dismiss() }
                    }
                }
            }
        }
        .onAppear(perform: seedFavouritesIfNeeded)
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

    private func networkLocation(for entry: VPNFavouriteLocationEntry) -> VPNNetworkLocation? {
        if let provider = providers.first(where: { $0.id == entry.providerID }),
           let location = provider.servers.first(where: { $0.persistenceKey == entry.persistenceKey }) {
            return VPNNetworkLocation(location: location, provider: provider)
        }
        for provider in providers where provider.status.isActive {
            if let location = provider.servers.first(where: { $0.persistenceKey == entry.persistenceKey }) {
                return VPNNetworkLocation(location: location, provider: provider)
            }
        }
        return nil
    }
}

// MARK: - Products

struct VelvetProductsPage: View {
    var showsDone: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showsTravelOffer = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if showsTravelOffer {
                        travelOffer
                    }
                    productSection(
                        title: ui("With Velvet"),
                        products: Self.included
                    )
                    productSection(
                        title: ui("More from Velvet"),
                        products: Self.more
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(ui("Products"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(ui("Done")) { dismiss() }
                    }
                }
            }
        }
    }

    private var travelOffer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "simcard.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(VelvetTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(ui("Get the Velvet eSIM"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showsTravelOffer = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ui("Dismiss"))
            }

            Text(ui("Mobile data in the countries where Velvet already connects you, without a roaming bill."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openURL(VelvetTheme.paywallURL)
            } label: {
                Text(ui("Get eSIM"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(VelvetTheme.accent, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func productSection(title: String, products: [VelvetProduct]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ForEach(products) { product in
                NavigationLink {
                    VelvetProductDetail(product: product)
                } label: {
                    productRow(product)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func productRow(_ product: VelvetProduct) -> some View {
        HStack(spacing: 12) {
            Image(systemName: product.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(VelvetTheme.accent)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(ui(product.title))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(ui(product.detail))
                    .font(.subheadline)
                    .foregroundStyle(product.showsChevron ? AnyShapeStyle(.secondary) : AnyShapeStyle(VelvetTheme.accent))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if product.showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private static let included = [
        VelvetProduct(
            id: "corporate",
            symbol: "building.2",
            title: "Corporate VPN",
            detail: "One network for the company",
            summary: "Shared servers, team logins, and a single bill. People join with a link instead of setting up a VPN themselves.",
            showsChevron: true
        ),
        VelvetProduct(
            id: "esim",
            symbol: "simcard",
            title: "eSIM",
            detail: "Data abroad without roaming",
            summary: "Install a Velvet data plan on the phone you already use. It works in the same countries as the VPN.",
            showsChevron: true
        ),
    ]

    private static let more = [
        VelvetProduct(
            id: "dedicated-ip",
            symbol: "network",
            title: "Dedicated IP",
            detail: "Keep one address",
            summary: "An address that stays yours, so banks and work tools stop asking you to sign in again.",
            showsChevron: false
        ),
        VelvetProduct(
            id: "family",
            symbol: "person.2",
            title: "Family",
            detail: "Share Velvet at home",
            summary: "One plan for the people you live with. Each person gets their own login.",
            showsChevron: false
        ),
    ]
}

private struct VelvetProduct: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
    let summary: String
    let showsChevron: Bool
}

private struct VelvetProductDetail: View {
    let product: VelvetProduct

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: product.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(VelvetTheme.accent)
                    .frame(width: 56, height: 56)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(ui(product.summary))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openURL(VelvetTheme.paywallURL)
                } label: {
                    Text(ui("Learn more"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(VelvetTheme.accent, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ui(product.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - VPN

private struct SimpleHomeVPNPage: View {
    @Bindable var providerStore: VPNProviderStore
    let onSelectAll: () -> Void
    let onSelect: (UUID) -> Void
    let onInfo: (UUID) -> Void
    let onOpenSubscriptions: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VPNActiveProviderSwitchCard(
                    providers: providerStore.providers,
                    activeProviderID: providerStore.activeProviderID,
                    showsAllSubscriptions: providerStore.showsAllSubscriptionsCatalog,
                    onSelectAll: onSelectAll,
                    onSelect: onSelect,
                    onInfo: onInfo,
                    onOpenSubscriptions: onOpenSubscriptions
                )
                .padding(VelvetTheme.horizontalPadding)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(ui("VPN"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ui("Done")) { dismiss() }
                }
            }
        }
    }
}
