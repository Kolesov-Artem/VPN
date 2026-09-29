import Foundation
import Observation

enum PromoDemoScenario {
    /// Surfshark active, Velvet expired — promo + stats, no renewal.
    case activeThirdParty
    /// NordVPN expiring in 5 days, Velvet expired — promo + renewal.
    case expiringThirdParty
}

enum VPNImportError: LocalizedError, Equatable {
    case invalidURL
    case unreadable
    case duplicate

    var errorDescription: String? {
        switch self {
        case .invalidURL, .unreadable:
            "Couldn't read subscription"
        case .duplicate:
            "This configuration is already added"
        }
    }
}

@Observable
@MainActor
final class VPNProviderStore {
    private static let onboardingKey = "velvet.hasCompletedOnboarding"
    private static let permissionKey = "velvet.hasSeenVPNPermission"
    private static let importedKeysKey = "velvet.importedProviderKeys"
    private static let providerSnapshotsKey = "velvet.providerSnapshots.v2"
    private static let providerScopeKey = "velvet.providerScope.v1"
    private static let activeProviderKey = "velvet.activeProvider.v1"
    private static let prototypeCycleKey = "velvet.prototypeOnboardingCycle"
    private static let switcherHiddenKey = "velvet.switcherHiddenProviderIDs"
    private static let thirdPartyDemoTemplateIndex = 2

    var providers: [VPNProvider] = []
    var highlightedProviderID: UUID?
    var isRefreshing = false
    var providerScope: VPNProviderScope = .allNetworks
    var activeProviderID: UUID?
    var hiddenRenewalBannerIDs: Set<UUID> = []
    /// Active subscriptions the person hid from the switch card. They stay on the subscriptions page.
    var switcherHiddenIDs: Set<UUID> = []
    private var catalogScopeWasPersisted = false

    /// State 2 demo: first connect should surface mismatch UX instead of silent Smart Auto fallback.
    var importedOnlyDemoAwaitingMismatch = false

#if DEBUG
    private static let activeScenarioKey = "velvet.dev.activeScenario"
    var activePrototypeScenario: VPNPrototypeScenario? {
        guard let raw = UserDefaults.standard.string(forKey: Self.activeScenarioKey) else { return nil }
        return VPNPrototypeScenario(rawValue: raw)
    }
#endif

    var showsProviderPicker: Bool { providers.count > 1 }

    /// Subscriptions offered in the switch card: active, and not hidden by a swipe.
    var switcherProviders: [VPNProvider] {
        providers.filter { $0.status.isActive && !switcherHiddenIDs.contains($0.id) }
    }

    func isInSwitcher(_ id: UUID) -> Bool {
        guard let provider = provider(id: id), provider.status.isActive else { return false }
        return !switcherHiddenIDs.contains(id)
    }

    /// Removes a subscription from the switch card. It stays in the full subscriptions list.
    func hideFromSwitcher(_ id: UUID) {
        switcherHiddenIDs.insert(id)
        persistSwitcherHiddenIDs()
        guard !showsAllSubscriptionsCatalog, activeProviderID == id else { return }
        if let next = switcherProviders.first {
            setActiveProvider(id: next.id)
        } else {
            showAllSubscriptions()
        }
    }

    /// Puts a subscription back in the switch card.
    func showInSwitcher(_ id: UUID) {
        switcherHiddenIDs.remove(id)
        persistSwitcherHiddenIDs()
    }

    var soleProvider: VPNProvider? {
        guard providers.count == 1 else { return nil }
        return providers.first
    }

    private var highlightTask: Task<Void, Never>?
    private var nextImportIndex = 1

