import Foundation

struct VPNRecentLocationEntry: Codable, Equatable, Identifiable {
    var id: String { persistenceKey }
    let persistenceKey: String
    let name: String
    let city: String
    let flag: String
    let providerID: UUID
    let providerName: String
}

enum VPNRecentLocationsStore {
    private static let storageKey = "velvet.recentLocations"

    static func load() -> [VPNRecentLocationEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let entries = try? JSONDecoder().decode([VPNRecentLocationEntry].self, from: data)
        else {
            return []
        }
        return entries
    }

    static func record(_ networkLocation: VPNNetworkLocation) {
        let entry = VPNRecentLocationEntry(
            persistenceKey: networkLocation.location.persistenceKey,
            name: networkLocation.location.name,
            city: networkLocation.location.city,
            flag: networkLocation.location.flag,
            providerID: networkLocation.provider.id,
            providerName: networkLocation.provider.name
        )
        var entries = load().filter { $0.persistenceKey != entry.persistenceKey }
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(3))
        persist(entries)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func persist(_ entries: [VPNRecentLocationEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
