import SwiftUI

struct VPNSupportView: View {
    let providerName: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section(ui("Help")) {
                    supportRow("Connection keeps failing", detail: ui("Check active subscriptions and try Smart-Auto."))
                    supportRow("Import failed", detail: ui("Verify the subscription URL and try again."))
                    supportRow("Slow speeds", detail: ui("Run Check ping and pick a lower-latency server."))
                }

                Section(ui("Contact")) {
                    Button {
                        openURL(URL(string: "mailto:support@velvet.vpn")!)
                    } label: {
                        Label(ui("Email support"), systemImage: "envelope")
                    }

                    Button {
                        openURL(URL(string: "https://velvet.vpn/help")!)
                    } label: {
                        Label(ui("Help center"), systemImage: "safari")
                    }
                }

                if let providerName {
                    Section(ui("Provider")) {
                        Text(uiFormat("Questions about %@ billing or renewal should go to that provider's support channel.", providerName))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(ui("Support"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ui("Done")) { dismiss() }
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
