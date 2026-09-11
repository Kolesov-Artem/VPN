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
    }

    var body: some View {
        HomeView(route: $route)
    }
}
