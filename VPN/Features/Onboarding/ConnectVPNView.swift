import SwiftUI
import UniformTypeIdentifiers

/// Foreground for the connect step. The map and brand bar live in `HomeView`
/// so the route change is a content crossfade, not a screen swap.
struct ConnectVPNView: View {
    @Binding var route: AppRoute

    @State private var configurationURL = ""
    @State private var isImportingFile = false
    @State private var isShowingScannerMessage = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Connect VPN")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            configurationField

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

            Button {
                route = .home
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle")
                        .font(.title)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Velvet VPN")
                            .font(.subheadline.weight(.semibold))
                        Text("3 days free trial")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(VelvetTheme.accent, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Opens the VPN dashboard")
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
            .background(Color(.secondarySystemBackground))
        }
        .frame(minHeight: 56)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: VelvetTheme.controlRadius))
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
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

