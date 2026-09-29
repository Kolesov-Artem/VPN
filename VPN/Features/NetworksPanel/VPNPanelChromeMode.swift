import Foundation

/// Product chrome for Networks island: one subscription vs several (Figma screens 2 vs 1).
enum VPNPanelChromeMode: Equatable {
    case singleProvider
    case multiProvider

    static func resolve(providerCount: Int) -> VPNPanelChromeMode {
        providerCount > 1 ? .multiProvider : .singleProvider
    }
}
