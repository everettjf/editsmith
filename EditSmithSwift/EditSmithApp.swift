import SwiftUI
import EditSmithCore

@main
struct EditSmithApp: App {
    var body: some Scene {
        WindowGroup { RecipeWorkbench() }
            .defaultSize(width: 1_080, height: 660)
            .commands { TextFormattingCommands() }
        Settings { ExtensionHelpView() }
    }
}
