import SwiftUI
import UIKit

struct VPNProviderDetailView: View {
    @Bindable var providerStore: VPNProviderStore
    let providerID: UUID
    var isVPNConnected = false
    var activeConnectionProviderID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("velvet.autoConnect") private var autoConnect = false
    @AppStorage("velvet.killSwitch") private var killSwitch = false
    @AppStorage("velvet.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("velvet.dnsLeakProtection") private var dnsLeakProtection = true
    @AppStorage("velvet.splitTunneling") private var splitTunneling = false

    @State private var showsDeleteConfirmation = false
    @State private var showsEditSheet = false
    @State private var showsSupportSheet = false
    @State private var showsProviderMessage = false
    @State private var updateMessage: String?
    @State private var useThisNetworkOnlyToggle = false

    private var provider: VPNProvider? {
        providerStore.provider(id: providerID)
    }

    private var usesThisNetworkOnly: Bool {
        providerStore.providerScope.isScoped(to: providerID)
    }

    private var providerSettingsNavigationTitle: String {
        guard let provider else { return "Provider" }
        if VPNReleaseProfile.isRelease1 {
            return "\(provider.name) settings"
        }
        return provider.name
    }

    var body: some View {
        NavigationStack {
            Group {
                if let provider {
                    if VPNReleaseProfile.isRelease1 {
                        release1DetailForm(provider)
                    } else {
                        legacyDetailForm(provider)
                    }
                } else {
                    ContentUnavailableView("Provider not found", systemImage: "exclamationmark.triangle")
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(providerSettingsNavigationTitle)
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
                Text("\(provider?.name ?? "This provider") will be removed from Networks and Smart-Auto.")
            }
            .sheet(isPresented: $showsEditSheet) {
                VPNProviderEditView(providerStore: providerStore, providerID: providerID)
            }
            .sheet(isPresented: $showsSupportSheet) {
                VPNSupportView(providerName: provider?.name)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsProviderMessage) {
                if let provider, let message = provider.displayedProviderMessage {
                    NavigationStack {
                        ScrollView {
                            Text(message)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .navigationTitle("Message from provider")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showsProviderMessage = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
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

    private func release1DetailForm(_ provider: VPNProvider) -> some View {
        Form {
            Section {
                VPNTrafficUsageCard(
                    providers: providerStore.providers,
                    scopedProviderID: provider.id,
                    embedInForm: true
                )
            }

            Section {
                if provider.status.isActive {
                    Text(VPNFigmaSection550Copy.providerSettingsAlertMessage)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent("Name", value: provider.catalogDisplayName)

                if let accountID = provider.subscriptionAccountID {
                    copyableInfoRow(label: "ID", value: accountID)
                }

                LabeledContent("Subscription", value: subscriptionTier(for: provider))
                LabeledContent("Status", value: statusLabel(for: provider))
                LabeledContent("Last updated", value: lastUpdatedLabel(for: provider))

                Button {
                    if let urlString = provider.subscriptionURL, let url = URL(string: urlString) {
                        openURL(url)
                    } else {
                        openURL(VelvetTheme.paywallURL)
                    }
                } label: {
                    Text(VPNFigmaSection550Copy.goToProviderSite)
                }
            }

            Section {
                Button {
                    refreshSubscription()
                } label: {
                    HStack {
                        Text(VPNFigmaSection550Copy.updateSubscriptionAction)
                        Spacer(minLength: 8)
                        if providerStore.isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(providerStore.isRefreshing)

                Button {
                    let wasExpired = provider.status == .expired
                    providerStore.purchaseTraffic(id: providerID)
                    updateMessage = wasExpired
                        ? "Added traffic. 100 GB is now available."
                        : "Added traffic. 500 GB is now available."
                } label: {
                    Text(VPNFigmaSection550Copy.buyTrafficAction)
                }

                if provider.status == .expired {
                    Button("Renew subscription") {
                        providerStore.renewSubscription(id: providerID)
                        updateMessage = "Subscription renewed for 30 days."
                    }
                }
            }

            if provider.status.isActive {
                Section("Settings") {
                    Toggle("Use as main VPN", isOn: mainVPNBinding(for: provider))
                    Toggle("Smart-Auto", isOn: smartAutoBinding(for: provider))
                    LabeledContent(
                        "Auto-Connect",
                        value: VPNFigmaSection550Copy.providerSettingsAutoConnectValue
                    )
                    Toggle("Split Tunneling", isOn: $splitTunneling)
                    Toggle("Notifications", isOn: $notificationsEnabled)
                }
            }

            Section {
                Button(VPNFigmaSection550Copy.deleteSubscriptionAction, role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
        }
    }

    private func copyableInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .contextMenu {
            Button("Copy") {
                UIPasteboard.general.string = value
            }
        }
        .accessibilityLabel("\(label), \(value)")
        .accessibilityHint("Copies the ID")
    }

    private func lastUpdatedLabel(for provider: VPNProvider) -> String {
        guard let lastUpdated = provider.lastUpdated else {
            return VPNFigmaSection550Copy.providerSettingsLastUpdated
        }
        return lastUpdated.formatted(date: .abbreviated, time: .shortened)
    }

    private func mainVPNBinding(for provider: VPNProvider) -> Binding<Bool> {
        Binding(
            get: { providerStore.activeProviderID == provider.id },
            set: { enabled in
                if enabled {
                    providerStore.setActiveProvider(id: provider.id)
                } else if let velvet = providerStore.velvetProvider, velvet.status.isActive {
                    providerStore.setActiveProvider(id: velvet.id)
                }
            }
        )
    }

    private func statusLabel(for provider: VPNProvider) -> String {
        switch provider.status {
        case .expired:
            VPNFigmaSection550Copy.subscriptionExpiredBadge
        case .active:
            VPNFigmaSection550Copy.providerSettingsStatusActive
        }
    }

    @ViewBuilder
    private func legacyDetailForm(_ provider: VPNProvider) -> some View {
        Form {
            if provider.hasProviderMessage, let message = provider.displayedProviderMessage {
                Section {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if provider.kind == .velvetFeatured {
                Section {
                    VelvetVPNStatisticsCard(
                        providerMessage: nil,
                        messageUpdatedAt: provider.providerMessageUpdatedAt,
                        embedInForm: true
                    )
                }
            } else if provider.kind == .imported {
                Section {
                    VelvetAnalyticsGateCard(embedInForm: true) {
                        openURL(VelvetTheme.paywallURL)
                    }
                }
            }

            Section {
                LabeledContent("Name", value: provider.name)
                LabeledContent(
                    "Status",
                    value: provider.tunnelStatusLabel(
                        isConnected: isVPNConnected,
                        activeProviderID: activeConnectionProviderID
                    )
                )
                if let lastUpdated = provider.lastUpdated {
                    LabeledContent("Last updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }
                if let expiresAt = provider.expiresAt {
                    LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("Subscription", value: subscriptionTier(for: provider))
                if let traffic = trafficSummary(for: provider) {
                    LabeledContent("Traffic", value: traffic)
                }
            }

            if provider.status.isActive {
                Section {
                    VPNConfirmedToggle(
                        title: "Smart-Auto",
                        isOn: smartAutoBinding(for: provider),
                        confirmation: VPNSettingsConfirmations.smartAuto
                    )
                    VPNConfirmedToggle(
                        title: "Kill Switch",
                        isOn: $killSwitch,
                        confirmation: VPNSettingsConfirmations.killSwitch
                    )
                    Toggle("DNS Leak Protection", isOn: $dnsLeakProtection)
                    Toggle("Auto-Connect", isOn: $autoConnect)
                    VPNConfirmedToggle(
                        title: "Split Tunneling",
                        isOn: $splitTunneling,
                        confirmation: VPNSettingsConfirmations.splitTunneling
                    )
                    Toggle("Notifications", isOn: $notificationsEnabled)

                    if provider.hasProviderMessage {
                        Button {
                            showsProviderMessage = true
                        } label: {
                            HStack {
                                Text("Message from provider")
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Text("Available")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    VPNConfirmedToggle(
                        title: "Use this network only",
                        isOn: $useThisNetworkOnlyToggle,
                        confirmation: VPNSettingsConfirmations.networkScope
                    )
                } header: {
                    Text("Settings")
                } footer: {
                    Text("When enabled, locations and Connect use only this subscription.")
                }
            }

            if provider.status == .expired {
                Section {
                    Button("Renew subscription") {
                        providerStore.renewSubscription(id: providerID)
                        updateMessage = "Subscription renewed for 30 days."
                    }
                }
            }

            Section {
                Button("Support") { showsSupportSheet = true }
                Button("Edit") { showsEditSheet = true }
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
                Button("Delete", role: .destructive) { showsDeleteConfirmation = true }
            }
        }
        .listSectionSpacing(.compact)
        .onAppear {
            useThisNetworkOnlyToggle = usesThisNetworkOnly
        }
        .onChange(of: providerStore.providerScope) { _, _ in
            let scoped = usesThisNetworkOnly
            if useThisNetworkOnlyToggle != scoped {
                useThisNetworkOnlyToggle = scoped
            }
        }
        .onChange(of: useThisNetworkOnlyToggle) { _, newValue in
            guard newValue != usesThisNetworkOnly else { return }
            applyNetworkScope(newValue)
        }
    }

    private func smartAutoBinding(for provider: VPNProvider) -> Binding<Bool> {
        Binding(
            get: { provider.includedInSmartAuto },
            set: { enabled in
                providerStore.setIncludedInSmartAuto(id: providerID, enabled: enabled)
            }
        )
    }

    private func applyNetworkScope(_ useThisNetworkOnly: Bool) {
        if useThisNetworkOnly {
            providerStore.setProviderScope(.provider(providerID))
        } else {
            providerStore.setProviderScope(.allNetworks)
        }
    }

    private func subscriptionTier(for provider: VPNProvider) -> String {
        switch provider.kind {
        case .velvetFeatured:
            "Premium"
        case .imported:
            provider.status == .expired ? "Expired" : "Standard"
        }
    }

    private func trafficSummary(for provider: VPNProvider) -> String? {
        guard case let .active(_, trafficRemaining) = provider.status else { return nil }
        if provider.kind == .velvetFeatured {
            return "332 GB / 2,064,000 GB"
        }
        return trafficRemaining
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

private extension VPNProviderScope {
    func isScoped(to providerID: UUID) -> Bool {
        if case let .provider(id) = self {
            return id == providerID
        }
        return false
    }
}
