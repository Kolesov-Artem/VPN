import SwiftUI

/// Collapsed summary of subscriptions; expand for provider rows (renew / messages).
struct VPNCompactNetworksCard: View {
    @Bindable var providerStore: VPNProviderStore
    let onOpenProvider: (UUID) -> Void

    @State private var isExpanded = false

    private var providers: [VPNProvider] { providerStore.providers }

    private var summaryTitle: String {
        let count = providers.count
        let providerWord = count == 1 ? "provider" : "providers"
        return "\(count) VPN \(providerWord)"
    }

    private var needsAttention: Bool {
        providers.contains { $0.status == .expired }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(summaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if needsAttention {
                        Circle()
                            .fill(VelvetTheme.errorTint)
                            .frame(width: 7, height: 7)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    providerRow(provider)

                    if index < providers.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .clipped()
        .background(VelvetTheme.contentSurface, in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous))
    }

    private func providerRow(_ provider: VPNProvider) -> some View {
        Button {
            onOpenProvider(provider.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: provider.iconSymbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(provider.kind == .velvetFeatured ? VelvetTheme.accent : VelvetTheme.providerAccent)
                    .frame(width: VelvetMetrics.listIconSlot, height: VelvetMetrics.listIconSlot)
                    .background(
                        (provider.kind == .velvetFeatured ? VelvetTheme.accent : VelvetTheme.providerAccent)
                            .opacity(VelvetTheme.selectionHighlightOpacity),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(provider.name)
                            .foregroundStyle(.primary)
                        if provider.kind == .velvetFeatured {
                            Text("Featured")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(VelvetTheme.accent)
                        }
                    }

                    if provider.hasProviderMessage, let message = provider.providerMessage {
                        Text(message.linePreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(provider.status == .expired ? "Renew to restore access" : provider.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if provider.status == .expired {
                    Text("Expired")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(VelvetTheme.errorTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(VelvetTheme.errorTint.opacity(VelvetTheme.selectionHighlightOpacity), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var linePreview: String {
        replacingOccurrences(of: "\n", with: " · ")
    }
}
