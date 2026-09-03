import SwiftUI

struct HomeView: View {
    @Binding var route: AppRoute

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var panelPosition = BottomPanelPosition.island
    @State private var connectionState = VPNConnectionState.disconnected
    @State private var selectedLocation = VPNLocation.samples[0]
    @State private var locationSelection: VPNLocationSelection = .smart(.auto)
    @State private var resolvedConnection: VPNResolvedConnection?
    @State private var showsSettings = false
    @State private var isPanelInteracting = false
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic

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
        .onChange(of: homeFormat) { _, _ in
            panelPosition = .island
            resolvedConnection = nil
        }
    }

    private var networksIslandLayout: some View {
        mapLayer { safeAreaBottom, safeAreaTop, _ in
            VPNNetworksIslandPanel(
                providers: VPNProvider.samples,
                position: $panelPosition,
                connectionState: $connectionState,
                selectedLocation: $selectedLocation,
                locationSelection: $locationSelection,
                resolvedConnection: $resolvedConnection,
                isPanelInteracting: $isPanelInteracting,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop
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
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop
            )
        }
    }

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
            let summaryPadding = detents.summaryBottomPadding(for: panelPosition)

            ZStack(alignment: .bottom) {
                VelvetMapBackground(
                    selectedLocation: selectedLocation,
                    isConnected: connectionState == .connected,
                    isInteractive: route == .home,
                    autoRotates: route == .onboarding,
                    includesBottomContrast: route == .home,
                    onPickCoordinate: selectNearestServer
                )
                .animation(nil, value: panelPosition)

                VStack(spacing: 0) {
                    header

                    Spacer()

                    if route == .home {
                        ConnectionSummaryView(
                            connectionState: connectionState,
                            homeFormat: homeFormat,
                            selectedLocation: selectedLocation,
                            resolvedConnection: resolvedConnection,
                            reduceMotion: reduceMotion
                        )
                        .padding(.bottom, summaryPadding)
                        .animation(VelvetMotion.easeOut(duration: 0.25), value: panelPosition)
                        .transition(VelvetMotion.homeContent(reduceMotion: reduceMotion))
                    }
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
            }
            .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
            .ignoresSafeArea(edges: .bottom)
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
        HomeSettingsView()
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
                        route = .onboarding
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
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
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Settings")
                .transition(VelvetMotion.headerControl(reduceMotion: reduceMotion))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .animation(VelvetMotion.route(reduceMotion: reduceMotion), value: route)
    }

    private func onboardingOverlay(safeAreaBottom: CGFloat) -> some View {
        ConnectVPNView(route: $route)
            .padding(.horizontal, VelvetTheme.horizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, max(safeAreaBottom, VelvetTheme.minimumBottomMargin))
            .frame(maxWidth: .infinity)
            .background {
                OnboardingContentBackdrop()
            }
            .keyboardLift()
    }
}
