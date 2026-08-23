import Foundation
import XcodeKit
import EditSmithCore

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() {}

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        let utilities: [[XCSourceEditorCommandDefinitionKey: Any]] = [[.nameKey: "Undo Last EditSmith Change", .identifierKey: "com.xnu.editsmith.rollback", .classNameKey: NSStringFromClass(SourceEditorCommand.self)]]
        return utilities + RecipeStore().load().filter(\.isEnabled).map { recipe in
            [
                .nameKey: recipe.name,
                .identifierKey: "com.xnu.editsmith.recipe.\(recipe.id)",
                .classNameKey: NSStringFromClass(SourceEditorCommand.self),
            ]
        }
    }
}
