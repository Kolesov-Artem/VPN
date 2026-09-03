import SwiftUI

enum VPNLocationFilterMenuStyle {
    /// Liquid Glass circle — no custom gray fill.
    case glass
    /// Material search row on iOS 17.
    case capsule
}

/// Shared filter and sort menu for the location list search chrome.
struct VPNLocationFilterMenu: View {
    @Binding var query: VPNLocationQuery
    var style: VPNLocationFilterMenuStyle = .capsule

    private var controlSize: CGFloat { LocationSearchChrome.controlHeight }

    var body: some View {
        Menu {
            Section("Server type") {
                Picker("Server type", selection: $query.filter) {
                    ForEach(VPNLocationFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Sort by") {
                Picker("Sort by", selection: $query.sort) {
                    ForEach(VPNLocationSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Toggle(isOn: $query.fastOnly) {
                    Label("Under \(VPNLocation.fastPingThreshold) ms", systemImage: "bolt.fill")
                }

                if !query.isDefault {
                    Button(role: .destructive) {
                        query.resetFilters()
                    } label: {
                        Label("Reset filters", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } label: {
            filterButtonLabel
        }
        .accessibilityLabel("Filter and sort servers")
    }

    @ViewBuilder
    private var filterButtonLabel: some View {
        switch style {
        case .glass:
            if #available(iOS 26.0, *) {
                if query.isDefault {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: controlSize, height: controlSize)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .clipShape(Circle())
                } else {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: controlSize, height: controlSize)
                        .background(VelvetTheme.accent, in: Circle())
                }
            } else {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: controlSize, height: controlSize)
            }
        case .capsule:
            Image(systemName: "line.3.horizontal.decrease")
                .font(.title3.weight(.semibold))
                .foregroundStyle(query.isDefault ? Color.primary : Color.white)
                .frame(width: controlSize, height: controlSize)
                .background(
                    query.isDefault ? Color(.tertiarySystemFill) : VelvetTheme.accent,
                    in: Circle()
                )
        }
    }
}
