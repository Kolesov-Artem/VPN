import CoreGraphics
import Foundation

enum AppRoute {
    case onboarding
    case home
}

enum VPNConnectionState: Equatable {
    case disconnected
    case connecting(race: RouteRaceProgress?)
    case connected(route: ActiveRoute, alternates: [RouteCandidate])

    var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var activeRoute: ActiveRoute? {
        if case .connected(let route, _) = self { return route }
        return nil
    }

    var raceProgress: RouteRaceProgress? {
        if case .connecting(let race) = self { return race }
        return nil
    }

    var alternates: [RouteCandidate] {
        if case .connected(_, let alternates) = self { return alternates }
        return []
    }

    mutating func handlePrimaryAction() {
        switch self {
        case .disconnected:
            self = .connecting(race: nil)
        case .connecting:
            break
        case .connected:
            self = .disconnected
        }
    }

    mutating func updateRaceProgress(_ progress: RouteRaceProgress) {
        guard case .connecting = self else { return }
        self = .connecting(race: progress)
    }

    mutating func completeConnection(route: ActiveRoute, alternates: [RouteCandidate]) {
        guard case .connecting = self else { return }
        self = .connected(route: route, alternates: alternates)
    }
}

/// Where a server sits on the globe. Kept free of CoreLocation so the model
/// stays comparable and testable without importing MapKit types.
struct GeoCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    /// Great-circle distance in metres, used to resolve a map tap to the
    /// closest server rather than to whatever country polygon was hit.
    func distance(to other: GeoCoordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)

        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}

struct VPNLocation: Identifiable, Equatable {
    enum Kind: Equatable {
        case smart
        case lte
        case standard

        var title: String {
            switch self {
            case .smart: "Smart"
            case .lte: "LTE"
            case .standard: "Standard"
            }
        }
    }

    enum Signal: Equatable {
        case excellent
        case good
        case fair
    }

    let id: UUID
    let name: String
    let city: String
    let flag: String
    let kind: Kind
    let ping: Int
    /// Nil for the automatic server, which stands for the whole network rather
    /// than one place on the map.
    let coordinate: GeoCoordinate?

    init(
        id: UUID = UUID(),
        name: String,
        city: String,
        flag: String,
        kind: Kind,
        ping: Int,
        coordinate: GeoCoordinate? = nil
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.flag = flag
        self.kind = kind
        self.ping = ping
        self.coordinate = coordinate
    }

    var subtitle: String {
        if kind == .smart {
            return "Auto · best of all networks"
        }
        return "\(city) · \(kind.title)"
    }

    var displayPing: Int {
        VPNNetworkCatalog.bestPing(for: self)
    }

    var isSmart: Bool {
        kind == .smart
    }

    var pingLabel: String {
        "\(ping) ms"
    }

    var signal: Signal {
        switch displayPing {
        case ..<60: .excellent
        case ..<120: .good
        default: .fair
        }
    }

    var searchText: String {
        "\(name) \(city) \(kind.title)"
    }

    /// Stable across launches, unlike the prototype UUID, so favourites can
    /// live in AppStorage without changing the public server model.
    var persistenceKey: String {
        "\(name)|\(city)|\(kind.title)"
    }
}

struct VPNCountryGroup: Identifiable, Equatable {
    var id: String { name }

    let name: String
    let flag: String
    let locations: [VPNLocation]
}

enum VPNLocationFilter: CaseIterable, Identifiable {
    case all
    case lte
    case standard

    var id: Int {
        switch self {
        case .all: 0
        case .lte: 1
        case .standard: 2
        }
    }

    var title: String {
        switch self {
        case .all: "All types"
        case .lte: "LTE"
        case .standard: "Standard"
        }
    }

    func accepts(_ location: VPNLocation) -> Bool {
        switch self {
        case .all: true
        case .lte: location.kind == .lte
        case .standard: location.kind == .standard
        }
    }
}

enum VPNLocationSort: CaseIterable, Identifiable {
    case fastest
    case country

    var id: Int {
        switch self {
        case .fastest: 0
        case .country: 1
        }
    }

    var title: String {
        switch self {
        case .fastest: "Fastest first"
        case .country: "Country A–Z"
        }
    }
}

