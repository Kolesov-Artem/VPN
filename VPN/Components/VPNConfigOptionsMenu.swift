import SwiftUI

/// Fixed-layout configuration menu. SwiftUI's `Menu` + `ControlGroup` reorders
/// items when the popover opens upward (collapsed island), so this popover keeps
/// Info/Support shortcuts, actions, and Delete in a stable order.
struct VPNConfigOptionsMenu<Label: View>: View {
    @Binding var showsDeleteConfirmation: Bool
    @ViewBuilder var label: () -> Label

    @State private var isPresented = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button {
            isPresented = true
        } label: {
            label()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("More options")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            menuCard
                .presentationCompactAdaptation(.popover)
        }
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            shortcutRow

            menuDivider

            VStack(spacing: 0) {
                menuRow("Routing", systemImage: "arrow.triangle.branch") {}
                menuRow("Update subscription", systemImage: "arrow.clockwise.circle") {}
                menuRow("Check ping", systemImage: "speedometer") {}
                menuRow("Edit", systemImage: "square.and.pencil") {}
            }

            menuDivider

            Button {
                dismiss()
                showsDeleteConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    Text("Delete")
                        .foregroundStyle(.red)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: VelvetTheme.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(.vertical, 8)
        .frame(width: 250)
        .background {
            if reduceTransparency {
                Color(.secondarySystemBackground)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
    }

    private var shortcutRow: some View {
        HStack(spacing: 0) {
            shortcutButton("Info", systemImage: "info.circle") {}
            shortcutButton("Support", systemImage: "paperplane") {}
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var menuDivider: some View {
        Divider()
            .padding(.horizontal, 12)
    }

    private func shortcutButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(VelvetTheme.accent)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: VelvetTheme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func menuRow(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(VelvetTheme.accent)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: VelvetTheme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func dismiss() {
        isPresented = false
    }
}
