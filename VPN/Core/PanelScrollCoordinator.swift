import SwiftUI
import UIKit

/// UIKit scroll container that owns vertical scrolling and only forwards downward
/// pans to the panel resize handler when content is at the top (or scroll is off).
struct PanelScrollCoordinator<Content: View>: UIViewControllerRepresentable {
    let isScrollEnabled: Bool
    let bottomContentInset: CGFloat
    @Binding var isScrollAtTop: Bool
    @Binding var scrollEdgeProgress: CGFloat
    let onPanelDragChanged: (CGFloat) -> Void
    let onPanelDragEnded: (_ translation: CGFloat, _ predicted: CGFloat) -> Void
    @ViewBuilder let content: () -> Content

    func makeUIViewController(context: Context) -> PanelScrollViewController<Content> {
        let controller = PanelScrollViewController(rootView: content())
        controller.isScrollEnabled = isScrollEnabled
        controller.bottomContentInset = bottomContentInset
        controller.onScrollStateChanged = { atTop, progress in
            if isScrollAtTop != atTop {
                isScrollAtTop = atTop
            }
            if abs(scrollEdgeProgress - progress) > 0.02 {
                scrollEdgeProgress = progress
            }
        }
        controller.onPanelDragChanged = onPanelDragChanged
        controller.onPanelDragEnded = onPanelDragEnded
        return controller
    }

    func updateUIViewController(_ controller: PanelScrollViewController<Content>, context: Context) {
        controller.rootView = content()
        controller.isScrollEnabled = isScrollEnabled
        controller.bottomContentInset = bottomContentInset
        controller.onScrollStateChanged = { atTop, progress in
            if isScrollAtTop != atTop {
                isScrollAtTop = atTop
            }
            if abs(scrollEdgeProgress - progress) > 0.02 {
                scrollEdgeProgress = progress
            }
        }
        controller.onPanelDragChanged = onPanelDragChanged
        controller.onPanelDragEnded = onPanelDragEnded
        controller.refreshHostedContent()
    }
}

final class PanelScrollViewController<Content: View>: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var rootView: Content
    var isScrollEnabled = true {
        didSet { applyScrollEnabled() }
    }

    var bottomContentInset: CGFloat = 0 {
        didSet { applyContentInset() }
    }

    var onScrollStateChanged: ((Bool, CGFloat) -> Void)?
    var onPanelDragChanged: ((CGFloat) -> Void)?
    var onPanelDragEnded: ((_ translation: CGFloat, _ predicted: CGFloat) -> Void)?

    private let scrollView = UIScrollView()
    private var hostingController: UIHostingController<Content>!
    private var panelPan: UIPanGestureRecognizer!
    private var isForwardingPanelPan = false
    private var contentHeightConstraint: NSLayoutConstraint?

    init(rootView: Content) {
        self.rootView = rootView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        contentHeightConstraint = hostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        contentHeightConstraint?.isActive = true

        panelPan = UIPanGestureRecognizer(target: self, action: #selector(handlePanelPan(_:)))
        panelPan.delegate = self
        scrollView.addGestureRecognizer(panelPan)

        applyScrollEnabled()
        applyContentInset()
        reportScrollState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let minHeight = max(scrollView.bounds.height - bottomContentInset, 0)
        contentHeightConstraint?.constant = minHeight
        hostingController.view.invalidateIntrinsicContentSize()
    }

    func refreshHostedContent() {
        hostingController.rootView = rootView
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        view.setNeedsLayout()
    }

    func scrollToTop(animated: Bool) {
        scrollView.setContentOffset(.zero, animated: animated)
        reportScrollState()
    }

    private func applyScrollEnabled() {
        scrollView.isScrollEnabled = isScrollEnabled
        scrollView.alwaysBounceVertical = isScrollEnabled
        scrollView.panGestureRecognizer.isEnabled = isScrollEnabled
        if !isScrollEnabled {
            scrollView.setContentOffset(.zero, animated: false)
        }
        reportScrollState()
    }

    private func applyContentInset() {
        scrollView.contentInset.bottom = bottomContentInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomContentInset
    }

    private func reportScrollState() {
        let offset = scrollView.contentOffset.y
        let atTop = offset <= 0.5
        let progress = min(max(offset / 28, 0), 1)
        onScrollStateChanged?(atTop, progress)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if isForwardingPanelPan, scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
        reportScrollState()
    }

    @objc private func handlePanelPan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view).y
        let velocity = pan.velocity(in: view).y
        let predicted = translation + velocity * 0.25

        switch pan.state {
        case .began:
            guard shouldBeginPanelPan(pan) else { return }
            isForwardingPanelPan = true
            scrollView.isScrollEnabled = false
            scrollView.panGestureRecognizer.isEnabled = false
        case .changed:
            guard isForwardingPanelPan else { return }
            scrollView.contentOffset.y = 0
            onPanelDragChanged?(translation)
        case .ended, .cancelled, .failed:
            guard isForwardingPanelPan else { return }
            onPanelDragEnded?(translation, predicted)
            isForwardingPanelPan = false
            applyScrollEnabled()
        default:
            break
        }
    }

    private func shouldBeginPanelPan(_ pan: UIPanGestureRecognizer) -> Bool {
        let velocity = pan.velocity(in: view)
        let translation = pan.translation(in: view)
        let isVertical = abs(velocity.y) > abs(velocity.x)
            || abs(translation.y) > abs(translation.x)

        if !isScrollEnabled {
            return isVertical
        }

        guard scrollView.contentOffset.y <= 0.5 else { return false }
        guard isVertical else { return false }
        return velocity.y > 0 || translation.y > 0
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panelPan else { return true }
        return shouldBeginPanelPan(panelPan)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer === scrollView.panGestureRecognizer
    }
}
