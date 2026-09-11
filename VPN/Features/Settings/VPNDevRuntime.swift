import SwiftUI

#if DEBUG
struct VPNDevRuntime {
    var route: Binding<AppRoute>
    var panelPosition: Binding<BottomPanelPosition>
    var connectionState: Binding<VPNConnectionState>
    var resolvedConnection: Binding<VPNResolvedConnection?>
    var connectedAt: Binding<Date?>
    var livePingMs: Binding<Int>
    var downloadRate: Binding<String>
    var uploadRate: Binding<String>
    var sessionBytesUsed: Binding<Int64>
    var isSwitchingServer: Binding<Bool>
    var locationSelection: Binding<VPNLocationSelection>
    var selectionSource: Binding<VPNSelectionSource>
    var onDismissSettings: () -> Void
}
#endif
