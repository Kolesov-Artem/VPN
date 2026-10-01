import Foundation

enum VPNJobSection: String, CaseIterable {
    case restrictedNetwork
    case everydayTasks
    case moreLocations
}

enum VPNUserJob: String, CaseIterable, Identifiable, Codable, Hashable {
    case mobileLTE
    case whitelistForeign
    case sport
    case streaming
    case gaming
    case work
    case privacy
    case socialMedia
    case europeTravel

    var id: String { rawValue }

    var section: VPNJobSection {
        switch self {
        case .mobileLTE, .whitelistForeign: .restrictedNetwork
        case .sport, .streaming, .gaming, .work, .privacy, .socialMedia: .everydayTasks
        case .europeTravel: .moreLocations
        }
    }

    var title: String {
        switch self {
        case .mobileLTE: ui("Mobile / LTE")
        case .whitelistForeign: ui("Whitelist & foreign access")
        case .sport: ui("Sport")
        case .streaming: ui("Streaming")
        case .gaming: ui("Gaming")
        case .work: ui("Work")
        case .privacy: ui("Privacy")
        case .socialMedia: ui("Social media")
        case .europeTravel: ui("Smart-Europe")
        }
    }

    var subtitle: String {
        switch self {
        case .mobileLTE: ui("When mobile data is throttled or jammed")
        case .whitelistForeign: ui("Foreign & non-whitelist via VPN · whitelisted sites direct")
        case .sport: ui("Best for Sport1, DAZN, Setanta")
        case .streaming: ui("Best for ITV, Disney+, Netflix")
        case .gaming: ui("Low latency game servers")
        case .work: ui("Stable video calls and remote desktop")
        case .privacy: ui("Minimal logging endpoints")
        case .socialMedia: ui("Instagram, X, and blocked social apps")
        case .europeTravel: ui("Travel and EU streaming content")
        }
    }

    var iconSymbol: String {
        switch self {
        case .mobileLTE: "antenna.radiowaves.left.and.right"
        case .whitelistForeign: "list.bullet.rectangle"
        case .sport: "sportscourt"
        case .streaming: "play.tv"
        case .gaming: "gamecontroller"
        case .work: "briefcase"
        case .privacy: "hand.raised"
        case .socialMedia: "bubble.left.and.bubble.right"
        case .europeTravel: "globe.europe.africa"
        }
    }

    static func jobs(in section: VPNJobSection) -> [VPNUserJob] {
        allCases.filter { $0.section == section }
    }
}

/// Five high-level use cases for the collapsed island menu.
enum VPNUseCaseMenuChoice: String, CaseIterable, Identifiable {
    case smart
    case restrictedNetwork
    case watchAndPlay
    case workAndBrowse
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: ui("Smart")
        case .restrictedNetwork: ui("Restricted network")
        case .watchAndPlay: ui("Watch & play")
        case .workAndBrowse: ui("Work & browse")
        case .travel: ui("Travel")
        }
    }

    var subtitle: String {
        switch self {
        case .smart: ui("Finds the best connection for you")
        case .restrictedNetwork: ui("Primary in Russia when mobile data or whitelists get in the way")
        case .watchAndPlay: ui("Sport streams, TV apps, and low-latency games")
        case .workAndBrowse: ui("Calls, privacy-focused routes, and social apps")
        case .travel: ui("EU streaming while traveling abroad")
        }
    }

    var panelLabel: String {
        switch self {
        case .smart: ui("Smart")
        case .restrictedNetwork: ui("Restricted")
        case .watchAndPlay: ui("Watch")
        case .workAndBrowse: ui("Work")
        case .travel: ui("Travel")
        }
    }

    var iconSymbol: String {
        switch self {
        case .smart: "sparkles"
        case .restrictedNetwork: "antenna.radiowaves.left.and.right"
        case .watchAndPlay: "play.tv"
        case .workAndBrowse: "briefcase"
        case .travel: "globe.europe.africa"
        }
    }

    /// Short copy for the horizontal cards in the expanded sheet.
    var cardSubtitle: String {
        switch self {
        case .smart: ui("Picks the best server")
        case .restrictedNetwork: ui("Mobile data & whitelists in Russia")
        case .watchAndPlay: ui("Sport1, DAZN, ITV and games")
        case .workAndBrowse: ui("Calls, privacy, and social apps")
        case .travel: ui("EU streaming while abroad")
        }
    }

    func locationSelection(scope: VPNProviderScope) -> VPNLocationSelection {
        switch self {
        case .smart:
            .smartAuto(scope: scope)
        case .restrictedNetwork:
            .smartJob(.mobileLTE, scope: scope)
        case .watchAndPlay:
            .smartJob(.streaming, scope: scope)
        case .workAndBrowse:
            .smartJob(.work, scope: scope)
        case .travel:
            .smartJob(.europeTravel, scope: scope)
        }
    }

    static func matching(_ selection: VPNLocationSelection) -> VPNUseCaseMenuChoice? {
        switch selection {
        case .smartAuto:
            .smart
        case let .smartJob(job, _):
            switch job {
            case .mobileLTE, .whitelistForeign: .restrictedNetwork
            case .sport, .streaming, .gaming: .watchAndPlay
            case .work, .privacy, .socialMedia: .workAndBrowse
            case .europeTravel: .travel
            }
        case .manual:
            nil
        }
    }
}

