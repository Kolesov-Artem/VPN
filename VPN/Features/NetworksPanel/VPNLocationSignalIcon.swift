import SwiftUI

struct VPNLocationSignalIcon: View {
    let signal: VPNLocation.Signal

    var body: some View {
        Image(systemName: "cellularbars", variableValue: level)
            .font(.subheadline)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
    }

    private var level: Double {
        switch signal {
        case .excellent: 1
        case .good: 0.66
        case .fair: 0.34
        }
    }

    private var color: Color {
        switch signal {
        case .excellent: .green
        case .good: .yellow
        case .fair: .red
        }
    }
}
