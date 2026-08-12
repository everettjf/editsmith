import Foundation
import XcodeKit
import JSPowerCore

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() {}

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        let utilities: [[XCSourceEditorCommandDefinitionKey: Any]] = [[.nameKey: "Undo Last JSPower Change", .identifierKey: "com.everettjf.qvcodefriend.rollback", .classNameKey: NSStringFromClass(SourceEditorCommand.self)]]
        return utilities + RecipeStore().load().filter(\.isEnabled).map { recipe in
            [
                .nameKey: recipe.name,
                .identifierKey: "com.everettjf.qvcodefriend.recipe.\(recipe.id)",
                .classNameKey: NSStringFromClass(SourceEditorCommand.self),
            ]
        }
    }
}
