import SwiftUI

/// Figma connect home: native tabs, the island's subscription switch, and the island's site list.
struct SimpleHomeHeroView: View {
    @Bindable var providerStore: VPNProviderStore
    var connectionState: VPNConnectionState
    var isSwitchingServer: Bool
    var selectedLocation: VPNLocation
    @Binding var locationSelection: VPNLocationSelection
    @Binding var selectionSource: VPNSelectionSource
    var displayProvider: VPNProvider
    var serviceAvailability: ServiceAvailabilityModel
    var sessionStats: VPNSessionStatsModel
    let onConnect: () -> Void
    let onSelectPreset: (VPNUseCaseMenuChoice) -> Void
    let onSelectAllSubscriptions: () -> Void
    let onSelectProvider: (UUID) -> Void
    let onProviderInfo: (UUID) -> Void
    let onOpenSubscriptions: () -> Void
    let onAdd: () -> Void
    let onSmartLocation: (VPNUserJob) -> Void
    let onManualLocation: (VPNNetworkLocation) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab = HeroTab.connect
    @State private var showsProviderSwitch = false
    @State private var showsTrafficChart = false

    private var providerName: String {
        displayProvider.catalogDisplayName.withoutEmoji
    }

    var body: some View {
        TabView(selection: $tab) {
            connectPage
                .tabItem { Label(ui("Connect"), systemImage: "diamond.fill") }
                .tag(HeroTab.connect)

            SimpleHomeLocationsPage(
                providerStore: providerStore,
                locationSelection: $locationSelection,
                selectionSource: $selectionSource,
                showsDone: false,
                onSmartLocation: onSmartLocation,
                onManualLocation: onManualLocation
            )
            .tabItem { Label(ui("Locations"), systemImage: "circle.fill") }
            .tag(HeroTab.locations)

            VelvetProductsPage(showsDone: false)
            .tabItem { Label(ui("Services"), systemImage: "triangle.fill") }
            .tag(HeroTab.services)

            VPNAccountView(providerStore: providerStore, showsDismissButton: false) { id in
                onProviderInfo(id)
            }
            .tabItem { Label(ui("Account"), systemImage: "person.crop.circle") }
            .tag(HeroTab.account)
        }
        .tint(VelvetTheme.accent)
        .overlay {
            if showsProviderSwitch {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { setProviderSwitchPresented(false) }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if showsProviderSwitch {
                VPNActiveProviderSwitchCard(
                    providers: providerStore.providers,
                    activeProviderID: providerStore.activeProviderID,
                    showsAllSubscriptions: providerStore.showsAllSubscriptionsCatalog,
                    onSelectAll: {
                        setProviderSwitchPresented(false)
                        onSelectAllSubscriptions()
                    },
                    onSelect: { id in
                        setProviderSwitchPresented(false)
                        onSelectProvider(id)
                    },
                    onInfo: { id in
                        setProviderSwitchPresented(false)
                        onProviderInfo(id)
                    },
                    onOpenSubscriptions: {
                        setProviderSwitchPresented(false)
                        onOpenSubscriptions()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(VelvetMotion.popoverTransition(reduceMotion: reduceMotion))
            }
        }
        .animation(VelvetMotion.popover(reduceMotion: reduceMotion), value: showsProviderSwitch)
        .sensoryFeedback(.selection, trigger: showsProviderSwitch) { _, presented in
            presented
        }
    }

    private var connectPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                trafficCard
                heroCard
                sitesBlock
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(VelvetTheme.pageWash)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title2.weight(.semibold))
                .foregroundStyle(VelvetTheme.accent)
                .frame(width: 44, height: 56)
                .accessibilityLabel(ui("Velvet"))

            Button {
                setProviderSwitchPresented(true)
            } label: {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(providerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelvetTheme.mainTextDark)
                            .lineLimit(1)
                        Text(displayProvider.subscriptionIdentityCaption)
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
            .accessibilityLabel("Active VPN, \(providerName)")

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VelvetTheme.mainTextDark)
                    .frame(width: 56, height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(ui("Add VPN configuration"))
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(placeTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(statusTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    tab = .locations
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(ui("Locations"))
            }
            .foregroundStyle(.white)
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.top, 12)

            Color.clear
                .frame(height: 112)
                .overlay {
                    if connectionState == .connecting || isSwitchingServer {
                        HeroConnectingGlow(reduceMotion: reduceMotion)
                            .transition(.opacity)
                    }
                }
                .clipped()
                .animation(
                    VelvetMotion.connectionState(reduceMotion: reduceMotion),
                    value: connectionState == .connecting || isSwitchingServer
                )
                .accessibilityHidden(true)

            if connectionState.isConnected {
                SessionStatsConsumer(model: sessionStats, readsLiveValues: true) { live in
                    heroLiveStats(live)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(VPNFigmaSection550Copy.expandedPresetChoices) { choice in
                        presetCard(choice)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)

            Button(action: onConnect) {
                Text(connectTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VelvetTheme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(connectionState == .connecting || isSwitchingServer)
            .padding(8)
        }
        .animation(VelvetMotion.connectionLayout(reduceMotion: reduceMotion), value: connectionState.isConnected)
        .background {
            ZStack {
                VelvetTheme.mapDisconnected
                VelvetMapBackground(
                    selectedLocation: selectedLocation,
                    connectionState: connectionState,
                    isInteractive: false,
                    showsEdgeFade: false,
                    extendsIntoSafeArea: false,
                    showsPinTitles: false,
                    scrimBottomIntoWash: true,
                    showsPinPulse: false,
                    onPickCoordinate: { _ in }
                )
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [Color.black.opacity(0.42), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 96)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroLiveStats(_ live: VPNSessionStatsSnapshot) -> some View {
        HStack(spacing: 0) {
            heroMetric(symbol: "arrow.down", value: live.downloadRate, label: ui("Download"))
            heroMetric(symbol: "arrow.up", value: live.uploadRate, label: ui("Upload"))
            heroMetric(symbol: "antenna.radiowaves.left.and.right", value: "\(live.pingMs) ms", label: ui("Ping"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Download \(live.downloadRate), upload \(live.uploadRate), ping \(live.pingMs) milliseconds")
    }

    private func heroMetric(symbol: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }

    private var trafficCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                setTrafficChartExpanded(!showsTrafficChart)
            } label: {
                HStack(spacing: 8) {
                    Text(ui("Traffic usage"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: showsTrafficChart ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ui("Traffic usage"))
            .accessibilityHint(showsTrafficChart ? ui("Hides the chart") : ui("Shows the chart"))

            HStack(alignment: .top, spacing: 16) {
                trafficMeter(
                    title: uiFormat("Basic %lld%%", 73),
                    emphasis: "",
                    trailing: "",
                    fraction: 0.73,
                    detail: "332 / 2 064 000 GB"
                )
                trafficMeter(
                    title: uiFormat("LTE %lld%%", 62),
                    emphasis: "",
                    trailing: "",
                    fraction: 0.62,
                    detail: "32 GB / 40 GB"
                )
            }

            if showsTrafficChart {
                VPNTrafficUsageCard(
                    providers: providerStore.providers,
                    scopedProviderID: displayProvider.id,
                    embedInForm: true,
                    showsHeading: false,
                    showsUsageMeters: false
                )
                .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion), value: showsTrafficChart)
    }

    private func trafficMeter(
        title: String,
        emphasis: String,
        trailing: String,
        fraction: Double,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            (
                Text(title) +
                Text(emphasis).fontWeight(.semibold) +
                Text(trailing).foregroundStyle(.secondary)
            )
            .font(.footnote)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Capsule()
                .fill(Color(.systemFill))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(VelvetTheme.connectedGreen)
                            .frame(width: proxy.size.width * fraction)
                    }
                }

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sitesBlock: some View {
        ServiceAvailabilityCard(
            model: serviceAvailability,
            isVPNConnected: connectionState.isConnected,
            usesPlainChrome: true
        )
    }

    private func presetCard(_ choice: VPNUseCaseMenuChoice) -> some View {
        let isSelected = selectionSource.activeUseCase(for: locationSelection) == choice
        return Button {
            onSelectPreset(choice)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(VPNFigmaSection550Copy.presetCardTitle(for: choice))
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: presetSymbol(choice, isSelected: isSelected))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                }
                Text(VPNFigmaSection550Copy.presetCardSubtitle(for: choice))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 16)
            .frame(width: 148, alignment: .topLeading)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func presetSymbol(_ choice: VPNUseCaseMenuChoice, isSelected: Bool) -> String {
        if isSelected { return "checkmark.circle.fill" }
        switch choice {
        case .watchAndPlay: return "play.tv"
        case .workAndBrowse: return "gamecontroller"
        default: return choice.iconSymbol
        }
    }

    private var placeTitle: String {
        let name = selectedLocation.name
            .withoutEmoji
            .replacingOccurrences(of: "SMART-", with: "")
        let city = selectedLocation.city.withoutEmoji
        let cityIsCaption = city.count > 22 || city.contains(".")
        guard !city.isEmpty, city != name, !cityIsCaption, !city.localizedCaseInsensitiveContains("быстр") else {
            return ui(name)
        }
        return uiFormat("%@, %@", ui(city), ui(name))
    }

    private var statusTitle: String {
        if isSwitchingServer { return ui("Switching…") }
        switch connectionState {
        case .connected: return ui("Connected")
        case .connecting: return ui("Connecting…")
        case .disconnected: return ui("Not connected")
        case .failed: return ui("Couldn't connect")
        }
    }

    private var connectTitle: String {
        if isSwitchingServer { return ui("Switching…") }
        switch connectionState {
        case .disconnected: return ui("Connect VPN")
        case .connecting: return ui("Connecting…")
        case .connected: return ui("Disconnect")
        case .failed: return ui("Try again")
        }
    }

    private func setProviderSwitchPresented(_ isPresented: Bool) {
        withAnimation(VelvetMotion.popover(reduceMotion: reduceMotion)) {
            showsProviderSwitch = isPresented
        }
    }

    private func setTrafficChartExpanded(_ isExpanded: Bool) {
        withAnimation(VelvetMotion.availabilityExpand(reduceMotion: reduceMotion)) {
            showsTrafficChart = isExpanded
        }
    }
}

/// Soft light that drifts across the map while a connection is starting.
private struct HeroConnectingGlow: View {
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    glow(
                        at: CGPoint(
                            x: size.width * (0.35 + 0.3 * cos(time * 0.7)),
                            y: size.height * 0.5
                        ),
                        diameter: size.height * 2.2,
                        opacity: 0.55
                    )
                    glow(
                        at: CGPoint(
                            x: size.width * (0.65 + 0.25 * sin(time * 0.55)),
                            y: size.height * 0.5
                        ),
                        diameter: size.height * 1.6,
                        opacity: 0.4
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
        .opacity(reduceMotion ? 0.2 : 1)
        .accessibilityHidden(true)
    }

    private func glow(at center: CGPoint, diameter: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(opacity), Color.white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(center)
    }
}

private enum HeroTab: String, Hashable {
    case connect
    case locations
    case services
    case account
}
