import SwiftUI
import EditSmithCore

@main
struct EditSmithApp: App {
    var body: some Scene {
        WindowGroup { RecipeWorkbench() }
            .defaultSize(width: 1_180, height: 760)
            .commands { TextFormattingCommands() }
        Settings { ExtensionHelpView() }
    }
}
