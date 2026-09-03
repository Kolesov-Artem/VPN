import SwiftUI

struct VPNProviderDetailView: View {
    let provider: VPNProvider

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name", value: provider.name)
                    LabeledContent("Status", value: provider.subtitle)
                    if provider.kind == .velvetFeatured {
                        LabeledContent("Type", value: "Featured")
                    }
                }

                Section("Subscription") {
                    if case let .active(_, traffic) = provider.status {
                        LabeledContent("Traffic", value: traffic)
                        LabeledContent("Locations", value: "\(provider.servers.count)")
                    } else {
                        Button("Renew subscription") {}
                    }
                    Button("Update subscription") {}
                }

                Section {
                    Button("Support") {}
                    Button("Edit") {}
                    Button("Delete", role: .destructive) {}
                }
            }
            .navigationTitle(provider.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
