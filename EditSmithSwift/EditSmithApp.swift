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
            .defaultSize(width: 1_080, height: 660)
            .commands { TextFormattingCommands() }
        Settings { ExtensionHelpView() }
    }
}

private struct WindowSizeGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { GuardView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class GuardView: NSView {
        private var hasCheckedWindow = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, !hasCheckedWindow else { return }
            hasCheckedWindow = true
            DispatchQueue.main.async { [weak self] in self?.clampRestoredWindow() }
        }

        private func clampRestoredWindow() {
            guard let window,
                  let screen = window.screen ?? NSScreen.main else { return }
            let visibleFrame = screen.visibleFrame
            guard window.frame.width > visibleFrame.width
                    || window.frame.height > visibleFrame.height else { return }

            let size = NSSize(
                width: min(1_080, visibleFrame.width * 0.9),
                height: min(660, visibleFrame.height * 0.9)
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
