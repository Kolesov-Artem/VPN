import SwiftUI

/// Horizontal use-case cards matching the five collapsed-island menu choices.
struct VPNUseCaseCardsCard: View {
    let locationSelection: VPNLocationSelection
    let selectionSource: VPNSelectionSource
    let scope: VPNProviderScope
    let onUseCaseConnect: (VPNUseCaseMenuChoice) -> Void

    private let cardWidth: CGFloat = 136
    private let cardHeight: CGFloat = 132
    private let horizontalInset: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(VPNUseCaseMenuChoice.allCases) { choice in
                    useCaseCard(choice)
                }
            }
            .padding(.leading, horizontalInset)
            .padding(.trailing, horizontalInset)
        }
        .scrollClipDisabled()
    }

    private func useCaseCard(_ choice: VPNUseCaseMenuChoice) -> some View {
        let isActive = selectionSource.activeUseCase(for: locationSelection) == choice

        return Button {
            onUseCaseConnect(choice)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
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
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .background(
                VelvetTheme.contentSurface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.primary : Color.black.opacity(0.06),
                        lineWidth: isActive ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
