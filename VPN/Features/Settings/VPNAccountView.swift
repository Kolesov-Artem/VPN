import SwiftUI

/// Account screen (traffic chart, support links, about app).
struct VPNAccountView: View {
    @Bindable var providerStore: VPNProviderStore
    var showsDismissButton = true
    /// When the account page is a tab, this leaves that tab. A cover uses dismiss instead.
    var onBack: (() -> Void)? = nil
    let onOpenProvider: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.ru

    @State private var showsSupport = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    listSection(title: ui("App")) {
                        accountNavigationRow("Settings") {
                            showsSettings = true
                        }
                    }
                    VPNTrafficUsageCard(providers: providerStore.providers)
                    listSection(title: VPNFigmaSection550Copy.subscriptionsTitle) {
                        NavigationLink {
                            VPNSubscriptionsPage(
                                providerStore: providerStore,
                                embedsNavigation: false,
                                onOpenProvider: onOpenProvider
                            )
                        } label: {
                            HStack {
                                Text(VPNFigmaSection550Copy.seeAllSubscriptions)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    listSection(title: ui("Support and bonuses")) {
                        accountNavigationRow("Invite a friend") {
                            openURL(VelvetTheme.paywallURL)
                        }
                        accountDivider
                        accountNavigationRow("Support") {
                            showsSupport = true
                        }
                    }
                    listSection(title: ui("About app")) {
                        languageRow
                        accountDivider
                        accountNavigationRow("Terms of use") {
                            openURL(URL(string: "https://velvet.vpn/terms")!)
                        }
                        accountDivider
                        accountNavigationRow("Privacy policy") {
                            openURL(URL(string: "https://velvet.vpn/privacy")!)
                        }
                    }

                    Text(ui("App version: 1.1"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, VelvetTheme.horizontalPadding)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(ui("Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if let onBack {
                                onBack()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                        .accessibilityLabel(ui("Back"))
                    }
                }
            }
            .sheet(isPresented: $showsSettings) {
                HomeSettingsView(providerStore: providerStore)
                    .id(appLanguage)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsSupport) {
                VPNSupportView(providerName: nil)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func listSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var languageRow: some View {
        Menu {
            Button("English") { appLanguage = AppLanguage.en }
            Button("Русский") { appLanguage = AppLanguage.ru }
        } label: {
            HStack {
                Text(ui("Language"))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(appLanguage == AppLanguage.en ? "English" : "Русский")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }

    private var accountDivider: some View {
        Divider().padding(.leading, 16)
    }

    private func accountNavigationRow(
        _ title: String,
        detail: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(ui(title))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if let detail {
                    Text(ui(detail))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
