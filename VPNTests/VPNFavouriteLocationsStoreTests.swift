import Foundation
import Testing
@testable import VPN

struct VPNFavouriteLocationsStoreTests {
    @Test
    func toggleAddsThenRemovesTheSameServer() throws {
        let location = try location(named: "SMART-Нидерланды")
        let added = VPNFavouriteLocationsStore.toggled(location, in: "")
        let entries = VPNFavouriteLocationsStore.load(from: added)
        #expect(entries.map(\.name) == ["SMART-Нидерланды"])

        let removed = VPNFavouriteLocationsStore.toggled(location, in: added)
        #expect(VPNFavouriteLocationsStore.load(from: removed).isEmpty)
    }

    @Test
    func toggleKeepsOnlyTheNewestFive() throws {
        var stored = ""
        for name in [
            "SMART-Нидерланды",
            "SMART-Швеция",
            "SMART-Германия",
            "SMART-Италия",
            "SMART-Литва",
            "SMART-Франция",
        ] {
            stored = VPNFavouriteLocationsStore.toggled(try location(named: name), in: stored)
        }
        let names = VPNFavouriteLocationsStore.load(from: stored).map(\.name)
        #expect(names == [
            "SMART-Франция",
            "SMART-Литва",
            "SMART-Италия",
            "SMART-Германия",
            "SMART-Швеция",
        ])
    }

    @Test
    func demoEntriesAreThreeQuietVelvetServers() {
        let names = VPNFavouriteLocationsStore.demoEntries(from: VPNProvider.samples).map(\.name)
        #expect(names == ["SMART-Нидерланды", "SMART-Швеция", "SMART-Германия"])
    }

    private func location(named name: String) throws -> VPNNetworkLocation {
        let provider = try #require(VPNProvider.samples.first)
        let server = try #require(provider.servers.first { $0.name == name && $0.kind != .smart })
        return VPNNetworkLocation(location: server, provider: provider)
    }
}
