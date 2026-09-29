import SwiftUI
import UIKit

/// Weak bridge from `PanelScrollViewController` to the panel search dock edge effect.
final class PanelScrollViewHandle {
    weak var scrollView: UIScrollView?

    /// Keeps the scroll position stable when nested accordions change height.
    func preserveContentOffset() {
        guard let scrollView else { return }
        let offset = scrollView.contentOffset
        DispatchQueue.main.async {
            Self.applyOffset(offset, to: scrollView)
        }
    }

    /// After an accordion toggle, keep a header at the same place on screen.
    func shiftContentOffset(by delta: CGFloat) {
        guard let scrollView, abs(delta) > 0.5 else { return }
        var offset = scrollView.contentOffset
        offset.y += delta
        Self.applyOffset(offset, to: scrollView)
    }

    private static func applyOffset(_ offset: CGPoint, to scrollView: UIScrollView) {
        UIView.performWithoutAnimation {
            scrollView.layoutIfNeeded()
            scrollView.setContentOffset(offset, animated: false)
        }
    }
}

private struct PanelScrollViewHandleKey: EnvironmentKey {
    static let defaultValue = PanelScrollViewHandle()
}

extension EnvironmentValues {
    var panelScrollViewHandle: PanelScrollViewHandle {
        get { self[PanelScrollViewHandleKey.self] }
        set { self[PanelScrollViewHandleKey.self] = newValue }
    }
}
