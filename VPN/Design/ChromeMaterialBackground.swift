import SwiftUI
import UIKit

/// Chrome material with a feathered lower edge so content dissolves under the
/// bar without adding a separate color tint.
struct ScrollEdgeSoftBackground: UIViewRepresentable {
    var progress: CGFloat

    func makeUIView(context: Context) -> ScrollEdgeSoftBackgroundView {
        ScrollEdgeSoftBackgroundView()
    }

    func updateUIView(_ uiView: ScrollEdgeSoftBackgroundView, context: Context) {
        uiView.setProgress(progress)
    }
}

final class ScrollEdgeSoftBackgroundView: UIView {
    private let effectView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemChromeMaterial)
    )
    private let maskLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectView)

        maskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1)
        maskLayer.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor,
        ]
        maskLayer.locations = [0, 0.68, 1]
        effectView.layer.mask = maskLayer
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        maskLayer.frame = effectView.bounds
    }

    func setProgress(_ progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        alpha = clamped
        isHidden = clamped < 0.01
    }
}
