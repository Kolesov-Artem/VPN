import SwiftUI

struct RouteDetailsSheet: View {
    let activeRoute: ActiveRoute
    let alternates: [RouteCandidate]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Active route") {
                    routeRow(
                        location: activeRoute.location.name,
                        provider: activeRoute.provider.name,
                        protocolName: activeRoute.endpoint.tunnelProtocol,
                        latency: activeRoute.latency,
                        isSelected: true
                    )
                }

                if !alternates.isEmpty {
                    Section("Also available") {
                        ForEach(alternates) { candidate in
                            routeRow(
                                location: candidate.location.name,
                                provider: candidate.provider.name,
                                protocolName: candidate.endpoint.tunnelProtocol,
                                latency: candidate.latency,
                                isSelected: false
                            )
                        }
                    }
                }

                Section {
                    Text("Disconnect to switch routes in this prototype.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Route details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func routeRow(
        location: String,
        provider: String,
        protocolName: String,
        latency: Int,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(location) · \(provider)")
                    .font(.subheadline.weight(.medium))
                Text("\(protocolName) · \(latency) ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct NetworksSheet: View {
    @Binding var providers: [VPNProvider]
    let onAddNetwork: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($providers) { $provider in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: provider.accentSymbol)
                                    .foregroundStyle(provider.isEnabled ? VelvetTheme.accent : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(provider.subscriptionLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle("Enabled", isOn: $provider.isEnabled)
                                    .labelsHidden()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("My networks")
                } footer: {
                    Text("Disabled networks are excluded from automatic route selection.")
                }

                Section {
                    Button {
                        dismiss()
                        onAddNetwork()
                    } label: {
                        Label("Add network", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Networks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
