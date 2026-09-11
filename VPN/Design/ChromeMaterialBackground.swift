import SwiftUI
import UIKit

// Ported from Telegram-iOS Display/NavigationBackgroundView.swift (BlurredBackgroundView).

enum TelegramScrollEdge {
    case top
    case bottom
}

enum TelegramBlurStrength {
    case navigationBar
    case scrollEdge
    /// Bottom search dock: denser blur so list icons don't bleed through the pills.
    case panelDock

    func effect(isLight: Bool) -> UIBlurEffect {
        switch self {
        case .navigationBar:
            return TelegramBlurEffects.customZoomBlur(isLight: isLight)
        case .scrollEdge:
            if isLight {
                return UIBlurEffect(style: .systemThinMaterialLight)
            }
            return UIBlurEffect(style: .systemThinMaterialDark)
        case .panelDock:
            if isLight {
                return UIBlurEffect(style: .systemChromeMaterialLight)
            }
            return UIBlurEffect(style: .systemChromeMaterialDark)
        }
    }
}

/// Telegram bar blur with an inner-edge feather toward scrolling content.
struct TelegramScrollEdgeBackground: UIViewRepresentable {
    var edge: TelegramScrollEdge
    var progress: CGFloat = 1
    var strength: TelegramBlurStrength = .navigationBar

    func makeUIView(context: Context) -> TelegramScrollEdgeBackgroundView {
        TelegramScrollEdgeBackgroundView(edge: edge, strength: strength)
    }

    func updateUIView(_ uiView: TelegramScrollEdgeBackgroundView, context: Context) {
        uiView.setEdge(edge)
        uiView.setProgress(progress)
        uiView.setStrength(strength)
    }
}

/// Telegram navigation-bar blur: trimmed UIVisualEffectView filter stack.
final class TelegramBlurredBackgroundView: UIView {
    private var effectView: UIVisualEffectView?
    private var blurStrength: TelegramBlurStrength = .navigationBar

    override init(frame: CGRect) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        installBlur()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: TelegramBlurredBackgroundView, _) in
                self.effectView?.removeFromSuperview()
                self.effectView = nil
                self.installBlur()
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView?.frame = bounds
    }

    func setStrength(_ strength: TelegramBlurStrength) {
        guard blurStrength != strength else { return }
        blurStrength = strength
        effectView?.removeFromSuperview()
        effectView = nil
        installBlur()
    }

    private func installBlur() {
        guard !UIAccessibility.isReduceTransparencyEnabled else {
            effectView?.removeFromSuperview()
            effectView = nil
            return
        }

        guard effectView == nil else { return }

        let isLight = traitCollection.userInterfaceStyle != .dark
        let effect = blurStrength.effect(isLight: isLight)
        let effectView = UIVisualEffectView(effect: effect)

        for subview in effectView.subviews where subview.description.contains("VisualEffectSubview") {
            subview.isHidden = true
        }

        if let sublayer = effectView.layer.sublayers?.first, let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false

            let allowedKeys = ["colorSaturate", "gaussianBlur"]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else { return true }
                return allowedKeys.contains(String(describing: filter))
            }
        }

        effectView.frame = bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(effectView, at: 0)
        self.effectView = effectView
    }
}

final class TelegramScrollEdgeBackgroundView: UIView {
    private let blurView = TelegramBlurredBackgroundView()
    private let maskLayer = CAGradientLayer()
    private var edge: TelegramScrollEdge
    private var strength: TelegramBlurStrength

    init(edge: TelegramScrollEdge, strength: TelegramBlurStrength = .navigationBar) {
        self.edge = edge
        self.strength = strength
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.setStrength(strength)
        addSubview(blurView)
        applyMask(for: edge)
        blurView.layer.mask = maskLayer
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        maskLayer.frame = blurView.bounds
    }

    func setEdge(_ edge: TelegramScrollEdge) {
        guard self.edge != edge else { return }
        self.edge = edge
        applyMask(for: edge)
    }

    func setStrength(_ strength: TelegramBlurStrength) {
        guard self.strength != strength else { return }
        self.strength = strength
        blurView.setStrength(strength)
        applyMask(for: edge)
    }

    func setProgress(_ progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        alpha = clamped
        isHidden = clamped < 0.01
    }

    private func applyMask(for edge: TelegramScrollEdge) {
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1)

        switch edge {
        case .top:
            switch strength {
            case .navigationBar:
                // Solid at the outer top edge; feather only toward the scrolling list.
                maskLayer.colors = [
                    UIColor.black.cgColor,
                    UIColor.black.withAlphaComponent(0.7).cgColor,
                    UIColor.clear.cgColor,
                ]
                maskLayer.locations = [0, 0.5, 1]
            case .scrollEdge, .panelDock:
                // Longer solid chrome; softer fade over the extended blur height.
                maskLayer.colors = [
                    UIColor.black.cgColor,
                    UIColor.black.cgColor,
                    UIColor.black.withAlphaComponent(0.85).cgColor,
                    UIColor.black.withAlphaComponent(0.35).cgColor,
                    UIColor.clear.cgColor,
                ]
                maskLayer.locations = [0, 0.28, 0.52, 0.78, 1]
            }
        case .bottom:
            switch strength {
            case .navigationBar:
                // Solid at the outer bottom edge; feather only toward the scrolling list.
                maskLayer.colors = [
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.7).cgColor,
                    UIColor.black.cgColor,
                ]
                maskLayer.locations = [0, 0.5, 1]
            case .scrollEdge:
                // Longer feather for the extended search dock blur zone.
                maskLayer.colors = [
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.35).cgColor,
                    UIColor.black.withAlphaComponent(0.85).cgColor,
                    UIColor.black.cgColor,
                    UIColor.black.cgColor,
                ]
                maskLayer.locations = [0, 0.22, 0.48, 0.72, 1]
            case .panelDock:
                // Settings-like dock: wide milky fade, dense blur at the bottom.
                maskLayer.colors = [
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.5).cgColor,
                    UIColor.black.withAlphaComponent(0.92).cgColor,
                    UIColor.black.cgColor,
                    UIColor.black.cgColor,
                ]
                maskLayer.locations = [0, 0.16, 0.38, 0.62, 1]
            }
        }
    }
}

enum TelegramBlurEffects {
    static func customZoomBlur(isLight: Bool) -> UIBlurEffect {
        if isLight {
            return UIBlurEffect(style: .systemUltraThinMaterialLight)
        }
        return UIBlurEffect(style: .systemUltraThinMaterialDark)
    }
}