    init() {
        loadActiveProviderID()
        loadProviderScope()
        loadSwitcherHiddenIDs()
        if UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            loadPersistedProviders()
        }
        reconcileActiveProvider()
    }

    var activeProvider: VPNProvider {
        if let activeProviderID,
           let match = providers.first(where: { $0.id == activeProviderID }) {
            return match
        }
        return providers.first ?? VPNProvider.samples[0]
    }

    func setActiveProvider(id: UUID, updatesCatalog: Bool = true) {
        guard providers.contains(where: { $0.id == id }) else { return }
        activeProviderID = id
        persistActiveProviderID()
        if updatesCatalog {
            setProviderScope(.provider(id))
        }
        VPNLogsStore.shared.append("Active VPN: \(providerName(id: id) ?? "Unknown")")
    }

    func showAllSubscriptions() {
        setProviderScope(.allNetworks)
        VPNLogsStore.shared.append("Active subscription: all")
    }

    var showsAllSubscriptionsCatalog: Bool {
        if case .allNetworks = providerScope { return true }
        return false
    }

    func setProviderScope(_ scope: VPNProviderScope) {
        providerScope = scope
        if case let .provider(id) = scope {
            activeProviderID = id
            persistActiveProviderID()
        }
        persistProviderScope()
    }

    func hideRenewalBanner(for providerID: UUID) {
        hiddenRenewalBannerIDs.insert(providerID)
    }

    var velvetProvider: VPNProvider? {
        providers.first(where: { $0.kind == .velvetFeatured })
    }

    /// Presets are a Velvet-only feature — selecting one scopes routing to Velvet.
    func activateVelvetForPresetSelection() {
        guard let velvet = velvetProvider else { return }
        setProviderScope(.provider(velvet.id))
    }

    func resetProviderScope() {
        if VPNReleaseProfile.isRelease1 {
            reconcileActiveProvider()
        } else {
            setProviderScope(.allNetworks)
        }
    }

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    var hasSeenVPNPermission: Bool {
        get { UserDefaults.standard.bool(forKey: Self.permissionKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.permissionKey) }
    }

    func markVPNPermissionSeen() {
        hasSeenVPNPermission = true
    }

    var prototypeOnboardingCycle: Int {
        UserDefaults.standard.integer(forKey: Self.prototypeCycleKey)
    }

    var nextOnboardingExpectsVelvet: Bool {
        prototypeOnboardingCycle % 2 == 1
    }

    func advancePrototypeCycle() {
        let next = prototypeOnboardingCycle + 1
        UserDefaults.standard.set(next, forKey: Self.prototypeCycleKey)
    }

    /// DEBUG launch helper: expired Velvet + one imported provider scoped for promo visibility.
    func configurePromoDemo(scenario: PromoDemoScenario) {
        let templateIndex: Int
        let providerMessage: String?
        let expiresAt: Date?

        switch scenario {
        case .activeThirdParty:
            templateIndex = Self.thirdPartyDemoTemplateIndex
            providerMessage = VPNProvider.velvetDemoMessage
            expiresAt = VPNProvider.samples[templateIndex].expiresAt
        case .expiringThirdParty:
            templateIndex = 1
            providerMessage = VPNProvider.samples[templateIndex].providerMessage
            expiresAt = Calendar.current.date(byAdding: .day, value: 5, to: .now)
        }

        let template = VPNProvider.samples[templateIndex]
        var velvet = VPNProvider.samples[0]
        velvet.status = .expired
        velvet.includedInSmartAuto = false

        let imported = VPNProvider(
            id: UUID(),
            name: template.name,
            iconSymbol: template.iconSymbol,
            kind: .imported,
            status: template.status,
            servers: template.servers,
            subscriptionURL: template.subscriptionURL ?? "https://provider.example/sub/demo",
            lastUpdated: .now,
            expiresAt: expiresAt,
            includedInSmartAuto: true,
            providerMessage: providerMessage,
            providerMessageUpdatedAt: .now
        )

        providers = [velvet, imported]
        nextImportIndex = templateIndex + 1
        highlightedProviderID = imported.id
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        UserDefaults.standard.set(["import-\(templateIndex)-1"], forKey: Self.importedKeysKey)
        persistSnapshots()
        setProviderScope(.provider(imported.id))
        VPNLogsStore.shared.append("Promo demo: \(template.name) (\(scenario))")
    }

    func resetToVelvetOnly() {
        providers = [VPNProvider.samples[0]]
        nextImportIndex = 1
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        UserDefaults.standard.set([String](), forKey: Self.importedKeysKey)
        persistSnapshots()
    }

