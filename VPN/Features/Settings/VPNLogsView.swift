import SwiftUI

struct VPNLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var logsStore = VPNLogsStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logsStore.lines.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(ui("Logs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(ui("Clear")) {
                        logsStore.clear()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(ui("Done")) { dismiss() }
                }
            }
        }
    }
}
