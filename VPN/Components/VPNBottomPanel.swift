import SwiftUI

enum VPNPanelPresentation {
    static let island = PresentationDetent.height(154)
    static let intermediate = PresentationDetent.fraction(0.56)
}

struct VPNBottomPanel: View {
    @Binding var position: BottomPanelPosition
    @Binding var connectionState: VPNConnectionState
    @Binding var selectedLocation: VPNLocation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchIsFocused: Bool
    @AppStorage("velvet.favoriteLocations") private var storedFavouriteKeys = ""

    @State private var query = VPNLocationQuery()
    @State private var expandedCountries = Set<String>()
    @State private var favouritesExpanded = true
    @State private var showsDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
                .padding(.top, 8)

            // Both layers stay mounted and only cross-fade. Swapping them with
            // an `if` re-flows the panel while the detent is still animating,
            // which reads as the content stretching open.
            ZStack(alignment: .top) {
                connectionButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .opacity(showsLocations ? 0 : 1)
                    .allowsHitTesting(!showsLocations)
                    .animation(contentAnimation, value: showsLocations)

                locationsList
                    .opacity(showsLocations ? 1 : 0)
                    .allowsHitTesting(showsLocations)
                    .animation(contentAnimation, value: showsLocations)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
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

    private var showsLocations: Bool {
        position != .island
    }

    private var contentAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.22)
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

            Spacer(minLength: 4)

            moreMenu

