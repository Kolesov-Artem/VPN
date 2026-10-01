import Foundation
import Testing
@testable import VPN

@MainActor
struct ServiceProbeTests {
    @Test
    func restrictedMobileMatchesTheSlowDesign() {
        let readings = ServiceAvailabilityModel.projectedReadings(
            sites: ServiceAvailabilityModel.defaultSites,
            isVPNConnected: false,
            jitterSeed: 0
        )
        #expect(latency("YouTube", in: readings) == 530)
        #expect(latency("ChatGPT", in: readings) == 530)
        #expect(latency("Google", in: readings) == 61)
        #expect(latency("Instagram", in: readings) == 362)
        #expect(latency("Telegram", in: readings) == 199)
        #expect(readings.filter(\.isSlow).map(\.name).sorted() == ["ChatGPT", "YouTube"])
    }

    @Test
    func wifiAndVPNMatchTheClearDesign() {
        let wifi = ServiceAvailabilityModel.projectedReadings(
            sites: ServiceAvailabilityModel.defaultSites,
            isVPNConnected: false,
            jitterSeed: 0
        )
        let tunnel = ServiceAvailabilityModel.projectedReadings(
            sites: ServiceAvailabilityModel.defaultSites,
            isVPNConnected: true,
            jitterSeed: 0
        )
        #expect(latency("YouTube", in: wifi) == 530)
        #expect(latency("ChatGPT", in: wifi) == 530)
        #expect(tunnel.allSatisfy { !$0.isSlow })
    }

    @Test(arguments: 1..<6)
    func refreshMovesNumbersWithoutLeavingTheBand(seed: Int) {
        let restricted = ServiceAvailabilityModel.projectedReadings(
            sites: ServiceAvailabilityModel.defaultSites,
            isVPNConnected: false,
            jitterSeed: seed
        )
        let open = ServiceAvailabilityModel.projectedReadings(
            sites: ServiceAvailabilityModel.defaultSites,
            isVPNConnected: true,
            jitterSeed: seed
        )
        let designed = ServiceAvailabilityModel.projectedReadings(
            sites: ServiceAvailabilityModel.defaultSites,
            isVPNConnected: false,
            jitterSeed: 0
        )
        #expect(restricted.map(\.latencyMs) != designed.map(\.latencyMs))
        #expect(restricted.filter(\.isSlow).map(\.name).sorted() == ["ChatGPT", "YouTube"])
        #expect(open.allSatisfy { !$0.isSlow })
    }

    @Test
    func customLinkImprovesOnWiFi() {
        let service = ServiceProbeSite(id: UUID(), name: "Example", link: "https://example.com")
        let cellular = ServiceAvailabilityModel.projectedReadings(
            sites: [service], isVPNConnected: false, jitterSeed: 0
        )[0]
        let wifi = ServiceAvailabilityModel.projectedReadings(
            sites: [service], isVPNConnected: true, jitterSeed: 0
        )[0]
        #expect(wifi.latencyMs < cellular.latencyMs)
        #expect(!wifi.isSlow)
    }

    @Test
    func linkParserAcceptsAHostAndRejectsDuplicates() {
        let existing = ServiceAvailabilityModel.defaultSites
        #expect(ServiceAvailabilityModel.canonicalLink(from: "youtube.com/feed") == "https://youtube.com/feed")
        #expect(
            ServiceAvailabilityModel.displayName(name: "", link: "https://youtube.com/feed") == "YouTube"
        )
        #expect(
            ServiceAvailabilityModel.additionError(name: "", link: "www.youtube.com", existing: existing)
                == ui("This site is already in the list")
        )
        #expect(
            ServiceAvailabilityModel.additionError(name: "", link: "not a link", existing: [])
                == ui("Enter a link like youtube.com")
        )
        #expect(ServiceAvailabilityModel.additionError(name: "News", link: "bbc.com", existing: []) == nil)
    }

    private func latency(_ name: String, in readings: [ServiceProbeReading]) -> Int? {
        readings.first { $0.name == name }?.latencyMs
    }
}
