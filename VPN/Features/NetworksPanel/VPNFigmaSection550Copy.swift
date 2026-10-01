import Foundation

/// Literal copy from Figma section 550:19337 «Velvet + others VPNs».
enum VPNFigmaSection550Copy {
    static var mapToastTitle: String { ui("New VPN added") }
    static var allProvidersUsageFilter: String { ui("All providers usage") }

    static func providerUsageFilter(providerName: String) -> String {
        "\(providerName) usage"
    }

    static var expandedConnectedTitle: String { ui("Connected") }

    static func expandedConnectedSubtitle(presetTitle: String, providerName: String) -> String {
        uiFormat("Smart, %@, %@", presetTitle, providerName)
    }

    static var activeSubscriptionLabel: String { ui("Active subscription") }
    static var allSubscriptionsLabel: String { ui("All subscriptions") }
    static var switchToTitle: String { ui("Switch to") }
    static var seeAllSubscriptions: String { ui("See all subscriptions") }
    static var subscriptionsTitle: String { ui("Subscriptions") }
    static var expiredSubscriptionsHeader: String { ui("Expired") }
    static var updateSubscriptionAction: String { ui("Update") }
    static var buyTrafficAction: String { ui("Buy traffic") }
    static var deleteSubscriptionAction: String { ui("Delete") }

    static var collapsedFastestTitle: String { ui("Smart") }
    static var collapsedConnectedSmartAutoSubtitle: String { ui("Smart-Auto") }
    static let smartAutoTrafficSubtitle = "Smart-Auto, 1 TB left"
    static var presetsSectionTitle: String { ui("Pressets") }
    static var locationSearchPlaceholder: String { ui("Locaion") }
    static var sessionUsageDelta: String { ui("-0.2% this session") }
    static var wifiTrafficLeading: String { ui("73% basic traffic left") }
    static var lteTrafficLeading: String { ui("63% LTE traffic left") }
    static let lteTrafficFraction = 0.63
    static var lteSessionDelta: String { ui("-0.2% this session") }

    static let velvetProviderMessage = """
    ⚠️ Глушат LTE — перебери все LTE-конфиги до рабочего.
    ⛔️ Перестало работать? Нажми 🔄 справа от Velvet VPN на Wi-Fi.
    """

    static func providersSummary(count: Int) -> String {
        "\(count) VPN providers"
    }

    static func presetCardSubtitle(for choice: VPNUseCaseMenuChoice) -> String {
        switch choice {
        case .smart: ui("Auto-choose the best option")
        case .watchAndPlay: ui("Best for ITV, Disney+, Netflix")
        case .workAndBrowse: ui("Low latency game servers")
        default: choice.cardSubtitle
        }
    }

    static func presetCardTitle(for choice: VPNUseCaseMenuChoice) -> String {
        switch choice {
        case .watchAndPlay: ui("Stream")
        case .workAndBrowse: ui("Gaming")
        default: choice.title
        }
    }

    static var expandedPresetChoices: [VPNUseCaseMenuChoice] {
        [.smart, .watchAndPlay, .workAndBrowse]
    }

    static var activeProviderBadge: String { ui("Active") }
    static var subscriptionExpiredBadge: String { ui("Subscription expired") }

    static func makeMainVPNPromptTitle(providerName: String) -> String {
        "Use \(providerName) as your main VPN?"
    }

    static var makeMainVPNPromptMessage: String { ui("It will be used for Connect, presets, and locations.") }
    static var makeMainVPNConfirm: String { ui("Use as main") }
    static var makeMainVPNDecline: String { ui("Not now") }

    static var providerSettingsStatusActive: String { ui("Active until 1 Oct 2026") }
    static var providerSettingsLastUpdated: String { ui("1 Sep 2026, 23:28") }
    static var providerSettingsAutoConnectValue: String { ui("Wi-Fi only") }
    static var goToProviderSite: String { ui("Go to provider site") }

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
