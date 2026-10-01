import SwiftUI

struct VPNPanelSectionHeader: View {
    let title: String
    var explanation: String? = nil
    var showsDisclosure = false
    var isDisclosureExpanded = true
    /// Headline on the page, the way iOS names a group you scan for. The quieter style stays inside a card.
    var isProminent = false

    var body: some View {
        HStack(alignment: explanation == nil ? .center : .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ui(title))
                    .font(isProminent ? .headline : VelvetTypography.sectionHeader)
                    .foregroundStyle(isProminent ? .primary : .secondary)

                if let explanation {
                    Text(ui(explanation))
                        .font(isProminent ? .subheadline : VelvetTypography.metadataLabel)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: isDisclosureExpanded ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isProminent ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                    .frame(width: VelvetMetrics.listDisclosureChevronWidth, height: 14)
                    .padding(.top, explanation == nil ? 0 : 3)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityHint(showsDisclosure ? (isDisclosureExpanded ? ui("Свернуть список") : ui("Развернуть список")) : "")
    }
}

struct VPNPanelContentSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(VelvetTheme.contentSurface, in: RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous))
    }
}
