import SwiftUI
import UIKit

enum LocationSearchChrome {
    /// Shared height for the search capsule and filter circle.
    static let controlHeight: CGFloat = 50
    static let fieldHorizontalPadding: CGFloat = 16
    /// Side inset for the floating search row, matching Settings tab search.
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 8
    /// Extra blur feather above the search pill when content scrolls underneath.
    static let panelSearchBlurExtension: CGFloat = 40
    /// Breathing room when the panel floats above the home indicator.
    static let extraBottomInset: CGFloat = 8

    /// Fixed offset from the screen bottom for legacy screen-anchored docks.
    static func screenBottomOffset(panelBottomMargin: CGFloat) -> CGFloat {
        panelBottomMargin + extraBottomInset
    }

    /// Home-indicator clearance when the search dock lives inside the panel card.
    static func panelSearchBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        max(safeAreaBottom, VelvetTheme.minimumBottomMargin)
    }

    static func chromeHeight(bottomMargin: CGFloat) -> CGFloat {
        controlHeight
            + rowVerticalPadding * 2
            + panelSearchBlurExtension
            + bottomMargin
    }

    static func barHeight(bottomMargin: CGFloat) -> CGFloat {
        chromeHeight(bottomMargin: bottomMargin)
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
            .floating
        }
    }
}

/// Search row for the panel search dock, including keyboard lift.
struct PanelLocationSearchControls: View {
    @Binding var query: VPNLocationQuery
    var isFocused: FocusState<Bool>.Binding
    let bottomMargin: CGFloat
    let safeAreaBottom: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var chromeHeight: CGFloat {
        LocationSearchChrome.chromeHeight(bottomMargin: bottomMargin)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrollEdgeBackground
                .frame(height: chromeHeight)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

            LocationSearchBar(query: $query, isFocused: isFocused)
                .padding(.bottom, bottomMargin)
        }
        .modifier(
            LocationSearchKeyboardLift(
                isFocused: isFocused,
                safeAreaBottom: safeAreaBottom
            )
        )
    }

    @ViewBuilder
    private var scrollEdgeBackground: some View {
        if reduceTransparency {
            Color(.systemBackground)
        } else {
            TelegramScrollEdgeBackground(
                edge: .bottom,
                strength: .navigationBar
            )
        }
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

/// Floating pill chrome like the Settings tab search bar on pre-glass OS versions.
struct LocationSearchFloatingChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    let reduceTransparency: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                floatingFill
            }
            .overlay {
                shape.strokeBorder(strokeColor, lineWidth: 0.5)
            }
            .shadow(color: shadowColor, radius: 16, y: 4)
    }

    @ViewBuilder
    private var floatingFill: some View {
        if reduceTransparency {
            shape.fill(Color(.secondarySystemGroupedBackground))
        } else {
            ZStack {
                shape.fill(.thinMaterial)
                shape.fill(Color(.systemBackground).opacity(colorScheme == .dark ? 0.22 : 0.52))
            }
        }
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.white.opacity(0.72)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.38)
            : Color.black.opacity(0.12)
    }
}

@available(iOS 26.0, *)
struct LocationSearchGlassChrome<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular
                    .tint(Color(.systemBackground).opacity(colorScheme == .dark ? 0.22 : 0.48))
                    .interactive(),
                in: shape
            )
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.16)
                        : Color.white.opacity(0.78),
                    lineWidth: 0.5
                )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.1),
                radius: 14,
                y: 4
            )
    }
}

private struct LocationSearchFieldChrome: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.modifier(LocationSearchGlassChrome(shape: Capsule()))
        } else {
            content.modifier(
                LocationSearchFloatingChrome(shape: Capsule(), reduceTransparency: reduceTransparency)
            )
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
