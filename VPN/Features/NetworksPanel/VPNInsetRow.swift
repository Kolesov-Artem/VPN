import SwiftUI

/// Standard inset list row styling aligned with `List` / `.insetGrouped`.
struct VPNInsetRow: View {
    var iconSymbol: String?
    var flag: String?
    let title: String
    var subtitle: String?
    var pingLabel: String?
    var isPinging = false
    var signal: VPNLocation.Signal?
    var showsChevron = false
    var isDisclosureExpanded = false
    var isSelected = false
    var accentIcon = false

    var body: some View {
        HStack(spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isSelected ? .body.weight(.semibold) : .body)
                    .foregroundStyle(isSelected ? VelvetTheme.accent : .primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            trailingMetadata
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VelvetTheme.accent.opacity(VelvetTheme.selectionHighlightOpacity))
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leading: some View {
        if let flag {
            Text(flag)
                .font(.title3)
                .frame(width: 30, alignment: .center)
        } else if let iconSymbol {
            Image(systemName: iconSymbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(accentIcon ? VelvetTheme.accent : .secondary)
                .frame(width: 30, alignment: .center)
        } else {
            Color.clear.frame(width: 30)
        }
    }

    @ViewBuilder
    private var trailingMetadata: some View {
        HStack(spacing: 8) {
            if isPinging {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 28, height: 20)
            } else if let pingLabel {
                Text(pingLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let signal {
                VPNLocationSignalIcon(signal: signal)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(VelvetTheme.accent)
                    .accessibilityLabel("Selected")
            }

            if showsChevron {
                Image(systemName: isDisclosureExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
