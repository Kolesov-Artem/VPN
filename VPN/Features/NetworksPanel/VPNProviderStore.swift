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
    private static let prototypeCycleKey = "velvet.prototypeOnboardingCycle"
    private static let thirdPartyDemoTemplateIndex = 2

    var providers: [VPNProvider] = []
    var highlightedProviderID: UUID?
    var isRefreshing = false
    var providerScope: VPNProviderScope = .allNetworks
    var hiddenRenewalBannerIDs: Set<UUID> = []

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

    var soleProvider: VPNProvider? {
        guard providers.count == 1 else { return nil }
        return providers.first
    }

    private var highlightTask: Task<Void, Never>?
    private var nextImportIndex = 1

    init() {
        loadProviderScope()
        if UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            loadPersistedProviders()
        }
    }

    func setProviderScope(_ scope: VPNProviderScope) {
        providerScope = scope
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
        setProviderScope(.allNetworks)
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
        hiddenRenewalBannerIDs.removeAll()
        providers = []
        nextImportIndex = 1
        highlightedProviderID = nil
        providerScope = .allNetworks
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
            var velvet = VPNProvider.samples[0]
            let template = VPNProvider.samples[Self.thirdPartyDemoTemplateIndex]
            let imported = makeImportedProvider(from: template, templateIndex: Self.thirdPartyDemoTemplateIndex)
            providers = [velvet, imported]
            nextImportIndex = Self.thirdPartyDemoTemplateIndex + 1
            highlightedProviderID = nil
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            UserDefaults.standard.set(
                ["import-\(Self.thirdPartyDemoTemplateIndex)-1"],
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

    private func makeImportedProvider(from template: VPNProvider, templateIndex: Int) -> VPNProvider {
        VPNProvider(
            id: UUID(),
            name: template.name,
            iconSymbol: template.iconSymbol,
            kind: .imported,
            status: template.status,
            servers: template.servers,
            subscriptionURL: template.subscriptionURL ?? "https://provider.example/sub/demo",
            lastUpdated: .now,
            expiresAt: template.expiresAt,
            includedInSmartAuto: true,
            providerMessage: template.providerMessage,
            providerMessageUpdatedAt: .now
        )
    }
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

    private func loadProviderScope() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.providerScopeKey),
            let scoped = try? JSONDecoder().decode(ScopedProviderID.self, from: data)
        else {
            providerScope = .allNetworks
            return
        }
        providerScope = .provider(scoped.id)
    }

    private func persistProviderScope() {
        switch providerScope {
        case .allNetworks:
            UserDefaults.standard.removeObject(forKey: Self.providerScopeKey)
        case let .provider(id):
            guard let data = try? JSONEncoder().encode(ScopedProviderID(id: id)) else { return }
            UserDefaults.standard.set(data, forKey: Self.providerScopeKey)
        }
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
            providers[index].providerMessage = snapshot.providerMessage
            providers[index].providerMessageUpdatedAt = snapshot.providerMessageUpdatedAt
        }

        if case let .provider(id) = providerScope,
           !providers.contains(where: { $0.id == id }) {
            providerScope = .allNetworks
            persistProviderScope()
        }
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
