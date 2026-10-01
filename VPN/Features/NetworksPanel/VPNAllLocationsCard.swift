import SwiftUI

struct VPNAllLocationsCard: View {
    @Bindable var providerStore: VPNProviderStore
    @Binding var locationSelection: VPNLocationSelection
    @Binding var selectionSource: VPNSelectionSource
    @Binding var query: VPNLocationQuery
    var pingResults: [String: Int] = [:]
    var pingingIDs: Set<String> = []
    var hidesForLoading: Bool = false
    var staggerIndexOffset: Int = 0
    var reduceMotion: Bool = false
    var panelRevealProgress: CGFloat = 1
    var panelStaggerIndexOffset: Int = 0

    var favouriteIDs: Set<String> = []
    /// The island keeps the white plate. A locations page can sit the rows on the page instead.
    var showsPlate = true
    /// Each group sits on its own white card. The page title above the list can go.
    var groupsAsPlates = false
    /// Group names read as headlines when the list is the page, not a caption inside a card.
    var prominentSectionHeaders = false
    let onSmartLocation: (VPNUserJob) -> Void
    let onManualLocation: (VPNNetworkLocation) -> Void
    var onToggleFavourite: (VPNNetworkLocation) -> Void = { _ in }

    @State private var expandedGroupIDs: Set<String> = []
    @State private var collapsedSectionIDs: Set<String> = []

    @Environment(\.panelScrollViewHandle) private var panelScrollViewHandle

    private var providers: [VPNProvider] { providerStore.providers }
    /// The list follows the catalog scope: one subscription, or every location.
    private var locationCatalogScope: VPNProviderScope {
        providerStore.providerScope
    }

    private var smartSelectionScope: VPNProviderScope {
        providerStore.providerScope
    }

    private var locationSections: [VPNLocationListSection] {
        VPNConnectionPlanner.filteredLocationSections(from: providers, scope: locationCatalogScope, query: query)
    }

    private var hasLocationRows: Bool {
        locationSections.contains { !$0.groups.isEmpty }
    }

