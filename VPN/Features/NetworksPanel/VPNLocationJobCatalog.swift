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
        case .mobileLTE: "Mobile / LTE"
        case .whitelistForeign: "Whitelist & foreign access"
        case .sport: "Sport"
        case .streaming: "Streaming"
        case .gaming: "Gaming"
        case .work: "Work"
        case .privacy: "Privacy"
        case .socialMedia: "Social media"
        case .europeTravel: "Smart-Europe"
        }
    }

    var subtitle: String {
        switch self {
        case .mobileLTE: "When mobile data is throttled or jammed"
        case .whitelistForeign: "Foreign & non-whitelist via VPN · whitelisted sites direct"
        case .sport: "Best for Sport1, DAZN, Setanta"
        case .streaming: "Best for ITV, Disney+, Netflix"
        case .gaming: "Low latency game servers"
        case .work: "Stable video calls and remote desktop"
        case .privacy: "Minimal logging endpoints"
        case .socialMedia: "Instagram, X, and blocked social apps"
        case .europeTravel: "Travel and EU streaming content"
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
        case .smart: "Smart"
        case .restrictedNetwork: "Restricted network"
        case .watchAndPlay: "Watch & play"
        case .workAndBrowse: "Work & browse"
        case .travel: "Travel"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: "Finds the best connection for you"
        case .restrictedNetwork: "Primary in Russia when mobile data or whitelists get in the way"
        case .watchAndPlay: "Sport streams, TV apps, and low-latency games"
        case .workAndBrowse: "Calls, privacy-focused routes, and social apps"
        case .travel: "EU streaming while traveling abroad"
        }
    }

    var panelLabel: String {
        switch self {
        case .smart: "Smart"
        case .restrictedNetwork: "Restricted"
        case .watchAndPlay: "Watch"
        case .workAndBrowse: "Work"
        case .travel: "Travel"
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
        case .smart: "Fastest available server"
        case .restrictedNetwork: "Mobile data & whitelists in Russia"
        case .watchAndPlay: "Sport1, DAZN, ITV and games"
        case .workAndBrowse: "Calls, privacy, and social apps"
        case .travel: "EU streaming while abroad"
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
                title: "Smart-Europe",
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
}

enum VPNLocationRowCopy {
    static func smartAuto(scope: VPNProviderScope, providers: [VPNProvider]) -> String {
        "Fastest across \(VPNSelectionSummary.scopeLabel(for: scope, providers: providers))"
    }

    static func smartRussia() -> String {
        "Mobile data & whitelists in Russia"
    }

    static func smartEurope() -> String {
        "Travel and EU streaming content"
    }

    static func countryGroup(_ group: VPNCountryLocationGroup) -> String {
        if group.candidates.count > 1 {
            return "Best \(group.bestPing) ms · \(group.providerCount) providers"
        }
        if let candidate = group.candidates.first {
            return networkLocation(candidate)
        }
        return group.areaLabel
    }

    static func networkLocation(_ candidate: VPNNetworkLocation) -> String {
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
