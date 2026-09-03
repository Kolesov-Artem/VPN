import SwiftUI

/// Live session stats shown inside the collapsed island and pinned in the sheet.
struct ConnectionStatsStrip: View {
    let mockPublicIP: String
    let regionLabel: String
    let downloadRate: String
    let uploadRate: String
    let durationText: String
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection stats. Tap for details.")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    private var content: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your IP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(mockPublicIP) · \(regionLabel)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            statColumn(title: "Down", value: downloadRate)
            statColumn(title: "Up", value: uploadRate)
            statColumn(title: "Time", value: durationText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }
}
