import SwiftUI

/// The hand-built floating island: it keeps its own drag gesture and height
/// interpolation, so it can sit inset from the screen edges the way a system
/// sheet never can. Scrolling stays inside the location list.
struct VPNIslandPanel: View {
    @Binding var position: BottomPanelPosition
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation
    let safeAreaBottom: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @GestureState private var dragTranslation: CGFloat = 0
    @FocusState private var searchIsFocused: Bool
    @State private var query = VPNLocationQuery()
    @State private var showsDeleteConfirmation = false

    var body: some View {
        GeometryReader { proxy in
            let detents = BottomPanelDetents.makeIsland(
                screenHeight: proxy.size.height,
                safeAreaBottom: safeAreaBottom,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let layout = BottomPanelInterpolator.layout(
                detents: detents,
                position: position,
                dragTranslation: dragTranslation
            )

            VStack(spacing: 0) {
                panelChrome
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .gesture(
                        panelDragGesture(detents: detents),
                        including: position == .island ? .subviews : .all
                    )

                ZStack(alignment: .top) {
                    connectionButton
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .opacity(layout.collapsedContentOpacity)
                        .offset(y: 18 * layout.expansionProgress)
                        .allowsHitTesting(layout.collapsedContentOpacity > 0.5)

                    expandedContent(detents: detents, progress: layout.listProgress)
                        .opacity(layout.listProgress)
                        .offset(y: 28 * (1 - layout.listProgress))
                        .allowsHitTesting(layout.listProgress > 0.5)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: layout.panelHeight, alignment: .top)
            .background {
                if reduceTransparency {
                    Color(.systemBackground)
                } else {
                    Rectangle().fill(.ultraThickMaterial)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: VelvetTheme.panelRadius,
                    bottomLeadingRadius: layout.bottomCornerRadius,
                    bottomTrailingRadius: layout.bottomCornerRadius,
                    topTrailingRadius: VelvetTheme.panelRadius
                )
            )
            .shadow(
                color: .black.opacity(layout.shadowOpacity),
                radius: layout.shadowRadius,
                y: layout.shadowY
            )
            .padding(.horizontal, layout.horizontalInset)
            .padding(.bottom, layout.bottomInset)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .simultaneousGesture(
                panelDragGesture(detents: detents),
                including: position == .island ? .all : .subviews
            )
            .animation(panelAnimation, value: position)
        }
        .sensoryFeedback(.selection, trigger: position)
        .onChange(of: position) { _, newValue in
            guard newValue == .island else { return }
            searchIsFocused = false
            query.text = ""
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

    private var panelChrome: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 8)
                .padding(.bottom, 6)

            panelHeader
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.42))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
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

            moreMenu
                .fixedSize()

            Button {
                togglePosition()
            } label: {
                headerIcon(position == .island ? "chevron.up" : "chevron.down")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleButtonStyle())
            .fixedSize()
            .accessibilityLabel(position == .island ? "Expand panel" : "Collapse panel")
        }
        .padding(.horizontal, 16)
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
            headerIcon("ellipsis")
        }
        .accessibilityLabel("More options")
    }

    private func headerIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(Color(.tertiarySystemFill), in: Circle())
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
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(connectionState == .connected ? Color.green : VelvetTheme.accent)
        .disabled(connectionState == .connecting)
        .accessibilityHint(
            connectionState == .connected
                ? "Disconnects the demo VPN"
                : "Connects the demo VPN"
        )
    }

    private func expandedContent(detents: BottomPanelDetents, progress: CGFloat) -> some View {
        VStack(spacing: 10) {
            searchRow

            if !query.isDefault {
                activeFilterChips
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView {
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
                                progress: progress
                            )
                        }

                        if !otherResults.isEmpty {
                            locationSection(
                                title: listSectionTitle,
                                locations: otherResults,
                                startIndex: smartResults.count,
                                progress: progress
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, detents.contentBottomInset)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 12)
        .animation(.easeOut(duration: 0.2), value: query)
    }

    /// Search and filtering share a single row: the field stretches, and every
    /// secondary control lives behind the trailing menu so the default state
    /// spends no vertical space on chrome.
    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Country, city or type", text: $query.text)
                    .focused($searchIsFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !query.text.isEmpty {
                    Button {
                        query.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.tertiarySystemFill), in: Capsule())

            filterMenu
        }
        .padding(.horizontal, 16)
    }

    private var filterMenu: some View {
        Menu {
            Section("Server type") {
                Picker("Server type", selection: $query.filter) {
                    ForEach(VPNLocationFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Sort by") {
                Picker("Sort by", selection: $query.sort) {
                    ForEach(VPNLocationSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Toggle(isOn: $query.fastOnly) {
                    Label("Under \(VPNLocation.fastPingThreshold) ms", systemImage: "bolt.fill")
                }

                if !query.isDefault {
                    Button(role: .destructive) {
                        query.resetFilters()
                    } label: {
                        Label("Reset filters", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(query.isDefault ? Color.primary : Color.white)
                .frame(width: 36, height: 36)
                .background(
                    query.isDefault ? Color(.tertiarySystemFill) : VelvetTheme.accent,
                    in: Circle()
                )
        }
        .accessibilityLabel("Filter and sort servers")
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
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
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
        progress: CGFloat
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
                    let appearance = rowProgress(progress, index: startIndex + offset)

                    Button {
                        selectLocation(location)
                    } label: {
                        locationRow(location)
                    }
                    .buttonStyle(.plain)
                    .opacity(appearance)
                    .offset(y: 20 * (1 - appearance))

                    if offset < locations.count - 1 {
                        Divider()
                            .padding(.leading, 58)
                            .opacity(appearance)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), \(location.subtitle), \(location.ping) milliseconds")
        .accessibilityAddTraits(selectedLocation.id == location.id ? [.isSelected] : [])
    }

    private func signalColor(_ signal: VPNLocation.Signal) -> Color {
        switch signal {
        case .excellent: .green
        case .good: .yellow
        case .fair: .red
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
        }
    }

    private func panelDragGesture(detents: BottomPanelDetents) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let target = BottomPanelSnapResolver.resolve(
                    current: position,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height,
                    detents: detents
                )
                withAnimation(panelAnimation) {
                    position = target
                }
            }
    }

    private var panelAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.12)
    }

    private func togglePosition() {
        withAnimation(panelAnimation) {
            position = position == .island ? .expanded : .island
        }
    }

    private func selectLocation(_ location: VPNLocation) {
        selectedLocation = location
        searchIsFocused = false

        withAnimation(panelAnimation) {
            position = .island
        }
    }

    /// Staggers rows so they fade and slide in as the sheet is pulled open.
    /// The delay stops accumulating past the first screenful, otherwise the
    /// lower rows would never finish their transition.
    private func rowProgress(_ progress: CGFloat, index: Int) -> CGFloat {
        let delay = CGFloat(min(index, 7)) * 0.05
        let start = 0.08 + delay
        let end = min(start + 0.5, 1)
        let value = min(max((progress - start) / max(end - start, 0.001), 0), 1)
        return value * value * (3 - 2 * value)
    }

    private func handleConnectionTap() {
        withAnimation(.easeOut(duration: 0.18)) {
            connectionState.handlePrimaryAction()
        }

        guard connectionState == .connecting else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.2)) {
                connectionState.completeConnection()
            }
        }
    }
}