#if DEBUG
    func loadSingleImportedOnly(templateIndex: Int = thirdPartyDemoTemplateIndex) {
        guard VPNProvider.samples.indices.contains(templateIndex) else { return }
        let template = VPNProvider.samples[templateIndex]
        let imported = VPNProvider(
            id: UUID(),
            name: template.name,
            iconSymbol: template.iconSymbol,
            kind: .imported,
            status: template.status,
            servers: template.servers,
            subscriptionURL: template.subscriptionURL ?? "https://provider.example/sub/demo",
            lastUpdated: .now,
            expiresAt: template.expiresAt,
            includedInSmartAuto: template.includedInSmartAuto,
            providerMessage: VPNProvider.velvetDemoMessage,
            providerMessageUpdatedAt: .now
        )
        providers = [imported]
        nextImportIndex = 1
        highlightedProviderID = imported.id
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        UserDefaults.standard.set(["import-\(templateIndex)-1"], forKey: Self.importedKeysKey)
        persistSnapshots()
        setProviderScope(.provider(imported.id))
    }

    func expireProvider(id: UUID) {
        update(id: id) { provider in
            provider.status = .expired
            provider.includedInSmartAuto = false
        }
    }

    func expireAllImported() {
        for provider in providers where provider.kind == .imported {
            expireProvider(id: provider.id)
        }
    }

    func setExpiringSoon(id: UUID, days: Int) {
        update(id: id) { provider in
            if provider.status == .expired {
                provider.status = .active(
                    locationCount: max(provider.servers.count, 1),
                    trafficRemaining: "100 GB left"
                )
            }
            provider.expiresAt = Calendar.current.date(byAdding: .day, value: days, to: .now)
            provider.includedInSmartAuto = true
        }
    }

    func resetPrototypeState() {
        UserDefaults.standard.removeObject(forKey: Self.onboardingKey)
        UserDefaults.standard.removeObject(forKey: Self.permissionKey)
        UserDefaults.standard.removeObject(forKey: Self.importedKeysKey)
        UserDefaults.standard.removeObject(forKey: Self.providerSnapshotsKey)
        UserDefaults.standard.removeObject(forKey: Self.providerScopeKey)
        UserDefaults.standard.removeObject(forKey: Self.activeScenarioKey)
        UserDefaults.standard.removeObject(forKey: Self.switcherHiddenKey)
        hiddenRenewalBannerIDs.removeAll()
        switcherHiddenIDs.removeAll()
        providers = []
        nextImportIndex = 1
        highlightedProviderID = nil
        providerScope = .allNetworks
        catalogScopeWasPersisted = false
    }

    func applyPrototypeScenario(_ scenario: VPNPrototypeScenario) {
        hiddenRenewalBannerIDs.removeAll()
        VPNDevFlags.setConnectShouldFail(false)
        UserDefaults.standard.set(scenario.rawValue, forKey: Self.activeScenarioKey)

        switch scenario {
        case .onboarding:
            resetPrototypeState()

        case .importedOnly:
            loadSingleImportedOnly()
            setProviderScope(.allNetworks)
            importedOnlyDemoAwaitingMismatch = true

        case .velvetOnly:
            resetToVelvetOnly()
            resetProviderScope()

        case .velvetPlusImported:
            let velvet = makeFeaturedProvider(
                name: "🚀 Velvet VPN — #34903",
                status: .active(locationCount: 903, trafficRemaining: "120 GB left"),
                servers: VPNProvider.velvetHappServers,
                providerMessage: VPNFigmaSection550Copy.velvetProviderMessage
            )

            let velvetTwo = makeImportedProvider(
                from: VPNProvider.samples[0],
                templateIndex: 1,
                name: "Velvet #4309-23-4534-Discount",
                iconSymbol: "shield.lefthalf.filled",
                status: .active(locationCount: 903, trafficRemaining: "64 GB left"),
                servers: Self.bangkokServers
            )
            let velvetThree = makeImportedProvider(
                from: VPNProvider.samples[0],
                templateIndex: 2,
                name: "Velvet #43-23-4534-Discount",
                iconSymbol: "shield.lefthalf.filled",
                status: .active(locationCount: 903, trafficRemaining: "18 GB left"),
                servers: Self.berlinServers
            )
            let vpnName = makeImportedProvider(
                from: VPNProvider.samples[2],
                templateIndex: 3,
                name: "VPN name",
                iconSymbol: "antenna.radiowaves.left.and.right",
                status: .active(locationCount: 903, trafficRemaining: "240 GB left"),
                servers: Self.londonServers
            )
            let vpnNameExpired = makeImportedProvider(
                from: VPNProvider.samples[2],
                templateIndex: 4,
                name: "VPN name",
                iconSymbol: "v.circle.fill",
                status: .expired
            )

            providers = [velvet, velvetTwo, velvetThree, vpnName, vpnNameExpired]
            nextImportIndex = 5
            highlightedProviderID = nil
            setActiveProvider(id: velvet.id)
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            UserDefaults.standard.set(
                ["import-1-1", "import-1-2", "import-2-1", "import-2-2"],
                forKey: Self.importedKeysKey
            )
            persistSnapshots()
            resetProviderScope()

        case .velvetExpired:
            var velvet = VPNProvider.samples[0]
            velvet.status = .expired
            velvet.includedInSmartAuto = false
            let template = VPNProvider.samples[Self.thirdPartyDemoTemplateIndex]
            let imported = makeImportedProvider(from: template, templateIndex: Self.thirdPartyDemoTemplateIndex)
            providers = [velvet, imported]
            nextImportIndex = Self.thirdPartyDemoTemplateIndex + 1
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            UserDefaults.standard.set(
                ["import-\(Self.thirdPartyDemoTemplateIndex)-1"],
                forKey: Self.importedKeysKey
            )
            persistSnapshots()
            resetProviderScope()

        case .importedExpired:
            loadSingleImportedOnly()
            if let importedID = providers.first(where: { $0.kind == .imported })?.id {
                expireProvider(id: importedID)
            }
            setProviderScope(.allNetworks)
        }

        VPNLogsStore.shared.append("Prototype scenario: \(scenario.title)")
    }

    private func makeImportedProvider(
        from template: VPNProvider,
        templateIndex: Int,
        name: String? = nil,
        iconSymbol: String? = nil,
        status: VPNProvider.Status? = nil,
        servers: [VPNLocation]? = nil
    ) -> VPNProvider {
        let resolvedStatus = status ?? template.status
        _ = templateIndex
        return VPNProvider(
            id: UUID(),
            name: name ?? template.name,
            iconSymbol: iconSymbol ?? template.iconSymbol,
            kind: .imported,
            status: resolvedStatus,
            servers: servers ?? template.servers,
            subscriptionURL: template.subscriptionURL ?? "https://provider.example/sub/demo",
            lastUpdated: .now,
            expiresAt: resolvedStatus == .expired ? template.expiresAt : template.expiresAt,
            includedInSmartAuto: resolvedStatus.isActive,
            providerMessage: nil,
            providerMessageUpdatedAt: nil
        )
    }

    private func makeFeaturedProvider(
        name: String,
        status: VPNProvider.Status,
        servers: [VPNLocation],
        providerMessage: String? = nil
    ) -> VPNProvider {
        let template = VPNProvider.samples[0]
        return VPNProvider(
            id: template.id,
            name: name,
            iconSymbol: template.iconSymbol,
            kind: .velvetFeatured,
            status: status,
            servers: servers,
            subscriptionURL: template.subscriptionURL,
            lastUpdated: template.lastUpdated,
            expiresAt: template.expiresAt,
            includedInSmartAuto: true,
            providerMessage: providerMessage,
            providerMessageUpdatedAt: providerMessage == nil ? nil : .now
        )
    }

    private static func place(
        _ name: String,
        _ city: String,
        _ flag: String,
        _ ping: Int,
        _ latitude: Double,
        _ longitude: Double,
        kind: VPNLocation.Kind = .standard
    ) -> VPNLocation {
        VPNLocation(
            name: name,
            city: city,
            flag: flag,
            kind: kind,
            ping: ping,
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude)
        )
    }

    private static let moscowServers: [VPNLocation] = [
        place("Russia", "Moscow", "🇷🇺", 13, 55.7558, 37.6173, kind: .lte),
        place("Russia", "Saint Petersburg", "🇷🇺", 26, 59.9311, 30.3609),
        place("Russia", "Kazan", "🇷🇺", 34, 55.8304, 49.0661),
        place("Kazakhstan", "Almaty", "🇰🇿", 42, 43.2220, 76.8512),
        place("Armenia", "Yerevan", "🇦🇲", 48, 40.1792, 44.4991),
        place("Georgia", "Tbilisi", "🇬🇪", 52, 41.7151, 44.8271),
        place("Turkey", "Istanbul", "🇹🇷", 58, 41.0082, 28.9784),
        place("Finland", "Helsinki", "🇫🇮", 64, 60.1699, 24.9384),
        place("Sweden", "Stockholm", "🇸🇪", 69, 59.3293, 18.0686),
        place("Poland", "Warsaw", "🇵🇱", 58, 52.2297, 21.0122),
        place("Germany", "Frankfurt", "🇩🇪", 74, 50.1109, 8.6821),
        place("Netherlands", "Amsterdam", "🇳🇱", 78, 52.3676, 4.9041),
        place("France", "Paris", "🇫🇷", 88, 48.8566, 2.3522),
        place("United Kingdom", "London", "🇬🇧", 94, 51.5072, -0.1276),
        place("United States", "New York", "🇺🇸", 128, 40.7128, -74.0060),
    ]

    private static let bangkokServers: [VPNLocation] = [
        place("Thailand", "Bangkok", "🇹🇭", 29, 13.7563, 100.5018, kind: .lte),
        place("Thailand", "Phuket", "🇹🇭", 41, 7.8804, 98.3923),
        place("Vietnam", "Ho Chi Minh City", "🇻🇳", 54, 10.8231, 106.6297),
        place("Cambodia", "Phnom Penh", "🇰🇭", 57, 11.5564, 104.9282),
        place("Malaysia", "Kuala Lumpur", "🇲🇾", 61, 3.1390, 101.6869),
        place("Singapore", "Singapore", "🇸🇬", 62, 1.3521, 103.8198),
        place("Indonesia", "Jakarta", "🇮🇩", 70, -6.2088, 106.8456),
        place("Philippines", "Manila", "🇵🇭", 76, 14.5995, 120.9842),
        place("Hong Kong", "Hong Kong", "🇭🇰", 80, 22.3193, 114.1694),
        place("Taiwan", "Taipei", "🇹🇼", 84, 25.0330, 121.5654),
        place("Japan", "Tokyo", "🇯🇵", 88, 35.6762, 139.6503),
        place("South Korea", "Seoul", "🇰🇷", 91, 37.5665, 126.9780),
        place("Australia", "Sydney", "🇦🇺", 118, -33.8688, 151.2093),
        place("India", "Mumbai", "🇮🇳", 96, 19.0760, 72.8777),
        place("China", "Shanghai", "🇨🇳", 92, 31.2304, 121.4737),
    ]

    private static let berlinServers: [VPNLocation] = [
        place("Germany", "Berlin", "🇩🇪", 48, 52.5200, 13.4050, kind: .lte),
        place("Germany", "Munich", "🇩🇪", 55, 48.1351, 11.5820),
        place("Germany", "Frankfurt", "🇩🇪", 51, 50.1109, 8.6821),
        place("Austria", "Vienna", "🇦🇹", 46, 48.2082, 16.3738),
        place("Czech Republic", "Prague", "🇨🇿", 44, 50.0755, 14.4378),
        place("Poland", "Warsaw", "🇵🇱", 52, 52.2297, 21.0122),
        place("Hungary", "Budapest", "🇭🇺", 58, 47.4979, 19.0402),
        place("Switzerland", "Zurich", "🇨🇭", 62, 47.3769, 8.5417),
        place("France", "Paris", "🇫🇷", 71, 48.8566, 2.3522),
        place("Belgium", "Brussels", "🇧🇪", 68, 50.8503, 4.3517),
        place("Netherlands", "Amsterdam", "🇳🇱", 66, 52.3676, 4.9041),
        place("Denmark", "Copenhagen", "🇩🇰", 63, 55.6761, 12.5683),
        place("Italy", "Rome", "🇮🇹", 79, 41.9028, 12.4964),
        place("Spain", "Madrid", "🇪🇸", 84, 40.4168, -3.7038),
        place("Portugal", "Lisbon", "🇵🇹", 90, 38.7223, -9.1393),
    ]

    private static let londonServers: [VPNLocation] = [
        place("United Kingdom", "London", "🇬🇧", 94, 51.5072, -0.1276, kind: .lte),
        place("United Kingdom", "Manchester", "🇬🇧", 101, 53.4808, -2.2426),
        place("Ireland", "Dublin", "🇮🇪", 98, 53.3498, -6.2603),
        place("France", "Paris", "🇫🇷", 88, 48.8566, 2.3522),
        place("Netherlands", "Amsterdam", "🇳🇱", 78, 52.3676, 4.9041),
        place("Germany", "Frankfurt", "🇩🇪", 82, 50.1109, 8.6821),
        place("Spain", "Madrid", "🇪🇸", 96, 40.4168, -3.7038),
        place("United States", "New York", "🇺🇸", 128, 40.7128, -74.0060),
        place("United States", "Los Angeles", "🇺🇸", 156, 34.0522, -118.2437),
        place("Canada", "Toronto", "🇨🇦", 134, 43.6532, -79.3832),
        place("Brazil", "São Paulo", "🇧🇷", 188, -23.5558, -46.6396),
        place("Mexico", "Mexico City", "🇲🇽", 162, 19.4326, -99.1332),
        place("United Arab Emirates", "Dubai", "🇦🇪", 142, 25.2048, 55.2708),
        place("South Africa", "Johannesburg", "🇿🇦", 176, -26.2041, 28.0473),
        place("Japan", "Tokyo", "🇯🇵", 210, 35.6762, 139.6503),
    ]
