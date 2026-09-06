import SwiftUI
import UIKit

extension Color {
    /// Resolves at runtime for light and dark appearance using UIKit colors directly.
    /// Avoids `UIColor(SwiftUI.Color)` which can trap during early app launch.
    static func velvetAdaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

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

    static let connectedGreen = Color(
        red: 0 / 255,
        green: 178 / 255,
        blue: 63 / 255
    )

    static let connectedTint = connectedGreen
    static let disconnectedTint = accent
    static let errorTint = Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255)
    static let warningTint = Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255)
    static let providerAccent = Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
    static let selectionHighlightOpacity: CGFloat = 0.12

    static let mainTextDark = Color.velvetAdaptive(
        light: UIColor(red: 24 / 255, green: 8 / 255, blue: 49 / 255, alpha: 1),
        dark: .label
    )

    static let statsStripBackground = Color.velvetAdaptive(
        light: UIColor.systemGray.withAlphaComponent(0.12),
        dark: UIColor.white.withAlphaComponent(0.08)
    )

    static let statsStripProgressTrack = Color.velvetAdaptive(
        light: UIColor.systemGray.withAlphaComponent(0.2),
        dark: UIColor.white.withAlphaComponent(0.14)
    )

    static let horizontalPadding: CGFloat = 16
    static let controlRadius: CGFloat = 16
    static let panelRadius: CGFloat = 28
    static let islandHorizontalInset: CGFloat = 20
    /// Compact floating margin at the half-height detent (Find My card inset).
    static let islandHalfMargin: CGFloat = 8
    /// Pulls the expanded sheet slightly closer to the status bar than the raw
    /// safe area inset.
    static let expandedTopInsetReduction: CGFloat = 16
    /// Fallback bottom margin for devices without a home indicator, matching the
    /// minimum layout margin Apple recommends for edge-adjacent content.
    static let minimumBottomMargin: CGFloat = 16
    static let islandShadowOpacity: CGFloat = 0.22
    static let expandedShadowOpacity: CGFloat = 0.14

    /// Expanded sheet scroll canvas behind white content blocks.
    static let sheetCanvas = Color.velvetAdaptive(
        light: UIColor(red: 245 / 255, green: 242 / 255, blue: 252 / 255, alpha: 1),
        dark: UIColor(red: 28 / 255, green: 26 / 255, blue: 36 / 255, alpha: 1)
    )

    static let connectedPanelFallback = Color.velvetAdaptive(
        light: UIColor(red: 220 / 255, green: 244 / 255, blue: 228 / 255, alpha: 1),
        dark: UIColor(red: 22 / 255, green: 48 / 255, blue: 32 / 255, alpha: 1)
    )

    static let disconnectedPanelFallback = Color.velvetAdaptive(
        light: UIColor(red: 232 / 255, green: 222 / 255, blue: 252 / 255, alpha: 1),
        dark: UIColor(red: 36 / 255, green: 28 / 255, blue: 52 / 255, alpha: 1)
    )

    static var connectedTintUIColor: UIColor {
        UIColor(red: 0 / 255, green: 178 / 255, blue: 63 / 255, alpha: 1)
    }

    static var deepPurpleUIColor: UIColor {
        UIColor(red: 94 / 255, green: 25 / 255, blue: 226 / 255, alpha: 1)
    }

    /// White surface for providers, cards, and location lists inside the sheet.
    static let contentSurface = Color(.systemBackground)
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
