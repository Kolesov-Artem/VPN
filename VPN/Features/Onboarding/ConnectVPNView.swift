import SwiftUI
import UniformTypeIdentifiers

/// Foreground for the connect step. The map and brand bar live in `HomeView`
/// so the route change is a content crossfade, not a screen swap.
struct ConnectVPNView: View {
    @Binding var route: AppRoute
    @Bindable var providerStore: VPNProviderStore

    var isAddingConfiguration: Bool
    var onImportSuccess: (VPNProvider) -> Void
    var onVelvetTrial: () -> Void
    var onCancel: () -> Void

    @State private var configurationURL = ""
    @State private var isImportingFile = false
    @State private var isShowingScannerMessage = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 24) {
            if isAddingConfiguration {
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .font(.subheadline.weight(.semibold))
                }
            }

            Text("Connect VPN")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            configurationField

            if let importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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

            if !configurationURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    attemptImport(from: configurationURL)
                } label: {
                    Text("Add configuration")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(VelvetTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(PressScaleButtonStyle())
            }

            if !isAddingConfiguration {
                Button(action: onVelvetTrial) {
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
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.data, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                configurationURL = url.absoluteString
                attemptImport(from: url.absoluteString)
            case .failure:
                importError = VPNImportError.unreadable.errorDescription
            }
        }
        .alert("QR scanner", isPresented: $isShowingScannerMessage) {
            Button("Use demo configuration") {
                configurationURL = "velvet://demo-config"
                attemptImport(from: configurationURL)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera scanning is represented by a local prototype action.")
        }
        .onChange(of: configurationURL) { _, _ in
            importError = nil
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
                attemptImport(from: configurationURL)
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
                .stroke(importError == nil ? Color(.separator).opacity(0.45) : Color.red.opacity(0.6), lineWidth: 1)
        }
    }

    private func attemptImport(from urlString: String) {
        switch providerStore.importFromURL(urlString) {
        case let .success(provider):
            importError = nil
            onImportSuccess(provider)
        case let .failure(error):
            importError = error.errorDescription
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
