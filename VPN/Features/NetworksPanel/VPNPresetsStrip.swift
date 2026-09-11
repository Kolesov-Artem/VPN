import SwiftUI

struct VPNPresetsStrip: View {
    let locationSelection: VPNLocationSelection
    let selectionSource: VPNSelectionSource
    var addsTopSpacing: Bool = false
    let onSelect: (VPNUseCaseMenuChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VPNPanelSectionHeader(title: "Presets")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VPNUseCaseMenuChoice.allCases) { choice in
                        presetCard(choice)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .padding(.top, addsTopSpacing ? 12 : 0)
    }

    private func presetCard(_ choice: VPNUseCaseMenuChoice) -> some View {
        let isActive = selectionSource.activeUseCase(for: locationSelection) == choice

        return Button {
            onSelect(choice)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: choice.iconSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(choice.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(choice.cardSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(width: 132, height: 96, alignment: .topLeading)
            .background(
                VelvetTheme.contentSurface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.black : Color.black.opacity(0.06),
                        lineWidth: isActive ? 2 : 1
                    )
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
