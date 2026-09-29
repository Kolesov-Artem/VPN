import SwiftUI

struct VPNPanelSectionHeader: View {
    let title: String
    var explanation: String? = nil
    var showsDisclosure = false
    var isDisclosureExpanded = true

    var body: some View {
        HStack(alignment: explanation == nil ? .center : .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(VelvetTypography.sectionHeader)

                if let explanation {
                    Text(explanation)
                        .font(VelvetTypography.metadataLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: isDisclosureExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: VelvetMetrics.listDisclosureChevronWidth, height: 14)
                    .padding(.top, explanation == nil ? 0 : 3)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .accessibilityHint(showsDisclosure ? (isDisclosureExpanded ? "Свернуть список" : "Развернуть список") : "")
    }
}

struct VPNPanelContentSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(VelvetTheme.contentSurface, in: RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous))
    }
}
