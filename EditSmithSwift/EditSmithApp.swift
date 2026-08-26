import SwiftUI
import AppKit
import EditSmithCore

@main
struct EditSmithApp: App {
    var body: some Scene {
        WindowGroup {
            RecipeWorkbench()
                .background(WindowSizeGuard())
        }
            .defaultSize(width: 1_180, height: 720)
            .commands { TextFormattingCommands() }
        Settings { ExtensionHelpView() }
    }
}

private struct WindowSizeGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { GuardView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class GuardView: NSView {
        private var observedWindow: NSWindow?
        private var activationObserver: NSObjectProtocol?
        private var hasAppliedInitialSize = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window !== observedWindow else { return }
            if let activationObserver {
                NotificationCenter.default.removeObserver(activationObserver)
            }
            observedWindow = window
            guard let window else { return }
            activationObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleInitialSizeCheck()
            }
            scheduleInitialSizeCheck()
        }

        deinit {
            if let activationObserver {
                NotificationCenter.default.removeObserver(activationObserver)
            }
        }

        private func scheduleInitialSizeCheck() {
            guard !hasAppliedInitialSize else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.clampRestoredWindow()
            }
        }

        private func clampRestoredWindow() {
            guard let window,
                  let screen = window.screen ?? NSScreen.main else { return }
            hasAppliedInitialSize = true
            let visibleFrame = screen.visibleFrame
            window.contentMinSize = NSSize(width: 860, height: 560)
            guard window.frame.width > 1_440
                    || window.frame.height > visibleFrame.height else { return }

            if window.isZoomed {
                window.zoom(nil)
            }

            let size = NSSize(
                width: min(1_180, visibleFrame.width * 0.9),
                height: min(720, visibleFrame.height * 0.9)
            )
            let frame = NSRect(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            window.setFrame(frame, display: true, animate: false)
        }
    }
}
