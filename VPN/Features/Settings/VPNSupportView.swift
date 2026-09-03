import SwiftUI

struct VPNSupportView: View {
    let providerName: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section("Help") {
                    supportRow("Connection keeps failing", detail: "Check active subscriptions and try Smart-Auto.")
                    supportRow("Import failed", detail: "Verify the subscription URL and try again.")
                    supportRow("Slow speeds", detail: "Run Check ping and pick a lower-latency server.")
                }

                Section("Contact") {
                    Button {
                        openURL(URL(string: "mailto:support@velvet.vpn")!)
                    } label: {
                        Label("Email support", systemImage: "envelope")
                    }

                    Button {
                        openURL(URL(string: "https://velvet.vpn/help")!)
                    } label: {
                        Label("Help center", systemImage: "safari")
                    }
                }

                if let providerName {
                    Section("Provider") {
                        Text("Questions about \(providerName) billing or renewal should go to that provider's support channel.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func supportRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
