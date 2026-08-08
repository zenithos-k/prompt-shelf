import AppKit
import SwiftUI

struct WindowVisibilityObserver: NSViewRepresentable {
    let onHidden: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHidden: onHidden)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        context.coordinator.onHidden = onHidden
        context.coordinator.attach(to: nsView.window)
    }

    final class TrackingView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onHidden: () -> Void

        private weak var observedWindow: NSWindow?
        private var visibilityTask: Task<Void, Never>?
        private var isHidden = false

        init(onHidden: @escaping () -> Void) {
            self.onHidden = onHidden
        }

        deinit {
            visibilityTask?.cancel()
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to window: NSWindow?) {
            guard let window, observedWindow !== window else { return }

            NotificationCenter.default.removeObserver(self)
            observedWindow = window
            isHidden = !window.isVisible

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowMayHaveHidden),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowOcclusionChanged),
                name: NSWindow.didChangeOcclusionStateNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowClosed),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }

        @objc private func windowMayHaveHidden() {
            visibilityTask?.cancel()
            visibilityTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 90_000_000)
                self?.evaluateVisibility()
            }
        }

        @objc private func windowOcclusionChanged() {
            evaluateVisibility()
        }

        @objc private func windowClosed() {
            markHidden()
        }

        private func evaluateVisibility() {
            guard let window = observedWindow else { return }
            let visible = window.isVisible && window.occlusionState.contains(.visible)

            if visible {
                isHidden = false
            } else {
                markHidden()
            }
        }

        private func markHidden() {
            guard !isHidden else { return }
            isHidden = true
            onHidden()
        }
    }
}
