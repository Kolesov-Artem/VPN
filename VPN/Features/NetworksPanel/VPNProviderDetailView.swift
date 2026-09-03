import SwiftUI

struct VPNProviderDetailView: View {
    @Bindable var providerStore: VPNProviderStore
    let providerID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showsDeleteConfirmation = false
    @State private var showsEditSheet = false
    @State private var showsSupportSheet = false
    @State private var updateMessage: String?

    private var provider: VPNProvider? {
        providerStore.provider(id: providerID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let provider {
                    detailForm(provider)
                } else {
                    ContentUnavailableView("Provider not found", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle(provider?.name ?? "Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete subscription?", isPresented: $showsDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    providerStore.remove(id: providerID)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove \(provider?.name ?? "this provider") from Velvet?")
            }
            .sheet(isPresented: $showsEditSheet) {
                VPNProviderEditView(providerStore: providerStore, providerID: providerID)
            }
            .sheet(isPresented: $showsSupportSheet) {
                VPNSupportView(providerName: provider?.name)
                    .presentationDetents([.medium, .large])
            }
            .alert("Subscription updated", isPresented: Binding(
                get: { updateMessage != nil },
                set: { if !$0 { updateMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(updateMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func detailForm(_ provider: VPNProvider) -> some View {
        Form {
            if provider.hasProviderMessage, let message = provider.providerMessage {
                Section {
                    Text(message)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let updated = provider.providerMessageUpdatedAt {
                        Text("Updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Message from provider")
                }
            }

            Section {
                LabeledContent("Name", value: provider.name)
                if provider.kind == .velvetFeatured {
                    LabeledContent("Type", value: "Featured")
                }
                LabeledContent("Status", value: provider.status == .expired ? "Expired" : "Active")
                if let lastUpdated = provider.lastUpdated {
                    LabeledContent("Last updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }
                if let expiresAt = provider.expiresAt {
                    LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if provider.status.isActive {
                Section {
                    Button("Use this network only") {
                        providerStore.setProviderScope(.provider(providerID))
                        dismiss()
                    }
                } footer: {
                    Text("Locations and Connect will use only this subscription until you tap Show all.")
                }

                Section("Smart-Auto") {
                    Toggle(
                        "Include in Smart-Auto",
                        isOn: Binding(
                            get: { provider.includedInSmartAuto },
                            set: { providerStore.setIncludedInSmartAuto(id: providerID, enabled: $0) }
                        )
                    )
                    if let badge = provider.smartAutoBadge {
                        Text(badge)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Subscription") {
                if case let .active(_, traffic) = provider.status {
                    LabeledContent("Traffic", value: traffic)
                    LabeledContent("Locations", value: "\(provider.servers.count)")
                    trafficBar
                }

                if provider.status == .expired {
                    Button("Renew subscription") {
                        providerStore.renewSubscription(id: providerID)
                        updateMessage = "Subscription renewed for 30 days."
                    }
                    Button("Open renewal link") {
                        openURL(URL(string: provider.renewURL)!)
                    }
                }

                Button {
                    refreshSubscription()
                } label: {
                    if providerStore.isRefreshing {
                        HStack {
                            Text("Update subscription")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Text("Update subscription")
                    }
                }
                .disabled(providerStore.isRefreshing)

                LabeledContent("Subscription URL", value: provider.maskedSubscriptionURL)
            }

            Section {
                Button("Support") { showsSupportSheet = true }
                Button("Edit") { showsEditSheet = true }
                Button("Delete", role: .destructive) { showsDeleteConfirmation = true }
            }
        }
    }

    private var trafficBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Traffic remaining")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ProgressView(value: 0.62)
                .tint(VelvetTheme.accent)
        }
    }

    private func refreshSubscription() {
        Task {
            let success = await providerStore.refreshSubscription(id: providerID)
            if success {
                updateMessage = "Fetched latest servers, traffic, and provider message."
            }
        }
    }
}
