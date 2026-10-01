import Foundation

enum VPNHomeFormat: String, CaseIterable, Identifiable, Codable {
    case classic
    case networksAndLocations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: ui("Single provider")
        case .networksAndLocations: ui("Networks & locations")
        }
    }
}

struct VPNProvider: Identifiable, Equatable, Codable {
    enum Status: Equatable, Codable {
        case active(locationCount: Int, trafficRemaining: String)
        case expired

        var isActive: Bool {
            if case .active = self { true } else { false }
        }
    }

    enum Kind: Equatable, Codable {
        case velvetFeatured
        case imported
    }

    let id: UUID
    var name: String
    let iconSymbol: String
    let kind: Kind
    var status: Status
    let servers: [VPNLocation]
    var subscriptionURL: String?
    var lastUpdated: Date?
    var expiresAt: Date?
    var includedInSmartAuto: Bool
    var providerMessage: String?
    var providerMessageUpdatedAt: Date?

    var isEligibleForAutoConnect: Bool {
        includedInSmartAuto && status.isActive
    }

    /// Smart, Stream, and Gaming belong to Velvet subscriptions only.
    var includesPresets: Bool {
        status.isActive && (kind == .velvetFeatured || name.contains("Velvet"))
    }

    var hasProviderMessage: Bool {
        displayedProviderMessage != nil
    }

    /// Rich multi-line announcements shown in the expanded stats area.
    /// Short traffic summaries belong in list subtitles only.
    var showsDetailMessage: Bool {
        guard let displayedProviderMessage else { return false }
        return displayedProviderMessage.contains("\n") || displayedProviderMessage.count > 80
    }

    /// Provider announcement without the trailing account ID / last-updated line.
    var displayedProviderMessage: String? {
        guard let providerMessage else { return nil }
        let stripped = Self.strippingIdentityFooter(from: providerMessage)
        return stripped.isEmpty ? nil : stripped
    }

    static func strippingIdentityFooter(from message: String) -> String {
        var lines = message.components(separatedBy: "\n")
        while let last = lines.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                lines.removeLast()
                continue
            }
            if isIdentityFooterLine(trimmed) {
                lines.removeLast()
            }
            break
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isIdentityFooterLine(_ line: String) -> Bool {
        line.contains("🆔") || (line.contains("⏱️") && line.contains("МСК"))
    }

    var subtitle: String {
        switch status {
        case let .active(locationCount, trafficRemaining):
            if let expiryLabel {
                uiFormat("%lld locations · %@ · %@", locationCount, uiTraffic(trafficRemaining), expiryLabel)
            } else {
                uiFormat("%lld locations · %@", locationCount, uiTraffic(trafficRemaining))
            }
        case .expired:
            ui("Subscription expired")
        }
    }

    var expiryLabel: String? {
        guard let expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        if days < 0 { return ui("Expired") }
        if days == 0 { return ui("Expires today") }
        if days <= 7 { return uiFormat("Expires in %lld days", days) }
        return nil
    }

    var renewURL: String {
        subscriptionURL ?? "https://velvet.vpn/renew"
    }

    var maskedSubscriptionURL: String {
        guard let subscriptionURL, !subscriptionURL.isEmpty else { return ui("Not set") }
        guard subscriptionURL.count > 24 else { return subscriptionURL }
        let prefix = subscriptionURL.prefix(18)
        return "\(prefix)…"
    }

    var smartAutoBadge: String? {
        guard status.isActive else { return nil }
        return includedInSmartAuto ? ui("Included in Auto") : ui("Manual only")
    }

    /// Subtitle for the expanded panel header, e.g. "120 GB left, 28 days left".
    var panelHeaderSubtitle: String {
        switch status {
        case .expired:
            ui("Subscription expired")
        case let .active(_, trafficRemaining):
            if let daysRemainingLabel {
                "\(uiTraffic(trafficRemaining)), \(daysRemainingLabel)"
            } else {
                uiTraffic(trafficRemaining)
            }
        }
    }

    private var daysRemainingLabel: String? {
        guard let expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        if days < 0 { return ui("Expired") }
        if days == 0 { return ui("0 days left") }
        return uiFormat("%lld days left", days)
    }

    var needsRenewalWarning: Bool {
        guard status.isActive, let expiresAt else { return false }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        return days >= 0 && days <= 7
    }

    /// Expired or expiring soon — show the renewal card before Velvet upsell.
    var needsSubscriptionRenewal: Bool {
        if status == .expired { return true }
        return needsRenewalWarning
    }

    var usageSummaryLabel: String? {
        guard status.isActive else { return nil }
        switch status {
        case let .active(_, trafficRemaining):
            if let daysRemainingLabel {
                return "\(uiTraffic(trafficRemaining)), \(daysRemainingLabel)"
            }
            return uiTraffic(trafficRemaining)
        case .expired:
            return nil
        }
    }

