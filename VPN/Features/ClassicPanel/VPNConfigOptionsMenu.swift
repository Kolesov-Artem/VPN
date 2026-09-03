import SwiftUI

/// Shared configuration menu. Uses the system `Menu` so presentation, separators,
/// and spring animation match other chrome (e.g. the filter menu).
struct VPNConfigOptionsMenu<MenuLabel: View>: View {
    @Binding var showsDeleteConfirmation: Bool
    @ViewBuilder var label: () -> MenuLabel

    var body: some View {
        Menu {
            ControlGroup {
                Button {} label: {
                    Label("Info", systemImage: "info.circle")
                }
                Button {} label: {
                    Label("Support", systemImage: "paperplane")
                }
            }
            .controlGroupStyle(.compactMenu)

            Section {
                Button {} label: {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }
                Button {} label: {
                    Label("Update subscription", systemImage: "arrow.clockwise.circle")
                }
                Button {} label: {
                    Label("Check ping", systemImage: "speedometer")
                }
                Button {} label: {
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