            Button {
                movePanelFromHeader()
            } label: {
                headerIcon(position == .island ? "chevron.up" : "chevron.down")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleButtonStyle())
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
                if connectionState.isConnecting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: connectionState.isConnected ? "checkmark.shield.fill" : "power")
                }
                Text(connectionButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(connectionState.isConnected ? Color.green : VelvetTheme.accent)
        .disabled(connectionState.isConnecting)
        .accessibilityHint(
            connectionState.isConnected
                ? "Disconnects the demo VPN"
                : "Connects the demo VPN"
        )
    }

    private var locationsList: some View {
        List {
            searchRow
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if !query.isDefault {
                activeFilterChips
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            favouritesSection

            if results.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                recommendedSection
                countriesSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        .textCase(nil)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.defaultMinListRowHeight, 44)
        .animation(.easeOut(duration: 0.2), value: query)
    }

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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
    }

    @ViewBuilder
    private var favouritesSection: some View {
        Section {
            if favouritesExpanded {
                if favouriteLocations.isEmpty {
                    emptyFavourites
                } else {
                    favouriteStrip
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    favouritesExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Favourites")
                        .textCase(nil)
                    Text("\(favouriteLocations.count)")
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .textCase(nil)
                    Spacer()
                    Image(systemName: favouritesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(
                favouritesExpanded ? "Collapse favourites" : "Expand favourites"
            )
        }
        .textCase(nil)
    }

    private var emptyFavourites: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                Button {
                    searchIsFocused = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, height: 38)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Find a server to add")
            }

            Spacer()

            Text("Swipe a server\nto add")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.trailing)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var favouriteStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(favouriteLocations) { location in
                    Button {
                        selectLocation(location)
                    } label: {
                        VStack(spacing: 4) {
                            Text(location.flag)
                                .font(.title2)
                                .frame(width: 42, height: 42)
                                .background(Color(.tertiarySystemFill), in: Circle())

                            Text(location.city)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            toggleFavourite(location)
                        } label: {
                            Label("Remove from Favourites", systemImage: "star.slash")
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var recommendedSection: some View {
        let smartResults = results.filter { $0.kind == .smart }

        if !smartResults.isEmpty {
            Section {
                ForEach(smartResults) { location in
                    Button {
                        selectLocation(location)
                    } label: {
                        smartLocationRow(location)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Recommended")
                        .textCase(nil)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var countriesSection: some View {
        let groups = VPNLocation.countryGroups(from: results)

        if !groups.isEmpty {
            Section {
                ForEach(groups) { group in
                    if group.locations.count > 1 {
                        DisclosureGroup(
                            isExpanded: countryExpansionBinding(for: group.name)
                        ) {
                            ForEach(group.locations) { location in
                                favouriteLocationButton(location) {
                                    serverLocationRow(location)
                                }
                            }
                        } label: {
                            countryRow(group)
                        }
                    } else if let location = group.locations.first {
                        favouriteLocationButton(location) {
                            singleLocationRow(location)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(listSectionTitle)
                        .textCase(nil)
                    Spacer()
                    Text("\(groups.count)")
                        .monospacedDigit()
                        .textCase(nil)
                }
            }
        }
    }

    private func favouriteLocationButton<Content: View>(
        _ location: VPNLocation,
        @ViewBuilder label: () -> Content
    ) -> some View {
        Button {
            selectLocation(location)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                toggleFavourite(location)
            } label: {
                Label(
                    isFavourite(location) ? "Remove Favourite" : "Add Favourite",
                    systemImage: isFavourite(location) ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
        .contextMenu {
            Button {
                toggleFavourite(location)
            } label: {
                Label(
                    isFavourite(location) ? "Remove from Favourites" : "Add to Favourites",
                    systemImage: isFavourite(location) ? "star.slash" : "star"
                )
            }
        }
    }

    private func smartLocationRow(_ location: VPNLocation) -> some View {
        HStack(spacing: 12) {
            Text(location.flag)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .foregroundStyle(.primary)
                Text(location.city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            trailingAccessory(for: location)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selectedLocation.id == location.id ? [.isSelected] : [])
    }

    private func countryRow(_ group: VPNCountryGroup) -> some View {
        HStack(spacing: 12) {
            Text(group.flag)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(group.name)
                        .foregroundStyle(.primary)
                    if group.locations.contains(where: isFavourite) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                if let selected = group.locations.first(where: { $0.id == selectedLocation.id }) {
                    Text(selected.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(group.locations.count) locations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(group.locations.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .contentShape(Rectangle())
    }

    private func singleLocationRow(_ location: VPNLocation) -> some View {
        HStack(spacing: 12) {
            Text(location.flag)
                .font(.title3)
                .frame(width: 30)

            locationLabels(location, title: location.name)

            Spacer()
            trailingAccessory(for: location)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), \(location.subtitle), \(location.ping) milliseconds")
        .accessibilityAddTraits(selectedLocation.id == location.id ? [.isSelected] : [])
    }

    private func serverLocationRow(_ location: VPNLocation) -> some View {
        HStack(spacing: 12) {
            locationLabels(location, title: location.city)

            Spacer()
            trailingAccessory(for: location)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), \(location.subtitle), \(location.ping) milliseconds")
        .accessibilityAddTraits(selectedLocation.id == location.id ? [.isSelected] : [])
    }

    private func locationLabels(_ location: VPNLocation, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(title)
                    .foregroundStyle(.primary)
                if isFavourite(location) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            Text(location.kind.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func trailingAccessory(for location: VPNLocation) -> some View {
        if selectedLocation.id == location.id {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(VelvetTheme.accent)
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "cellularbars", variableValue: signalLevel(location.signal))
                .font(.subheadline)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(signalColor(location.signal))
                .frame(width: 24, height: 24)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No servers found",
            systemImage: "magnifyingglass",
            description: Text("Try another country or reset the filters.")
        )
    }

    private var results: [VPNLocation] {
        VPNLocation.matching(query)
    }

    private var listSectionTitle: String {
        query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "All countries"
            : "Search results"
    }

    private var favouriteKeys: Set<String> {
        Set(storedFavouriteKeys.split(separator: "\n").map(String.init))
    }

    private var favouriteLocations: [VPNLocation] {
        VPNLocation.samples.filter {
            $0.kind != .smart && favouriteKeys.contains($0.persistenceKey)
        }
    }

    private func isFavourite(_ location: VPNLocation) -> Bool {
        favouriteKeys.contains(location.persistenceKey)
    }

    private func toggleFavourite(_ location: VPNLocation) {
        var keys = favouriteKeys
        if !keys.insert(location.persistenceKey).inserted {
            keys.remove(location.persistenceKey)
        }
        storedFavouriteKeys = keys.sorted().joined(separator: "\n")
    }

    private func countryExpansionBinding(for country: String) -> Binding<Bool> {
        Binding(
            get: { expandedCountries.contains(country) },
            set: { isExpanded in
                if isExpanded {
                    expandedCountries.insert(country)
                } else {
                    expandedCountries.remove(country)
                }
            }
        )
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

    private var connectionButtonTitle: String {
        switch connectionState {
        case .disconnected: "Connect"
        case .connecting: "Finding route…"
        case .connected: "Connected"
        }
    }

    private func movePanelFromHeader() {
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(response: 0.42, dampingFraction: 0.86)
        ) {
            position = position == .island ? .intermediate : position.nextLower
        }
    }

    private func selectLocation(_ location: VPNLocation) {
        selectedLocation = location
        searchIsFocused = false

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            position = .island
        }
    }

    private let orchestrator = RouteOrchestrator()

    private func handleConnectionTap() {
        withAnimation(.easeOut(duration: 0.18)) {
            connectionState.handlePrimaryAction()
        }

        guard connectionState.isConnecting else { return }

        let target: ConnectionTarget = selectedLocation.isSmart
            ? .smart
            : .location(selectedLocation)

        Task { @MainActor in
            do {
                let result = try await orchestrator.race(for: target) { progress in
                    connectionState.updateRaceProgress(progress)
                }

                withAnimation(.easeOut(duration: 0.2)) {
                    connectionState.completeConnection(
                        route: result.winner,
                        alternates: result.alternates
                    )
                }
            } catch {
                connectionState = .disconnected
            }
        }
    }
}
