import SwiftUI

@main
struct VPNApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(VelvetTheme.accent)
        }
    }
}

private struct RootView: View {
    @State private var route: AppRoute

    init() {
#if DEBUG
        let initialRoute: AppRoute =
            if CommandLine.arguments.contains("--show-permission") {
                .permission
            } else if CommandLine.arguments.contains("--show-home") {
                .home
            } else {
                .onboarding
            }
#else
        let initialRoute = AppRoute.onboarding
#endif
        _route = State(initialValue: initialRoute)
#if DEBUG
        if CommandLine.arguments.contains("--home-island-menu") {
            UserDefaults.standard.set(VPNHomeChrome.islandMenu.rawValue, forKey: VPNHomeChrome.storageKey)
        } else if CommandLine.arguments.contains("--home-hero") {
            UserDefaults.standard.set(VPNHomeChrome.hero.rawValue, forKey: VPNHomeChrome.storageKey)
        } else if CommandLine.arguments.contains("--home-board") {
            UserDefaults.standard.set(VPNHomeChrome.board.rawValue, forKey: VPNHomeChrome.storageKey)
        } else if CommandLine.arguments.contains("--home-page") {
            UserDefaults.standard.set(VPNHomeChrome.page.rawValue, forKey: VPNHomeChrome.storageKey)
        } else if CommandLine.arguments.contains("--home-tabs") {
            UserDefaults.standard.set(VPNHomeChrome.tabs.rawValue, forKey: VPNHomeChrome.storageKey)
        } else if CommandLine.arguments.contains("--home-island") {
            UserDefaults.standard.set(VPNHomeChrome.island.rawValue, forKey: VPNHomeChrome.storageKey)
        }
#endif
    }

    var body: some View {
        HomeView(route: $route)
    }
}
