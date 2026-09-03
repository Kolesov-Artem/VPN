import Foundation

enum VPNHomeFormat: String, CaseIterable, Identifiable {
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

struct VPNProvider: Identifiable, Equatable {
    enum Status: Equatable {
        case active(locationCount: Int, trafficRemaining: String)
        case expired
    }

    enum Kind: Equatable {
        case velvetFeatured
        case imported
    }

    let id: UUID
    let name: String
    let iconSymbol: String
    let kind: Kind
    let status: Status
    let servers: [VPNLocation]

    var isEligibleForAutoConnect: Bool {
        if case .active = status { true } else { false }
    }

    var subtitle: String {
        switch status {
        case let .active(locationCount, trafficRemaining):
            "\(locationCount) locations · \(trafficRemaining)"
        case .expired:
            "Subscription expired"
        }
    }
}

enum VPNSmartPreset: String, CaseIterable, Identifiable, Equatable {
    case auto
    case russia
    case europe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Smart-Auto"
        case .russia: "Smart-Russia"
        case .europe: "Smart-Europe"
        }
    }

    var subtitle: String {
        switch self {
        case .auto: "Fastest across all networks"
        case .russia: "Best server in Russia"
        case .europe: "Best server in Europe"
        }
    }
}

enum VPNLocationSelection: Equatable {
    case smart(VPNSmartPreset)
    case manual(location: VPNLocation, providerID: UUID)
}

struct VPNResolvedConnection: Equatable {
    let location: VPNLocation
    let provider: VPNProvider
    let selection: VPNLocationSelection

    var summarySubtitle: String {
        let presetLabel: String = switch selection {
        case let .smart(preset): preset.title
        case .manual: "Manual"
        }
        return "\(presetLabel) · \(location.city) · \(location.pingLabel) · \(provider.name)"
    }
}

struct VPNNetworkLocation: Identifiable, Equatable {
    let location: VPNLocation
    let provider: VPNProvider

    var id: UUID { location.id }
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

        case let .smart(preset):
            let candidates = eligibleLocations(from: providers, preset: preset)
            guard
                let best = candidates.min(by: { $0.location.ping < $1.location.ping })
            else { return nil }
            return VPNResolvedConnection(
                location: best.location,
                provider: best.provider,
                selection: .smart(preset)
            )
        }
    }

    static func mergedLocations(from providers: [VPNProvider]) -> [VPNNetworkLocation] {
        providers.flatMap { provider in
            provider.servers
                .filter { $0.kind != .smart }
                .map { VPNNetworkLocation(location: $0, provider: provider) }
        }
        .sorted { $0.location.ping < $1.location.ping }
    }

    static func qualityLabel(for preset: VPNSmartPreset, providers: [VPNProvider]) -> String {
        guard let best = resolve(providers: providers, selection: .smart(preset))?.location else {
            return "—"
        }

        switch best.signal {
        case .excellent: return "Best"
        case .good: return "Good"
        case .fair: return "Fair"
        }
    }

    private static func eligibleLocations(
        from providers: [VPNProvider],
        preset: VPNSmartPreset
    ) -> [VPNNetworkLocation] {
        mergedLocations(from: providers.filter(\.isEligibleForAutoConnect))
            .filter { networkLocation in
                switch preset {
                case .auto:
                    true
                case .russia:
                    networkLocation.location.name.localizedCaseInsensitiveContains("Russia")
                case .europe:
                    europeanCountries.contains(networkLocation.location.name)
                }
            }
    }

    private static let europeanCountries: Set<String> = [
        "Finland", "Sweden", "Germany", "Netherlands", "Poland",
        "France", "United Kingdom", "Switzerland", "Turkey",
    ]
}

extension VPNProvider {
    static let samples: [VPNProvider] = [
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
            ]
        ),
        VPNProvider(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!,
            name: "VPN name 2",
            iconSymbol: "mountain.2.fill",
            kind: .imported,
            status: .active(locationCount: 412, trafficRemaining: "86 GB left"),
            servers: [
                VPNLocation(name: "Kazakhstan", city: "Almaty", flag: "🇰🇿", kind: .lte, ping: 42, coordinate: GeoCoordinate(latitude: 43.2220, longitude: 76.8512)),
                VPNLocation(name: "Armenia", city: "Yerevan", flag: "🇦🇲", kind: .standard, ping: 48, coordinate: GeoCoordinate(latitude: 40.1792, longitude: 44.4991)),
                VPNLocation(name: "Georgia", city: "Tbilisi", flag: "🇬🇪", kind: .lte, ping: 52, coordinate: GeoCoordinate(latitude: 41.7151, longitude: 44.8271)),
            ]
        ),
        VPNProvider(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!,
            name: "VPN name 3",
            iconSymbol: "globe.europe.africa.fill",
            kind: .imported,
            status: .active(locationCount: 218, trafficRemaining: "34 GB left"),
            servers: [
                VPNLocation(name: "Germany", city: "Frankfurt", flag: "🇩🇪", kind: .standard, ping: 71, coordinate: GeoCoordinate(latitude: 50.1109, longitude: 8.6821)),
                VPNLocation(name: "France", city: "Paris", flag: "🇫🇷", kind: .standard, ping: 88, coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)),
                VPNLocation(name: "United Kingdom", city: "London", flag: "🇬🇧", kind: .standard, ping: 94, coordinate: GeoCoordinate(latitude: 51.5072, longitude: -0.1276)),
            ]
        ),
        VPNProvider(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!,
            name: "VPN name 4",
            iconSymbol: "network",
            kind: .imported,
            status: .expired,
            servers: [
                VPNLocation(name: "United States", city: "New York", flag: "🇺🇸", kind: .standard, ping: 132, coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.0060)),
            ]
        ),
    ]
}
