import SwiftUI

/// How the home screen is organized. The island stays available so the
/// labeled page and the tab bar can be compared with it in one build.
enum VPNHomeChrome: String, CaseIterable, Identifiable {
    case island
    case islandMenu
    case page
    case board
    case hero
    case tabs

    static let storageKey = "velvet.homeChrome"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .island: ui("Island")
        case .islandMenu: ui("Island menu")
        case .page: ui("One page")
        case .board: ui("Dashboard")
        case .hero: ui("Hero")
        case .tabs: ui("Bottom menu")
        }
    }
}
