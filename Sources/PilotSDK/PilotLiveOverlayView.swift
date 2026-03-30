import Foundation
#if canImport(UIKit)
import UIKit

final class PilotLiveOverlayView: UIView {
    private enum Constants {
        static let tapReleaseDelay: TimeInterval = 0.09
        static let tapHideDelay: TimeInterval = 0.42
        static let releaseHideDelay: TimeInterval = 0.26
        static let outerPressedRadius: CGFloat = 28
        static let outerReleasedRadius: CGFloat = 22
        static let innerPressedRadius: CGFloat = 12
        static let innerReleasedRadius: CGFloat = 8
    }

    private var isIndicatorVisible = false
    private var isPressed = false
    private var indicatorCenter = CGPoint.zero
    private var releaseWorkItem: DispatchWorkItem?
    private var hideWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    func showTap(at point: CGPoint) {
        self.updatePosition(point)
        self.isPressed = true
        self.isIndicatorVisible = true
        self.cancelPendingWork()
        self.setNeedsDisplay()

        let releaseWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isPressed = false
            self.setNeedsDisplay()
        }
        self.releaseWorkItem = releaseWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.tapReleaseDelay, execute: releaseWorkItem)

        let hideWorkItem = DispatchWorkItem { [weak self] in
            self?.clearIndicator()
        }
        self.hideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.tapHideDelay, execute: hideWorkItem)
    }

    func showPress(at point: CGPoint) {
        self.updatePosition(point)
        self.isPressed = true
        self.isIndicatorVisible = true
        self.cancelPendingWork()
        self.setNeedsDisplay()
    }

    func showRelease(at point: CGPoint) {
        self.updatePosition(point)
        self.isPressed = false
        self.isIndicatorVisible = true
        self.cancelPendingWork()
        self.setNeedsDisplay()

        let hideWorkItem = DispatchWorkItem { [weak self] in
            self?.clearIndicator()
        }
        self.hideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.releaseHideDelay, execute: hideWorkItem)
    }

    func clearIndicator() {
        self.cancelPendingWork()
        self.isIndicatorVisible = false
        self.isPressed = false
        self.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard self.isIndicatorVisible,
              let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let outerRadius = self.isPressed ? Constants.outerPressedRadius : Constants.outerReleasedRadius
        let innerRadius = self.isPressed ? Constants.innerPressedRadius : Constants.innerReleasedRadius

        context.setFillColor(UIColor.white.withAlphaComponent(0.4).cgColor)
        context.fillEllipse(in: CGRect(
            x: self.indicatorCenter.x - outerRadius,
            y: self.indicatorCenter.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))

        context.setFillColor(UIColor(red: 1.0, green: 0.44, blue: 0.26, alpha: 1.0).cgColor)
        context.fillEllipse(in: CGRect(
            x: self.indicatorCenter.x - innerRadius,
            y: self.indicatorCenter.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        ))
    }

    private func commonInit() {
        self.backgroundColor = .clear
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = false
    }

    private func updatePosition(_ point: CGPoint) {
        self.indicatorCenter = point
    }

    private func cancelPendingWork() {
        self.releaseWorkItem?.cancel()
        self.releaseWorkItem = nil
        self.hideWorkItem?.cancel()
        self.hideWorkItem = nil
    }
}
#endif