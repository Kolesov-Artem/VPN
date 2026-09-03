import SwiftUI

struct VPNCountryPickerSheet: View {
    let group: VPNCountryLocationGroup
    let selectedLocationSelection: VPNLocationSelection
    let onSelect: (VPNNetworkLocation) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(group.candidates) { candidate in
                    Button {
                        onSelect(candidate)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(candidate.location.city) · \(candidate.location.kind.title)")
                                    .font(.subheadline.weight(.medium))
                                Text(candidate.provider.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(candidate.location.pingLabel)
                                .font(.caption.monospacedDigit())
                            if isSelected(candidate) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VelvetTheme.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick network for \(group.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func isSelected(_ candidate: VPNNetworkLocation) -> Bool {
        if case let .manual(location, providerID) = selectedLocationSelection {
            return location.persistenceKey == candidate.location.persistenceKey
                && providerID == candidate.provider.id
        }
        return false
    }
}
