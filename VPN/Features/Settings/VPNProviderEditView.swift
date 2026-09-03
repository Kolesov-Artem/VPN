import SwiftUI
import UIKit

struct VPNProviderEditView: View {
    @Bindable var providerStore: VPNProviderStore
    let providerID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var subscriptionURL = ""
    @State private var copiedLink = false

    private var provider: VPNProvider? {
        providerStore.provider(id: providerID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                }

                Section("Subscription") {
                    TextField("Subscription URL", text: $subscriptionURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button {
                        UIPasteboard.general.string = subscriptionURL
                        copiedLink = true
                    } label: {
                        Label(copiedLink ? "Copied" : "Copy link", systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(subscriptionURL.isEmpty)
                }
            }
            .navigationTitle("Edit provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let provider else { return }
                name = provider.name
                subscriptionURL = provider.subscriptionURL ?? ""
            }
        }
    }

    private func save() {
        providerStore.renameProvider(id: providerID, name: name)
        providerStore.updateSubscriptionURL(id: providerID, url: subscriptionURL.nilIfBlank)
        dismiss()
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
