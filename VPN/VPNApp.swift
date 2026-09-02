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
            CommandLine.arguments.contains("--show-home") ? .home : .onboarding
#else
        let initialRoute = AppRoute.onboarding
#endif
        _route = State(initialValue: initialRoute)
    }

    var body: some View {
#if DEBUG
        if CommandLine.arguments.contains("--prototype-onboarding") {
            OnboardingPrototypeHarness()
        } else {
            HomeView(route: $route)
        }
#else
        HomeView(route: $route)
#endif
    }
}
