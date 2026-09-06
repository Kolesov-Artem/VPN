import SwiftUI

/// Compact device / VPN IP readout used in the classic sheet panel.
struct ConnectionIPWell: View {
    static let demoDeviceIP = "192.168.1.42"

    let deviceIP: String
    let vpnIP: String?
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
    }

    private var content: some View {
        HStack(spacing: 12) {
            ipColumn(title: "Device", value: deviceIP)
            ipColumn(title: "VPN", value: vpnIP ?? "—")
        }
        .padding(.horizontal, VelvetTheme.horizontalPadding)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: VelvetMetrics.contentSurfaceCornerRadius, style: .continuous))
        .contentShape(Rectangle())
    }

    private func ipColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
