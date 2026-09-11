import Foundation

#if DEBUG
enum VPNDevFlags {
    private static let connectFailKey = "velvet.dev.connectFail"

    static var connectShouldFail: Bool {
        CommandLine.arguments.contains("--connect-fail")
            || UserDefaults.standard.bool(forKey: connectFailKey)
    }

    static func setConnectShouldFail(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: connectFailKey)
    }
}
#endif
