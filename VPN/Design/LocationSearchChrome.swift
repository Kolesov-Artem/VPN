import SwiftUI

enum LocationSearchChrome {
    /// Shared height for the search capsule and filter circle.
    static let controlHeight: CGFloat = 50
    static let fieldHorizontalPadding: CGFloat = 16
    static let rowHorizontalPadding: CGFloat = 20
    static let rowVerticalPadding: CGFloat = 10
    /// Breathing room when the panel floats above the home indicator.
    static let extraBottomInset: CGFloat = 8

    /// Fixed offset from the screen bottom for the search dock across all detents.
    static func screenBottomOffset(panelBottomMargin: CGFloat) -> CGFloat {
        panelBottomMargin + extraBottomInset
    }

    static func barHeight(bottomMargin: CGFloat) -> CGFloat {
        controlHeight + rowVerticalPadding * 2 + bottomMargin
    }

    static func scrollBottomPadding(
        revealProgress: CGFloat,
        bottomMargin: CGFloat,
        contentInset: CGFloat
    ) -> CGFloat {
        revealProgress > 0.01
            ? barHeight(bottomMargin: bottomMargin)
            : contentInset
    }
}

/// Search field and filter button in the panel footer row.
struct LocationSearchBar: View {
    @Binding var query: VPNLocationQuery
    var isFocused: FocusState<Bool>.Binding

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Country, city or type", text: $query.text)
                    .focused(isFocused)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !query.text.isEmpty {
                    Button {
                        query.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, LocationSearchChrome.fieldHorizontalPadding)
            .frame(height: LocationSearchChrome.controlHeight)
            .modifier(LocationSearchFieldChrome(reduceTransparency: reduceTransparency))

            VPNLocationFilterMenu(query: $query, style: filterStyle)
        }
        .padding(.horizontal, LocationSearchChrome.rowHorizontalPadding)
        .padding(.vertical, LocationSearchChrome.rowVerticalPadding)
    }

    private var filterStyle: VPNLocationFilterMenuStyle {
        if #available(iOS 26.0, *), !reduceTransparency {
            .glass
        } else {
            .capsule
        }
    }
}

/// Search row for the panel search dock, including keyboard lift.
struct PanelLocationSearchControls: View {
    @Binding var query: VPNLocationQuery
    var isFocused: FocusState<Bool>.Binding
    let bottomMargin: CGFloat
    let safeAreaBottom: CGFloat

    var body: some View {
        LocationSearchBar(query: $query, isFocused: isFocused)
            .padding(.bottom, bottomMargin)
            .modifier(
                LocationSearchKeyboardLift(
                    isFocused: isFocused,
                    safeAreaBottom: safeAreaBottom
                )
            )
    }
}

extension View {
    /// Pins location search to the panel bottom. Custom panels cannot rely on
    /// `safeAreaBar` in expanded detents, so the dock is an explicit overlay.
    func panelLocationSearchDock(
        revealProgress: CGFloat,
        query: Binding<VPNLocationQuery>,
        isFocused: FocusState<Bool>.Binding,
        bottomMargin: CGFloat,
        safeAreaBottom: CGFloat
    ) -> some View {
        overlay(alignment: .bottom) {
            if revealProgress > 0.01 {
                PanelLocationSearchControls(
                    query: query,
                    isFocused: isFocused,
                    bottomMargin: bottomMargin,
                    safeAreaBottom: safeAreaBottom
                )
                .opacity(revealProgress)
                .allowsHitTesting(revealProgress > 0.35)
            }
        }
    }
}

private struct LocationSearchFieldChrome: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
                .clipShape(Capsule())
        } else {
            content.background {
                if reduceTransparency {
                    Capsule().fill(Color(.tertiarySystemFill))
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
        }
    }
}

/// Lifts the search footer to sit flush above the keyboard, not higher.
private struct LocationSearchKeyboardLift: ViewModifier {
    var isFocused: FocusState<Bool>.Binding
    let safeAreaBottom: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardOverlap: CGFloat = 0

    private var lift: CGFloat {
        guard isFocused.wrappedValue else { return 0 }
        return max(0, keyboardOverlap - safeAreaBottom)
    }

    func body(content: Content) -> some View {
        content
            .offset(y: -lift)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillChangeFrameNotification
                )
            ) { notification in
                guard
                    let userInfo = notification.userInfo,
                    let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                else { return }

                let overlap = max(0, UIScreen.main.bounds.maxY - endFrame.origin.y)

                withAnimation(VelvetMotion.keyboard(reduceMotion: reduceMotion, duration: duration)) {
                    keyboardOverlap = overlap
                }
            }
    }
}
