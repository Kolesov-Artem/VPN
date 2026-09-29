import Foundation

/// Literal copy from Figma section 550:19337 «Velvet + others VPNs».
enum VPNFigmaSection550Copy {
    static let mapToastTitle = "New VPN added"
    static let allProvidersUsageFilter = "All providers usage"

    static func providerUsageFilter(providerName: String) -> String {
        "\(providerName) usage"
    }

    static let expandedConnectedTitle = "Connected"

    static func expandedConnectedSubtitle(presetTitle: String, providerName: String) -> String {
        "Fastest, \(presetTitle), \(providerName)"
    }

    static let activeSubscriptionLabel = "Active subscription"
    static let allSubscriptionsLabel = "All subscriptions"
    static let switchToTitle = "Switch to"
    static let seeAllSubscriptions = "See all subscriptions"
    static let subscriptionsTitle = "Subscriptions"
    static let expiredSubscriptionsHeader = "Expired"
    static let updateSubscriptionAction = "Update"
    static let buyTrafficAction = "Buy traffic"
    static let deleteSubscriptionAction = "Delete"

    static let collapsedFastestTitle = "Fastest"
    static let collapsedConnectedSmartAutoSubtitle = "Smart-Auto"
    static let smartAutoTrafficSubtitle = "Smart-Auto, 1 TB left"
    static let presetsSectionTitle = "Pressets"
    static let locationSearchPlaceholder = "Locaion"
    static let sessionUsageDelta = "-0.2% this session"
    static let wifiTrafficLeading = "73% basic traffic left"
    static let lteTrafficLeading = "63% LTE traffic left"
    static let lteTrafficFraction = 0.63
    static let lteSessionDelta = "-0.2% this session"

    static let velvetProviderMessage = """
    ⚠️ Глушат LTE — перебери все LTE-конфиги до рабочего.
    ⛔️ Перестало работать? Нажми 🔄 справа от Velvet VPN на Wi-Fi.
    """

    static func providersSummary(count: Int) -> String {
        "\(count) VPN providers"
    }

    static func presetCardSubtitle(for choice: VPNUseCaseMenuChoice) -> String {
        switch choice {
        case .smart: "Auto-choose the best option"
        case .watchAndPlay: "Best for ITV, Disney+, Netflix"
        case .workAndBrowse: "Low latency game servers"
        default: choice.cardSubtitle
        }
    }

    static func presetCardTitle(for choice: VPNUseCaseMenuChoice) -> String {
        switch choice {
        case .watchAndPlay: "Stream"
        case .workAndBrowse: "Gaming"
        default: choice.title
        }
    }

    static var expandedPresetChoices: [VPNUseCaseMenuChoice] {
        [.smart, .watchAndPlay, .workAndBrowse]
    }

    static let activeProviderBadge = "Active"
    static let subscriptionExpiredBadge = "Subscription expired"

    static func makeMainVPNPromptTitle(providerName: String) -> String {
        "Use \(providerName) as your main VPN?"
    }

    static let makeMainVPNPromptMessage = "It will be used for Connect, presets, and locations."
    static let makeMainVPNConfirm = "Use as main"
    static let makeMainVPNDecline = "Not now"

    static let providerSettingsStatusActive = "Active until 1 Oct 2026"
    static let providerSettingsLastUpdated = "1 Sep 2026, 23:28"
    static let providerSettingsAutoConnectValue = "Wi-Fi only"
    static let goToProviderSite = "Go to provider site"

    /// Provider settings alert block (without LTE quota line).
    static let providerSettingsAlertMessage = """
    ‼️ Глушат LTE - перебери все LTE-конфиги до рабочего.
    ⛔ Перестало работать? Нажми справа от Velvet VPN на Wi-Fi.
    """

    struct DemoSessionStats {
        let region: String
        let pingMs: Int
        let downloadRate: String
        let uploadRate: String
    }

    struct DemoTraffic {
        let fraction: Double
        let leading: String
        let trailing: String
    }

    /// Collapsed island vs expanded panel. Numbers follow the active subscription.
    static func demoSessionStats(providerName: String, islandCollapsed: Bool) -> DemoSessionStats {
        let expanded = expandedSessionStats(providerName: providerName)
        if islandCollapsed {
            return DemoSessionStats(
                region: collapsedFastestTitle,
                pingMs: expanded.pingMs + 80,
                downloadRate: "44 MB/s",
                uploadRate: "80 MB/s"
            )
        }
        return expanded
    }

    static func demoTraffic(providerName: String) -> DemoTraffic {
        switch providerKey(providerName) {
        case .velvetBangkok:
            DemoTraffic(fraction: 0.41, leading: "41% basic traffic left", trailing: "-1.4% this session")
        case .velvetBerlin:
            DemoTraffic(fraction: 0.88, leading: "88% basic traffic left", trailing: "-0.6% this session")
        case .otherVPN:
            DemoTraffic(fraction: 0.22, leading: "22% basic traffic left", trailing: "-3.1% this session")
        case .velvetMoscow:
            DemoTraffic(
                fraction: 0.73,
                leading: wifiTrafficLeading,
                trailing: sessionUsageDelta
            )
        }
    }

    private enum ProviderKey {
        case velvetMoscow
        case velvetBangkok
        case velvetBerlin
        case otherVPN
    }

    private static func providerKey(_ name: String) -> ProviderKey {
        if name.contains("4309") { return .velvetBangkok }
        if name.contains("43-23") { return .velvetBerlin }
        if name == "VPN name" { return .otherVPN }
        return .velvetMoscow
    }

    private static func expandedSessionStats(providerName: String) -> DemoSessionStats {
        switch providerKey(providerName) {
        case .velvetBangkok:
            DemoSessionStats(region: "Bangkok", pingMs: 29, downloadRate: "210 MB/s", uploadRate: "180 MB/s")
        case .velvetBerlin:
            DemoSessionStats(region: "Berlin", pingMs: 48, downloadRate: "140 MB/s", uploadRate: "96 MB/s")
        case .otherVPN:
            DemoSessionStats(region: "London", pingMs: 94, downloadRate: "72 MB/s", uploadRate: "54 MB/s")
        case .velvetMoscow:
            DemoSessionStats(region: "Moscow", pingMs: 13, downloadRate: "332 MB/s", uploadRate: "323 MB/s")
        }
    }
}
