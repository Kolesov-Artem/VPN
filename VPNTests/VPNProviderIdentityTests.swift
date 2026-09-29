import Foundation
import Testing
@testable import VPN

struct VPNProviderIdentityTests {
    @Test
    func velvetNameSplitsAccountIDFromDisplayName() {
        let velvet = VPNProvider.samples[0]
        #expect(velvet.subscriptionAccountID == "#34903")
        #expect(velvet.catalogDisplayName == "🚀 Velvet VPN")
        #expect(velvet.subscriptionIdentityCaption.contains("#34903"))
    }

    @Test
    func importedNameWithoutAccountNumberStaysIntact() throws {
        let nord = try #require(VPNProvider.samples.first { $0.name == "NordVPN" })
        #expect(nord.subscriptionAccountID == nil)
        #expect(nord.catalogDisplayName == "NordVPN")
        #expect(nord.subscriptionIdentityCaption.contains("Updated"))
    }

    @Test
    func allNetworksCatalogIncludesEveryActiveProvider() {
        let providers = VPNProvider.samples.filter(\.status.isActive)
        let scoped = VPNConnectionPlanner.filteredLocationSections(
            from: providers,
            scope: .allNetworks,
            query: VPNLocationQuery()
        )
        let providerNames = Set(
            scoped.flatMap(\.groups).flatMap(\.candidates).map(\.provider.name)
        )
        #expect(providerNames.contains("🚀 Velvet VPN — #34903"))
        #expect(providerNames.contains("NordVPN"))
        #expect(providerNames.contains("Surfshark"))
    }

    @Test
    func providerScopeKeepsASingleSubscriptionCatalog() throws {
        let velvet = VPNProvider.samples[0]
        let nord = try #require(VPNProvider.samples.first { $0.name == "NordVPN" })
        let scoped = VPNConnectionPlanner.filteredLocationSections(
            from: [velvet, nord],
            scope: .provider(velvet.id),
            query: VPNLocationQuery()
        )
        let providerNames = Set(
            scoped.flatMap(\.groups).flatMap(\.candidates).map(\.provider.name)
        )
        #expect(providerNames == ["🚀 Velvet VPN — #34903"])
    }

    @Test
    func providerAnnouncementDropsTrailingAccountFooter() {
        let message = """
        ⚠️ Глушат LTE — перебери все LTE-конфиги до рабочего.
        ⛔️ Перестало работать? Нажми 🔄 справа от Velvet VPN на Wi-Fi.
        🆔 34903 ⏱️ 28.09.2026 14:30 МСК
        """
        let stripped = VPNProvider.strippingIdentityFooter(from: message)
        #expect(!stripped.contains("🆔"))
        #expect(!stripped.contains("34903"))
        #expect(stripped.contains("Глушат LTE"))
        #expect(VPNProvider.samples[0].displayedProviderMessage?.contains("🆔") != true)
    }
}
