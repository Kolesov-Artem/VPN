import Foundation
import Testing
@testable import VPN

struct VPNLocationListCatalogTests {
    @Test
    func smartNetherlandsKeepsOnlySmartVariants() {
        let netherlands = VPNProvider.velvetHappServers.filter {
            $0.listIdentity.groupingKey == "smart|Нидерланды"
        }
        #expect(netherlands.count == 2)
        #expect(Set(netherlands.map(\.listIdentity.nestedTitle)) == ["Smart", "Запасной"])
        #expect(netherlands.map(\.listIdentity.family).allSatisfy { $0 == .smart })
    }

    @Test
    func extraCountriesJoinSmartWithoutDuplicatingExistingOnes() {
        let germany = VPNProvider.velvetHappServers.filter {
            $0.listIdentity.groupingKey == "smart|Германия"
        }
        #expect(germany.map(\.listIdentity.nestedTitle).contains("Разовый доступ"))
        #expect(germany.contains { $0.name == "SMART-Германия" })

        let brazil = VPNProvider.velvetHappServers.first { $0.name == "Бразилия" }
        #expect(brazil?.listIdentity.family == .smart)
        #expect(brazil?.listIdentity.groupingKey == "smart|Бразилия")
        #expect(VPNProvider.velvetHappServers.contains { $0.listIdentity.family == .bridge })
        #expect(VPNProvider.velvetHappServers.contains { $0.listIdentity.family == .torrent })
    }

    @Test
    func ltePacksCollapseIntoGuidedChoices() {
        let auto = VPNProvider.velvetHappServers.first { $0.name == "LTE-Авто" }
        #expect(auto?.listIdentity.groupTitle == "Smart LTE")
        #expect(auto?.listIdentity.groupFlag == "✨")

        let universal = VPNProvider.velvetHappServers.filter {
            $0.listIdentity.groupingKey == "lte|universal"
        }
        let fallback = VPNProvider.velvetHappServers.filter {
            $0.listIdentity.groupingKey == "lte|hys2"
        }
        #expect(universal.count == 10)
        #expect(fallback.count == 4)
        #expect(universal.map(\.listIdentity.groupTitle).allSatisfy { $0 == "Универсальный" })
        #expect(fallback.map(\.listIdentity.groupTitle).allSatisfy { $0 == "Запасной протокол" })
    }

    @Test
    func featuredVelvetListUsesTypeSections() throws {
        let featured = VPNProvider.samples[0]
        let sections = VPNConnectionPlanner.filteredLocationSections(
            from: [featured],
            scope: .provider(featured.id),
            query: VPNLocationQuery()
        )
        #expect(sections.map(\.family) == [.bridge, .torrent, .lte, .smart])
        #expect(sections.map(\.title) == ["Через Москву", "Загрузки", "Мобильный интернет", "Страны"])
        #expect(sections.first { $0.family == .smart }?.explanation == nil)

        let countries = try #require(sections.first { $0.family == .smart })
        #expect(countries.groups.first?.name == "Smart")
        #expect(countries.groups.first?.flag == "✨")
        #expect(countries.groups.contains { $0.name == "Нидерланды" && $0.candidates.count == 2 })
        #expect(countries.groups.contains { $0.name == "Нидерланды" && $0.candidates.first?.location.listIdentity.nestedTitle == "Smart" })
        #expect(countries.groups.contains { $0.name == "Бразилия" })
        #expect(countries.groups.filter { $0.name == "Германия" }.count == 1)

        let lte = try #require(sections.first { $0.family == .lte })
        #expect(lte.groups.map(\.name) == ["Smart LTE", "Универсальный", "Запасной протокол"])
        #expect(lte.groups.first?.flag == "✨")
    }

    @Test
    func classicCountryCatalogStaysUngroupedByType() throws {
        let nord = try #require(VPNProvider.samples.first { $0.name == "NordVPN" })
        let sections = VPNConnectionPlanner.filteredLocationSections(
            from: [nord],
            scope: .provider(nord.id),
            query: VPNLocationQuery()
        )
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].family == .country)
    }
}
