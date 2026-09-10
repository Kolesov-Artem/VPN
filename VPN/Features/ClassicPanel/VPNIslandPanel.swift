import SwiftUI

struct VPNIslandPanel: View {
    @Binding var position: BottomPanelPosition
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation
    @Binding var isPanelInteracting: Bool
    var onShowConnectionInfo: (() -> Void)? = nil

    let downloadRate: String
    let uploadRate: String
    let pingMs: Int
    let usageFraction: Double
    let sessionDataUsedText: String

    let safeAreaBottom: CGFloat
    let safeAreaTop: CGFloat
    var detentMode: VPNPanelDetentMode = .stepped

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @FocusState private var searchIsFocused: Bool
    @State private var query = VPNLocationQuery()
    @State private var showsDeleteConfirmation = false
    @State private var cachedViewportHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let searchRevealProgress = searchRevealProgress(for: position)
            let searchScreenOffset = LocationSearchChrome.screenBottomOffset(
                panelBottomMargin: max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
            )
            let viewportHeight = cachedViewportHeight > 0 ? cachedViewportHeight : proxy.size.height

            BottomPanelCurtain(
                position: $position,
                isPanelInteracting: $isPanelInteracting,
                showsSessionStats: connectionState == .connected,
                safeAreaBottom: safeAreaBottom,
                safeAreaTop: safeAreaTop,
                detentMode: detentMode,
                onDismissSearch: { searchIsFocused = false }
            ) { context in
                panelHeader(context: context)
            } stats: { context in
                connectionStatsStrip(context: context)
            } footer: {
                connectionButton
            } scrollContent: { context in
                floatingListContent(
                    detents: context.detents,
                    progress: 1,
                    animateRows: false
                )
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(width: proxy.size.width, height: viewportHeight)
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottom) {
                        if searchRevealProgress > 0.01 {
                            PanelLocationSearchControls(
                                query: $query,
                                isFocused: $searchIsFocused,
                                bottomMargin: searchScreenOffset,
                                safeAreaBottom: max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
                            )
                            .opacity(searchRevealProgress)
                            .allowsHitTesting(searchRevealProgress > 0.35)
                        }
                    }
            }
            .onAppear {
                cachedViewportHeight = proxy.size.height
            }
            .onChange(of: proxy.size.height) { _, height in
                cachedViewportHeight = height
            }
        }
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
        .confirmationDialog(
            "Delete this configuration?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                connectionState = .disconnected
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The prototype keeps the demo configuration, so nothing is removed.")
        }
    }

    @ViewBuilder
    private func connectionStatsStrip(context: BottomPanelCurtainContext) -> some View {
        if connectionState == .connected {
            AnimatedPanelStatsReveal(context: context) { reveal in
                ConnectionStatsRevealShell(revealProgress: reveal) {
                    ConnectionStatsStrip(
                        regionLabel: selectedLocation.name,
                        pingMs: pingMs,
                        downloadRate: downloadRate,
                        uploadRate: uploadRate,
                        usageFraction: usageFraction,
                        sessionDataUsedText: sessionDataUsedText,
                        usesContentPadding: false,
                        progressTint: VelvetMotion.revealStep(reveal) > 0.45
                            ? .primary
                            : VelvetTheme.accent,
                        onTap: context.isStatsExpanded ? onShowConnectionInfo : nil
                    )
                } details: {
                    EmptyView()
                }
            }
            .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
            .padding(.top, VelvetMetrics.infoBlockTopSpacing)
        }
    }

    private func searchRevealProgress(for position: BottomPanelPosition) -> CGFloat {
        switch position {
        case .expanded, .intermediate:
            1
        case .island:
            0
        }
    }

    private func panelHeader(context: BottomPanelCurtainContext) -> some View {
        HStack(spacing: 10) {
            if context.position == .island {
                ConnectionStatusLabels(
                    connectionState: connectionState,
                    selectedLocation: selectedLocation
                )
            } else {
                ZStack {
                    Circle()
                        .fill(VelvetTheme.accent.opacity(0.13))
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(VelvetTheme.accent)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Velvet VPN")
                        .font(.subheadline.weight(.semibold))
                    Text("99% traffic · 933 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 4)
            }

            moreMenu
                .fixedSize()

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
            .accessibilityLabel(context.position == .island ? "Expand panel" : "Collapse panel")
        }
        .padding(.horizontal, VelvetTheme.horizontalPadding)
        .padding(.bottom, VelvetMetrics.collapsedHeaderBottomPadding)
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private var moreMenu: some View {
        Menu {
            ControlGroup {
                Button {} label: {
                    Label("Info", systemImage: "info.circle")
                }

                Button {} label: {
                    Label("Support", systemImage: "paperplane")
                }
            }
            .controlGroupStyle(.compactMenu)

            Section {
                Button {} label: {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }

                Button {} label: {
                    Label("Update subscription", systemImage: "arrow.clockwise.circle")
                }

                Button {} label: {
                    Label("Check ping", systemImage: "speedometer")
                }

                Button {} label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }

            Section {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            VelvetPanelHeaderIcon(systemName: "ellipsis")
        }
        .accessibilityLabel("More options")
    }

    private var connectionButton: some View {
        VPNPrimaryConnectionButton(
            title: connectionButtonTitle,
            connectionState: connectionState,
            action: handleConnectionTap
        )
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
    }

    private func floatingListContent(
        detents: BottomPanelDetents,
        progress: CGFloat,
        animateRows: Bool
    ) -> some View {
        VStack(spacing: 10) {
            if !query.isDefault {
                activeFilterChips
                    .transition(VelvetMotion.filterChip(reduceMotion: reduceMotion))
            }

            locationListContent(
                detents: detents,
                progress: progress,
                animateRows: animateRows
            )
        }
        .animation(VelvetMotion.queryChange(reduceMotion: reduceMotion), value: query)
        .padding(.horizontal, VelvetTheme.horizontalPadding)
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
                    .accessibilityLabel("Remove filter: \(chip.title)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func locationListContent(
        detents: BottomPanelDetents,
        progress: CGFloat,
        animateRows: Bool
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            let smartResults = results.filter { $0.kind == .smart }
            let otherResults = results.filter { $0.kind != .smart }

            if results.isEmpty {
                emptyState
            } else {
                if !smartResults.isEmpty {
                    locationSection(
                        title: "Recommended",
                        locations: smartResults,
                        startIndex: 0,
                        progress: progress,
                        animateRows: animateRows
                    )
                }

                if !otherResults.isEmpty {
                    locationSection(
                        title: listSectionTitle,
                        locations: otherResults,
                        startIndex: smartResults.count,
                        progress: progress,
                        animateRows: animateRows
                    )
                }
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No servers found")
                .font(.subheadline.weight(.semibold))
            Text("Try another country, or reset the filters from the menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func locationSection(
        title: String,
        locations: [VPNLocation],
        startIndex: Int,
        progress: CGFloat,
        animateRows: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(locations.count)")
                    .font(.footnote.monospacedDigit())
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(locations.enumerated()), id: \.element.id) { offset, location in
                    let appearance = animateRows
                        ? VelvetMotion.rowProgress(progress, index: startIndex + offset)
                        : 1

                    Button {
                        selectLocation(location)
                    } label: {
                        locationRow(location)
                    }
                    .buttonStyle(.plain)
                    .opacity(appearance)
                    .offset(y: animateRows ? 20 * (1 - appearance) : 0)

                    if offset < locations.count - 1 {
                        Divider()
                            .padding(.leading, VelvetMetrics.nestedDividerInset)
                            .opacity(appearance)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius))
        }
    }

    private func locationRow(_ location: VPNLocation) -> some View {
        HStack(spacing: 12) {
            Text(location.flag)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .foregroundStyle(.primary)
                Text(location.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            Group {
                if selectedLocation.id == location.id {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelvetTheme.accent)
                } else {
                    Image(systemName: "cellularbars", variableValue: signalLevel(location.signal))
                        .font(.subheadline)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(signalColor(location.signal))
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, VelvetTheme.horizontalPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), \(location.subtitle), \(location.ping) milliseconds")
        .accessibilityAddTraits(selectedLocation.id == location.id ? [.isSelected] : [])
    }

    private func signalColor(_ signal: VPNLocation.Signal) -> Color {
        switch signal {
        case .excellent: VelvetTheme.connectedTint
        case .good: VelvetTheme.warningTint
        case .fair: VelvetTheme.errorTint
        }
    }

    private func signalLevel(_ signal: VPNLocation.Signal) -> Double {
        switch signal {
        case .excellent: 1
        case .good: 0.67
        case .fair: 0.34
        }
    }

    private var results: [VPNLocation] {
        VPNLocation.matching(query)
    }

    private var listSectionTitle: String {
        query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "All locations"
            : "Search results"
    }

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected:
            "Connect"
        case .connecting:
            "Connecting…"
        case .connected:
            "Connected"
        case .failed:
            "Retry"
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

    private func selectLocation(_ location: VPNLocation) {
        selectedLocation = location
        searchIsFocused = false

        withAnimation(VelvetMotion.panel(reduceMotion: reduceMotion)) {
            position = .island
        }
    }

    private func handleConnectionTap() {
        withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
            connectionState.handlePrimaryAction()
        }

        guard connectionState == .connecting else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(VelvetMotion.connectionState(reduceMotion: reduceMotion)) {
                connectionState.completeConnection()
            }
        }
    }
}
