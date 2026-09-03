import Foundation
import Observation

@Observable
@MainActor
final class VPNLogsStore {
    static let shared = VPNLogsStore()

    private(set) var lines: [String] = []

    private init() {
        append("Velvet VPN log ready")
    }

    func append(_ message: String) {
        let stamp = Self.timestampFormatter.string(from: .now)
        lines.append("[\(stamp)] \(message)")
    }

    func clear() {
        lines = []
        append("Log cleared")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
