import Foundation

enum VPNHomeFormat: String, CaseIterable, Identifiable, Codable {
    case classic
    case networksAndLocations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Single provider"
        case .networksAndLocations: "Networks & locations"
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

    var hasProviderMessage: Bool {
        guard let providerMessage else { return false }
        return !providerMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Rich multi-line announcements shown in the expanded stats area.
    /// Short traffic summaries belong in list subtitles only.
    var showsDetailMessage: Bool {
        guard let providerMessage else { return false }
        let trimmed = providerMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("\n") || trimmed.count > 80
    }

    var subtitle: String {
        switch status {
        case let .active(locationCount, trafficRemaining):
            if let expiryLabel {
                "\(locationCount) locations · \(trafficRemaining) · \(expiryLabel)"
            } else {
                "\(locationCount) locations · \(trafficRemaining)"
            }
        case .expired:
            "Subscription expired"
        }
    }

    var expiryLabel: String? {
        guard let expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        if days < 0 { return "Expired" }
        if days == 0 { return "Expires today" }
        if days <= 7 { return "Expires in \(days) days" }
        return nil
    }

    var renewURL: String {
        subscriptionURL ?? "https://velvet.vpn/renew"
    }

    var maskedSubscriptionURL: String {
        guard let subscriptionURL, !subscriptionURL.isEmpty else { return "Not set" }
        guard subscriptionURL.count > 24 else { return subscriptionURL }
        let prefix = subscriptionURL.prefix(18)
        return "\(prefix)…"
    }

    var smartAutoBadge: String? {
        guard status.isActive else { return nil }
        return includedInSmartAuto ? "Included in Auto" : "Manual only"
    }

    /// Subtitle for the expanded panel header, e.g. "120 GB left, 28 days left".
    var panelHeaderSubtitle: String {
        switch status {
        case .expired:
            "Subscription expired"
        case let .active(_, trafficRemaining):
            if let daysRemainingLabel {
                "\(trafficRemaining), \(daysRemainingLabel)"
            } else {
                trafficRemaining
            }
        }
    }

    private var daysRemainingLabel: String? {
        guard let expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        if days < 0 { return "Expired" }
        if days == 0 { return "0 days left" }
        return "\(days) days left"
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
                return "\(trafficRemaining), \(daysRemainingLabel)"
            }
            return trafficRemaining
        case .expired:
            return nil
        }
    }

    /// Secondary line in the multi-provider list: locations and traffic only.
    var networksListSubtitle: String {
        switch status {
        case let .active(locationCount, trafficRemaining):
            "\(locationCount) locations · \(trafficRemaining)"
        case .expired:
            "Subscription expired"
        }
    }

    func tunnelStatusLabel(isConnected: Bool, activeProviderID: UUID?) -> String {
        switch status {
        case .expired:
            "Expired"
        case .active:
            if isConnected, activeProviderID == id {
                "Connected"
            } else {
                "Disconnected"
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
            return "\(expired) expired"
        case (let available, 0):
            return "\(available) available"
        case (let available, let expired):
            return "\(available) available, \(expired) expired"
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
        return "\(modeLabel) · \(location.city) · \(location.pingLabel) · \(provider.name)"
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
            self.init(label: "Best", tone: .positive)
        case .good:
            self.init(label: "Good", tone: .positive)
        case .fair:
            self.init(label: "So so", tone: .caution)
        }
    }
}

enum VPNSelectionSummary {
    static func selectionLabel(for selection: VPNLocationSelection) -> String {
        switch selection {
        case .smartAuto: "Smart-Auto"
        case let .smartJob(job, _): job.title
        case .manual: "Manual"
        }
    }

    static func scopeLabel(for scope: VPNProviderScope, providers: [VPNProvider]) -> String {
        switch scope {
        case .allNetworks: "All networks"
        case let .provider(id):
            providers.first(where: { $0.id == id })?.name ?? "One network"
        }
    }

    static func heroTitle(
        connectionState: VPNConnectionState,
        homeFormat: VPNHomeFormat,
        isSwitchingServer: Bool
    ) -> String {
        switch connectionState {
        case .connecting:
            if isSwitchingServer { return "Switching server…" }
            return homeFormat == .networksAndLocations ? "Finding best connection…" : "Connecting…"
        case .connected:
            return "Protected"
        case .failed:
            return "Couldn't connect"
        case .disconnected:
            return "Ready to connect"
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
                return isSwitchingServer ? "Applying new location…" : "Pinging all active providers"
            }
            return selectedLocation.name
        }

        if connectionState == .connected,
           let resolvedConnection,
           homeFormat == .networksAndLocations {
            return resolvedConnection.summarySubtitle
        }

        if homeFormat == .networksAndLocations {
            return disconnectedNetworksSubtitle(selection: selection, providers: providers)
        }

