import Foundation
import SwiftUI

/// Live session numbers. A class so a one-second ticker can move ping and speed
/// without rebuilding the location list that sits next to the stats.
@MainActor
@Observable
final class VPNSessionStatsModel {
    var downloadRate = "0 KB/s"
    var uploadRate = "0 KB/s"
    var pingMs = 0
    var bytesUsed: Int64 = 0

    static let limitBytes: Int64 = 7_000_000_000

    var usageFraction: Double {
        Double(bytesUsed) / Double(Self.limitBytes)
    }

    var dataUsedText: String {
        let megabytes = Double(bytesUsed) / (1024 * 1024)
        if megabytes >= 1024 {
            return String(format: "%.1f GB this session", megabytes / 1024)
        }
        return String(format: "%.0f MB this session", megabytes)
    }

    var snapshot: VPNSessionStatsSnapshot {
        VPNSessionStatsSnapshot(
            downloadRate: downloadRate,
            uploadRate: uploadRate,
            pingMs: pingMs,
            usageFraction: usageFraction,
            dataUsedText: dataUsedText
        )
    }

    func tick(basePing: Int) {
        let down = Double.random(in: 8.0...24.0)
        let up = Double.random(in: 2.0...8.0)
        downloadRate = String(format: "%.0f MB/s", down)
        uploadRate = String(format: "%.0f MB/s", up)
        pingMs = max(12, basePing + Int.random(in: -8...12))
        bytesUsed += Int64((down + up) * 1024 * 1024 / 8)
    }

    func reset() {
        downloadRate = "0 KB/s"
        uploadRate = "0 KB/s"
        pingMs = 0
        bytesUsed = 0
    }
}

struct VPNSessionStatsSnapshot: Equatable {
    var downloadRate: String
    var uploadRate: String
    var pingMs: Int
    var usageFraction: Double
    var dataUsedText: String

    static let idle = VPNSessionStatsSnapshot(
        downloadRate: "0 KB/s",
        uploadRate: "0 KB/s",
        pingMs: 0,
        usageFraction: 0,
        dataUsedText: "0 MB this session"
    )
}

/// Reads the ticker only when the screen actually shows those numbers.
/// Release 1 uses fixed demo copy, so it stays unsubscribed and the list does not redraw each second.
struct SessionStatsConsumer<Content: View>: View {
    var model: VPNSessionStatsModel
    var readsLiveValues: Bool
    @ViewBuilder var content: (VPNSessionStatsSnapshot) -> Content

    var body: some View {
        if readsLiveValues {
            content(model.snapshot)
        } else {
            content(.idle)
        }
    }
}

/// Live session metrics passed into provider detail when Velvet stats are available.
struct VPNProviderLiveStats: Equatable {
    let regionLabel: String
    let pingMs: Int
    let downloadRate: String
    let uploadRate: String
    let usageFraction: Double
    let sessionDataUsedText: String
    let isConnected: Bool
}