/// Everything the location list needs to narrow itself down. Keeping it in one
/// value means the panel holds a single piece of state, and the chip strip can
/// be derived instead of tracked separately.
struct VPNLocationQuery: Equatable {
    enum Chip: Identifiable, Equatable {
        case filter(VPNLocationFilter)
        case sort(VPNLocationSort)
        case fastOnly

        var id: String {
            switch self {
            case .filter(let filter): "filter-\(filter.id)"
            case .sort(let sort): "sort-\(sort.id)"
            case .fastOnly: "fast-only"
            }
        }

        var title: String {
            switch self {
            case .filter(let filter): filter.title
            case .sort(let sort): sort.title
            case .fastOnly: "Under \(VPNLocation.fastPingThreshold) ms"
            }
        }
    }

    var text = ""
    var filter = VPNLocationFilter.all
    var sort = VPNLocationSort.fastest
    var fastOnly = false

    /// True while nothing but free text is narrowing the list, which is when the
    /// chip strip stays hidden and the sheet shows only one row of controls.
    var isDefault: Bool {
        filter == .all && sort == .fastest && !fastOnly
    }

    var activeChips: [Chip] {
        var chips: [Chip] = []

        if filter != .all {
            chips.append(.filter(filter))
        }
        if fastOnly {
            chips.append(.fastOnly)
        }
        if sort != .fastest {
            chips.append(.sort(sort))
        }

        return chips
    }

    mutating func clear(_ chip: Chip) {
        switch chip {
        case .filter: filter = .all
        case .sort: sort = .fastest
        case .fastOnly: fastOnly = false
        }
    }

    mutating func resetFilters() {
        filter = .all
        sort = .fastest
        fastOnly = false
    }
}

extension VPNLocation {
    /// Latency below which a server is worth surfacing as a fast option.
    static let fastPingThreshold = 60

    /// Applies the free-text query, the type filter and the latency cut-off,
    /// then sorts with the automatic server pinned first so the safest choice
    /// needs no reading.
    static func matching(
        _ query: VPNLocationQuery,
        in locations: [VPNLocation] = VPNLocation.samples
    ) -> [VPNLocation] {
        let trimmedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)