    var body: some View {
        VStack(spacing: groupsAsPlates ? 12 : 0) {
            if !query.isDefault {
                activeFilterChips
                    .velvetPanelRowReveal(
                        progress: panelRevealProgress,
                        index: max(panelStaggerIndexOffset - 1, 0),
                        reduceMotion: reduceMotion
                    )
                Divider().padding(.leading, 16)
            }

            if !hasLocationRows {
                emptyFilterState
                    .velvetPanelRowReveal(
                        progress: panelRevealProgress,
                        index: panelStaggerIndexOffset,
                        reduceMotion: reduceMotion
                    )
            } else {
                locationSectionStack
                    .transaction(value: collapsedSectionIDs) { $0.animation = nil }
                    .transaction(value: expandedGroupIDs) { $0.animation = nil }
            }
        }
        .padding(.vertical, showsPlate ? 12 : 4)
        .background {
            if showsPlate {
                RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous)
                    .fill(VelvetTheme.contentSurface)
                    .velvetPanelRowReveal(
                        progress: panelRevealProgress,
                        index: max(panelStaggerIndexOffset - 1, 0),
                        reduceMotion: reduceMotion
                    )
            }
        }
        .velvetLoadingShimmer(
            isActive: hidesForLoading,
            reduceMotion: reduceMotion,
            index: staggerIndexOffset
        )
    }

    private var locationSectionStack: some View {
        let enumerated = Array(locationSections.enumerated())
        return ForEach(enumerated, id: \.element.id) { sectionIndex, section in
            let staggerBase = panelStaggerIndexOffset + enumerated.prefix(sectionIndex).reduce(0) {
                $0 + ($1.element.title == nil ? 0 : 1) + $1.element.groups.count
            }

            VStack(spacing: 0) {
                if let title = section.title {
                    let isSectionExpanded = !collapsedSectionIDs.contains(section.id)
                    Button {
                        toggleSectionExpansion(section.id)
                    } label: {
                        VPNPanelSectionHeader(
                            title: title,
                            explanation: section.explanation,
                            showsDisclosure: true,
                            isDisclosureExpanded: isSectionExpanded,
                            isProminent: prominentSectionHeaders
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, VelvetMetrics.panelSectionHeaderSpacing)
                    .overlay(alignment: .topLeading) {
                        PanelScrollAnchor(name: section.id)
                            .frame(width: 1, height: 1)
                            .allowsHitTesting(false)
                    }
                    .velvetPanelRowReveal(
                        progress: panelRevealProgress,
                        index: staggerBase,
                        reduceMotion: reduceMotion
                    )
                }

                let isSectionExpanded = section.title == nil || !collapsedSectionIDs.contains(section.id)
                VStack(spacing: 0) {
                    ForEach(Array(section.groups.enumerated()), id: \.element.id) { index, group in
                        VStack(spacing: 0) {
                            if index > 0 || (section.title == nil && sectionIndex > 0) {
                                Divider().padding(.leading, VelvetMetrics.nestedDividerInset)
                            }
                            countryRow(group)
                        }
                        .velvetPanelRowReveal(
                            progress: panelRevealProgress,
                            index: staggerBase + (section.title == nil ? 0 : 1) + index,
                            reduceMotion: reduceMotion
                        )
                    }
                }
                .frame(height: isSectionExpanded ? nil : 0, alignment: .top)
                .clipped()
                .opacity(isSectionExpanded ? 1 : 0)
                .allowsHitTesting(isSectionExpanded)
                .accessibilityHidden(!isSectionExpanded)
            }
            .padding(.bottom, groupsAsPlates ? 4 : 0)
            .background {
                if groupsAsPlates {
                    RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous)
                        .fill(VelvetTheme.contentSurface)
                }
            }
            .animation(nil, value: collapsedSectionIDs.contains(section.id))
        }
    }

    private func countryRow(_ group: VPNCountryLocationGroup) -> some View {
        let smartLocation = group.family == .country
            ? VPNLocationJobCatalog.smartLocation(for: group.name)
            : nil
        let isExpanded = expandedGroupIDs.contains(group.id)
        let isExpandable = isCountryGroupExpandable(group, smartLocation: smartLocation)

        let favouriteTarget = isExpandable ? nil : group.candidates.first

        return VStack(spacing: 0) {
            tappableLocationRow(favourite: favouriteTarget) {
                if isExpandable {
                    toggleGroupExpansion(group.id)
                } else if let only = group.candidates.first {
                    onManualLocation(only)
                }
            } label: {
                VPNInsetRow(
                    flag: group.flag,
                    title: group.name,
                    subtitle: VPNLocationRowCopy.countryGroup(group),
                    pingLabel: pingLabel(for: group),
                    isPinging: isGroupPinging(group, smartLocation: smartLocation),
                    signal: signalForGroup(group),
                    showsChevron: isExpandable,
                    isDisclosureExpanded: isExpanded,
                    isSelected: isCountryGroupHeaderSelected(group, smartLocation: smartLocation)
                )
            }
            .overlay(alignment: .topLeading) {
                PanelScrollAnchor(name: Self.groupAnchorName(group.id))
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
            }

            if isExpandable {
                expandedGroupContent(group, smartLocation: smartLocation)
                    .frame(height: isExpanded ? nil : 0, alignment: .top)
                    .clipped()
                    .opacity(isExpanded ? 1 : 0)
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)
            }
        }
        .animation(nil, value: isExpanded)
    }

    @ViewBuilder
    private func expandedGroupContent(
        _ group: VPNCountryLocationGroup,
        smartLocation: VPNSmartCountryLocation?
    ) -> some View {
        if let smartLocation {
            Divider().padding(.leading, VelvetMetrics.nestedDividerInset)
            smartLocationRow(smartLocation, country: group.name)
        }

        ForEach(group.candidates) { candidate in
            Divider().padding(.leading, VelvetMetrics.nestedDividerInset)
            tappableLocationRow(favourite: candidate) {
                onManualLocation(candidate)
            } label: {
                candidateRow(candidate)
            }
        }
    }

    private func smartLocationRow(_ smartLocation: VPNSmartCountryLocation, country: String) -> some View {
        let selection = smartLocation.selection(scope: smartSelectionScope)
        let pingID = smartLocation.pingID(for: country)

        return Button {
            onSmartLocation(smartLocation.job)
        } label: {
            VPNInsetRow(
                iconSymbol: smartLocation.iconSymbol,
                title: smartLocation.title,
                subtitle: smartLocation.subtitle,
                pingLabel: pingResults[pingID].map { "\($0) ms" },
                isPinging: pingingIDs.contains(pingID),
                signal: VPNConnectionPlanner.signalForSelection(selection, providers: providers),
                isSelected: isSmartLocationSelected(smartLocation, country: country),
                accentIcon: true
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func candidateRow(_ candidate: VPNNetworkLocation) -> some View {
        if candidate.location.listIdentity.family.isCatalogFamily {
            let copy = VPNLocationRowCopy.catalogNestedRow(candidate)
            VPNInsetRow(
                title: copy.title,
                subtitle: catalogRowSubtitle(copy.subtitle, provider: candidate.provider),
                pingLabel: pingLabel(for: candidate),
                isPinging: pingingIDs.contains(candidate.id),
                signal: candidate.location.signal,
                isSelected: isCandidateSelected(candidate)
            )
        } else {
            VPNInsetRow(
                title: "\(candidate.location.city) · \(candidate.provider.catalogDisplayName)",
                subtitle: candidateSubtitle(candidate),
                pingLabel: pingLabel(for: candidate),
                isPinging: pingingIDs.contains(candidate.id),
                signal: candidate.location.signal,
                isSelected: isCandidateSelected(candidate)
            )
        }
    }

    private func catalogRowSubtitle(_ subtitle: String, provider: VPNProvider) -> String {
        guard case .allNetworks = locationCatalogScope, providers.count > 1 else {
            return subtitle
        }
        return "\(subtitle) · \(provider.catalogDisplayName)"
    }

    private func tappableLocationRow<Label: View>(
        favourite: VPNNetworkLocation?,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if let favourite {
                favouriteToggle(favourite)
                    .padding(.trailing, 6)
            }
        }
    }

    private func favouriteToggle(_ location: VPNNetworkLocation) -> some View {
        let saved = isFavourite(location)
        return Button {
            onToggleFavourite(location)
        } label: {
            Image(systemName: saved ? "star.fill" : "star")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved ? "Remove from Favourites" : "Add to Favourites")
    }

    private func isFavourite(_ location: VPNNetworkLocation) -> Bool {
        favouriteIDs.contains(
            VPNFavouriteLocationEntry.id(
                providerID: location.provider.id,
                persistenceKey: location.location.persistenceKey
            )
        )
    }

    private func candidateSubtitle(_ candidate: VPNNetworkLocation) -> String {
        if let hint = candidate.optimizationHint {
            return hint
        }
        if pingResults[candidate.id] != nil {
            return candidate.location.kind.title
        }
        return "\(candidate.location.kind.title) · \(candidate.location.ping) ms"
    }

    private func isCountryGroupExpandable(
        _ group: VPNCountryLocationGroup,
        smartLocation: VPNSmartCountryLocation?
    ) -> Bool {
        group.candidates.count > 1 || smartLocation != nil
    }

    private func isCountryGroupHeaderSelected(
        _ group: VPNCountryLocationGroup,
        smartLocation: VPNSmartCountryLocation?
    ) -> Bool {
        guard case .location = selectionSource else { return false }

        if group.candidates.count == 1,
           smartLocation == nil,
           let only = group.candidates.first {
            return isCandidateSelected(only)
        }

        return false
    }

    private func isSmartLocationSelected(_ smartLocation: VPNSmartCountryLocation, country: String) -> Bool {
        selectionSource.isLocationActive { selection in
            if case let .smartJob(job, selectedScope) = selection {
                return job == smartLocation.job && selectedScope == smartSelectionScope
            }
            return false
        }
    }

    private func isGroupPinging(
        _ group: VPNCountryLocationGroup,
        smartLocation: VPNSmartCountryLocation?
    ) -> Bool {
        guard pingLabel(for: group) == nil else { return false }
        if let smartLocation, pingingIDs.contains(smartLocation.pingID(for: group.name)) {
            return true
        }
        return group.candidates.contains { pingingIDs.contains($0.id) }
    }

    private var emptyFilterState: some View {
        Text(ui("No locations match your search or filters."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
    }

    private func toggleSectionExpansion(_ id: String) {
        panelScrollViewHandle.preserveAnchor(id)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if collapsedSectionIDs.contains(id) {
                collapsedSectionIDs.remove(id)
            } else {
                collapsedSectionIDs.insert(id)
            }
        }
    }

    private func toggleGroupExpansion(_ id: String) {
        panelScrollViewHandle.preserveAnchor(Self.groupAnchorName(id))
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if expandedGroupIDs.contains(id) {
                expandedGroupIDs.remove(id)
            } else {
                expandedGroupIDs.insert(id)
            }
        }
    }

    private static func groupAnchorName(_ id: String) -> String {
        "group:\(id)"
    }

    private func pingLabel(for candidate: VPNNetworkLocation) -> String? {
        pingResults[candidate.id].map { "\($0) ms" }
    }

    private func pingLabel(for group: VPNCountryLocationGroup) -> String? {
        let pings = group.candidates.compactMap { pingResults[$0.id] }
        guard let best = pings.min() else { return nil }
        return "\(best) ms"
    }

    private func signalForGroup(_ group: VPNCountryLocationGroup) -> VPNLocation.Signal? {
        group.candidates.min(by: { $0.location.ping < $1.location.ping })?.location.signal
    }

    private func isCandidateSelected(_ candidate: VPNNetworkLocation) -> Bool {
        selectionSource.isLocationActive { selection in
            if case let .manual(location, providerID) = selection {
                return location.persistenceKey == candidate.location.persistenceKey
                    && providerID == candidate.provider.id
            }
            return false
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
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}
