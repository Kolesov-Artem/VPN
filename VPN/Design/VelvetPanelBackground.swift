import SwiftUI

/// Frosted panel fill — the most opaque system glass, without state tint washes.
struct VelvetPanelBackground: View {
    enum MaterialStyle {
        case island
        case sheet

        var material: Material {
            switch self {
            case .island, .sheet: .ultraThickMaterial
            }
        }
    }

    var materialStyle: MaterialStyle = .island
    /// Solid fill during panel drag — avoids re-blurring material every frame.
    var prefersSolidFill = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var solidFallback: Color {
        Color(.systemBackground)
    }

    var body: some View {
        Group {
            if reduceTransparency || prefersSolidFill {
                solidFallback
            } else {
                Rectangle().fill(materialStyle.material)
            }
        }
    }
}
