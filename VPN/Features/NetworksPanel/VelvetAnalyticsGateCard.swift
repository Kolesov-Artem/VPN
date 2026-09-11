import SwiftUI

struct VelvetAnalyticsGateCard: View {
    let onExplore: () -> Void
    var embedInForm = false

    var body: some View {
        Group {
            if embedInForm {
                formRowContent
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analytics only with Velvet")
        .accessibilityHint("Opens Velvet VPN website")
    }

    private var formRowContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.tertiarySystemFill), in: Circle())

            Text("Analytics only with Velvet")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)

            Button("Explore Velvet", action: onExplore)
                .font(.body)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var cardContent: some View {
        ZStack {
            analyticsChartBackground
                .blur(radius: 6)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)

            formRowContent
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .frame(minHeight: 112)
    }

    private var analyticsChartBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBlue).opacity(0.18),
                    Color(.systemGray4).opacity(0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.72))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.32),
                        control1: CGPoint(x: width * 0.3, y: height * 0.55),
                        control2: CGPoint(x: width * 0.65, y: height * 0.2)
                    )
                }
                .stroke(Color(.systemBlue).opacity(0.35), lineWidth: 2)
            }
        }
    }
}
