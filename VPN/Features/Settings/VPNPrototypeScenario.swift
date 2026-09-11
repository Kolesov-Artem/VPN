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
        case .onboarding: "1. Onboarding"
        case .importedOnly: "2. Other VPN only"
        case .velvetOnly: "3. Velvet only"
        case .velvetPlusImported: "4. Velvet + other VPN"
        case .velvetExpired: "5. Velvet expired"
        case .importedExpired: "6. Other VPN expired"
        }
    }

    var detail: String {
        switch self {
        case .onboarding:
            "Nothing configured yet"
        case .importedOnly:
            "No presets · purple stats promo"
        case .velvetOnly:
            "Presets on · no Velvet ads"
        case .velvetPlusImported:
            "Presets on · no promo shells"
        case .velvetExpired:
            "Velvet renewal card · no purple frame"
        case .importedExpired:
            "Imported renewal inside purple Velvet upsell"
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
