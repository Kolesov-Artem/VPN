import SwiftUI

/// Two shipped takes on the bottom panel. The island is the original
/// hand-built one; the sheet is the system presentation that hands scrolling
/// over to UIKit. Both stay in the build so they can be compared on device.
enum VPNPanelStyle: String, CaseIterable, Identifiable {
    case island
    case sheet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .island: "Floating island"
        case .sheet: "System sheet"
        }
    }
}

/// Bottom map contrast behind the status text and panel. `nil` keeps onboarding
/// clear so the connect form owns its own backdrop.
enum VPNBottomBackdropStyle: String, CaseIterable, Identifiable {
    case blur
    case purple
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blur: "Frosted blur"
        case .purple: "Brand tint"
        case .none: "None"
        }
    }
}

struct HomeView: View {
    @Binding var route: AppRoute

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var panelPosition = BottomPanelPosition.island
    @State private var connectionState = VPNConnectionState.disconnected
    @State private var selectedLocation = VPNLocation.samples[0]
    @State private var showsSettings = false
    @State private var isPanelInteracting = false
    @State private var hasEnteredHome: Bool
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.bottomBackdropStyle") private var bottomBackdropStyle = VPNBottomBackdropStyle.blur
    @ScaledMetric(relativeTo: .largeTitle) private var connectionSummaryIconSize = 48

    init(route: Binding<AppRoute>) {
        _route = route
#if DEBUG
        // Seeding the store rather than the state keeps the launch flag and the
        // settings picker reading from the same place.
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
        _hasEnteredHome = State(initialValue: route.wrappedValue == .home)
    }

    var body: some View {
        switch panelStyle {
        case .island:
            islandLayout
        case .sheet:
            sheetLayout
        }
    }

    /// Variant A: the panel lives in the same stack as the map, so it can float
    /// inset from the edges. Settings present from here because nothing else
    /// is on screen.
    private var islandLayout: some View {
        mapLayer { safeAreaBottom, safeAreaTop, _ in
            VPNIslandPanel(
                position: $panelPosition,
                connectionState: $connectionState,
                selectedLocation: $selectedLocation,
                isPanelInteracting: $isPanelInteracting,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop
            )
        }
        .sheet(isPresented: $showsSettings) {
            settingsSheet
        }
    }

    /// Variant B: a system sheet owns the panel, which is what lets a swipe
    /// resize it first and scroll the list afterwards.
    private var sheetLayout: some View {
        mapLayer { _, _, _ in EmptyView() }
            .sheet(isPresented: isHomePresented) {
                VPNBottomPanel(
                    position: $panelPosition,
                    connectionState: $connectionState,
                    selectedLocation: $selectedLocation
                )
                .presentationDetents(
                    [
                        VPNPanelPresentation.island,
                        VPNPanelPresentation.intermediate,
                        .large,
                    ],
                    selection: presentationDetent
                )
                .presentationContentInteraction(.resizes)
                .presentationBackgroundInteraction(
                    .enabled(upThrough: VPNPanelPresentation.intermediate)
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
                // A view controller can only present one sheet, so settings
                // have to come from the panel rather than from the map.
                .sheet(isPresented: $showsSettings) {
                    settingsSheet
                }
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

    // The reader keeps the bottom safe area so the panel can size its margins
    // from the real home indicator inset before ignoring it.
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
            let summaryPadding = detents.summaryBottomPadding(for: panelPosition)
            let mapViewport = VelvetMapViewportBand(
                screenWidth: proxy.size.width,
                screenHeight: proxy.size.height,
                topInset: safeAreaTop + 68,
                bottomInset: mapViewportBottomInset(
                    screenHeight: proxy.size.height,
                    safeAreaBottom: safeAreaBottom,
                    detents: detents
                )
            )

            ZStack(alignment: .bottom) {
                VelvetMapBackground(
                    selectedLocation: selectedLocation,
                    isConnected: connectionState == .connected,
                    atmosphere: mapAtmosphere,
                    bottomBackdropStyle: bottomBackdropStyle,
                    viewportBand: mapViewport,
                    onPickCoordinate: selectNearestServer
                )
                .animation(nil, value: panelPosition)

                VStack(spacing: 0) {
                    header

                    Spacer()

                    if route == .home {
                        connectionSummary
                            .padding(.bottom, summaryPadding)
                            .animation(VelvetMotion.easeOut(duration: 0.25), value: panelPosition)
                            .transition(VelvetMotion.homeContent(reduceMotion: reduceMotion))
                    }
                }

                if route == .home {
                    panel(safeAreaBottom, safeAreaTop, detents)
                        .transition(VelvetMotion.homeContent(reduceMotion: reduceMotion))
                }

                if route == .onboarding {
                    onboardingOverlay(safeAreaBottom: safeAreaBottom)
                        .transition(VelvetMotion.onboardingContent(reduceMotion: reduceMotion))
                }
            }
            .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: route) { _, newRoute in
                if newRoute == .home {
                    hasEnteredHome = true
                }
            }
        }
    }

