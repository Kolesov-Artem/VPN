import SwiftUI
import UIKit

/// Context for panel-height drags while content scrolling is disabled.
struct PanelResizeContext: Equatable {
    let baseHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
}

/// UIKit scroll container that owns vertical scrolling and only forwards downward
/// pans to the panel resize handler when content is at the top (or scroll is off).
struct PanelScrollCoordinator<Content: View>: UIViewControllerRepresentable {
    let isScrollEnabled: Bool
    let bottomContentInset: CGFloat
    let panelResizeContext: PanelResizeContext?
    @Binding var isScrollAtTop: Bool
    @Binding var scrollEdgeProgress: CGFloat
    let onPanelDragChanged: (CGFloat) -> Void
    let onPanelExpandedDuringDrag: (() -> Void)?
    let onPanelDragEnded: (_ translation: CGFloat, _ predicted: CGFloat) -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.panelScrollViewHandle) private var panelScrollViewHandle

    func makeUIViewController(context: Context) -> PanelScrollViewController<Content> {
        let controller = PanelScrollViewController(rootView: content())
        controller.scrollViewHandle = panelScrollViewHandle
        controller.isScrollEnabled = isScrollEnabled
        controller.bottomContentInset = bottomContentInset
        controller.panelResizeContext = panelResizeContext
        controller.onScrollStateChanged = { atTop, progress in
            if isScrollAtTop != atTop {
                isScrollAtTop = atTop
            }
            if abs(scrollEdgeProgress - progress) > 0.02 {
                scrollEdgeProgress = progress
            }
        }
        controller.onPanelDragChanged = onPanelDragChanged
        controller.onPanelExpandedDuringDrag = onPanelExpandedDuringDrag
        controller.onPanelDragEnded = onPanelDragEnded
        return controller
    }

    func updateUIViewController(_ controller: PanelScrollViewController<Content>, context: Context) {
        let preservedOffset = controller.currentContentOffset

        controller.scrollViewHandle = panelScrollViewHandle
        controller.isScrollEnabled = isScrollEnabled
        controller.bottomContentInset = bottomContentInset
        controller.panelResizeContext = panelResizeContext
        controller.onScrollStateChanged = { atTop, progress in
            if isScrollAtTop != atTop {
                isScrollAtTop = atTop
            }
            if abs(scrollEdgeProgress - progress) > 0.02 {
                scrollEdgeProgress = progress
            }
        }
        controller.onPanelDragChanged = onPanelDragChanged
        controller.onPanelExpandedDuringDrag = onPanelExpandedDuringDrag
        controller.onPanelDragEnded = onPanelDragEnded
        controller.updateHostedContent(content(), preservingOffset: preservedOffset)
    }
}

