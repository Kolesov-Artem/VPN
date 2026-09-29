import SwiftUI
import UIKit

/// Scroll-edge fade for the compact bar. Kept off the panel's own state so a
/// flick does not rebuild the location list on every point of movement.
@MainActor
@Observable
final class PanelScrollChromeModel {
    var edgeProgress: CGFloat = 0

    private var pending: CGFloat?
    private var scheduled = false

    func setProgress(_ progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        pending = clamped
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            guard let pending = self.pending else { return }
            self.pending = nil
            self.apply(pending)
        }
    }

    private func apply(_ progress: CGFloat) {
        let atRest = progress == 0 || progress == 1
        guard atRest || abs(edgeProgress - progress) > 0.04 else { return }
        edgeProgress = progress
    }

    func reset() {
        pending = nil
        edgeProgress = 0
    }
}

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
    /// While the finger is down, the list is pushed only when reveal crosses a step.
    let isDraggingPanel: Bool
    let hostedContentRevision: Int
    var scrollChrome: PanelScrollChromeModel
    let onPanelDragChanged: (CGFloat) -> Void
    let onPanelExpandedDuringDrag: (() -> Void)?
    let onPanelDragEnded: (_ translation: CGFloat, _ predicted: CGFloat) -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.panelScrollViewHandle) private var panelScrollViewHandle

    func makeUIViewController(context: Context) -> PanelScrollViewController<Content> {
        let controller = PanelScrollViewController(rootView: content())
        apply(to: controller, pushContent: false)
        controller.appliedHostedRevision = hostedContentRevision
        return controller
    }

    func updateUIViewController(_ controller: PanelScrollViewController<Content>, context: Context) {
        let revisionChanged = controller.appliedHostedRevision != hostedContentRevision
        let shouldPush = !isDraggingPanel || revisionChanged
        apply(to: controller, pushContent: shouldPush)
    }

    private func apply(to controller: PanelScrollViewController<Content>, pushContent: Bool) {
        controller.scrollViewHandle = panelScrollViewHandle
        if controller.isScrollEnabled != isScrollEnabled {
            controller.isScrollEnabled = isScrollEnabled
        }
        if controller.bottomContentInset != bottomContentInset {
            controller.bottomContentInset = bottomContentInset
        }
        controller.panelResizeContext = panelResizeContext
        let chrome = scrollChrome
        controller.onScrollStateChanged = { progress in
            chrome.setProgress(progress)
        }
        controller.onPanelDragChanged = onPanelDragChanged
        controller.onPanelExpandedDuringDrag = onPanelExpandedDuringDrag
        controller.onPanelDragEnded = onPanelDragEnded
        guard pushContent else { return }
        controller.appliedHostedRevision = hostedContentRevision
        controller.updateHostedContent(content(), preservingOffset: controller.currentContentOffset)
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

    var appliedHostedRevision: Int?
    var onScrollStateChanged: ((CGFloat) -> Void)?
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
    private var appliedLayoutWidth: CGFloat = .nan
    private var appliedLayoutInset: CGFloat = .nan

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
        let width = scrollView.bounds.width
        let inset = bottomContentInset
        guard abs(width - appliedLayoutWidth) > 0.5 || abs(inset - appliedLayoutInset) > 0.5 else {
            return
        }
        appliedLayoutWidth = width
        appliedLayoutInset = inset
        let preservedOffset = scrollView.contentOffset
        minContentHeightConstraint?.constant = -inset
        if abs(scrollView.contentOffset.y - preservedOffset.y) > 0.5 {
            scrollView.contentOffset = preservedOffset
        }
    }

    func updateHostedContent(_ content: Content, preservingOffset: CGPoint) {
        rootView = content
        guard isViewLoaded else { return }
        UIView.performWithoutAnimation {
            hostingController.rootView = content
            hostingController.view.invalidateIntrinsicContentSize()
            hostingController.view.layoutIfNeeded()
            scrollView.layoutIfNeeded()
            scrollView.contentOffset = preservingOffset
        }
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
        let progress = min(max(offset / 28, 0), 1)
        onScrollStateChanged?(progress)
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
