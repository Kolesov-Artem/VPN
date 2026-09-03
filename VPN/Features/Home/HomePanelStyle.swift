import SwiftUI

/// Two shipped takes on the bottom panel. The island is the original
/// hand-built one; the sheet is the system presentation that hands scrolling
/// over to UIKit. Both stay in the build so they can be compared on device.
enum VPNPanelStyle: String, CaseIterable, Identifiable {
    case island
    case sheet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .island: "Floating island"
        case .sheet: "System sheet"
        }
    }
}
