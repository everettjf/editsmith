import SwiftUI
import EditSmithCore

@main
struct EditSmithApp: App {
    var body: some Scene {
        WindowGroup { RecipeWorkbench() }
            .defaultSize(width: 1_020, height: 680)
        Settings { ExtensionHelpView() }
    }
}
