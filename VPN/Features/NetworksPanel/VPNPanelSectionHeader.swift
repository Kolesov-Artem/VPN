import SwiftUI

struct VPNPanelSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct VPNPanelContentSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(VelvetTheme.contentSurface, in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous))
    }
}
