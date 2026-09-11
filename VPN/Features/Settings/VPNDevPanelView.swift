import SwiftUI

#if DEBUG

private enum DevConnectionPreset: String, CaseIterable, Identifiable {
    case disconnected
    case connecting
    case connected
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .failed: "Failed"
        }
    }
}

private enum DevAppRouteOption: String, CaseIterable, Identifiable {
    case onboarding
    case permission
    case home

    var id: String { rawValue }

    var route: AppRoute {
        switch self {
        case .onboarding: .onboarding
        case .permission: .permission
        case .home: .home
        }
    }

    static func matching(_ route: AppRoute) -> DevAppRouteOption {
        switch route {
        case .onboarding: .onboarding
        case .permission: .permission
        case .home: .home
        }
    }
}

struct VPNDevPanelView: View {
    @Bindable var providerStore: VPNProviderStore
    let runtime: VPNDevRuntime

    @AppStorage("velvet.homeFormat") private var homeFormat = VPNHomeFormat.classic
    @AppStorage("velvet.panelStyle") private var panelStyle = VPNPanelStyle.island
    @AppStorage("velvet.panelDetentMode") private var panelDetentMode = VPNPanelDetentMode.stepped
    @AppStorage("velvet.autoConnect") private var autoConnect = false

    @State private var connectFailSimulation = false
    @State private var mockUsagePercent = 13
    @State private var dismissAfterApply = true

    private let sessionDataLimitBytes: Int64 = 7_000_000_000

    var body: some View {
        Form {
            scenariosSection
            navigationSection
            layoutSection
            connectionSection
            mockStatsSection
            flagsSection
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            connectFailSimulation = VPNDevFlags.connectShouldFail
            mockUsagePercent = Int(runtime.sessionUsageFraction * 100)
        }
    }

