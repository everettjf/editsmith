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
            .commands {
                TextFormattingCommands()
                WorkbenchCommands()
                SupportCommands()
            }
        Settings { ExtensionHelpView() }
    }
}

private struct SupportCommands: Commands {
    private let issuesURL = URL(string: "https://github.com/everettjf/editsmith/issues")!
    private let discordURL = URL(string: "https://discord.gg/eGzEaP6TzR")!

    var body: some Commands {
        CommandGroup(after: .help) {
            Divider()
            Link(destination: issuesURL) {
                Label("Submit an Issue", systemImage: "exclamationmark.bubble")
            }
            Link(destination: discordURL) {
                Label("Join Discord", systemImage: "message")
            }
        }
    }
}

extension FocusedValues {
    @Entry var recipeLibrary: RecipeLibrary?
}

private struct WorkbenchCommands: Commands {
    @FocusedValue(\.recipeLibrary) private var library

    var body: some Commands {
        CommandMenu("Action") {
            Button("Run Current Test", systemImage: "play.fill") {
                library?.runCurrent()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(library?.selectedTestIndex == nil)

            Button("Run All Tests", systemImage: "checkmark.circle") {
                library?.runAll()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(library?.selectedIndex.map { library?.recipes[$0].testCases.isEmpty ?? true } ?? true)

            Divider()

            Button("Update Snapshot", systemImage: "arrow.triangle.2.circlepath") {
                library?.updateSnapshot()
            }
            .keyboardShortcut("u", modifiers: [.command, .option])
            .disabled(library?.execution == nil)
        }
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
