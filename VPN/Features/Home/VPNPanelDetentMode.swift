import SwiftUI

/// How the bottom panel snaps after a drag — three explicit stops or direct collapsed ↔ expanded.
enum VPNPanelDetentMode: String, CaseIterable, Identifiable {
    case stepped
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stepped: "Three stops"
        case .direct: "Direct expand"
        }
    }

    var subtitle: String {
        switch self {
        case .stepped: "Island → half → full, one step per swipe"
        case .direct: "Collapsed ↔ full; fling skips half; slow release can rest at half"
        }
    }
}
