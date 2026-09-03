import Foundation
import Observation

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
    private static let importedKeysKey = "velvet.importedProviderKeys"
    private static let providerSnapshotsKey = "velvet.providerSnapshots.v2"
    private static let providerScopeKey = "velvet.providerScope.v1"

    var providers: [VPNProvider] = []
    var highlightedProviderID: UUID?
    var isRefreshing = false
    var providerScope: VPNProviderScope = .allNetworks

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

    func resetProviderScope() {
        setProviderScope(.allNetworks)
    }

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    func resetToVelvetOnly() {
        providers = [VPNProvider.samples[0]]
        nextImportIndex = 1
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        UserDefaults.standard.set([String](), forKey: Self.importedKeysKey)
        persistSnapshots()
    }

    func importFromURL(_ urlString: String) -> Result<VPNProvider, VPNImportError> {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidURL) }

        let lowered = trimmed.lowercased()
        if lowered == "bad-link" || lowered.contains("bad-link") {
            return .failure(.unreadable)
        }

        let templateIndex = min(nextImportIndex, VPNProvider.samples.count - 2)
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
            providerMessage: template.providerMessage,
            providerMessageUpdatedAt: .now
        )

        if providers.contains(where: { $0.name == imported.name && $0.kind == .imported }) {
            return .failure(.duplicate)
        }

        if !hasCompletedOnboarding {
            resetToVelvetOnly()
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
            providers = [VPNProvider.samples[0]]
            for key in keys {
                guard let imported = demoProvider(forImportKey: key) else { continue }
                providers.append(imported)
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
}
