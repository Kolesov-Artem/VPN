import SwiftUI

struct VPNToggleConfirmation {
    let title: String
    let enablingMessage: String
    let disablingMessage: String
    var confirmsOnEnable = true
    var confirmsOnDisable = false

    func message(from oldValue: Bool, to newValue: Bool) -> String? {
        if newValue, confirmsOnEnable { return enablingMessage }
        if !newValue, confirmsOnDisable { return disablingMessage }
        return nil
    }

    func shouldConfirm(from oldValue: Bool, to newValue: Bool) -> Bool {
        message(from: oldValue, to: newValue) != nil
    }
}

struct VPNConfirmedToggle: View {
    let title: String
    @Binding var isOn: Bool
    var confirmation: VPNToggleConfirmation?

    @State private var showsConfirmation = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(title, isOn: confirmedBinding)
            .confirmationDialog(
                confirmation?.title ?? "",
                isPresented: $showsConfirmation,
                titleVisibility: .visible
            ) {
                Button(confirmButtonTitle, role: confirmButtonRole) {
                    isOn = pendingValue
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let confirmation {
                    Text(confirmation.message(from: isOn, to: pendingValue) ?? "")
                }
            }
    }

    private var confirmedBinding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                guard let confirmation, confirmation.shouldConfirm(from: isOn, to: newValue) else {
                    isOn = newValue
                    return
                }
                pendingValue = newValue
                showsConfirmation = true
            }
        )
    }

    private var confirmButtonTitle: String {
        pendingValue ? "Turn On" : "Turn Off"
    }

    private var confirmButtonRole: ButtonRole? {
        pendingValue ? nil : .destructive
    }
}

enum VPNSettingsConfirmations {
    static let killSwitch = VPNToggleConfirmation(
        title: "Turn on Kill Switch?",
        enablingMessage: "If the VPN disconnects, internet access will be blocked until you connect again.",
        disablingMessage: "Traffic may leave the secure tunnel if the VPN drops while Kill Switch is off.",
        confirmsOnEnable: true,
        confirmsOnDisable: true
    )

    static let splitTunneling = VPNToggleConfirmation(
        title: "Turn on Split Tunneling?",
        enablingMessage: "Some apps and sites may bypass the VPN and use your regular connection.",
        disablingMessage: "All traffic will route through the VPN again.",
        confirmsOnEnable: true,
        confirmsOnDisable: false
    )

    static let routeAllTraffic = VPNToggleConfirmation(
        title: "Allow traffic outside VPN?",
        enablingMessage: "Some traffic may bypass the VPN when this is turned off.",
        disablingMessage: "Some apps and sites may use your regular connection instead of the VPN tunnel.",
        confirmsOnEnable: false,
        confirmsOnDisable: true
    )

    static let networkScope = VPNToggleConfirmation(
        title: "Change network preference?",
        enablingMessage: "Locations and Connect will use only this subscription until you change it back.",
        disablingMessage: "Velvet will choose from all active subscriptions again.",
        confirmsOnEnable: true,
        confirmsOnDisable: true
    )

    static let smartAuto = VPNToggleConfirmation(
        title: "Remove from Smart-Auto?",
        enablingMessage: "",
        disablingMessage: "This subscription will no longer be used for Smart picks or automatic server selection.",
        confirmsOnEnable: false,
        confirmsOnDisable: true
    )
}
