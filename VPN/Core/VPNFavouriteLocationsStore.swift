import Foundation

struct VPNFavouriteLocationEntry: Codable, Equatable, Identifiable {
    var id: String { Self.id(providerID: providerID, persistenceKey: persistenceKey) }

    let persistenceKey: String
    let name: String
    let city: String
    let flag: String
    let providerID: UUID
    let providerName: String

    static func id(providerID: UUID, persistenceKey: String) -> String {
        "\(providerID.uuidString)|\(persistenceKey)"
    }

    init(_ location: VPNNetworkLocation) {
        persistenceKey = location.location.persistenceKey
        name = location.location.name
        city = location.location.city
        flag = location.location.flag
        providerID = location.provider.id
        providerName = location.provider.name
    }
}

enum VPNFavouriteLocationsStore {
    static let storageKey = "velvet.favouriteLocationEntries"
    static let seededKey = "velvet.favouriteLocationsSeeded"
    static let limit = 5

    static func load(from stored: String) -> [VPNFavouriteLocationEntry] {
        guard let data = stored.data(using: .utf8), !stored.isEmpty else { return [] }
        return (try? JSONDecoder().decode([VPNFavouriteLocationEntry].self, from: data)) ?? []
    }

    static func encode(_ entries: [VPNFavouriteLocationEntry]) -> String {
        guard let data = try? JSONEncoder().encode(entries),
              let stored = String(data: data, encoding: .utf8) else {
            return ""
        }
        return stored
    }

    static func toggled(_ location: VPNNetworkLocation, in stored: String) -> String {
        var entries = load(from: stored)
        let entry = VPNFavouriteLocationEntry(location)
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.remove(at: index)
        } else {
            entries.insert(entry, at: 0)
            if entries.count > limit {
                entries = Array(entries.prefix(limit))
            }
        }
        return encode(entries)
    }

    /// A few ordinary servers so the quiet strip is visible the first time the prototype opens.
    static func demoEntries(from providers: [VPNProvider]) -> [VPNFavouriteLocationEntry] {
        let velvetID = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")
        let wanted: [(String, String)] = [
            ("SMART-Нидерланды", "Быстрый. Без рекламы"),
            ("SMART-Швеция", "Быстрый. Без рекламы"),
            ("SMART-Германия", "Быстрый. Без рекламы"),
        ]
        return wanted.compactMap { name, city in
            guard let provider = providers.first(where: { $0.id == velvetID }),
                  let server = provider.servers.first(where: {
                      $0.name == name && $0.city == city && $0.kind != .smart
                  })
            else { return nil }
            return VPNFavouriteLocationEntry(VPNNetworkLocation(location: server, provider: provider))
        }
    }
}
