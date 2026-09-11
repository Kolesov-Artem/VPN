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
