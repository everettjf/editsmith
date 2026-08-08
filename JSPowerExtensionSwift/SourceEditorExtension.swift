import Foundation
import XcodeKit
import JSPowerCore

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() {}

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        RecipeStore().load().filter(\.isEnabled).map { recipe in
            [
                .nameKey: recipe.name,
                .identifierKey: "com.everettjf.qvcodefriend.recipe.\(recipe.id)",
                .classNameKey: NSStringFromClass(SourceEditorCommand.self),
            ]
        }
    }
}
