import SwiftUI

private struct NetworksScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

/// Multi-provider panel: one Connect button in island mode, Networks + Locations
/// when expanded. Mirrors the island drag/scroll mechanics from `VPNIslandPanel`.
struct VPNNetworksIslandPanel: View {
    let providers: [VPNProvider]

    @Binding var position: BottomPanelPosition
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation
    @Binding var locationSelection: VPNLocationSelection
    @Binding var resolvedConnection: VPNResolvedConnection?
    @Binding var isPanelInteracting: Bool

    let safeAreaBottom: CGFloat
    let safeAreaTop: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var dragTranslation: CGFloat = 0
    @State private var scrollChromeMinY: CGFloat?
    @State private var scrollRestMinY: CGFloat?
    @State private var scrollEdgeProgress: CGFloat = 0
    @State private var isScrollAtTop = true
    @State private var isDraggingPanel = false
    @State private var isCollapsingFromScroll = false
    @State private var isPositionAnimating = false
    @State private var positionAnimationTask: Task<Void, Never>?
    @State private var isFindingBest = false
    @State private var query = VPNLocationQuery()
    @State private var showsDeleteConfirmation = false
    @State private var detailProvider: VPNProvider?
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let detents = BottomPanelDetents.makeIsland(
                screenHeight: proxy.size.height + safeAreaBottom,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let layout = BottomPanelInterpolator.layout(
                detents: detents,
                position: position,
                dragTranslation: dragTranslation
            )
            let panelInteracting = isDraggingPanel || isCollapsingFromScroll || isPositionAnimating
            let expandedTopInset = max(safeAreaTop - VelvetTheme.expandedTopInsetReduction, 0)
            let searchRevealProgress = locationSearchRevealProgress(layout: layout)
            let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
                panelBottomMargin: detents.bottomMargin
            )
            let viewportHeight = min(
                proxy.size.height,
                max(0, UIScreen.main.bounds.maxY - proxy.frame(in: .global).minY)
            )

