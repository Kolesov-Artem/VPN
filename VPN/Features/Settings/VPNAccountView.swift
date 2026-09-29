import SwiftUI

/// Account screen (traffic chart, support links, about app).
struct VPNAccountView: View {
    @Bindable var providerStore: VPNProviderStore
    let onOpenProvider: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showsSupport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
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
                    listSection(title: "Support and bonuses") {
                        accountNavigationRow("Invite a friend") {
                            openURL(VelvetTheme.paywallURL)
                        }
                        accountDivider
                        accountNavigationRow("Support") {
                            showsSupport = true
                        }
                    }
                    listSection(title: "About app") {
                        accountNavigationRow("Language", detail: "English") {}
                        accountDivider
                        accountNavigationRow("Terms of use") {
                            openURL(URL(string: "https://velvet.vpn/terms")!)
                        }
                        accountDivider
                        accountNavigationRow("Privacy policy") {
                            openURL(URL(string: "https://velvet.vpn/privacy")!)
                        }
                    }

                    Text("App version: 1.1")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, VelvetTheme.horizontalPadding)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .accessibilityLabel("Back")
                }
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
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if let detail {
                    Text(detail)
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