        return locations
            .filter { location in
                guard query.filter.accepts(location) else { return false }
                guard !query.fastOnly || location.ping < fastPingThreshold else { return false }
                guard !trimmedQuery.isEmpty else { return true }
                return location.searchText.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { lhs, rhs in
                if (lhs.kind == .smart) != (rhs.kind == .smart) {
                    return lhs.kind == .smart
                }

                switch query.sort {
                case .fastest:
                    return lhs.displayPing < rhs.displayPing
                case .country:
                    if lhs.name == rhs.name {
                        return lhs.city.localizedCompare(rhs.city) == .orderedAscending
                    }
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
            }
    }

    /// Groups filtered results without losing their current sort order. The
    /// first server determines where a country appears; servers within it keep
    /// their latency or alphabetical order from `matching`.
    static func countryGroups(from locations: [VPNLocation]) -> [VPNCountryGroup] {
        let manualLocations = locations.filter { $0.kind != .smart }
        let countryOrder = manualLocations.reduce(into: [String]()) { order, location in
            guard !order.contains(location.name) else { return }
            order.append(location.name)
        }

        return countryOrder.compactMap { country in
            let servers = manualLocations.filter { $0.name == country }
            guard let first = servers.first else { return nil }
            return VPNCountryGroup(name: country, flag: first.flag, locations: servers)
        }
    }

    /// Resolves a point on the map to the server the user most likely meant.
    /// Matching by distance keeps taps working over open water and over
    /// countries Velvet has no server in, where a border hit test would fail.
    static func nearest(
        to coordinate: GeoCoordinate,
        in locations: [VPNLocation] = VPNLocation.samples
    ) -> VPNLocation? {
        locations
            .compactMap { location -> (VPNLocation, Double)? in
                guard let target = location.coordinate else { return nil }
                return (location, target.distance(to: coordinate))
            }
            .min { lhs, rhs in
                // Ties break on latency so the better server wins in cities
                // that host more than one exit node.
                lhs.1 == rhs.1 ? lhs.0.ping < rhs.0.ping : lhs.1 < rhs.1
            }?
            .0
    }

    static let samples = [
        VPNLocation(name: "Smart — Auto", city: "Fastest available server", flag: "✨", kind: .smart, ping: 24),
        VPNLocation(name: "Russia", city: "Moscow", flag: "🇷🇺", kind: .lte, ping: 18, coordinate: GeoCoordinate(latitude: 55.7558, longitude: 37.6173)),
        VPNLocation(name: "Russia", city: "Saint Petersburg", flag: "🇷🇺", kind: .standard, ping: 26, coordinate: GeoCoordinate(latitude: 59.9311, longitude: 30.3609)),
        VPNLocation(name: "Russia", city: "Yekaterinburg", flag: "🇷🇺", kind: .lte, ping: 34, coordinate: GeoCoordinate(latitude: 56.8389, longitude: 60.6057)),
        VPNLocation(name: "Kazakhstan", city: "Almaty", flag: "🇰🇿", kind: .lte, ping: 42, coordinate: GeoCoordinate(latitude: 43.2220, longitude: 76.8512)),
        VPNLocation(name: "Armenia", city: "Yerevan", flag: "🇦🇲", kind: .standard, ping: 48, coordinate: GeoCoordinate(latitude: 40.1792, longitude: 44.4991)),
        VPNLocation(name: "Georgia", city: "Tbilisi", flag: "🇬🇪", kind: .lte, ping: 52, coordinate: GeoCoordinate(latitude: 41.7151, longitude: 44.8271)),
        VPNLocation(name: "Turkey", city: "Istanbul", flag: "🇹🇷", kind: .standard, ping: 58, coordinate: GeoCoordinate(latitude: 41.0082, longitude: 28.9784)),
        VPNLocation(name: "Finland", city: "Helsinki", flag: "🇫🇮", kind: .standard, ping: 62, coordinate: GeoCoordinate(latitude: 60.1699, longitude: 24.9384)),
        VPNLocation(name: "Sweden", city: "Stockholm", flag: "🇸🇪", kind: .lte, ping: 66, coordinate: GeoCoordinate(latitude: 59.3293, longitude: 18.0686)),
        VPNLocation(name: "Germany", city: "Frankfurt", flag: "🇩🇪", kind: .standard, ping: 71, coordinate: GeoCoordinate(latitude: 50.1109, longitude: 8.6821)),
        VPNLocation(name: "Germany", city: "Berlin", flag: "🇩🇪", kind: .lte, ping: 74, coordinate: GeoCoordinate(latitude: 52.5200, longitude: 13.4050)),
        VPNLocation(name: "Netherlands", city: "Amsterdam", flag: "🇳🇱", kind: .standard, ping: 78, coordinate: GeoCoordinate(latitude: 52.3676, longitude: 4.9041)),
        VPNLocation(name: "Poland", city: "Warsaw", flag: "🇵🇱", kind: .lte, ping: 83, coordinate: GeoCoordinate(latitude: 52.2297, longitude: 21.0122)),
        VPNLocation(name: "France", city: "Paris", flag: "🇫🇷", kind: .standard, ping: 88, coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)),
        VPNLocation(name: "United Kingdom", city: "London", flag: "🇬🇧", kind: .standard, ping: 94, coordinate: GeoCoordinate(latitude: 51.5072, longitude: -0.1276)),
        VPNLocation(name: "Switzerland", city: "Zurich", flag: "🇨🇭", kind: .lte, ping: 99, coordinate: GeoCoordinate(latitude: 47.3769, longitude: 8.5417)),
        VPNLocation(name: "United Arab Emirates", city: "Dubai", flag: "🇦🇪", kind: .standard, ping: 118, coordinate: GeoCoordinate(latitude: 25.2048, longitude: 55.2708)),
        VPNLocation(name: "United States", city: "New York", flag: "🇺🇸", kind: .standard, ping: 132, coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.0060)),
        VPNLocation(name: "Singapore", city: "Singapore", flag: "🇸🇬", kind: .lte, ping: 168, coordinate: GeoCoordinate(latitude: 1.3521, longitude: 103.8198)),
    ]
}