            Color.clear
                .allowsHitTesting(false)
                .overlay(alignment: .bottom) {
                    panelCard(detents: detents, layout: layout, expandedTopInset: expandedTopInset)
                }
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(
                            width: proxy.size.width,
                            height: viewportHeight
                        )
                        .overlay(alignment: .bottom) {
                            if searchRevealProgress > 0.01 {
                                PanelLocationSearchControls(
                                    query: $query,
                                    isFocused: $searchIsFocused,
                                    bottomMargin: searchScreenOffset,
                                    safeAreaBottom: detents.bottomMargin
                                )
                                .opacity(searchRevealProgress)
                                .allowsHitTesting(searchRevealProgress > 0.35)
                            }
                        }
                    }
                .onChange(of: panelInteracting) { _, interacting in
                    isPanelInteracting = interacting
                }
                .onAppear {
                    isPanelInteracting = panelInteracting
                }
        }
        .sensoryFeedback(.selection, trigger: position)
        .onChange(of: position) { _, newValue in
            if newValue == .island {
                searchIsFocused = false
                query.text = ""
            }
            if newValue != .expanded {
                isScrollAtTop = true
                scrollEdgeProgress = 0
                isCollapsingFromScroll = false
            }
        }
        .sheet(item: $detailProvider) { provider in
            VPNProviderDetailView(provider: provider)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete this configuration?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                connectionState = .disconnected
                resolvedConnection = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The prototype keeps the demo configuration, so nothing is removed.")
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if reduceTransparency {
            Color(.systemBackground)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    private func panelShape(layout: BottomPanelVisualState) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: VelvetTheme.panelRadius,
            bottomLeadingRadius: layout.bottomCornerRadius,
            bottomTrailingRadius: layout.bottomCornerRadius,
            topTrailingRadius: VelvetTheme.panelRadius
        )
    }

    private func panelCard(
        detents: BottomPanelDetents,
        layout: BottomPanelVisualState,
        expandedTopInset: CGFloat
    ) -> some View {
        let shape = panelShape(layout: layout)
        let searchRevealProgress = locationSearchRevealProgress(layout: layout)
        let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
            panelBottomMargin: detents.bottomMargin
        )

        return ZStack(alignment: .top) {
            expandedScrollBody(
                detents: detents,
                layout: layout,
                searchRevealProgress: searchRevealProgress,
                searchScreenOffset: searchScreenOffset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(spacing: 8) {
                connectionButton
                if let subtitle = collapsedSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, panelChromeHeight + 12)
            .opacity(layout.collapsedContentOpacity)
            .allowsHitTesting(layout.collapsedContentOpacity > 0.5)
        }
        .frame(height: layout.panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background { panelBackground }
        .clipShape(shape)
        .shadow(color: .black.opacity(layout.shadowOpacity), radius: layout.shadowRadius, y: layout.shadowY)
        .padding(.top, expandedTopInset * layout.sheetMorphProgress)
        .padding(.horizontal, layout.horizontalInset)
        .padding(.bottom, layout.bottomInset)
        .contentShape(Rectangle())
        .gesture(
            panelResizeGesture(detents: detents),
            including: position != .expanded ? .all : .subviews
        )
    }

    private func locationSearchRevealProgress(layout: BottomPanelVisualState) -> CGFloat {
        switch position {
        case .expanded, .intermediate:
            1
        case .island:
            layout.listProgress
        }
    }

    private var panelChromeHeight: CGFloat {
        BottomPanelDetents.expandedGripBandHeight + 44
    }

    private var collapsedSubtitle: String? {
        if connectionState == .connected, let resolvedConnection {
            return resolvedConnection.summarySubtitle
        }
        if case let .smart(preset) = locationSelection, connectionState == .disconnected {
            return "\(preset.title) · \(VPNConnectionPlanner.qualityLabel(for: preset, providers: providers))"
        }
        return nil
    }

    private func panelTopBar(detents: BottomPanelDetents) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.42))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .frame(height: BottomPanelDetents.expandedGripBandHeight)
                .contentShape(Rectangle())
                .gesture(
                    sheetCollapseGesture(detents: detents),
                    including: isScrollAtTop ? .all : .subviews
                )

            ZStack {
                networksPanelHeader
                    .opacity(1 - scrollEdgeProgress)
                    .allowsHitTesting(scrollEdgeProgress < 0.5)

                ExpandedSheetCompactBar(
                    title: "Networks & locations",
                    scrollEdgeProgress: scrollEdgeProgress,
                    onCollapse: collapseExpandedPanel
                )
            }
            .frame(height: 44)
        }
    }

    private var networksPanelHeader: some View {
        HStack(spacing: 10) {
            Text("Networks & locations")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            VPNConfigOptionsMenu(showsDeleteConfirmation: $showsDeleteConfirmation) {
                headerIcon("ellipsis")
            }

            Button {
                togglePosition()
            } label: {
                headerIcon(position == .island ? "chevron.up" : "chevron.down")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(position == .island ? "Expand panel" : "Collapse panel")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func headerIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(Color(.tertiarySystemFill), in: Circle())
    }

    private func expandedScrollBody(
        detents: BottomPanelDetents,
        layout: BottomPanelVisualState,
        searchRevealProgress: CGFloat,
        searchScreenOffset: CGFloat
    ) -> some View {
        let isExpanded = position == .expanded
        let canScroll = isExpanded && !isPositionAnimating && !isCollapsingFromScroll

        return ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id("scrollTop")
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: NetworksScrollOffsetKey.self,
                                    value: geometry.frame(in: .named("networksScroll")).minY
                                )
                            }
                            .frame(height: 0)
                        }

                    networksAndLocationsContent
                        .opacity(layout.listProgress)
                        .allowsHitTesting(layout.listProgress > 0.5)
                        .padding(.top, 12)
                }
                .padding(
                    .bottom,
                    LocationSearchChrome.scrollBottomPadding(
                        revealProgress: searchRevealProgress,
                        bottomMargin: searchScreenOffset,
                        contentInset: detents.contentBottomInset
                    )
                )
            }
            .panelScrollEdgeBar(scrollEdgeProgress: scrollEdgeProgress) {
                panelTopBar(detents: detents)
            }
            .coordinateSpace(name: "networksScroll")
            .onPreferenceChange(NetworksScrollOffsetKey.self) { minY in
                updateScrollAtTop(chromeMinY: minY)
            }
            .scrollDisabled(!canScroll)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                sheetCollapseGesture(detents: detents),
                including: isExpanded && isScrollAtTop ? .all : .subviews
            )
            .onChange(of: position) { _, newValue in
                isScrollAtTop = true
                scrollEdgeProgress = 0
                guard newValue != .expanded else { return }
                scrollChromeMinY = nil
                scrollRestMinY = nil
                scrollProxy.scrollTo("scrollTop", anchor: .top)
            }
        }
    }

    private var networksAndLocationsContent: some View {
        VStack(spacing: 16) {
            networksCard
            locationsCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var networksCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                Button {
                    detailProvider = provider
                } label: {
                    providerRow(provider)
                }
                .buttonStyle(.plain)

                if index < providers.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func providerRow(_ provider: VPNProvider) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(providerAccent(provider).opacity(0.14))
                Image(systemName: provider.iconSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(providerAccent(provider))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .foregroundStyle(.primary)
                    if provider.kind == .velvetFeatured {
                        Text("Featured")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(VelvetTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VelvetTheme.accent.opacity(0.12), in: Capsule())
                    }
                }
                Text(provider.subtitle)
                    .font(.caption)
                    .foregroundStyle(provider.status == .expired ? .red : .secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            if provider.status == .expired {
                Text("!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.red, in: Circle())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func providerAccent(_ provider: VPNProvider) -> Color {
        provider.kind == .velvetFeatured ? VelvetTheme.accent : Color.blue
    }

    private var locationsCard: some View {
        VStack(spacing: 10) {
            smartPresetsSection

            if !query.isDefault && !isDraggingPanel {
                activeFilterChips
            }

            serverListSection
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var smartPresetsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(VPNSmartPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                Button {
                    selectSmartPreset(preset)
                } label: {
                    smartPresetRow(preset)
                }
                .buttonStyle(.plain)

                if index < VPNSmartPreset.allCases.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
    }

    private func smartPresetRow(_ preset: VPNSmartPreset) -> some View {
        let isSelected = locationSelection == .smart(preset)
        let quality = VPNConnectionPlanner.qualityLabel(for: preset, providers: providers)

        return HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelvetTheme.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .foregroundStyle(.primary)
                Text(preset.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VelvetTheme.accent)
            }

            Text(quality)
                .font(.caption.weight(.semibold))
                .foregroundStyle(qualityColor(quality))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "Best": .green
        case "Good": .yellow
        default: .secondary
        }
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(query.activeChips) { chip in
                    Button {
                        query.clear(chip)
                    } label: {
                        HStack(spacing: 4) {
                            Text(chip.title)
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VelvetTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VelvetTheme.accent.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var serverListSection: some View {
        VStack(spacing: 0) {
            let results = filteredNetworkLocations

            if results.isEmpty {
                Text("No servers found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, networkLocation in
                    Button {
                        selectManualLocation(networkLocation)
                    } label: {
                        serverRow(networkLocation)
                    }
                    .buttonStyle(.plain)

                    if index < results.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
        }
    }

    private var filteredNetworkLocations: [VPNNetworkLocation] {
        let merged = VPNConnectionPlanner.mergedLocations(from: providers.filter(\.isEligibleForAutoConnect))
        let trimmedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)

        return merged
            .filter { networkLocation in
                guard query.filter.accepts(networkLocation.location) else { return false }
                guard !query.fastOnly || networkLocation.location.ping < VPNLocation.fastPingThreshold else {
                    return false
                }
                guard !trimmedQuery.isEmpty else { return true }
                return networkLocation.location.searchText.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { lhs, rhs in
                switch query.sort {
                case .fastest:
                    lhs.location.ping < rhs.location.ping
                case .country:
                    lhs.location.name.localizedCompare(rhs.location.name) == .orderedAscending
                }
            }
    }

    private func serverRow(_ networkLocation: VPNNetworkLocation) -> some View {
        let isSelected = if case let .manual(location, providerID) = locationSelection {
            location.id == networkLocation.location.id && providerID == networkLocation.provider.id
        } else {
            false
        }

        return HStack(spacing: 12) {
            Text(networkLocation.location.flag)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(networkLocation.location.name)
                    .foregroundStyle(.primary)
                Text("\(networkLocation.location.subtitle) · \(networkLocation.provider.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VelvetTheme.accent)
            } else {
                Text(networkLocation.location.pingLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var connectionButton: some View {
        Button {
            handleConnectionTap()
        } label: {
            HStack {
                if connectionState == .connecting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: connectionState == .connected ? "checkmark.shield.fill" : "power")
                }
                Text(connectionButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(connectionState == .connected ? Color.green : VelvetTheme.accent)
        .disabled(connectionState == .connecting)
    }

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected:
            "Connect"
        case .connecting:
            isFindingBest ? "Finding best connection…" : "Connecting…"
        case .connected:
            "Connected"
        }
    }

    private func selectSmartPreset(_ preset: VPNSmartPreset) {
        locationSelection = .smart(preset)
        collapseToIsland()
    }

    private func selectManualLocation(_ networkLocation: VPNNetworkLocation) {
        locationSelection = .manual(
            location: networkLocation.location,
            providerID: networkLocation.provider.id
        )
        selectedLocation = networkLocation.location
        collapseToIsland()
    }

    private func collapseToIsland() {
        searchIsFocused = false
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .island
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func handleConnectionTap() {
        if connectionState == .connected {
            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState = .disconnected
                resolvedConnection = nil
            }
            return
        }

        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState = .connecting
            isFindingBest = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard connectionState == .connecting else { return }

            if let resolved = VPNConnectionPlanner.resolve(providers: providers, selection: locationSelection) {
                resolvedConnection = resolved
                selectedLocation = resolved.location
            }

            isFindingBest = false

            try? await Task.sleep(for: .milliseconds(500))
            guard connectionState == .connecting else { return }

            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
            }
        }
    }

    private func updateScrollAtTop(chromeMinY: CGFloat?) {
        guard let chromeMinY else { return }
        if scrollRestMinY == nil { scrollRestMinY = chromeMinY }

        let restMinY = scrollRestMinY ?? chromeMinY
        let scrollOffset = restMinY - chromeMinY
        let newAtTop = scrollOffset <= 1
        let newProgress = min(max(scrollOffset / 28, 0), 1)

        if let previous = scrollChromeMinY,
           abs(previous - chromeMinY) < 0.5,
           newAtTop == isScrollAtTop,
           abs(newProgress - scrollEdgeProgress) < 0.02 {
            return
        }

        scrollChromeMinY = chromeMinY
        isScrollAtTop = newAtTop
        scrollEdgeProgress = newProgress
    }

    private func sheetCollapseGesture(detents: BottomPanelDetents) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard position == .expanded, isScrollContentAtTop else { return }
                guard value.translation.height > 4 else { return }
                guard value.translation.height > abs(value.translation.width) else { return }

                isCollapsingFromScroll = true
                isDraggingPanel = true
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                guard position == .expanded, isCollapsingFromScroll else {
                    isCollapsingFromScroll = false
                    isDraggingPanel = false
                    return
                }

                snapPanel(
                    detents: detents,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height
                )
                isCollapsingFromScroll = false
            }
    }

    private var isScrollContentAtTop: Bool {
        guard let chromeMinY = scrollChromeMinY else { return isScrollAtTop }
        guard let scrollRestMinY else { return isScrollAtTop }
        return chromeMinY >= scrollRestMinY - 1
    }

    private func panelResizeGesture(detents: BottomPanelDetents) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard position != .expanded else { return }
                isDraggingPanel = true
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                guard position != .expanded else {
                    isDraggingPanel = false
                    return
                }
                snapPanel(
                    detents: detents,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height
                )
            }
    }

    private func snapPanel(
        detents: BottomPanelDetents,
        translation: CGFloat,
        predictedEndTranslation: CGFloat
    ) {
        let target = BottomPanelSnapResolver.resolve(
            current: position,
            translation: translation,
            predictedEndTranslation: predictedEndTranslation,
            detents: detents
        )
        isDraggingPanel = false
        isCollapsingFromScroll = false
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = target
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }

    private func schedulePositionAnimationEnd() {
        positionAnimationTask?.cancel()
        let delay = VelvetMotion.panelSettleDelay(reduceMotion: reduceMotion)
        positionAnimationTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            isPositionAnimating = false
        }
    }

    private func collapseExpandedPanel() {
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .intermediate
            dragTranslation = 0
            isScrollAtTop = true
            isCollapsingFromScroll = false
            isDraggingPanel = false
        }
        schedulePositionAnimationEnd()
    }

    private func togglePosition() {
        isPositionAnimating = true
        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            switch position {
            case .island:
                position = .intermediate
            case .intermediate:
                position = .expanded
            case .expanded:
                position = .island
            }
            dragTranslation = 0
        }
        schedulePositionAnimationEnd()
    }
}