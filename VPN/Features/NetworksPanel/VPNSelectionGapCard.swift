import SwiftUI

/// Contextual card when the current VPN cannot satisfy the selected preset.
struct VPNSelectionGapCard: View {
    let mismatch: VPNSelectionMismatch
    let onUseSmartAuto: () -> Void
    let onBrowseLocations: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mismatch.gapCardTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(mismatch.gapCardBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: onUseSmartAuto) {
                    Text("Use Smart Auto")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(VelvetTheme.accent, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())

                Button(action: onBrowseLocations) {
                    Text("Browse locations")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemFill), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous)
                .fill(VelvetTheme.contentSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mismatch.gapCardTitle). \(mismatch.gapCardBody)")
    }
}