final class PanelScrollViewController<Content: View>: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var rootView: Content
    weak var scrollViewHandle: PanelScrollViewHandle?
    var isScrollEnabled = true {
        didSet { applyScrollEnabled() }
    }

    var bottomContentInset: CGFloat = 0 {
        didSet { applyContentInset() }
    }

    var panelResizeContext: PanelResizeContext?

    var onScrollStateChanged: ((Bool, CGFloat) -> Void)?
    var onPanelDragChanged: ((CGFloat) -> Void)?
    var onPanelExpandedDuringDrag: (() -> Void)?
    var onPanelDragEnded: ((_ translation: CGFloat, _ predicted: CGFloat) -> Void)?

    var currentContentOffset: CGPoint {
        scrollView.contentOffset
    }

    private let scrollView = UIScrollView()
    private var hostingController: UIHostingController<Content>!
    private var panelPan: UIPanGestureRecognizer!
    private var isForwardingPanelPan = false
    private var isHandedOffToScroll = false
    private var activeResizeContext: PanelResizeContext?
    private var minContentHeightConstraint: NSLayoutConstraint?

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
        scrollView.delaysContentTouches = false
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
        hostingController.safeAreaRegions = []
        if #available(iOS 16.0, *) {
            hostingController.sizingOptions = [.intrinsicContentSize]
        }
        addChild(hostingController)
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        minContentHeightConstraint = hostingController.view.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor,
            constant: 0
        )
        minContentHeightConstraint?.priority = .defaultHigh

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            minContentHeightConstraint!,
        ])

        panelPan = UIPanGestureRecognizer(target: self, action: #selector(handlePanelPan(_:)))
        panelPan.delegate = self
        scrollView.addGestureRecognizer(panelPan)

        applyScrollEnabled()
        applyContentInset()
        registerScrollViewHandle()
        reportScrollState()
    }

    deinit {
        scrollViewHandle?.scrollView = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        minContentHeightConstraint?.constant = -bottomContentInset
        hostingController.view.invalidateIntrinsicContentSize()
    }

    func updateHostedContent(_ content: Content, preservingOffset: CGPoint) {
        rootView = content
        hostingController.rootView = content
        view.setNeedsLayout()
        view.layoutIfNeeded()
        scrollView.contentOffset = preservingOffset
        reportScrollState()
    }

    func scrollToTop(animated: Bool) {
        scrollView.setContentOffset(.zero, animated: animated)
        reportScrollState()
    }

    private func applyScrollEnabled() {
        scrollView.isScrollEnabled = isScrollEnabled
        scrollView.alwaysBounceVertical = isScrollEnabled
        scrollView.panGestureRecognizer.isEnabled = isScrollEnabled && !isForwardingPanelPan
        if !isScrollEnabled, !isHandedOffToScroll {
            scrollView.setContentOffset(.zero, animated: false)
        }
        reportScrollState()
    }

    private func applyContentInset() {
        scrollView.contentInset.bottom = bottomContentInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomContentInset
    }

    private func registerScrollViewHandle() {
        scrollViewHandle?.scrollView = scrollView
        if #available(iOS 26.0, *) {
            scrollView.bottomEdgeEffect.isHidden = true
        }
    }

    private func reportScrollState() {
        let offset = scrollView.contentOffset.y
        let atTop = offset <= 0.5
        let progress = min(max(offset / 28, 0), 1)
        onScrollStateChanged?(atTop, progress)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if isForwardingPanelPan, !isHandedOffToScroll, scrollView.contentOffset.y != 0 {
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
            isHandedOffToScroll = false
            activeResizeContext = panelResizeContext
            scrollView.panGestureRecognizer.isEnabled = false
            if !isScrollEnabled {
                scrollView.isScrollEnabled = false
            }
        case .changed:
            guard isForwardingPanelPan else { return }
            if !isScrollEnabled {
                handleResizePanChanged(translation: translation)
            } else if isHandedOffToScroll {
                handleHandedOffPanChanged(translation: translation)
            } else {
                scrollView.contentOffset.y = 0
                onPanelDragChanged?(translation)
            }
        case .ended, .cancelled, .failed:
            guard isForwardingPanelPan else { return }
            onPanelDragEnded?(translation, predicted)
            isForwardingPanelPan = false
            isHandedOffToScroll = false
            activeResizeContext = nil
            applyScrollEnabled()
        default:
            break
        }
    }

    private func handleResizePanChanged(translation: CGFloat) {
        guard let context = activeResizeContext ?? panelResizeContext else {
            scrollView.contentOffset.y = 0
            onPanelDragChanged?(translation)
            return
        }

        let rawHeight = context.baseHeight - translation
        let panelTranslation = context.baseHeight - context.maxHeight

        if rawHeight >= context.maxHeight, translation < 0 {
            if !isHandedOffToScroll {
                isHandedOffToScroll = true
                scrollView.isScrollEnabled = true
                scrollView.panGestureRecognizer.isEnabled = true
                onPanelDragChanged?(panelTranslation)
                onPanelExpandedDuringDrag?()
            }
            let overflow = rawHeight - context.maxHeight
            scrollView.contentOffset.y = overflow
            reportScrollState()
        } else {
            if isHandedOffToScroll {
                isHandedOffToScroll = false
                scrollView.isScrollEnabled = false
                scrollView.panGestureRecognizer.isEnabled = false
                scrollView.contentOffset.y = 0
            }
            onPanelDragChanged?(translation)
        }
    }

    private func handleHandedOffPanChanged(translation: CGFloat) {
        guard let context = activeResizeContext ?? panelResizeContext else { return }

        let rawHeight = context.baseHeight - translation
        let overflow = max(rawHeight - context.maxHeight, 0)
        scrollView.contentOffset.y = overflow
        reportScrollState()
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
        if otherGestureRecognizer === scrollView.panGestureRecognizer {
            return true
        }
        if gestureRecognizer === panelPan, otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
