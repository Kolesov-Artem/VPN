import SwiftUI
import UIKit

/// Weak bridge from `PanelScrollViewController` to the panel search dock edge effect.
final class PanelScrollViewHandle {
    weak var scrollView: UIScrollView?
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
