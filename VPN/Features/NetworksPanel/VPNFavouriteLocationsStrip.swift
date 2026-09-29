import SwiftUI

/// One quiet line of saved places. No section title and no accent colour.
struct VPNFavouriteLocationsStrip: View {
    let entries: [VPNFavouriteLocationEntry]
    var selectedID: String?
    let onSelect: (VPNFavouriteLocationEntry) -> Void
    let onRemove: (VPNFavouriteLocationEntry) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(entries) { entry in
                    chip(entry)
                }
            }
            .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .frame(height: VelvetMetrics.favouriteStripHeight)
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
            Button("Remove from Favourites", systemImage: "star.slash", role: .destructive) {
                onRemove(entry)
            }
        }
        .accessibilityLabel("\(entry.city), \(entry.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chipTitle(_ entry: VPNFavouriteLocationEntry) -> String {
        let sharesCity = entries.contains { $0.id != entry.id && $0.city == entry.city }
        return sharesCity ? "\(entry.city) · \(entry.providerName)" : entry.city
    }
}
