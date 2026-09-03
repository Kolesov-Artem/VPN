import SwiftUI

struct VPNPingResultsView: View {
    let providers: [VPNProvider]

    @Environment(\.dismiss) private var dismiss
    @State private var results: [VPNPingResult] = []
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No active servers",
                        systemImage: "speedometer",
                        description: Text("Add an active subscription to run ping checks.")
                    )
                } else {
                    ForEach(results) { result in
                        HStack(spacing: 12) {
                            Text(result.location.flag)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(result.location.name) · \(result.location.city)")
                                    .font(.subheadline.weight(.medium))
                                Text(result.provider.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(result.ping) ms")
                                .font(.subheadline.monospacedDigit())
                            signalBadge(result.signal)
                        }
                    }
                }
            }
            .navigationTitle("Ping results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        refresh()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Text("Refresh")
                        }
                    }
                    .disabled(isRefreshing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                refresh()
            }
        }
    }

    private func refresh() {
        isRefreshing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            results = VPNConnectionPlanner.pingResults(from: providers)
            isRefreshing = false
            VPNLogsStore.shared.append("Ping check completed (\(results.count) servers)")
        }
    }

    @ViewBuilder
    private func signalBadge(_ signal: VPNLocation.Signal) -> some View {
        let label: String = switch signal {
        case .excellent: "Best"
        case .good: "Good"
        case .fair: "Fair"
        }
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }
}
