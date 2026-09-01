import Foundation

struct VPNProvider: Identifiable, Equatable {
    let id: UUID
    let name: String
    let accentSymbol: String
    var isEnabled: Bool
    var subscriptionLabel: String

    init(
        id: UUID = UUID(),
        name: String,
        accentSymbol: String,
        isEnabled: Bool = true,
        subscriptionLabel: String
    ) {
        self.id = id
        self.name = name
        self.accentSymbol = accentSymbol
        self.isEnabled = isEnabled
        self.subscriptionLabel = subscriptionLabel
    }
}

struct VPNEndpoint: Identifiable, Equatable {
    let id: UUID
    let providerID: UUID
    let locationKey: String
    let ping: Int
    let tunnelProtocol: String

    init(
        id: UUID = UUID(),
        providerID: UUID,
        locationKey: String,
        ping: Int,
        tunnelProtocol: String = "WireGuard"
    ) {
        self.id = id
        self.providerID = providerID
        self.locationKey = locationKey
        self.ping = ping
        self.tunnelProtocol = tunnelProtocol
    }
}

enum ConnectionTarget: Equatable {
    case smart
    case location(VPNLocation)
}

struct RouteCandidate: Equatable, Identifiable {
    var id: String { "\(provider.id.uuidString)-\(endpoint.id.uuidString)" }

    let provider: VPNProvider
    let endpoint: VPNEndpoint
    let location: VPNLocation
    let latency: Int
}

struct ActiveRoute: Equatable {
    let provider: VPNProvider
    let endpoint: VPNEndpoint
    let location: VPNLocation
    let latency: Int

    var summaryLine: String {
        "\(location.name) · \(provider.name) · \(latency) ms"
    }
}

struct RouteRaceProgress: Equatable {
    var testedCount: Int
    var totalCount: Int

    var label: String {
        "Testing routes… \(testedCount)/\(totalCount)"
    }

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(testedCount) / Double(totalCount)
    }
}

enum VPNNetworkCatalog {
    static let providers: [VPNProvider] = [
        VPNProvider(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!,
            name: "Mullvad",
            accentSymbol: "m.circle.fill",
            subscriptionLabel: "Renews Mar 2026"
        ),
        VPNProvider(
            id: UUID(uuidString: "A1000002-0000-4000-8000-000000000002")!,
            name: "Proton VPN",
            accentSymbol: "p.circle.fill",
            subscriptionLabel: "Renews Dec 2025"
        ),
        VPNProvider(
            id: UUID(uuidString: "A1000003-0000-4000-8000-000000000003")!,
            name: "IVPN",
            accentSymbol: "i.circle.fill",
            isEnabled: false,
            subscriptionLabel: "Expired"
        ),
    ]

    static let endpoints: [VPNEndpoint] = {
        let mullvad = providers[0].id
        let proton = providers[1].id
        let ivpn = providers[2].id

        return [
            VPNEndpoint(providerID: mullvad, locationKey: "smart", ping: 24),
            VPNEndpoint(providerID: proton, locationKey: "smart", ping: 31),
            VPNEndpoint(providerID: ivpn, locationKey: "smart", ping: 39),

            VPNEndpoint(providerID: mullvad, locationKey: "netherlands|amsterdam", ping: 42),
            VPNEndpoint(providerID: proton, locationKey: "netherlands|amsterdam", ping: 51),
            VPNEndpoint(providerID: ivpn, locationKey: "netherlands|amsterdam", ping: 67),

            VPNEndpoint(providerID: mullvad, locationKey: "germany|frankfurt", ping: 48),
            VPNEndpoint(providerID: proton, locationKey: "germany|frankfurt", ping: 55),
            VPNEndpoint(providerID: ivpn, locationKey: "germany|frankfurt", ping: 71),

            VPNEndpoint(providerID: mullvad, locationKey: "united kingdom|london", ping: 58),
            VPNEndpoint(providerID: proton, locationKey: "united kingdom|london", ping: 64),
            VPNEndpoint(providerID: ivpn, locationKey: "united kingdom|london", ping: 82),

            VPNEndpoint(providerID: mullvad, locationKey: "united states|new york", ping: 96),
            VPNEndpoint(providerID: proton, locationKey: "united states|new york", ping: 104),
            VPNEndpoint(providerID: ivpn, locationKey: "united states|new york", ping: 118),
        ]
    }()

    static var activeProviders: [VPNProvider] {
        providers.filter(\.isEnabled)
    }

    static func provider(for id: UUID) -> VPNProvider? {
        providers.first { $0.id == id }
    }

    static func locationKey(for location: VPNLocation) -> String? {
        guard location.kind != .smart else { return "smart" }
        return "\(location.name.lowercased())|\(location.city.lowercased())"
    }

    /// Aggregates latency across providers so the list shows one ping per geography.
    static func bestPing(for location: VPNLocation) -> Int {
        guard let key = locationKey(for: location) else { return location.ping }

        let pings = endpoints
            .filter { $0.locationKey == key }
            .compactMap { endpoint -> Int? in
                guard let provider = provider(for: endpoint.providerID), provider.isEnabled else { return nil }
                return endpoint.ping
            }

        return pings.min() ?? location.ping
    }

    static func endpointCount(for target: ConnectionTarget) -> Int {
        RouteOrchestrator().candidates(for: target).count
    }
}

struct RouteOrchestrator {
    func candidates(
        for target: ConnectionTarget,
        providers: [VPNProvider] = VPNNetworkCatalog.providers
    ) -> [RouteCandidate] {
        let enabledProviders = providers.filter(\.isEnabled)
        let providerLookup = Dictionary(uniqueKeysWithValues: enabledProviders.map { ($0.id, $0) })

        let locations: [VPNLocation]
        switch target {
        case .smart:
            locations = VPNLocation.samples
        case .location(let location):
            locations = [location]
        }

        return locations.flatMap { location -> [RouteCandidate] in
            guard let key = VPNNetworkCatalog.locationKey(for: location) else { return [] }

            return VPNNetworkCatalog.endpoints
                .filter { $0.locationKey == key }
                .compactMap { endpoint in
                    guard let provider = providerLookup[endpoint.providerID] else { return nil }
                    return RouteCandidate(
                        provider: provider,
                        endpoint: endpoint,
                        location: location,
                        latency: endpoint.ping
                    )
                }
        }
    }

    func sortedCandidates(
        for target: ConnectionTarget,
        providers: [VPNProvider] = VPNNetworkCatalog.providers
    ) -> [RouteCandidate] {
        candidates(for: target, providers: providers).sorted { $0.latency < $1.latency }
    }

    /// Demo race: walks candidates with short delays and returns the fastest route.
    @MainActor
    func race(
        for target: ConnectionTarget,
        providers: [VPNProvider] = VPNNetworkCatalog.providers,
        onProgress: @escaping (RouteRaceProgress) -> Void
    ) async throws -> (winner: ActiveRoute, alternates: [RouteCandidate]) {
        let ordered = sortedCandidates(for: target, providers: providers)
        guard !ordered.isEmpty else {
            throw RouteOrchestratorError.noRoutesAvailable
        }

        let total = ordered.count
        for index in 1...total {
            onProgress(RouteRaceProgress(testedCount: index, totalCount: total))
            try await Task.sleep(for: .milliseconds(220))
        }

        let winner = ordered[0]
        let route = ActiveRoute(
            provider: winner.provider,
            endpoint: winner.endpoint,
            location: winner.location,
            latency: winner.latency
        )

        return (route, Array(ordered.dropFirst()))
    }
}

enum RouteOrchestratorError: Error, Equatable {
    case noRoutesAvailable
}
