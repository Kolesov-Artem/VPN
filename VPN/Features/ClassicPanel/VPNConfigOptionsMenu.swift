import SwiftUI

enum VPNConfigMenuAction {
    case info
    case support
    case routing
    case updateSubscription
    case checkPing
    case edit
    case providerSettings
}

/// Shared configuration menu. Uses the system `Menu` so presentation, separators,
/// and spring animation match other chrome (e.g. the filter menu).
struct VPNConfigOptionsMenu<MenuLabel: View>: View {
    @Binding var showsDeleteConfirmation: Bool
    var showsProviderSettings = false
    var onAction: (VPNConfigMenuAction) -> Void
    @ViewBuilder var label: () -> MenuLabel

    var body: some View {
        Menu {
            ControlGroup {
                Button {
                    onAction(.info)
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
                Button {
                    onAction(.support)
                } label: {
                    Label("Support", systemImage: "paperplane")
                }
            }
            .controlGroupStyle(.compactMenu)

            Section {
                if showsProviderSettings {
                    Button {
                        onAction(.providerSettings)
                    } label: {
                        Label("Provider settings", systemImage: "gearshape")
                    }
                }
                Button {
                    onAction(.routing)
                } label: {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }
                Button {
                    onAction(.updateSubscription)
                } label: {
                    Label("Update subscription", systemImage: "arrow.clockwise.circle")
                }
                Button {
                    onAction(.checkPing)
                } label: {
                    Label("Check ping", systemImage: "speedometer")
                }
                Button {
                    onAction(.edit)
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }

            Section {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label {
                        Text("Delete")
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel("More options")
    }
}