        return selectedLocation.name
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
            return "Last attempt failed · tap Retry"
        }

        let quality = VPNConnectionPlanner.qualityLabel(for: selection, providers: providers)

        switch selection {
        case let .smartAuto(scope):
            return "\(scopeLabel(for: scope, providers: providers)) · Smart-Auto · \(quality)"
        case let .smartJob(job, scope):
            return "\(scopeLabel(for: scope, providers: providers)) · \(job.title) · \(quality)"
        case let .manual(location, _):
            return "Manual · \(location.city) · \(location.pingLabel)"
        }
    }

    private static func disconnectedNetworksSubtitle(
        selection: VPNLocationSelection,
        providers: [VPNProvider]
    ) -> String {
        let quality = VPNConnectionPlanner.qualityLabel(for: selection, providers: providers)

        switch selection {
        case let .smartAuto(scope):
            return "\(quality) · Smart-Auto · \(scopeLabel(for: scope, providers: providers))"
        case let .smartJob(job, scope):
            if job == .whitelistForeign {
                return "\(quality) · \(job.title) · split routing"
            }
            return "\(quality) · \(job.title) · \(scopeLabel(for: scope, providers: providers))"
        case let .manual(location, providerID):
            let providerName = providers.first(where: { $0.id == providerID })?.name ?? "Network"
            return "Manual · \(location.name) · \(location.city) · \(providerName)"
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
        let grouped = Dictionary(grouping: merged) { $0.location.name }

        return grouped.keys.sorted().map { country in
            let candidates = grouped[country]?.sorted { $0.location.ping < $1.location.ping } ?? []
            return VPNCountryLocationGroup(
                id: country,
                name: country,
                flag: candidates.first?.location.flag ?? "🌐",
                candidates: candidates
            )
        }
        .sorted { $0.bestPing < $1.bestPing }
    }

    static func filteredCountryGroups(
        from providers: [VPNProvider],
        scope: VPNProviderScope,
        query: VPNLocationQuery
    ) -> [VPNCountryLocationGroup] {
        let groups = countryGroups(from: providers, scope: scope).compactMap { group -> VPNCountryLocationGroup? in
            let filtered = group.candidates.filter { query.matches($0) }
            guard !filtered.isEmpty else { return nil }

            return VPNCountryLocationGroup(
                id: group.id,
                name: group.name,
                flag: group.flag,
                candidates: sortCandidates(filtered, query: query)
            )
        }

        switch query.sort {
        case .fastest:
            return groups.sorted { $0.bestPing < $1.bestPing }
        case .country:
            return groups.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    static func signalForSelection(
        _ selection: VPNLocationSelection,
        providers: [VPNProvider]
    ) -> VPNLocation.Signal? {
        resolve(providers: providers, selection: selection)?.location.signal
    }

    private static func sortCandidates(
        _ candidates: [VPNNetworkLocation],
        query: VPNLocationQuery
    ) -> [VPNNetworkLocation] {
        candidates.sorted { lhs, rhs in
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
                    reason: .scopedProviderMissing(scopeLabel: "Selected network"),
                    providerName: providerName,
                    selection: selection
                )
            }

        case let .manual(_, providerID):
            if !providers.contains(where: { $0.id == providerID && $0.isEligibleForAutoConnect }) {
                return VPNSelectionMismatch(
                    reason: .scopedProviderMissing(scopeLabel: "Selected server"),
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
            switch storeScope {
            case .allNetworks:
                return .allNetworks
            case let .provider(id):
                return eligible.contains(where: { $0.id == id }) ? .provider(id) : .allNetworks
            }

        case let .provider(id):
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
    static let velvetDemoMessage = """
    📶 LTE: 0.0/40 GB (test: 3 GB)
    ‼️ Глушат LTE — перебери все LTE-конфиги до рабочего.
    ⛔ Перестало работать? Нажми справа от Velvet VPN на Wi-Fi.
    🆔 1208800 / 28.08.2026 14:10 MSK
    """

    static let samples: [VPNProvider] = {
        let velvetUpdated = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let velvetExpires = Calendar.current.date(byAdding: .day, value: 28, to: .now)!
        let provider2Expires = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let provider3Updated = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
        let provider4Expired = Calendar.current.date(byAdding: .day, value: -3, to: .now)!

        return [
            VPNProvider(
                id: UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!,
                name: "Velvet VPN",
                iconSymbol: "shield.lefthalf.filled",
                kind: .velvetFeatured,
                status: .active(locationCount: 903, trafficRemaining: "120 GB left"),
                servers: [
                    VPNLocation(name: "Smart — Auto", city: "Fastest available server", flag: "✨", kind: .smart, ping: 24),
                    VPNLocation(name: "Russia", city: "Moscow", flag: "🇷🇺", kind: .lte, ping: 18, coordinate: GeoCoordinate(latitude: 55.7558, longitude: 37.6173)),
                    VPNLocation(name: "Russia", city: "Saint Petersburg", flag: "🇷🇺", kind: .standard, ping: 26, coordinate: GeoCoordinate(latitude: 59.9311, longitude: 30.3609)),
                    VPNLocation(name: "Netherlands", city: "Amsterdam", flag: "🇳🇱", kind: .standard, ping: 78, coordinate: GeoCoordinate(latitude: 52.3676, longitude: 4.9041)),
                    VPNLocation(name: "Finland", city: "Helsinki", flag: "🇫🇮", kind: .standard, ping: 64, coordinate: GeoCoordinate(latitude: 60.1699, longitude: 24.9384)),
                    VPNLocation(name: "Sweden", city: "Stockholm", flag: "🇸🇪", kind: .standard, ping: 69, coordinate: GeoCoordinate(latitude: 59.3293, longitude: 18.0686)),
                    VPNLocation(name: "Poland", city: "Warsaw", flag: "🇵🇱", kind: .standard, ping: 58, coordinate: GeoCoordinate(latitude: 52.2297, longitude: 21.0122)),
                    VPNLocation(name: "Turkey", city: "Istanbul", flag: "🇹🇷", kind: .standard, ping: 73, coordinate: GeoCoordinate(latitude: 41.0082, longitude: 28.9784)),
                    VPNLocation(name: "Switzerland", city: "Zurich", flag: "🇨🇭", kind: .standard, ping: 81, coordinate: GeoCoordinate(latitude: 47.3769, longitude: 8.5417)),
                    VPNLocation(name: "United States", city: "New York", flag: "🇺🇸", kind: .standard, ping: 128, coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.0060)),
                ],
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

