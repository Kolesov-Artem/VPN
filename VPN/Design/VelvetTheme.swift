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
    static let controlRadius: CGFloat = 16
    static let panelRadius: CGFloat = 28
    static let islandHorizontalInset: CGFloat = 20
    /// Fallback bottom margin for devices without a home indicator, matching the
    /// minimum layout margin Apple recommends for edge-adjacent content.
    static let minimumBottomMargin: CGFloat = 16
    static let islandShadowOpacity: CGFloat = 0.22
    static let expandedShadowOpacity: CGFloat = 0.14
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

