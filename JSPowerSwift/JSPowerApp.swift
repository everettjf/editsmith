import SwiftUI
import JSPowerCore

@main
struct JSPowerApp: App {
    var body: some Scene {
        WindowGroup { RecipeWorkbench() }
            .defaultSize(width: 1_020, height: 680)
        Settings { ExtensionHelpView() }
    }
}
