import SwiftUI

/// Provider announcement shown at the top of the networks sheet when there is
/// only one subscription — the picker that would otherwise surface this copy is hidden.
struct VPNProviderMessageCard: View {
    let provider: VPNProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message from provider")
                .font(VelvetTypography.sectionHeader)
                .foregroundStyle(.secondary)

            if let message = provider.providerMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let updated = provider.providerMessageUpdatedAt {
                Text("Updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                    .font(VelvetTypography.metadataLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, VelvetMetrics.rowHorizontalPadding)
        .padding(.vertical, VelvetMetrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            VelvetTheme.contentSurface,
            in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = ["Message from provider"]
        if let message = provider.providerMessage {
            parts.append(message)
        }
        if let updated = provider.providerMessageUpdatedAt {
            parts.append("Updated \(updated.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: ". ")
    }
}
