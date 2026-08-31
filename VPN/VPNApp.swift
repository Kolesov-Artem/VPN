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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        ZStack {
            switch route {
            case .onboarding:
                ConnectVPNView(route: routeBinding)
                    .transition(rootTransition)
            case .home:
                HomeView(route: routeBinding)
                    .transition(rootTransition)
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.28),
            value: route
        )
    }

    private var routeBinding: Binding<AppRoute> {
        Binding(
            get: { route },
            set: { route = $0 }
        )
    }

    private var rootTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
    }
}
