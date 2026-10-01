import SwiftUI
import UIKit

/// Weak bridge from `PanelScrollViewController` to the panel search dock edge effect.
final class PanelScrollViewHandle {
    weak var scrollView: UIScrollView?
    var freezeAccordion: ((_ anchorName: String?) -> Void)?

    /// Keeps the scroll position stable when nested accordions change height.
    func preserveContentOffset() {
        freezeAccordion?(nil)
    }

    /// Keeps a named header at the same place on screen while the list resizes.
    func preserveAnchor(_ name: String) {
        freezeAccordion?(name)
    }

    /// Brings a named marker to the top of the list, under the compact bar.
    @discardableResult
    func scrollToAnchor(_ name: String, animated: Bool) -> Bool {
        guard let scrollView, let anchor = scrollView.panelScrollAnchor(named: name) else {
            return false
        }
        let origin = anchor.convert(anchor.bounds.origin, to: scrollView).y
        let topChrome = VelvetMetrics.panelScrollChromeHeight
        let targetY = max(0, origin - topChrome)
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: animated)
        return true
    }
}

/// Invisible UIKit marker so accordion layout can pin a header in scroll coordinates.
struct PanelScrollAnchor: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> PanelScrollAnchorView {
        let view = PanelScrollAnchorView()
        view.anchorName = name
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PanelScrollAnchorView, context: Context) {
        uiView.anchorName = name
    }
}

final class PanelScrollAnchorView: UIView {
    var anchorName = ""

    override var intrinsicContentSize: CGSize {
        CGSize(width: 1, height: 1)
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

extension UIView {
    func panelScrollAnchor(named name: String) -> PanelScrollAnchorView? {
        if let anchor = self as? PanelScrollAnchorView, anchor.anchorName == name {
            return anchor
        }
        for subview in subviews {
            if let anchor = subview.panelScrollAnchor(named: name) {
                return anchor
            }
        }
        return nil
    }
}