    /// Secondary line in the multi-provider list: locations and traffic only.
    var networksListSubtitle: String {
        switch status {
        case let .active(locationCount, trafficRemaining):
            uiFormat("%lld locations · %@", locationCount, uiTraffic(trafficRemaining))
        case .expired:
            ui("Subscription expired")
        }
    }

    /// Name without the trailing account number, so the ID can sit on its own line.
    var catalogDisplayName: String {
        guard let subscriptionAccountID else { return name }
        let suffixes = [" — \(subscriptionAccountID)", " - \(subscriptionAccountID)", " \(subscriptionAccountID)"]
        for suffix in suffixes where name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name
    }

    /// Happ-style account number, e.g. `#34903`.
    var subscriptionAccountID: String? {
        guard let match = name.firstMatch(of: /#\d[\d-]*/) else { return nil }
        return String(match.0)
    }

    var lastUpdatedCaption: String? {
        guard let lastUpdated else { return nil }
        return Self.relativeCaption(for: lastUpdated)
    }

    /// ID and freshness on one line — same pattern as Mail accounts and App Store subscriptions.
    var subscriptionIdentityCaption: String {
        [subscriptionAccountID, lastUpdatedCaption]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private static func relativeCaption(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        if days <= 0 { return ui("Updated just now") }
        if days == 1 { return ui("Updated yesterday") }
        return uiFormat("Updated %lld days ago", days)
    }

    static func allSubscriptionsCaption(providers: [VPNProvider]) -> String {
        let count = providers.count
        let noun = uiFormat(count == 1 ? "%lld subscription" : "%lld subscriptions", count)
        let latest = providers.compactMap(\.lastUpdated).max()
        var parts = [noun]
        if let latest {
            parts.append(relativeCaption(for: latest))
        }
        return parts.joined(separator: " · ")
    }

    func tunnelStatusLabel(isConnected: Bool, activeProviderID: UUID?) -> String {
        switch status {
        case .expired:
            ui("Expired")
        case .active:
            if isConnected, activeProviderID == id {
                ui("Connected")
            } else {
                ui("Disconnected")
            }
        }
    }
}

enum VPNProviderAvailabilitySummary {
    static func subtitle(for providers: [VPNProvider]) -> String {
        let available = providers.filter(\.status.isActive).count
        let expired = providers.filter { $0.status == .expired }.count

        switch (available, expired) {
        case (0, let expired) where expired > 0:
            return uiFormat("%lld expired", expired)
        case (let available, 0):
            return uiFormat("%lld available", available)
        case (let available, let expired):
            return uiFormat("%lld available, %lld expired", available, expired)
        }
    }

    static func hasActiveVelvet(in providers: [VPNProvider]) -> Bool {
        providers.first(where: { $0.kind == .velvetFeatured })?.status.isActive == true
    }

    /// Purple stats shell — other VPN only, Velvet row not added yet (state 2).
    static func showsVelvetStatsPromo(for providers: [VPNProvider]) -> Bool {
        guard !hasActiveVelvet(in: providers) else { return false }
        guard !providers.contains(where: { $0.kind == .velvetFeatured }) else { return false }
        return providers.contains { $0.kind == .imported && $0.status.isActive }
    }

    /// Purple shell around an imported renewal card (state 6).
    static func showsVelvetRenewalPromoShell(for renewalProvider: VPNProvider) -> Bool {
        renewalProvider.kind == .imported && renewalProvider.needsSubscriptionRenewal
    }

    static func velvetNeedingRenewal(
        in providers: [VPNProvider],
        hiddenBannerIDs: Set<UUID> = []
    ) -> VPNProvider? {
        providers.first {
            $0.kind == .velvetFeatured && showsRenewalAttention(for: $0, hiddenBannerIDs: hiddenBannerIDs)
        }
    }

    static func showsRenewalAttention(
        for provider: VPNProvider,
        hiddenBannerIDs: Set<UUID> = []
    ) -> Bool {
        provider.needsSubscriptionRenewal && !hiddenBannerIDs.contains(provider.id)
    }

    static func anyNeedsRenewalAttention(
        in providers: [VPNProvider],
        hiddenBannerIDs: Set<UUID> = []
    ) -> Bool {
        providers.contains { showsRenewalAttention(for: $0, hiddenBannerIDs: hiddenBannerIDs) }
    }
}

enum VPNLocationSelection: Equatable, Codable {
    case smartAuto(scope: VPNProviderScope)
    case smartJob(VPNUserJob, scope: VPNProviderScope)
    case manual(location: VPNLocation, providerID: UUID)

    var scope: VPNProviderScope {
        switch self {
        case let .smartAuto(scope): scope
        case let .smartJob(_, scope): scope
        case .manual: .allNetworks
        }
    }
}

struct VPNResolvedConnection: Equatable {
    let location: VPNLocation
    let provider: VPNProvider
    let selection: VPNLocationSelection

    var summarySubtitle: String {
        let modeLabel = VPNSelectionSummary.selectionLabel(for: selection)
        return "\(modeLabel) · \(ui(location.city)) · \(location.pingLabel) · \(provider.name)"
    }
}

struct VPNNetworkLocation: Identifiable, Equatable {
    let location: VPNLocation
    let provider: VPNProvider

    var id: String { "\(provider.id.uuidString)-\(location.persistenceKey)" }
}

struct VPNPingResult: Identifiable, Equatable {
    let id: String
    let location: VPNLocation
    let provider: VPNProvider
    let ping: Int

    init(location: VPNLocation, provider: VPNProvider, ping: Int) {
        self.id = "\(provider.id.uuidString)-\(location.persistenceKey)"
        self.location = location
        self.provider = provider
        self.ping = ping
    }

    var signal: VPNLocation.Signal {
        location.signal
    }
}

struct VPNQualityDisplay: Equatable {
    enum Tone {
        case positive
        case caution
        case neutral
    }

    let label: String
    let tone: Tone

    init(label: String, tone: Tone) {
        self.label = label
        self.tone = tone
    }

    init(signal: VPNLocation.Signal) {
        switch signal {
        case .excellent:
            self.init(label: ui("Best"), tone: .positive)
        case .good:
            self.init(label: ui("Good"), tone: .positive)
        case .fair:
            self.init(label: ui("So so"), tone: .caution)
        }
    }
}

enum VPNSelectionSummary {
    static func selectionLabel(for selection: VPNLocationSelection) -> String {
        switch selection {
        case .smartAuto: ui("Smart-Auto")
        case let .smartJob(job, _): job.title
        case .manual: ui("Manual")
        }
    }

    static func scopeLabel(for scope: VPNProviderScope, providers: [VPNProvider]) -> String {
        switch scope {
        case .allNetworks: ui("All networks")
        case let .provider(id):
            providers.first(where: { $0.id == id })?.name ?? ui("One network")
        }
    }

    static func heroTitle(
        connectionState: VPNConnectionState,
        homeFormat: VPNHomeFormat,
        isSwitchingServer: Bool
    ) -> String {
        switch connectionState {
        case .connecting:
            if isSwitchingServer { return ui("Switching server…") }
            return homeFormat == .networksAndLocations ? ui("Finding best connection…") : ui("Connecting…")
        case .connected:
            return ui("Protected")
        case .failed:
            return ui("Couldn't connect")
        case .disconnected:
            return ui("Ready to connect")
        }
    }

    static func subtitle(
        selection: VPNLocationSelection,
        providers: [VPNProvider],
        connectionState: VPNConnectionState,
        resolvedConnection: VPNResolvedConnection?,
        homeFormat: VPNHomeFormat,
        selectedLocation: VPNLocation,
        isSwitchingServer: Bool = false
    ) -> String {
        if case let .failed(failure) = connectionState {
            return failure.displayMessage
        }

        if connectionState == .connecting {
            if homeFormat == .networksAndLocations {
                return isSwitchingServer ? ui("Applying new location…") : ui("Pinging all active providers")
            }
            return ui(selectedLocation.name)
        }

        if connectionState == .connected,
           let resolvedConnection,
           homeFormat == .networksAndLocations {
            return resolvedConnection.summarySubtitle
        }

        if homeFormat == .networksAndLocations {
            return disconnectedNetworksSubtitle(selection: selection, providers: providers)
        }

        return ui(selectedLocation.name)
    }

    static func collapsedSubtitle(
        selection: VPNLocationSelection,
        providers: [VPNProvider],
        connectionState: VPNConnectionState,
        resolvedConnection: VPNResolvedConnection?
    ) -> String? {
        if connectionState == .connected, let resolvedConnection {
            return resolvedConnection.summarySubtitle
        }

        if case .failed = connectionState {
            return ui("Last attempt failed · tap Retry")
        }

        let quality = VPNConnectionPlanner.qualityLabel(for: selection, providers: providers)

        switch selection {
        case let .smartAuto(scope):
            return "\(scopeLabel(for: scope, providers: providers)) · \(ui("Smart-Auto")) · \(quality)"
        case let .smartJob(job, scope):
            return "\(scopeLabel(for: scope, providers: providers)) · \(job.title) · \(quality)"
        case let .manual(location, _):
            return uiFormat("Manual · %@ · %@", ui(location.city), location.pingLabel)
        }
    }

    private static func disconnectedNetworksSubtitle(
        selection: VPNLocationSelection,
        providers: [VPNProvider]
    ) -> String {
        let quality = VPNConnectionPlanner.qualityLabel(for: selection, providers: providers)

        switch selection {
        case let .smartAuto(scope):
            return "\(quality) · \(ui("Smart-Auto")) · \(scopeLabel(for: scope, providers: providers))"
        case let .smartJob(job, scope):
            if job == .whitelistForeign {
                return "\(quality) · \(job.title) · \(ui("split routing"))"
            }
            return "\(quality) · \(job.title) · \(scopeLabel(for: scope, providers: providers))"
        case let .manual(location, providerID):
            let providerName = providers.first(where: { $0.id == providerID })?.name ?? ui("Network")
            return uiFormat("Manual · %@ · %@ · %@", ui(location.name), ui(location.city), providerName)
        }
    }
}

enum VPNConnectionPlanner {
    static func resolve(
        providers: [VPNProvider],
        selection: VPNLocationSelection
    ) -> VPNResolvedConnection? {
        switch selection {
        case let .manual(location, providerID):
            guard
                let provider = providers.first(where: { $0.id == providerID }),
                provider.isEligibleForAutoConnect
            else { return nil }
            return VPNResolvedConnection(location: location, provider: provider, selection: selection)

        case let .smartAuto(scope):
            let candidates = mergedLocations(from: scopedEligibleProviders(providers, scope: scope))
            guard let best = candidates.min(by: { $0.location.ping < $1.location.ping }) else { return nil }
            return VPNResolvedConnection(location: best.location, provider: best.provider, selection: selection)

        case let .smartJob(job, scope):
            let candidates = servers(for: job, scope: scope, providers: providers)
            guard let best = candidates.min(by: { $0.location.ping < $1.location.ping }) else { return nil }
            return VPNResolvedConnection(location: best.location, provider: best.provider, selection: selection)
        }
    }

    static func servers(
        for job: VPNUserJob,
        scope: VPNProviderScope,
        providers: [VPNProvider]
    ) -> [VPNNetworkLocation] {
        mergedLocations(from: scopedEligibleProviders(providers, scope: scope))
            .filter { $0.jobTags.contains(job) }
            .sorted { $0.location.ping < $1.location.ping }
    }

    static func mergedLocations(from providers: [VPNProvider]) -> [VPNNetworkLocation] {
        providers.flatMap { provider in
            provider.servers
                .filter { $0.kind != .smart }
                .map { VPNNetworkLocation(location: $0, provider: provider) }
        }
        .sorted { $0.location.ping < $1.location.ping }
    }

    static func countryGroups(from providers: [VPNProvider], scope: VPNProviderScope) -> [VPNCountryLocationGroup] {
        let merged = mergedLocations(from: scopedEligibleProviders(providers, scope: scope))
        let grouped = Dictionary(grouping: merged) { $0.location.listIdentity.groupingKey }

        return grouped.keys.sorted().map { key in
            let unsorted = grouped[key] ?? []
            let identity = unsorted.first?.location.listIdentity
            let candidates = unsorted.sorted { lhs, rhs in
                let left = lhs.location.listIdentity
                let right = rhs.location.listIdentity
                if left.variantRank != right.variantRank {
                    return left.variantRank < right.variantRank
                }
                return lhs.location.ping < rhs.location.ping
            }
            return VPNCountryLocationGroup(
                id: key,
                name: identity?.groupTitle ?? key,
                flag: identity?.groupFlag ?? candidates.first?.location.flag ?? "🌐",
                family: identity?.family ?? .country,
                candidates: candidates
            )
        }
    }

    static func filteredLocationSections(
        from providers: [VPNProvider],
        scope: VPNProviderScope,
        query: VPNLocationQuery
    ) -> [VPNLocationListSection] {
        let groups = countryGroups(from: providers, scope: scope).compactMap { group -> VPNCountryLocationGroup? in
            let filtered = group.candidates.filter { query.matches($0) }
            guard !filtered.isEmpty else { return nil }

            return VPNCountryLocationGroup(
                id: group.id,
                name: group.name,
                flag: group.flag,
                family: group.family,
                candidates: sortCandidates(filtered, query: query)
            )
        }

        let clustered = Dictionary(grouping: groups, by: \.family)
        return VPNLocationListFamily.listOrder.compactMap { family in
            guard var familyGroups = clustered[family], !familyGroups.isEmpty else { return nil }
            familyGroups = sortGroups(familyGroups, query: query)
            let showTitle = groups.contains { $0.family.isCatalogFamily }
            return VPNLocationListSection(
                family: family,
                title: showTitle ? family.sectionTitle : nil,
                explanation: showTitle ? family.sectionExplanation : nil,
                groups: familyGroups
            )
        }
    }

    static func filteredCountryGroups(
        from providers: [VPNProvider],
        scope: VPNProviderScope,
        query: VPNLocationQuery
    ) -> [VPNCountryLocationGroup] {
        filteredLocationSections(from: providers, scope: scope, query: query).flatMap(\.groups)
    }

    static func signalForSelection(
        _ selection: VPNLocationSelection,
        providers: [VPNProvider]
    ) -> VPNLocation.Signal? {
        resolve(providers: providers, selection: selection)?.location.signal
    }

    private static func sortGroups(
        _ groups: [VPNCountryLocationGroup],
        query: VPNLocationQuery
    ) -> [VPNCountryLocationGroup] {
        groups.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.hasSmartServer != rhs.hasSmartServer {
                return lhs.hasSmartServer && !rhs.hasSmartServer
            }
            switch query.sort {
            case .fastest:
                return lhs.bestPing < rhs.bestPing
            case .country:
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private static func sortCandidates(
        _ candidates: [VPNNetworkLocation],
        query: VPNLocationQuery
    ) -> [VPNNetworkLocation] {
        candidates.sorted { lhs, rhs in
            let left = lhs.location.listIdentity
            let right = rhs.location.listIdentity
            if left.family.isCatalogFamily || right.family.isCatalogFamily,
               left.variantRank != right.variantRank {
                return left.variantRank < right.variantRank
            }
            switch query.sort {
            case .fastest:
                return lhs.location.ping < rhs.location.ping
            case .country:
                if lhs.location.name == rhs.location.name {
                    return lhs.location.city.localizedCompare(rhs.location.city) == .orderedAscending
                }
                return lhs.location.name.localizedCompare(rhs.location.name) == .orderedAscending
            }
        }
    }

    static func inlinePingEntries(from providers: [VPNProvider]) -> [(id: String, ping: Int)] {
        pingResults(from: providers).map { ($0.id, $0.ping) }
    }

    static func inlinePingEntries(
        providers: [VPNProvider],
        scope: VPNProviderScope,
        query: VPNLocationQuery
    ) -> [(id: String, ping: Int)] {
        let allPings = Dictionary(
            uniqueKeysWithValues: pingResults(from: providers).map { ($0.id, $0.ping) }
        )
        var entries: [(String, Int)] = []
        let groups = filteredCountryGroups(from: providers, scope: scope, query: query)

        for group in groups {
            if let smart = VPNLocationJobCatalog.smartLocation(for: group.name),
               let resolved = resolve(providers: providers, selection: smart.selection(scope: scope)) {
                let resolvedID = "\(resolved.provider.id.uuidString)-\(resolved.location.persistenceKey)"
                if let ping = allPings[resolvedID] {
                    entries.append((smart.pingID(for: group.name), ping))
                }
            }

            for candidate in group.candidates {
                if let ping = allPings[candidate.id] {
                    entries.append((candidate.id, ping))
                }
            }
        }

        return entries
    }

    static func pingResults(from providers: [VPNProvider]) -> [VPNPingResult] {
        mergedLocations(from: providers.filter(\.isEligibleForAutoConnect))
            .map { networkLocation in
                let jitter = Int.random(in: -6...8)
                return VPNPingResult(
                    location: networkLocation.location,
                    provider: networkLocation.provider,
                    ping: max(12, networkLocation.location.ping + jitter)
                )
            }
            .sorted { $0.ping < $1.ping }
    }

    static func qualityLabel(for selection: VPNLocationSelection, providers: [VPNProvider]) -> String {
        qualityDisplay(for: selection, providers: providers).label
    }

    static func qualityDisplay(
        for selection: VPNLocationSelection,
        providers: [VPNProvider]
    ) -> VPNQualityDisplay {
        guard let best = resolve(providers: providers, selection: selection)?.location else {
            return VPNQualityDisplay(label: "—", tone: .neutral)
        }
        return VPNQualityDisplay(signal: best.signal)
    }

    private static func scopedEligibleProviders(_ providers: [VPNProvider], scope: VPNProviderScope) -> [VPNProvider] {
        scope.filtered(providers).filter(\.isEligibleForAutoConnect)
    }

    static func reconcileSelection(
        _ selection: VPNLocationSelection,
        providers: [VPNProvider],
        storeScope: VPNProviderScope
    ) -> VPNLocationSelection {
        let correctedScope = correctedScope(
            for: selection.scope,
            providers: providers,
            storeScope: storeScope
        )

        switch selection {
        case .smartAuto:
            return .smartAuto(scope: correctedScope)
        case let .smartJob(job, _):
            return .smartJob(job, scope: correctedScope)
        case .manual:
            return selection
        }
    }

    static func smartAutoFallbackSelection(
        providers: [VPNProvider],
        preferredScope: VPNProviderScope,
        storeScope: VPNProviderScope
    ) -> VPNLocationSelection? {
        let scope = correctedScope(
            for: preferredScope,
            providers: providers,
            storeScope: storeScope
        )
        let selection = VPNLocationSelection.smartAuto(scope: scope)
        guard resolve(providers: providers, selection: selection) != nil else { return nil }
        return selection
    }

    static func diagnoseSelectionFailure(
        providers: [VPNProvider],
        selection: VPNLocationSelection
    ) -> VPNSelectionMismatch? {
        guard resolve(providers: providers, selection: selection) == nil else { return nil }

        let providerName = primaryProviderName(providers: providers, selection: selection)

        switch selection {
        case let .smartJob(job, scope):
            if case let .provider(id) = scope,
               !providers.contains(where: { $0.id == id && $0.isEligibleForAutoConnect }) {
                let label = VPNSelectionSummary.scopeLabel(for: scope, providers: providers)
                return VPNSelectionMismatch(
                    reason: .scopedProviderMissing(scopeLabel: label),
                    providerName: providerName,
                    selection: selection
                )
            }
            if servers(for: job, scope: scope, providers: providers).isEmpty {
                return VPNSelectionMismatch(
                    reason: .presetUnavailable(job: job),
                    providerName: providerName,
                    selection: selection
                )
            }

        case let .smartAuto(scope):
            if case let .provider(id) = scope,
               !providers.contains(where: { $0.id == id && $0.isEligibleForAutoConnect }) {
                let label = VPNSelectionSummary.scopeLabel(for: scope, providers: providers)
                return VPNSelectionMismatch(
                    reason: .scopedProviderMissing(scopeLabel: label),
                    providerName: providerName,
                    selection: selection
                )
            }
            if mergedLocations(from: scopedEligibleProviders(providers, scope: scope)).isEmpty {
                return VPNSelectionMismatch(
                    reason: .scopedProviderMissing(scopeLabel: ui("Selected network")),
                    providerName: providerName,
                    selection: selection
                )
            }

        case let .manual(_, providerID):
            if !providers.contains(where: { $0.id == providerID && $0.isEligibleForAutoConnect }) {
                return VPNSelectionMismatch(
                    reason: .scopedProviderMissing(scopeLabel: ui("Selected server")),
                    providerName: providerName,
                    selection: selection
                )
            }
        }

        return VPNSelectionMismatch(
            reason: .presetUnavailable(job: .streaming),
            providerName: providerName,
            selection: selection
        )
    }

    static func primaryProviderName(
        providers: [VPNProvider],
        selection: VPNLocationSelection
    ) -> String {
        switch selection.scope {
        case .allNetworks:
            if providers.count == 1 {
                return providers[0].name
            }
            return providers.first(where: \.isEligibleForAutoConnect)?.name ?? "Your VPN"
        case let .provider(id):
            return providers.first(where: { $0.id == id })?.name ?? "Your VPN"
        }
    }

    private static func correctedScope(
        for selectionScope: VPNProviderScope,
        providers: [VPNProvider],
        storeScope: VPNProviderScope
    ) -> VPNProviderScope {
        let eligible = providers.filter(\.isEligibleForAutoConnect)

        switch selectionScope {
        case .allNetworks:
            if VPNReleaseProfile.isRelease1, case let .provider(id) = storeScope {
                return eligible.contains(where: { $0.id == id }) ? .provider(id) : storeScope
            }
            switch storeScope {
            case .allNetworks:
                return .allNetworks
            case let .provider(id):
                return eligible.contains(where: { $0.id == id }) ? .provider(id) : .allNetworks
            }

        case let .provider(id):
            if VPNReleaseProfile.isRelease1, case let .provider(storeID) = storeScope {
                return eligible.contains(where: { $0.id == storeID }) ? .provider(storeID) : storeScope
            }
            if eligible.contains(where: { $0.id == id }) {
                return .provider(id)
            }
            if eligible.count == 1, let only = eligible.first {
                return .provider(only.id)
            }
            return .allNetworks
        }
    }

    private static let europeanCountries: Set<String> = [
        "Finland", "Sweden", "Germany", "Netherlands", "Poland",
        "France", "United Kingdom", "Switzerland", "Turkey",
    ]
}

extension VPNProvider {
    static let velvetDemoMessage = VPNFigmaSection550Copy.velvetProviderMessage

    /// Happ snapshot from 25.09.2026: `ТИП-Страна [метка]` plus LTE and extra-country rows.
    static let velvetHappServers: [VPNLocation] = {
        let fast = "Быстрый. Без рекламы"
        let hys2 = "Hysteria2. Экспериментальный"
        let experimental = "Экспериментальная конфигурация"
        let east = "Восточным регионам"
        let temp = "Для временного доступа"
        let lteUniversal = "Почти все операторы и регионы"

        return [
            velvetHappHost("SMART-Авто", "Автовыбор доступного сервера", "✨", 18),
            velvetHappHost("SMART-Нидерланды", fast, "🇳🇱", 28, 52.3676, 4.9041),
            velvetHappHost("SMART-Нидерланды [HYS2]", hys2, "🇳🇱", 31, 52.3676, 4.9041),
            velvetHappHost("SMART-Швеция", fast, "🇸🇪", 34, 59.3293, 18.0686),
            velvetHappHost("SMART-Швеция [S+]", experimental, "🇸🇪", 36, 59.3293, 18.0686),
            velvetHappHost("SMART-Швеция [HYS2]", hys2, "🇸🇪", 38, 59.3293, 18.0686),
            velvetHappHost("SMART-Россия", "Через Москву. Работает всё", "🇷🇺", 13, 55.7558, 37.6173),
            velvetHappHost("SMART-Россия [HYS2]", hys2, "🇷🇺", 16, 55.7558, 37.6173),
            velvetHappHost("SMART-Германия", fast, "🇩🇪", 42, 50.1109, 8.6821),
            velvetHappHost("SMART-Германия [HYS2]", hys2, "🇩🇪", 45, 50.1109, 8.6821),
            velvetHappHost("SMART-Италия", fast, "🇮🇹", 52, 41.9028, 12.4964),
            velvetHappHost("SMART-Литва", fast, "🇱🇹", 40, 54.6872, 25.2797),
            velvetHappHost("SMART-Литва [HYS2]", hys2, "🇱🇹", 43, 54.6872, 25.2797),
            velvetHappHost("SMART-Франция", fast, "🇫🇷", 48, 48.8566, 2.3522),
            velvetHappHost("SMART-Англия", fast, "🇬🇧", 54, 51.5072, -0.1276),
            velvetHappHost("SMART-Англия [S+]", fast, "🇬🇧", 56, 51.5072, -0.1276),
            velvetHappHost("SMART-Канада", fast, "🇨🇦", 118, 43.6532, -79.3832),
            velvetHappHost("SMART-Канада [S+]", experimental, "🇨🇦", 122, 43.6532, -79.3832),
            velvetHappHost("SMART-США", fast, "🇺🇸", 128, 40.7128, -74.0060),
            velvetHappHost("SMART-Сингапур", east, "🇸🇬", 96, 1.3521, 103.8198),
            velvetHappHost("SMART-Сингапур [S+]", experimental, "🇸🇬", 99, 1.3521, 103.8198),
            velvetHappHost("SMART-Япония", east, "🇯🇵", 142, 35.6762, 139.6503),
            velvetHappHost("BRIDGE-Германия", "Франкфурт через Москву", "🇩🇪", 58, 50.1109, 8.6821),
            velvetHappHost("BRIDGE-Швеция", "Стокгольм через Москву", "🇸🇪", 62, 59.3293, 18.0686),
            velvetHappHost("BRIDGE-Нидерланды", "Амстердам через Москву", "🇳🇱", 60, 52.3676, 4.9041),
            velvetHappHost("🏴‍☠️ TORRENT-Нидерланды", "Разрешен torrent. Быстрый.", "🏴‍☠️", 33, 52.3676, 4.9041),
            velvetHappHost("LTE-Авто", "Автовыбор: SMART/LTE-Авто", "✨", 22, kind: .lte),
            velvetHappHost("#100 LTE Универсальный [HYS2]", hys2, "📶", 26, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#101 LTE Универсальный [HYS2]", hys2, "📶", 27, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#102 LTE Универсальный [HYS2]", hys2, "📶", 29, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#103 LTE Универсальный [HYS2]", hys2, "📶", 30, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#24 LTE Универсальный", lteUniversal, "📶", 24, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#11 LTE Универсальный", lteUniversal, "📶", 25, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#11-1 LTE Универсальный", lteUniversal, "📶", 28, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#9 LTE Универсальный", lteUniversal, "📶", 32, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#8 LTE Универсальный", lteUniversal, "📶", 34, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#12 LTE Универсальный", lteUniversal, "📶", 35, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#13-1 LTE Универсальный", lteUniversal, "📶", 37, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#13 LTE Универсальный", lteUniversal, "📶", 39, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#20 LTE Универсальный", lteUniversal, "📶", 41, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("#32 LTE Универсальный", lteUniversal, "📶", 44, 55.7558, 37.6173, kind: .lte),
            velvetHappHost("Бразилия", temp, "🇧🇷", 188, -23.5558, -46.6396),
            velvetHappHost("Германия", temp, "🇩🇪", 74, 50.1109, 8.6821),
            velvetHappHost("Египет", temp, "🇪🇬", 86, 30.0444, 31.2357),
            velvetHappHost("Индия", temp, "🇮🇳", 96, 19.0760, 72.8777),
            velvetHappHost("Казахстан", temp, "🇰🇿", 42, 43.2220, 76.8512),
            velvetHappHost("Литва", temp, "🇱🇹", 46, 54.6872, 25.2797),
            velvetHappHost("ОАЭ", temp, "🇦🇪", 92, 25.2048, 55.2708),
            velvetHappHost("Россия", temp, "🇷🇺", 21, 55.7558, 37.6173),
            velvetHappHost("США", temp, "🇺🇸", 134, 40.7128, -74.0060),
            velvetHappHost("Таиланд", temp, "🇹🇭", 88, 13.7563, 100.5018),
            velvetHappHost("Турция", temp, "🇹🇷", 58, 41.0082, 28.9784),
            velvetHappHost("Франция", temp, "🇫🇷", 82, 48.8566, 2.3522),
        ]
    }()

    static let samples: [VPNProvider] = {
        let velvetUpdated = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let velvetExpires = Calendar.current.date(byAdding: .day, value: 28, to: .now)!
        let provider2Expires = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let provider3Updated = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
        let provider4Expired = Calendar.current.date(byAdding: .day, value: -3, to: .now)!

        return [
            VPNProvider(
                id: UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!,
                name: "🚀 Velvet VPN — #34903",
                iconSymbol: "shield.lefthalf.filled",
                kind: .velvetFeatured,
                status: .active(locationCount: 903, trafficRemaining: "120 GB left"),
                servers: Self.velvetHappServers,
                subscriptionURL: "https://velvet.vpn/sub/featured-demo",
                lastUpdated: velvetUpdated,
                expiresAt: velvetExpires,
                includedInSmartAuto: true,
                providerMessage: velvetDemoMessage,
                providerMessageUpdatedAt: velvetUpdated
            ),
            VPNProvider(
                id: UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!,
                name: "NordVPN",
                iconSymbol: "mountain.2.fill",
                kind: .imported,
                status: .active(locationCount: 412, trafficRemaining: "86 GB left"),
                servers: [
                    VPNLocation(name: "Russia", city: "Moscow", flag: "🇷🇺", kind: .standard, ping: 24, coordinate: GeoCoordinate(latitude: 55.7558, longitude: 37.6173)),
                    VPNLocation(name: "Kazakhstan", city: "Almaty", flag: "🇰🇿", kind: .lte, ping: 42, coordinate: GeoCoordinate(latitude: 43.2220, longitude: 76.8512)),
                    VPNLocation(name: "Armenia", city: "Yerevan", flag: "🇦🇲", kind: .standard, ping: 48, coordinate: GeoCoordinate(latitude: 40.1792, longitude: 44.4991)),
                    VPNLocation(name: "Georgia", city: "Tbilisi", flag: "🇬🇪", kind: .lte, ping: 52, coordinate: GeoCoordinate(latitude: 41.7151, longitude: 44.8271)),
                ],
                subscriptionURL: "https://provider.example/sub/2",
                lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: .now),
                expiresAt: provider2Expires,
                includedInSmartAuto: true,
                providerMessage: nil,
                providerMessageUpdatedAt: nil
            ),
            VPNProvider(
                id: UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!,
                name: "Surfshark",
                iconSymbol: "globe.europe.africa.fill",
                kind: .imported,
                status: .active(locationCount: 218, trafficRemaining: "34 GB left"),
                servers: [
                    VPNLocation(name: "Germany", city: "Frankfurt", flag: "🇩🇪", kind: .standard, ping: 71, coordinate: GeoCoordinate(latitude: 50.1109, longitude: 8.6821)),
                    VPNLocation(name: "France", city: "Paris", flag: "🇫🇷", kind: .standard, ping: 88, coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)),
                    VPNLocation(name: "United Kingdom", city: "London", flag: "🇬🇧", kind: .standard, ping: 94, coordinate: GeoCoordinate(latitude: 51.5072, longitude: -0.1276)),
                    VPNLocation(name: "Netherlands", city: "Rotterdam", flag: "🇳🇱", kind: .standard, ping: 82, coordinate: GeoCoordinate(latitude: 51.9244, longitude: 4.4777)),
                    VPNLocation(name: "Spain", city: "Madrid", flag: "🇪🇸", kind: .standard, ping: 96, coordinate: GeoCoordinate(latitude: 40.4168, longitude: -3.7038)),
                    VPNLocation(name: "Italy", city: "Rome", flag: "🇮🇹", kind: .standard, ping: 92, coordinate: GeoCoordinate(latitude: 41.9028, longitude: 12.4964)),
                    VPNLocation(name: "Czech Republic", city: "Prague", flag: "🇨🇿", kind: .standard, ping: 76, coordinate: GeoCoordinate(latitude: 50.0755, longitude: 14.4378)),
                ],
                subscriptionURL: "https://provider.example/sub/3",
                lastUpdated: provider3Updated,
                expiresAt: Calendar.current.date(byAdding: .day, value: 45, to: .now),
                includedInSmartAuto: true,
                providerMessage: nil,
                providerMessageUpdatedAt: nil
            ),
            VPNProvider(
                id: UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!,
                name: "Proton VPN",
                iconSymbol: "network",
                kind: .imported,
                status: .expired,
                servers: [
                    VPNLocation(name: "United States", city: "New York", flag: "🇺🇸", kind: .standard, ping: 132, coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.0060)),
                ],
                subscriptionURL: "https://provider.example/sub/4",
                lastUpdated: Calendar.current.date(byAdding: .day, value: -30, to: .now),
                expiresAt: provider4Expired,
                includedInSmartAuto: false,
                providerMessage: "Subscription expired · Renew to restore access",
                providerMessageUpdatedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now)
            ),
        ]
    }()
}

private func velvetHappHost(
    _ title: String,
    _ caption: String,
    _ flag: String,
    _ ping: Int,
    _ latitude: Double? = nil,
    _ longitude: Double? = nil,
    kind: VPNLocation.Kind = .standard
) -> VPNLocation {
    let coordinate: GeoCoordinate?
    if let latitude, let longitude {
        coordinate = GeoCoordinate(latitude: latitude, longitude: longitude)
    } else {
        coordinate = nil
    }
    return VPNLocation(
        name: title,
        city: caption,
        flag: flag,
        kind: kind,
        ping: ping,
        coordinate: coordinate
    )
}

