import Foundation

#if DEBUG

/// Canonical prototype states — each maps to one predictable home-screen experience.
enum VPNPrototypeScenario: String, CaseIterable, Identifiable, Codable {
    case onboarding
    case importedOnly
    case velvetOnly
    case velvetPlusImported
    case velvetExpired
    case importedExpired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onboarding: ui("1. Onboarding")
        case .importedOnly: ui("2. Other VPN only")
        case .velvetOnly: ui("3. Velvet only")
        case .velvetPlusImported: ui("4. Velvet + other VPN")
        case .velvetExpired: ui("5. Velvet expired")
        case .importedExpired: ui("6. Other VPN expired")
        }
    }

    var detail: String {
        switch self {
        case .onboarding:
            ui("Nothing configured yet")
        case .importedOnly:
            ui("No presets · purple stats promo")
        case .velvetOnly:
            ui("Presets on · no Velvet ads")
        case .velvetPlusImported:
            ui("Active subscription switches the VPN · All subscriptions shows every location")
        case .velvetExpired:
            ui("Velvet renewal card · no purple frame")
        case .importedExpired:
            ui("Imported renewal inside purple Velvet upsell")
        }
    }

    var usesNetworksLayout: Bool {
        self != .onboarding
    }

    var preferredPanelPosition: BottomPanelPosition {
        switch self {
        case .velvetExpired, .importedExpired: .intermediate
        default: .island
        }
    }

    /// Demo selection that triggers mismatch handling on the first connect attempt.
    func demoLocationSelection(scope: VPNProviderScope) -> VPNLocationSelection? {
        switch self {
        case .importedOnly:
            .smartJob(.mobileLTE, scope: scope)
        default:
            nil
        }
    }

    var defersSilentConnectFallback: Bool {
        self == .importedOnly
    }
}

#endif
