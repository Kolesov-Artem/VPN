import SwiftUI
import UniformTypeIdentifiers

/// Foreground for the connect step. The map and brand bar live in `HomeView`
/// so the route change is a content crossfade, not a screen swap.
struct ConnectVPNView: View {
    @Binding var route: AppRoute
    /// Shown when this screen is adding a configuration on top of home, not first-run.
    var canCancel = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var configurationURL = ""
    @State private var isImportingFile = false
    @State private var isShowingScannerMessage = false
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 24) {
            staggered(0) {
                Text("Connect VPN")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            staggered(1) {
                configurationField
            }

            staggered(2) {
                HStack(spacing: 12) {
                    secondaryButton(
                        title: "Upload",
                        symbol: "folder",
                        action: { isImportingFile = true }
                    )

                    secondaryButton(
                        title: "Scan",
                        symbol: "qrcode.viewfinder",
                        action: { isShowingScannerMessage = true }
                    )
                }
            }

            staggered(3) {
                Button {
                    withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                        route = .home
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.9))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Velvet VPN")
                                .font(.subheadline.weight(.semibold))
                            Text("3 days free trial")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(VelvetTheme.accent, in: RoundedRectangle(cornerRadius: VelvetTheme.cardRadius))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityHint("Opens the VPN dashboard")
            }

            if canCancel {
                staggered(4) {
                    Button("Cancel") {
                        withAnimation(VelvetMotion.route(reduceMotion: reduceMotion)) {
                            route = .home
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityHint("Returns to the dashboard without adding a configuration")
                }
            }
        }
        .onAppear {
            guard !reduceMotion else {
                revealed = true
                return
            }
            withAnimation(VelvetMotion.route(reduceMotion: false)) {
                revealed = true
            }
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.data, .text],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                configurationURL = url.absoluteString
            }
        }
        .alert("QR scanner", isPresented: $isShowingScannerMessage) {
            Button("Use demo configuration") {
                configurationURL = "velvet://demo-config"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera scanning is represented by a local prototype action.")
        }
    }

    private func staggered<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : VelvetMotion.entranceOffsetY * 0.6)
            .animation(
                VelvetMotion.easeOut(duration: VelvetMotion.contentDuration)
                    .delay(Double(index) * VelvetMotion.rowStaggerStep + VelvetMotion.rowStaggerBase),
                value: revealed
            )
    }

    private var configurationField: some View {
        HStack(spacing: 0) {
            TextField("https://yourvpn.example", text: $configurationURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)

            Button("Paste") {
                configurationURL = "https://yourvpn.34945"
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 20)
            .frame(minHeight: 56)
            .background(.regularMaterial)
        }
        .frame(minHeight: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: VelvetTheme.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: VelvetTheme.controlRadius)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        }
    }

    private func secondaryButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: VelvetTheme.controlRadius))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
