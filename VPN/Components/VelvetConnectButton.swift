import SwiftUI

/// Shared connect CTA for both panel variants — press feedback on pointer-down,
/// symbol crossfade on state, haptic on connect/disconnect.
struct VelvetConnectButton: View {
    @Binding var connectionState: VPNConnectionState
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Group {
                    if connectionState == .connecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(
                            systemName: connectionState == .connected
                                ? "checkmark.shield.fill"
                                : "power"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 24, height: 24)

                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
        }
        .buttonStyle(VelvetProminentButtonStyle(tint: tint))
        .disabled(connectionState == .connecting)
        .sensoryFeedback(.impact(weight: .medium), trigger: connectionState) { _, new in
            new == .connected || new == .disconnected
        }
        .animation(VelvetMotion.connectionState(reduceMotion: reduceMotion), value: connectionState)
        .accessibilityHint(
            connectionState == .connected
                ? "Disconnects the demo VPN"
                : "Connects the demo VPN"
        )
    }

    private var title: String {
        switch connectionState {
        case .disconnected: "Connect"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        }
    }

    private var tint: Color {
        connectionState == .connected ? .green : VelvetTheme.accent
    }
}

struct VelvetProminentButtonStyle: ButtonStyle {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                tint.opacity(isEnabled ? 1 : 0.55),
                in: RoundedRectangle(cornerRadius: VelvetTheme.controlRadius)
            )
            .scaleEffect(
                configuration.isPressed && isEnabled && !reduceMotion
                    ? VelvetMotion.pressScale
                    : 1
            )
            .opacity(configuration.isPressed && isEnabled ? 0.92 : 1)
            .animation(VelvetMotion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