/// Separates use-case picks from location picks so only one surface shows a checkmark.
enum VPNSelectionSource: Equatable {
    case useCase(VPNUseCaseMenuChoice)
    case location(VPNLocationSelection)

    func activeUseCase(for selection: VPNLocationSelection) -> VPNUseCaseMenuChoice? {
        guard case let .useCase(choice) = self else { return nil }
        return VPNUseCaseMenuChoice.matching(selection) == choice ? choice : nil
    }

    func isLocationActive(matching matcher: (VPNLocationSelection) -> Bool) -> Bool {
        guard case let .location(selection) = self else { return false }
        return matcher(selection)
    }
}

struct VPNSmartCountryLocation: Identifiable, Equatable {
    let job: VPNUserJob
    let title: String
    let subtitle: String
    let iconSymbol: String

    var id: String { job.rawValue }

    func pingID(for country: String) -> String {
        "smart-\(country)-\(job.rawValue)"
    }

    func selection(scope: VPNProviderScope) -> VPNLocationSelection {
        .smartJob(job, scope: scope)
    }
}

enum VPNProviderScope: Equatable, Codable, Hashable {
    case allNetworks
    case provider(UUID)

    func filtered(_ providers: [VPNProvider]) -> [VPNProvider] {
        switch self {
        case .allNetworks:
            providers
        case let .provider(id):
            providers.filter { $0.id == id }
        }
    }

    var bannerLabel: String? {
        switch self {
        case .allNetworks: nil
        case let .provider(id): id.uuidString
        }
    }
}

enum VPNLocationJobCatalog {
    static func tags(for location: VPNLocation, provider: VPNProvider) -> Set<VPNUserJob> {
        guard location.kind != .smart else { return [] }

        var tags = Set<VPNUserJob>()

        if location.kind == .lte {
            tags.formUnion([.mobileLTE, .whitelistForeign])
        }

        switch location.name {
        case "Russia", "Kazakhstan", "Armenia", "Georgia":
            tags.formUnion([.mobileLTE, .whitelistForeign, .privacy])
        case "Germany":
            tags.formUnion([.sport, .gaming, .work, .streaming])
        case "Netherlands":
            tags.formUnion([.streaming, .socialMedia, .privacy])
        case "France", "United Kingdom":
            tags.formUnion([.streaming, .sport, .europeTravel])
        case "Finland", "Sweden", "Poland", "Spain", "Italy", "Czech Republic":
            tags.formUnion([.privacy, .europeTravel])
        case "United States":
            tags.formUnion([.sport, .streaming, .gaming, .socialMedia])
        default:
            break
        }

        if europeanCountries.contains(location.name) {
            tags.insert(.europeTravel)
        }

        return tags
    }

    static func optimizationHint(for location: VPNLocation, provider: VPNProvider) -> String? {
        switch (location.name, location.city, provider.name) {
        case ("Russia", "Moscow", "Velvet VPN"):
            "Optimized for Sports & Canal+"
        case ("Germany", "Frankfurt", _):
            "Optimized for DAZN & Sport1"
        case ("Netherlands", "Amsterdam", _):
            "Optimized for ITV & Disney+"
        case ("United Kingdom", "London", _):
            "Optimized for ITV Sports"
        case ("United States", "New York", _):
            "Optimized for ESPN & NBC Sports"
        case ("Russia", _, _):
            "Optimized for LTE when mobile data is restricted"
        case (_, _, _):
            location.kind == .lte ? "LTE profile · try if standard fails" : nil
        }
    }