    /// First-run connect keeps the idle globe spin. Adding a configuration from
    /// home must reuse the live map and only pull the camera back.
    private var mapAtmosphere: VelvetMapAtmosphere {
        switch route {
        case .home:
            .focused
        case .onboarding:
            hasEnteredHome ? .pullbackGlobe : .spinningGlobe
        }
    }

    /// Bottom edge of the globe band: island on home, connect form when adding.
    private func mapViewportBottomInset(
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat,
        detents: BottomPanelDetents
    ) -> CGFloat {
        if route == .onboarding, hasEnteredHome {
            return screenHeight * 0.52 + max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
        }

        return detents.height(for: .island) + detents.bottomMargin + 16
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
        SettingsView(
            panelStyle: $panelStyle,
            bottomBackdropStyle: $bottomBackdropStyle
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

    /// Tapping the map is a shortcut, not a commitment: it moves the selection
    /// the same way the list does and leaves connecting to the panel button.
    private func selectNearestServer(at coordinate: GeoCoordinate) {
        guard let match = VPNLocation.nearest(to: coordinate) else { return }
        guard match != selectedLocation else { return }

        selectedLocation = match
    }

    private var header: some View {
        HStack(spacing: 12) {
            if route == .onboarding && hasEnteredHome {
                headerCircleButton(symbol: "xmark", label: "Cancel adding configuration") {
                    returnToHome()
                }
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))
            }

            VelvetBrand()

            Spacer()

            if route == .home {
                headerCircleButton(symbol: "plus", label: "Add VPN configuration") {
                    withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                        route = .onboarding
                    }
                }
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))

                headerCircleButton(symbol: "gearshape", label: "Settings") {
                    showsSettings = true
                }
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))
            }
        }
        .padding(.horizontal, VelvetTheme.headerHorizontalPadding)
        .padding(.top, 12)
        .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
    }

    private func headerCircleButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func returnToHome() {
        withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
            route = .home
        }
    }

    private func onboardingOverlay(safeAreaBottom: CGFloat) -> some View {
        ConnectVPNView(route: $route, canCancel: hasEnteredHome)
            .padding(.horizontal, VelvetTheme.horizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, max(safeAreaBottom, VelvetTheme.minimumBottomMargin))
            .frame(maxWidth: .infinity)
            .keyboardLift()
    }

    private var connectionSummary: some View {
        VStack(spacing: 12) {
            Image(systemName: connectionState == .connected ? "lock.shield.fill" : "shield")
                .font(.system(size: connectionSummaryIconSize, weight: .medium))
                .foregroundStyle(connectionState == .connected ? Color.green : Color.primary.opacity(0.72))
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(connectionState == .connected ? 1.04 : 1)

            Text(connectionState == .connected ? "Protected" : "Ready to connect")
                .font(.title3.weight(.semibold))
                .contentTransition(.numericText())

            Label(selectedLocation.name, systemImage: "location.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
        .sensoryFeedback(.success, trigger: connectionState) { _, new in
            new == .connected
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsView: View {
    @Binding var panelStyle: VPNPanelStyle
    @Binding var bottomBackdropStyle: VPNBottomBackdropStyle

    @Environment(\.dismiss) private var dismiss
    @State private var connectsAutomatically = true
    @State private var showsNotifications = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    Toggle("Auto-connect", isOn: $connectsAutomatically)
                    Toggle("Notifications", isOn: $showsNotifications)
                }

                Section {
                    Picker("Panel", selection: $panelStyle) {
                        ForEach(VPNPanelStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                } header: {
                    Text("Bottom panel")
                } footer: {
                    Text("The island floats above the map. The sheet expands to full screen before the country list scrolls.")
                }

                Section {
                    Picker("Backdrop", selection: $bottomBackdropStyle) {
                        ForEach(VPNBottomBackdropStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                } header: {
                    Text("Map backdrop")
                } footer: {
                    Text("The tint below the status text. Brand tint turns green while the VPN is connected.")
                }

                Section("Prototype") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("VPN engine", value: "Demo")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
