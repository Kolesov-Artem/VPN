import SwiftUI

/// Contextual card when the current VPN cannot satisfy the selected preset.
struct VPNSelectionGapCard: View {
    let mismatch: VPNSelectionMismatch
    let showsVelvetPromo: Bool
    let onTryVelvet: () -> Void
    let onUseSmartAuto: () -> Void

    var body: some View {
        if showsVelvetPromo {
            VelvetPromoCard(onPromoTap: onTryVelvet) {
                gapContent
            }
        } else {
            gapContent
                .padding(VelvetMetrics.statsStripExpandedCardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous)
                        .fill(VelvetTheme.contentSurface)
                )
        }
    }

    private var gapContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mismatch.gapCardTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelvetTheme.mainTextDark)

                Text(mismatch.gapCardBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if showsVelvetPromo {
                    gapActionButton(title: "Try Velvet", isPrimary: true, action: onTryVelvet)
                }

                gapActionButton(
                    title: "Use Smart Auto",
                    isPrimary: !showsVelvetPromo,
                    action: onUseSmartAuto
                )
            }
        }
    }

    private func gapActionButton(
        title: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isPrimary ? Color.white : VelvetTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isPrimary ? VelvetTheme.accent : VelvetTheme.accent.opacity(0.12))
                )
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
