import Foundation

struct VPNRoutingDomainRule: Identifiable, Equatable, Codable {
    let id: UUID
    let domain: String
    let action: String

    static let samples: [VPNRoutingDomainRule] = [
        VPNRoutingDomainRule(id: UUID(), domain: "*.local", action: "Bypass"),
        VPNRoutingDomainRule(id: UUID(), domain: "bank.example.com", action: "Direct"),
        VPNRoutingDomainRule(id: UUID(), domain: "ads.example.net", action: "Block"),
    ]
}

enum VPNRoutingPreferences {
    private static let routeAllKey = "velvet.routing.routeAll"
    private static let bypassLocalKey = "velvet.routing.bypassLocal"

    static var routesAllTraffic: Bool {
        get {
            if UserDefaults.standard.object(forKey: routeAllKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: routeAllKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: routeAllKey) }
    }

    static var bypassLocalNetworks: Bool {
        get {
            if UserDefaults.standard.object(forKey: bypassLocalKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: bypassLocalKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: bypassLocalKey) }
    }
}
