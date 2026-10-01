import SwiftUI

/// Saved places, with the same section title the location groups use.
struct VPNFavouriteLocationsStrip: View {
    let entries: [VPNFavouriteLocationEntry]
    var selectedID: String?
    /// Pulls the title and the first chip in from a full-width row so they line up with the island.
    var horizontalInset: CGFloat = 0
    let onSelect: (VPNFavouriteLocationEntry) -> Void
    let onRemove: (VPNFavouriteLocationEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VelvetMetrics.favouriteStripSpacing) {
            VPNPanelSectionHeader(title: ui("Favourites"))
                .padding(.horizontal, horizontalInset)
                .frame(height: VelvetMetrics.favouriteHeaderHeight, alignment: .leading)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(entries) { entry in
                        chip(entry)
                    }
                }
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: VelvetMetrics.favouriteStripHeight)
        }
    }

    private func chip(_ entry: VPNFavouriteLocationEntry) -> some View {
        let isSelected = entry.id == selectedID
        return Button {
            onSelect(entry)
        } label: {
            HStack(spacing: 6) {
                Text(entry.flag)
                    .font(.body)
                Text(chipTitle(entry))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 14)
            .frame(height: VelvetMetrics.islandChromeButtonSize)
            .background(
                isSelected ? Color(.secondarySystemFill) : Color(.tertiarySystemFill),
                in: Capsule()
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .contextMenu {
            Button(ui("Remove from Favourites"), systemImage: "star.slash", role: .destructive) {
                onRemove(entry)
            }
        }
        .accessibilityLabel("\(entry.city), \(entry.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chipTitle(_ entry: VPNFavouriteLocationEntry) -> String {
        ui(entry.name.replacingOccurrences(of: "SMART-", with: ""))
    }
}
