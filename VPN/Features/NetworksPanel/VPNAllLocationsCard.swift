import SwiftUI

struct VPNAllLocationsCard: View {
    @Bindable var providerStore: VPNProviderStore
    @Binding var locationSelection: VPNLocationSelection
    @Binding var selectionSource: VPNSelectionSource
    @Binding var query: VPNLocationQuery
    var pingResults: [String: Int] = [:]
    var pingingIDs: Set<String> = []

    let isDraggingPanel: Bool
    let onSmartLocation: (VPNUserJob) -> Void
    let onManualLocation: (VPNNetworkLocation) -> Void

    @State private var expandedGroupIDs: Set<String> = []

    private var providers: [VPNProvider] { providerStore.providers }
    private var scope: VPNProviderScope { providerStore.providerScope }

    private var filteredCountryGroups: [VPNCountryLocationGroup] {
        VPNConnectionPlanner.filteredCountryGroups(from: providers, scope: scope, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !query.isDefault && !isDraggingPanel {
                activeFilterChips
                Divider().padding(.leading, 16)
            }

            if filteredCountryGroups.isEmpty {
                emptyFilterState
            } else {
                ForEach(Array(filteredCountryGroups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    countryRow(group)
                }
            }
        }
        .padding(.vertical, 4)
        .background(VelvetTheme.contentSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func countryRow(_ group: VPNCountryLocationGroup) -> some View {
        let smartLocation = VPNLocationJobCatalog.smartLocation(for: group.name)
        let isExpanded = expandedGroupIDs.contains(group.id)
        let isExpandable = isCountryGroupExpandable(group, smartLocation: smartLocation)

        return VStack(spacing: 0) {
            Button {
                if isExpandable {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleGroupExpansion(group.id)
                    }
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
            .buttonStyle(.plain)

            if isExpanded {
                if let smartLocation {
                    Divider().padding(.leading, 58)
                    smartLocationRow(smartLocation, country: group.name)
                }

                ForEach(group.candidates) { candidate in
                    Divider().padding(.leading, 58)
                    Button {
                        onManualLocation(candidate)
                    } label: {
                        candidateRow(candidate)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func smartLocationRow(_ smartLocation: VPNSmartCountryLocation, country: String) -> some View {
        let selection = smartLocation.selection(scope: scope)
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

    private func candidateRow(_ candidate: VPNNetworkLocation) -> some View {
        VPNInsetRow(
            title: "\(candidate.location.city) · \(candidate.provider.name)",
            subtitle: candidateSubtitle(candidate),
            pingLabel: pingLabel(for: candidate),
            isPinging: pingingIDs.contains(candidate.id),
            signal: candidate.location.signal,
            isSelected: isCandidateSelected(candidate)
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
                return job == smartLocation.job && selectedScope == scope
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
        Text("No locations match your search or filters.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
    }

    private func toggleGroupExpansion(_ id: String) {
        if expandedGroupIDs.contains(id) {
            expandedGroupIDs.remove(id)
        } else {
            expandedGroupIDs.insert(id)
        }
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
                        .foregroundStyle(VelvetTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VelvetTheme.accent.opacity(0.14), in: Capsule())
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
