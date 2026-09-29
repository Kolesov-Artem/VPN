import SwiftUI

/// Figma 358:29398 — grouped table row on the map after import.
struct MapProviderHighlightCard: View {
    let provider: VPNProvider

    var body: some View {
        HStack(spacing: 0) {
            VPNProviderBrandLogo(provider: provider, size: 68)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(VPNFigmaSection550Copy.mapToastTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(provider.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .frame(height: 68)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            }
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(VPNFigmaSection550Copy.mapToastTitle). \(provider.subtitle)")
    }
}
