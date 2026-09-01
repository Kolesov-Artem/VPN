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

struct HomeView: View {
    @Binding var route: AppRoute

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var panelPosition = BottomPanelPosition.island
    @State private var connectionState = VPNConnectionState.disconnected
    @State private var selectedLocation = VPNLocation.samples[0]
    @State private var providers = VPNNetworkCatalog.providers
    @State private var showsSettings = false
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island

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
        mapLayer { safeAreaBottom, _ in
            VPNIslandPanel(
                position: $panelPosition,
                connectionState: $connectionState,
                selectedLocation: $selectedLocation,
                providers: $providers,
                safeAreaBottom: safeAreaBottom
            )
        }
        .sheet(isPresented: $showsSettings) {
            settingsSheet
        }
    }

    /// Variant B: a system sheet owns the panel, which is what lets a swipe
    /// resize it first and scroll the list afterwards.
    private var sheetLayout: some View {
        mapLayer { _, _ in EmptyView() }
            .sheet(isPresented: .constant(true)) {
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

    // The reader keeps the bottom safe area so the panel can size its margins
    // from the real home indicator inset before ignoring it.
    private func mapLayer<Panel: View>(
        @ViewBuilder panel: @escaping (CGFloat, BottomPanelDetents) -> Panel
    ) -> some View {
        GeometryReader { proxy in
            let safeAreaBottom = proxy.safeAreaInsets.bottom
            let detents = detents(
                screenHeight: proxy.size.height + safeAreaBottom,
                safeAreaBottom: safeAreaBottom
            )
            let summaryPadding = detents.summaryBottomPadding(for: panelPosition)

            ZStack(alignment: .bottom) {
                VelvetMapBackground(
                    selectedLocation: connectionState.activeRoute?.location ?? selectedLocation,
                    isConnected: connectionState.isConnected,
                    onPickCoordinate: selectNearestServer
                )

                VStack(spacing: 0) {
                    header

                    Spacer()

                    connectionSummary
                        .padding(.bottom, summaryPadding)
                }

                panel(safeAreaBottom, detents)
            }
            .ignoresSafeArea(edges: .bottom)
            .animation(.easeOut(duration: 0.25), value: panelPosition)
        }
    }

    private func detents(
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat
    ) -> BottomPanelDetents {
        switch panelStyle {
        case .island:
            .makeIsland(
                screenHeight: screenHeight,
                safeAreaBottom: safeAreaBottom,
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
        SettingsView(panelStyle: $panelStyle)
            .presentationDetents([.medium])
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
            VelvetBrand()

            Spacer()

            Button {
                route = .onboarding
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Add VPN configuration")

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
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var connectionSummary: some View {
        VStack(spacing: 12) {
            Image(systemName: summarySymbol)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(summarySymbolColor)
                .contentTransition(.symbolEffect(.replace))

            Text(summaryTitle)
                .font(.title3.weight(.semibold))

            Label(summaryLocationLabel, systemImage: "location.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if connectionState.isConnecting {
                Text("Finding route…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let route = connectionState.activeRoute {
                Text(route.summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if selectedLocation.isSmart {
                Text("Smart · Auto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeOut(duration: 0.2), value: connectionState)
        .accessibilityElement(children: .combine)
    }

    private var summarySymbol: String {
        if connectionState.isConnected { return "lock.shield.fill" }
        if connectionState.isConnecting { return "shield.lefthalf.filled" }
        return "shield"
    }

    private var summarySymbolColor: Color {
        if connectionState.isConnected { return .green }
        return .primary.opacity(0.72)
    }

    private var summaryTitle: String {
        switch connectionState {
        case .disconnected: "Ready to connect"
        case .connecting: "Connecting"
        case .connected: "Protected"
        }
    }

    private var summaryLocationLabel: String {
        if let route = connectionState.activeRoute {
            return route.location.name
        }
        return selectedLocation.isSmart ? "Smart · Auto" : selectedLocation.name
    }
}

private struct SettingsView: View {
    @Binding var panelStyle: VPNPanelStyle

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