    private var scenariosSection: some View {
        Section {
            if let active = providerStore.activePrototypeScenario {
                LabeledContent("Active", value: active.title)
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(VPNPrototypeScenario.allCases) { scenario in
                Button {
                    applyScenario(scenario)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scenario.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if providerStore.activePrototypeScenario == scenario {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(VelvetTheme.accent)
                            }
                        }
                        Text(scenario.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Prototype states")
        } footer: {
            Text("Each state resets providers, connection, scope, and flags so the screen matches the scenario.")
        }
    }

    private var navigationSection: some View {
        Section("App route") {
            Picker("Screen", selection: routeBinding) {
                ForEach(DevAppRouteOption.allCases) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
        }
    }

    private var layoutSection: some View {
        Section("Layout") {
            Picker("Home layout", selection: $homeFormat) {
                ForEach(VPNHomeFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }

            Picker("Panel style", selection: $panelStyle) {
                ForEach(VPNPanelStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }

            Picker("Detent behavior", selection: $panelDetentMode) {
                ForEach(VPNPanelDetentMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker("Panel position", selection: runtime.panelPosition) {
                Text("Collapsed").tag(BottomPanelPosition.island)
                Text("Half").tag(BottomPanelPosition.intermediate)
                Text("Full").tag(BottomPanelPosition.expanded)
            }
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            Picker("State", selection: connectionPresetBinding) {
                ForEach(DevConnectionPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }

            Toggle("Auto-connect on launch", isOn: $autoConnect)
        }
    }

    private var mockStatsSection: some View {
        Section {
            Stepper("Ping: \(runtime.livePingMs.wrappedValue) ms", value: runtime.livePingMs, in: 0...500, step: 1)

            TextField("Download", text: runtime.downloadRate)
            TextField("Upload", text: runtime.uploadRate)

            Stepper("Usage: \(mockUsagePercent)%", value: $mockUsagePercent, in: 0...100, step: 1)
                .onChange(of: mockUsagePercent) { _, value in
                    runtime.sessionBytesUsed.wrappedValue =
                        Int64(Double(sessionDataLimitBytes) * Double(value) / 100)
                }
        } header: {
            Text("Mock stats")
        }
    }

    private var flagsSection: some View {
        Section("Flags") {
            Toggle("Simulate connect failure", isOn: $connectFailSimulation)
                .onChange(of: connectFailSimulation) { _, value in
                    VPNDevFlags.setConnectShouldFail(value)
                }

            Toggle("Dismiss Settings after apply", isOn: $dismissAfterApply)

            Button("Show renewal banners again") {
                providerStore.hiddenRenewalBannerIDs.removeAll()
            }

            LabeledContent("Launch args", value: launchArgsSummary)
                .font(.caption)
        }
    }

    private var routeBinding: Binding<DevAppRouteOption> {
        Binding(
            get: { DevAppRouteOption.matching(runtime.route.wrappedValue) },
            set: { runtime.route.wrappedValue = $0.route }
        )
    }

    private var connectionPresetBinding: Binding<DevConnectionPreset> {
        Binding(
            get: {
                switch runtime.connectionState.wrappedValue {
                case .disconnected: .disconnected
                case .connecting: .connecting
                case .connected: .connected
                case .failed: .failed
                }
            },
            set: { applyConnectionPreset($0) }
        )
    }

    private func applyScenario(_ scenario: VPNPrototypeScenario) {
        providerStore.applyPrototypeScenario(scenario)

        homeFormat = scenario.usesNetworksLayout ? .networksAndLocations : .classic
        panelStyle = .island
        runtime.panelPosition.wrappedValue = scenario.preferredPanelPosition
        runtime.connectionState.wrappedValue = .disconnected
        runtime.isSwitchingServer.wrappedValue = false
        clearConnection()

        if let demo = scenario.demoLocationSelection(scope: providerStore.providerScope) {
            runtime.locationSelection.wrappedValue = demo
            runtime.selectionSource.wrappedValue = .useCase(
                VPNUseCaseMenuChoice.matching(demo) ?? .smart
            )
        } else {
            runtime.locationSelection.wrappedValue = .smartAuto(scope: providerStore.providerScope)
            runtime.selectionSource.wrappedValue = .useCase(.smart)
        }

        switch scenario {
        case .onboarding:
            runtime.route.wrappedValue = .onboarding
        case .importedOnly, .velvetOnly, .velvetPlusImported, .velvetExpired, .importedExpired:
            runtime.route.wrappedValue = .home
        }

        connectFailSimulation = false

        if dismissAfterApply {
            runtime.onDismissSettings()
        }
    }

    private func applyConnectionPreset(_ preset: DevConnectionPreset) {
        runtime.isSwitchingServer.wrappedValue = false

        switch preset {
        case .disconnected:
            runtime.connectionState.wrappedValue = .disconnected
            clearConnection()
        case .connecting:
            runtime.connectionState.wrappedValue = .connecting
        case .connected:
            if runtime.resolvedConnection.wrappedValue == nil {
                seedResolvedConnectionIfPossible()
            }
            runtime.connectionState.wrappedValue = .connected
            if runtime.connectedAt.wrappedValue == nil {
                runtime.connectedAt.wrappedValue = .now
            }
        case .failed:
            runtime.connectionState.wrappedValue = .failed(.network(message: "Try another server"))
            runtime.connectedAt.wrappedValue = nil
        }
    }

    private func seedResolvedConnectionIfPossible() {
        guard let resolved = VPNConnectionPlanner.resolve(
            providers: providerStore.providers,
            selection: runtime.locationSelection.wrappedValue
        ) else { return }
        runtime.resolvedConnection.wrappedValue = resolved
        runtime.livePingMs.wrappedValue = resolved.location.ping
    }

    private func clearConnection() {
        runtime.resolvedConnection.wrappedValue = nil
        runtime.connectedAt.wrappedValue = nil
        runtime.isSwitchingServer.wrappedValue = false
    }

    private var launchArgsSummary: String {
        let args = CommandLine.arguments.filter { $0.hasPrefix("--") }
        return args.isEmpty ? "none" : args.joined(separator: ", ")
    }
}

private extension VPNDevRuntime {
    var sessionUsageFraction: Double {
        let limit: Int64 = 7_000_000_000
        return Double(sessionBytesUsed.wrappedValue) / Double(limit)
    }
}

#endif
