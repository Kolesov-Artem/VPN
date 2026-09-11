import Foundation

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