    private static let europeanCountries: Set<String> = [
        "Finland", "Sweden", "Germany", "Netherlands", "Poland",
        "France", "United Kingdom", "Switzerland", "Turkey",
        "Czech Republic", "Spain", "Italy",
    ]

    static func smartLocation(for country: String) -> VPNSmartCountryLocation? {
        switch country {
        case "Russia":
            VPNSmartCountryLocation(
                job: .mobileLTE,
                title: "Smart-Russia",
                subtitle: VPNLocationRowCopy.smartRussia(),
                iconSymbol: VPNUserJob.mobileLTE.iconSymbol
            )
        case "Germany":
            VPNSmartCountryLocation(
                job: .europeTravel,
                title: ui("Smart-Europe"),
                subtitle: VPNLocationRowCopy.smartEurope(),
                iconSymbol: VPNUserJob.europeTravel.iconSymbol
            )
        default:
            nil
        }
    }
}

struct VPNCountryLocationGroup: Identifiable, Equatable {
    let id: String
    let name: String
    let flag: String
    let family: VPNLocationListFamily
    let candidates: [VPNNetworkLocation]

    var bestPing: Int {
        candidates.map(\.location.ping).min() ?? 0
    }

    var providerCount: Int {
        Set(candidates.map(\.provider.id)).count
    }

    var areaLabel: String {
        candidates.first?.location.city ?? name
    }

    var isPinned: Bool {
        candidates.contains { $0.location.listIdentity.isPinned }
    }

    var hasSmartServer: Bool {
        candidates.contains { $0.location.name.hasPrefix("SMART-") }
    }
}

enum VPNLocationRowCopy {
    static func smartAuto(scope: VPNProviderScope, providers: [VPNProvider]) -> String {
        uiFormat("Smart across %@", VPNSelectionSummary.scopeLabel(for: scope, providers: providers))
    }

    static func smartRussia() -> String {
        "Mobile data & whitelists in Russia"
    }

    static func smartEurope() -> String {
        "Travel and EU streaming content"
    }

    static func countryGroup(_ group: VPNCountryLocationGroup) -> String {
        if group.family.isCatalogFamily {
            return catalogCountryGroup(group)
        }
        if group.candidates.count > 1 {
            return uiFormat("Best %lld ms · %lld providers", group.bestPing, group.providerCount)
        }
        if let candidate = group.candidates.first {
            return networkLocation(candidate)
        }
        return group.areaLabel
    }

    static func catalogNestedRow(_ candidate: VPNNetworkLocation) -> (title: String, subtitle: String) {
        let identity = candidate.location.listIdentity
        return (identity.nestedTitle, identity.nestedSubtitle)
    }

    private static func catalogCountryGroup(_ group: VPNCountryLocationGroup) -> String {
        switch group.name {
        case "Универсальный":
            return "Почти все операторы. Перебери, если Smart LTE не помог"
        case "Запасной протокол":
            return "Если универсальные не берутся"
        default:
            break
        }
        let preferred = group.candidates.min {
            $0.location.listIdentity.variantRank < $1.location.listIdentity.variantRank
        }
        return preferred?.location.listIdentity.nestedSubtitle ?? group.areaLabel
    }

    static func networkLocation(_ candidate: VPNNetworkLocation) -> String {
        if candidate.provider.kind == .velvetFeatured {
            return candidate.location.city
        }
        if let hint = candidate.optimizationHint {
            return "\(candidate.provider.name) · \(hint)"
        }
        return "\(candidate.location.city) · \(candidate.provider.name) · \(candidate.location.kind.title)"
    }
}

extension VPNNetworkLocation {
    var jobTags: Set<VPNUserJob> {
        VPNLocationJobCatalog.tags(for: location, provider: provider)
    }

    var optimizationHint: String? {
        VPNLocationJobCatalog.optimizationHint(for: location, provider: provider)
    }
}