#endif

    func importFromURL(_ urlString: String) -> Result<VPNProvider, VPNImportError> {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidURL) }

        let lowered = trimmed.lowercased()
        if lowered == "bad-link" || lowered.contains("bad-link") {
            return .failure(.unreadable)
        }

        let templateIndex = onboardingImportTemplateIndex
        let template = VPNProvider.samples[templateIndex]
        let importKey = "import-\(templateIndex)-\(nextImportIndex)"

        if UserDefaults.standard.stringArray(forKey: Self.importedKeysKey)?.contains(importKey) == true {
            return .failure(.duplicate)
        }

        let imported = VPNProvider(
            id: UUID(),
            name: template.name,
            iconSymbol: template.iconSymbol,
            kind: .imported,
            status: template.status,
            servers: template.servers,
            subscriptionURL: trimmed,
            lastUpdated: .now,
            expiresAt: template.expiresAt,
            includedInSmartAuto: template.includedInSmartAuto,
            providerMessage: onboardingProviderMessage(for: template),
            providerMessageUpdatedAt: .now
        )

        if providers.contains(where: { $0.name == imported.name && $0.kind == .imported }) {
            return .failure(.duplicate)
        }

        if !hasCompletedOnboarding {
            prepareForFirstImport()
        } else if !providers.contains(where: { $0.kind == .velvetFeatured }) {
            insertVelvetIfMissing()
        }

        providers.append(imported)
        nextImportIndex += 1
        persistImportedKey(importKey)
        persistSnapshots()
        highlight(imported.id)
        if VPNReleaseProfile.isRelease1 {
            reconcileActiveProvider()
        } else {
            setActiveProvider(id: imported.id)
        }
        VPNLogsStore.shared.append("Imported \(imported.name)")

        return .success(imported)
    }

    func remove(id: UUID) {
        guard let provider = providers.first(where: { $0.id == id }) else { return }
        providers.removeAll { $0.id == id }
        if providers.isEmpty {
            providers = [VPNProvider.samples[0]]
        }
        persistImportedKeysFromProviders()
        persistSnapshots()
        if highlightedProviderID == id {
            highlightedProviderID = nil
        }
        reconcileActiveProvider()
        VPNLogsStore.shared.append("Removed \(provider.name)")
    }

    func update(id: UUID, mutate: (inout VPNProvider) -> Void) {
        guard let index = providers.firstIndex(where: { $0.id == id }) else { return }
        mutate(&providers[index])
        persistSnapshots()
    }

    func setIncludedInSmartAuto(id: UUID, enabled: Bool) {
        update(id: id) { provider in
            provider.includedInSmartAuto = enabled && provider.status.isActive
        }
    }

    func renameProvider(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id: id) { $0.name = trimmed }
        VPNLogsStore.shared.append("Renamed provider to \(trimmed)")
    }

    func updateSubscriptionURL(id: UUID, url: String?) {
        update(id: id) { $0.subscriptionURL = url }
    }

    /// Prototype purchase: adds a block of traffic. An expired subscription becomes active again.
    func purchaseTraffic(id: UUID) {
        update(id: id) { provider in
            switch provider.status {
            case let .active(count, _):
                provider.status = .active(locationCount: count, trafficRemaining: "500 GB left")
            case .expired:
                provider.status = .active(
                    locationCount: max(provider.servers.count, 1),
                    trafficRemaining: "100 GB left"
                )
                provider.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: .now)
                provider.includedInSmartAuto = true
            }
            provider.lastUpdated = .now
        }
        VPNLogsStore.shared.append("Bought traffic for \(providerName(id: id) ?? "subscription")")
    }

    func renewSubscription(id: UUID) {
        update(id: id) { provider in
            provider.status = .active(
                locationCount: max(provider.servers.count, 1),
                trafficRemaining: "100 GB left"
            )
            provider.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: .now)
            provider.includedInSmartAuto = true
            provider.lastUpdated = .now
            provider.providerMessageUpdatedAt = .now
        }
        VPNLogsStore.shared.append("Renewed \(providerName(id: id) ?? "subscription")")
    }

    func refreshSubscription(id: UUID) async -> Bool {
        isRefreshing = true
        defer { isRefreshing = false }

        try? await Task.sleep(for: .milliseconds(900))
        guard providers.contains(where: { $0.id == id }) else { return false }

        update(id: id) { provider in
            provider.lastUpdated = .now
            provider.providerMessageUpdatedAt = .now
            if provider.providerMessage == nil {
                provider.providerMessage = "Subscription refreshed · \(provider.name)"
            }
            if case let .active(count, traffic) = provider.status {
                provider.status = .active(locationCount: count + Int.random(in: 1...5), trafficRemaining: traffic)
            }
        }
        VPNLogsStore.shared.append("Updated \(providerName(id: id) ?? "subscription")")
        return true
    }

    func refreshAllActiveSubscriptions() async -> Int {
        isRefreshing = true
        defer { isRefreshing = false }

        let activeIDs = providers.filter(\.status.isActive).map(\.id)
        try? await Task.sleep(for: .milliseconds(700))

        for id in activeIDs {
            update(id: id) { provider in
                provider.lastUpdated = .now
                provider.providerMessageUpdatedAt = .now
                if case let .active(count, traffic) = provider.status {
                    provider.status = .active(locationCount: count + 1, trafficRemaining: traffic)
                }
            }
        }

        if !activeIDs.isEmpty {
            VPNLogsStore.shared.append("Updated \(activeIDs.count) active subscriptions")
        }
        return activeIDs.count
    }

    func provider(id: UUID) -> VPNProvider? {
        providers.first { $0.id == id }
    }

    func providerPendingDeletion(from resolvedConnection: VPNResolvedConnection?) -> VPNProvider? {
        if let resolvedConnection {
            return resolvedConnection.provider
        }
        return providers.last(where: { $0.kind == .imported })
    }

    private func providerName(id: UUID) -> String? {
        providers.first { $0.id == id }?.name
    }

    private func loadPersistedProviders() {
        let keys = UserDefaults.standard.stringArray(forKey: Self.importedKeysKey) ?? []
        if keys.isEmpty {
            providers = VPNProvider.samples
        } else {
            providers = []
            for key in keys {
                guard let imported = demoProvider(forImportKey: key) else { continue }
                providers.append(imported)
            }
            if providers.filter({ $0.kind == .imported }).count > 1 {
                insertVelvetIfMissing()
            }
        }
        nextImportIndex = max(providers.filter { $0.kind == .imported }.count + 1, 1)
        applySnapshots()
    }

    private func demoProvider(forImportKey key: String) -> VPNProvider? {
        guard key.hasPrefix("import-") else { return nil }
        let parts = key.split(separator: "-")
        guard parts.count >= 2, let templateIndex = Int(parts[1]) else { return nil }
        guard VPNProvider.samples.indices.contains(templateIndex) else { return nil }
        let template = VPNProvider.samples[templateIndex]
        return VPNProvider(
            id: UUID(),
            name: template.name,
            iconSymbol: template.iconSymbol,
            kind: .imported,
            status: template.status,
            servers: template.servers,
            subscriptionURL: template.subscriptionURL,
            lastUpdated: template.lastUpdated,
            expiresAt: template.expiresAt,
            includedInSmartAuto: template.includedInSmartAuto,
            providerMessage: template.providerMessage,
            providerMessageUpdatedAt: template.providerMessageUpdatedAt
        )
    }

    private struct ScopedProviderID: Codable {
        let id: UUID
    }

    private enum PersistedCatalogScope: Codable {
        case allNetworks
        case provider(UUID)
    }

    private func loadProviderScope() {
        guard let data = UserDefaults.standard.data(forKey: Self.providerScopeKey) else {
            providerScope = .allNetworks
            catalogScopeWasPersisted = false
            return
        }
        if let persisted = try? JSONDecoder().decode(PersistedCatalogScope.self, from: data) {
            catalogScopeWasPersisted = true
            switch persisted {
            case .allNetworks:
                providerScope = .allNetworks
            case let .provider(id):
                providerScope = .provider(id)
            }
            return
        }
        if let scoped = try? JSONDecoder().decode(ScopedProviderID.self, from: data) {
            catalogScopeWasPersisted = true
            providerScope = .provider(scoped.id)
            return
        }
        providerScope = .allNetworks
        catalogScopeWasPersisted = false
    }

    private func persistProviderScope() {
        catalogScopeWasPersisted = true
        let persisted: PersistedCatalogScope = switch providerScope {
        case .allNetworks: .allNetworks
        case let .provider(id): .provider(id)
        }
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        UserDefaults.standard.set(data, forKey: Self.providerScopeKey)
    }

    private struct ProviderSnapshot: Codable {
        let id: UUID
        var name: String
        var status: VPNProvider.Status
        var subscriptionURL: String?
        var lastUpdated: Date?
        var expiresAt: Date?
        var includedInSmartAuto: Bool
        var providerMessage: String?
        var providerMessageUpdatedAt: Date?
    }

    private func persistSnapshots() {
        let snapshots = providers.map {
            ProviderSnapshot(
                id: $0.id,
                name: $0.name,
                status: $0.status,
                subscriptionURL: $0.subscriptionURL,
                lastUpdated: $0.lastUpdated,
                expiresAt: $0.expiresAt,
                includedInSmartAuto: $0.includedInSmartAuto,
                providerMessage: $0.providerMessage,
                providerMessageUpdatedAt: $0.providerMessageUpdatedAt
            )
        }
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: Self.providerSnapshotsKey)
    }

    private func applySnapshots() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.providerSnapshotsKey),
            let snapshots = try? JSONDecoder().decode([ProviderSnapshot].self, from: data)
        else { return }

        for snapshot in snapshots {
            guard let index = providers.firstIndex(where: { $0.id == snapshot.id }) else { continue }
            providers[index].name = snapshot.name
            providers[index].status = snapshot.status
            providers[index].subscriptionURL = snapshot.subscriptionURL
            providers[index].lastUpdated = snapshot.lastUpdated
            providers[index].expiresAt = snapshot.expiresAt
            providers[index].includedInSmartAuto = snapshot.includedInSmartAuto
            providers[index].providerMessage = snapshot.providerMessage.map {
                VPNProvider.strippingIdentityFooter(from: $0)
            }
            providers[index].providerMessageUpdatedAt = snapshot.providerMessageUpdatedAt
        }

        if case let .provider(id) = providerScope,
           !providers.contains(where: { $0.id == id }) {
            if VPNReleaseProfile.isRelease1 {
                reconcileActiveProvider()
            } else {
                providerScope = .allNetworks
                persistProviderScope()
            }
        } else {
            reconcileActiveProvider()
        }
    }

    func reconcileActiveProvider() {
        guard VPNReleaseProfile.isRelease1 else { return }

        let validActiveID = resolvedActiveProviderID()
        if validActiveID != activeProviderID {
            activeProviderID = validActiveID
            persistActiveProviderID()
        }

        switch providerScope {
        case .allNetworks:
            if !catalogScopeWasPersisted, let validActiveID {
                providerScope = .provider(validActiveID)
                persistProviderScope()
            }
        case let .provider(id):
            if !providers.contains(where: { $0.id == id }), let validActiveID {
                providerScope = .provider(validActiveID)
                persistProviderScope()
            }
        }
    }

    private func resolvedActiveProviderID() -> UUID? {
        if let activeProviderID, providers.contains(where: { $0.id == activeProviderID }) {
            return activeProviderID
        }
        return providers.first(where: { $0.kind == .velvetFeatured && $0.status.isActive })?.id
            ?? providers.first(where: \.isEligibleForAutoConnect)?.id
            ?? providers.first?.id
    }

    private func loadActiveProviderID() {
        guard
            let raw = UserDefaults.standard.string(forKey: Self.activeProviderKey),
            let id = UUID(uuidString: raw)
        else { return }
        activeProviderID = id
    }

    private func loadSwitcherHiddenIDs() {
        let raw = UserDefaults.standard.stringArray(forKey: Self.switcherHiddenKey) ?? []
        switcherHiddenIDs = Set(raw.compactMap(UUID.init(uuidString:)))
    }

    private func persistSwitcherHiddenIDs() {
        UserDefaults.standard.set(switcherHiddenIDs.map(\.uuidString), forKey: Self.switcherHiddenKey)
    }

    private func persistActiveProviderID() {
        guard let activeProviderID else {
            UserDefaults.standard.removeObject(forKey: Self.activeProviderKey)
            return
        }
        UserDefaults.standard.set(activeProviderID.uuidString, forKey: Self.activeProviderKey)
    }

    private func persistImportedKey(_ key: String) {
        var keys = UserDefaults.standard.stringArray(forKey: Self.importedKeysKey) ?? []
        keys.append(key)
        UserDefaults.standard.set(keys, forKey: Self.importedKeysKey)
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    private func persistImportedKeysFromProviders() {
        let imported = providers.filter { $0.kind == .imported }
        let keys = imported.enumerated().compactMap { index, provider -> String? in
            guard let sampleIndex = VPNProvider.samples.firstIndex(where: { $0.name == provider.name }) else {
                return "import-1-\(index + 1)"
            }
            return "import-\(sampleIndex)-\(index + 1)"
        }
        UserDefaults.standard.set(keys, forKey: Self.importedKeysKey)
    }

    private func highlight(_ id: UUID) {
        highlightedProviderID = id
        highlightTask?.cancel()
        highlightTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, highlightedProviderID == id else { return }
            highlightedProviderID = nil
        }
    }

    private var onboardingImportTemplateIndex: Int {
        if !hasCompletedOnboarding {
            return Self.thirdPartyDemoTemplateIndex
        }
        return min(nextImportIndex, VPNProvider.samples.count - 2)
    }

    private func onboardingProviderMessage(for template: VPNProvider) -> String? {
        if !hasCompletedOnboarding {
            return VPNProvider.velvetDemoMessage
        }
        return template.providerMessage
    }

    private func prepareForFirstImport() {
        providers = []
        nextImportIndex = 1
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        UserDefaults.standard.set([String](), forKey: Self.importedKeysKey)
    }

    private func insertVelvetIfMissing() {
        guard !providers.contains(where: { $0.kind == .velvetFeatured }) else { return }
        providers.insert(VPNProvider.samples[0], at: 0)
    }
}
