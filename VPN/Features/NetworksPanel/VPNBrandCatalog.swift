import Foundation

enum VPNBrandCatalog {
    /// Bundled brand marks shipped with the app (works offline, no network dependency).
    static func bundledAssetName(for provider: VPNProvider) -> String? {
        switch provider.id.uuidString.uppercased() {
        case "A1000000-0000-0000-0000-000000000001":
            "VPNBrandVelvet"
        case "A1000000-0000-0000-0000-000000000002":
            "VPNBrandNordVPN"
        case "A1000000-0000-0000-0000-000000000003":
            "VPNBrandSurfshark"
        case "A1000000-0000-0000-0000-000000000004":
            "VPNBrandProtonVPN"
        default:
            assetName(forProviderName: provider.name)
        }
    }

    /// Optional remote fallback when a provider is imported without a bundled asset.
    static func remoteLogoURL(for provider: VPNProvider) -> URL? {
        switch provider.name.lowercased() {
        case let name where name.contains("nord") || name.contains("vpn name 2"):
            URL(string: "https://www.google.com/s2/favicons?domain=nordvpn.com&sz=128")
        case let name where name.contains("surfshark") || name.contains("vpn name 3"):
            URL(string: "https://www.google.com/s2/favicons?domain=surfshark.com&sz=128")
        case let name where name.contains("proton") || name.contains("vpn name 4"):
            URL(string: "https://www.google.com/s2/favicons?domain=protonvpn.com&sz=128")
        case let name where name.contains("velvet"):
            nil
        case let name where name.contains("express"):
            URL(string: "https://www.google.com/s2/favicons?domain=expressvpn.com&sz=128")
        default:
            nil
        }
    }

    private static func assetName(forProviderName name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("velvet") { return "VPNBrandVelvet" }
        if lower.contains("nord") || lower.contains("vpn name 2") { return "VPNBrandNordVPN" }
        if lower.contains("surfshark") || lower.contains("vpn name 3") { return "VPNBrandSurfshark" }
        if lower.contains("proton") || lower.contains("vpn name 4") { return "VPNBrandProtonVPN" }
        return nil
    }
}
