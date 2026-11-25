import SwiftUI
import UIKit

struct NativeDrawerPanGesture: ViewModifier {
    let enabled: Bool
    let canBegin: (CGPoint, CGPoint) -> Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (CGFloat, CGFloat, Bool) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        let configuration = DrawerPanConfiguration(enabled: enabled, canBegin: canBegin,
                                                   onChange: onChange, onEnd: onEnd)
        content.background(DrawerPanAttachment(configuration: configuration))
    }
}

private struct DrawerPanConfiguration {
    let enabled: Bool
    let canBegin: (CGPoint, CGPoint) -> Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (CGFloat, CGFloat, Bool) -> Void
}

@MainActor
private final class DrawerPanCoordinator: NSObject, UIGestureRecognizerDelegate {
    private var configuration: DrawerPanConfiguration
    private var startPoint: CGPoint?
    private var isRecognizing = false
    private var lastTranslation: CGFloat = 0
    private var lastVelocity: CGFloat = 0
    private weak var legacyHost: UIView?
    private var legacyRecognizer: UIPanGestureRecognizer?

    init(configuration: DrawerPanConfiguration) {
        self.configuration = configuration
    }

    func makeRecognizer(legacy: Bool = false) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = self
        recognizer.minimumNumberOfTouches = 1
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = true
        recognizer.isEnabled = configuration.enabled
        if legacy {
            recognizer.addTarget(self, action: #selector(handleLegacyPan(_:)))
        }
        return recognizer
    }

    func update(_ configuration: DrawerPanConfiguration, recognizer: UIPanGestureRecognizer? = nil) {
        self.configuration = configuration
        if let recognizer = recognizer ?? legacyRecognizer,
           recognizer.isEnabled != configuration.enabled {
            recognizer.isEnabled = configuration.enabled
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard configuration.enabled, let window = gestureRecognizer.view?.window else { return false }
        if gestureRecognizer.numberOfTouches == 0 {
            startPoint = touch.location(in: window)
        }
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard configuration.enabled, let recognizer = gestureRecognizer as? UIPanGestureRecognizer,
              let window = recognizer.view?.window else { return false }
        let translation = recognizer.translation(in: window)
        let location = recognizer.location(in: window)
        let start = startPoint ?? CGPoint(x: location.x - translation.x, y: location.y - translation.y)
        return configuration.canBegin(start, recognizer.velocity(in: window))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
        return otherGestureRecognizer === scrollView.panGestureRecognizer
    }

    func handle(_ recognizer: UIPanGestureRecognizer) {
        if let window = recognizer.view?.window {
            lastTranslation = recognizer.translation(in: window).x
            lastVelocity = recognizer.velocity(in: window).x
        }
        switch recognizer.state {
        case .began:
            isRecognizing = true
            configuration.onChange(lastTranslation)
        case .changed:
            configuration.onChange(lastTranslation)
        case .ended:
            finish(cancelled: false)
        case .cancelled, .failed:
            finish(cancelled: true)
        default:
            break
        }
    }

    private func finish(cancelled: Bool) {
        guard isRecognizing else { return }
        isRecognizing = false
        startPoint = nil
        configuration.onEnd(lastTranslation, lastVelocity, cancelled)
    }

    @objc private func handleLegacyPan(_ recognizer: UIPanGestureRecognizer) {
        handle(recognizer)
    }

    func attachLegacyRecognizer(to host: UIView?) {
        guard legacyHost !== host else { return }
        detachLegacyRecognizer()
        guard let host else { return }
        let recognizer = makeRecognizer(legacy: true)
        legacyHost = host
        legacyRecognizer = recognizer
        host.addGestureRecognizer(recognizer)
    }

    func detachLegacyRecognizer() {
        guard let recognizer = legacyRecognizer else { return }
        finish(cancelled: true)
        recognizer.removeTarget(self, action: #selector(handleLegacyPan(_:)))
        recognizer.delegate = nil
        legacyHost?.removeGestureRecognizer(recognizer)
        legacyRecognizer = nil
        legacyHost = nil
    }
}

private struct DrawerPanAttachment: UIViewRepresentable {
    let configuration: DrawerPanConfiguration

    func makeCoordinator() -> DrawerPanCoordinator {
        DrawerPanCoordinator(configuration: configuration)
    }

    func makeUIView(context: Context) -> DrawerPanAttachmentView {
        let view = DrawerPanAttachmentView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: DrawerPanAttachmentView, context: Context) {
        context.coordinator.update(configuration)
        view.attachToHostingAncestor()
    }

    static func dismantleUIView(_ view: DrawerPanAttachmentView, coordinator: DrawerPanCoordinator) {
        view.coordinator = nil
        coordinator.detachLegacyRecognizer()
    }
}

private final class DrawerPanAttachmentView: UIView {
    weak var coordinator: DrawerPanCoordinator?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        attachToHostingAncestor()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachToHostingAncestor()
    }

    func attachToHostingAncestor() {
        guard window != nil else {
            coordinator?.attachLegacyRecognizer(to: nil)
            return
        }
        // The background can have its own hosting controller. The window's root
        // view is the stationary ancestor shared with the native TabView content.
        coordinator?.attachLegacyRecognizer(to: window?.rootViewController?.viewIfLoaded)
    }
}
