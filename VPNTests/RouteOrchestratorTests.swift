import Foundation
import Testing
@testable import VPN

struct RouteOrchestratorTests {
  @Test
  func smartRacePicksFastestEnabledProvider() async throws {
    let orchestrator = RouteOrchestrator()
    let result = try await orchestrator.race(for: .smart) { _ in }

    #expect(result.winner.provider.name == "Mullvad")
    #expect(result.winner.latency == 24)
  }

  @Test
  func locationRaceLimitsCandidatesToSelectedGeography() async throws {
    let orchestrator = RouteOrchestrator()
    let amsterdam = try #require(
      VPNLocation.samples.first { $0.name == "Netherlands" && $0.city == "Amsterdam" }
    )

    let candidates = orchestrator.sortedCandidates(for: .location(amsterdam))

    #expect(candidates.count == 2)
    #expect(candidates.allSatisfy { $0.location.id == amsterdam.id })
    #expect(candidates.first?.provider.name == "Mullvad")
  }
}
