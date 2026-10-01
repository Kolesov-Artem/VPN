import SwiftUI

struct VPNPresetsStrip: View {
    let locationSelection: VPNLocationSelection
    let selectionSource: VPNSelectionSource
    var usesFigmaSection550Copy: Bool = false
    var staggerIndexOffset: Int = 0
    var hidesForLoading: Bool = false
    var reduceMotion: Bool = false
    var panelRevealProgress: CGFloat = 1
    var panelStaggerIndexOffset: Int = 0
    let onSelect: (VPNUseCaseMenuChoice) -> Void

    private var sectionTitle: String {
        usesFigmaSection550Copy ? VPNFigmaSection550Copy.presetsSectionTitle : ui("Presets")
    }

    private var choices: [VPNUseCaseMenuChoice] {
        usesFigmaSection550Copy ? VPNFigmaSection550Copy.expandedPresetChoices : VPNUseCaseMenuChoice.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VelvetMetrics.panelSectionHeaderSpacing) {
            VPNPanelSectionHeader(title: sectionTitle)
                .velvetPanelRowReveal(
                    progress: panelRevealProgress,
                    index: panelStaggerIndexOffset,
                    reduceMotion: reduceMotion
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        presetCard(choice)
                            .velvetLoadingShimmer(
                                isActive: hidesForLoading,
                                reduceMotion: reduceMotion,
                                index: staggerIndexOffset + index
                            )
                            .velvetPanelRowReveal(
                                progress: panelRevealProgress,
                                index: panelStaggerIndexOffset + 1 + index,
                                reduceMotion: reduceMotion
                            )
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func presetCard(_ choice: VPNUseCaseMenuChoice) -> some View {
        let isActive = selectionSource.activeUseCase(for: locationSelection) == choice
        let title = usesFigmaSection550Copy
            ? VPNFigmaSection550Copy.presetCardTitle(for: choice)
            : choice.title
        let subtitle = usesFigmaSection550Copy
            ? VPNFigmaSection550Copy.presetCardSubtitle(for: choice)
            : choice.cardSubtitle

        return Button {
            onSelect(choice)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: choice.iconSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(width: 132, height: 96, alignment: .topLeading)
            .background(
                VelvetTheme.contentSurface,
                in: RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: VelvetMetrics.groupedCornerRadius, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.black : Color.black.opacity(0.06),
                        lineWidth: isActive ? 2 : 1
                    )
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
