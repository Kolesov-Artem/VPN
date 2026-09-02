import SwiftUI

enum VelvetTheme {
    static let accent = Color(
        red: 119 / 255,
        green: 41 / 255,
        blue: 246 / 255
    )
    static let deepPurple = Color(
        red: 94 / 255,
        green: 25 / 255,
        blue: 226 / 255
    )
    static let softPurple = Color(
        red: 191 / 255,
        green: 150 / 255,
        blue: 255 / 255
    )

    static let horizontalPadding: CGFloat = 16
    static let headerHorizontalPadding: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let cardRadius: CGFloat = 20
    static let panelRadius: CGFloat = 28
    static let iconVisualSize: CGFloat = 36
    static let minimumTapTarget: CGFloat = 44
    static let islandHorizontalInset: CGFloat = 20
    /// Compact floating margin at the half-height detent (Find My card inset).
    static let islandHalfMargin: CGFloat = 8
    /// Pulls the expanded sheet slightly closer to the status bar than the raw
    /// safe area inset.
    static let expandedTopInsetReduction: CGFloat = 16
    /// Fallback bottom margin for devices without a home indicator, matching the
    /// minimum layout margin Apple recommends for edge-adjacent content.
    static let minimumBottomMargin: CGFloat = 16
    static let islandShadowOpacity: CGFloat = 0.12
    static let expandedShadowOpacity: CGFloat = 0.08
    static let islandShadowRadius: CGFloat = 12
    static let expandedShadowRadius: CGFloat = 16
}

struct VelvetBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: VelvetTheme.deepPurple, location: 0),
                .init(color: VelvetTheme.softPurple, location: 0.43),
                .init(color: Color(.systemBackground), location: 0.78),
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct VelvetBrand: View {
    var body: some View {
        Label {
            Text("VELVET")
                .font(.headline.weight(.heavy))
        } icon: {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title2)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Velvet VPN")
    }
}

/// Circular panel control: 36pt visual, 44pt HIG hit area.
struct VelvetIconButtonLabel: View {
    let systemName: String
    var foreground: Color = .primary
    var background: Color = Color(.tertiarySystemFill)

    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: VelvetTheme.iconVisualSize, height: VelvetTheme.iconVisualSize)
            .background(background, in: Circle())
            .frame(width: VelvetTheme.minimumTapTarget, height: VelvetTheme.minimumTapTarget)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Expands tappable area to the HIG minimum without changing visual size.
    func velvetTapTarget(
        width: CGFloat = VelvetTheme.minimumTapTarget,
        height: CGFloat = VelvetTheme.minimumTapTarget
    ) -> some View {
        frame(width: width, height: height)
            .contentShape(Rectangle())
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion
                    ? VelvetMotion.pressScale
                    : 1
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(VelvetMotion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// Bottom contrast for the connect form. Kept on the form layer so it lifts
/// with the keyboard instead of staying pinned to the map.
struct OnboardingContentBackdrop: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(.systemBackground).opacity(0.28), location: 0.2),
                .init(color: Color(.systemBackground).opacity(0.9), location: 0.45),
                .init(color: Color(.systemBackground), location: 0.62),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .padding(.top, -56)
    }
}

private struct KeyboardLiftModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardOverlap: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardOverlap)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillChangeFrameNotification
                )
            ) { notification in
                guard
                    let userInfo = notification.userInfo,
                    let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                else { return }

                let overlap = max(0, UIScreen.main.bounds.maxY - endFrame.origin.y)

                withAnimation(VelvetMotion.keyboard(reduceMotion: reduceMotion, duration: duration)) {
                    keyboardOverlap = overlap
                }
            }
    }
}

extension View {
    func keyboardLift() -> some View {
        modifier(KeyboardLiftModifier())
    }
}

