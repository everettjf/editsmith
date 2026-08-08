import Foundation
import XcodeKit
import JSPowerCore

final class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        Task { @MainActor in
            do {
                let prefix = "com.everettjf.qvcodefriend.recipe."
                let recipeID = invocation.commandIdentifier.replacingOccurrences(of: prefix, with: "")
                guard let recipe = RecipeStore().load().first(where: { $0.id == recipeID }) else {
                    throw RecipeError.unknownBuiltin(recipeID)
                }
                let lines = invocation.buffer.lines.compactMap { $0 as? String }
                let ranges = invocation.buffer.selections.compactMap { value -> JSPowerCore.TextRange? in
                    guard let range = value as? XCSourceTextRange else { return nil }
                    return JSPowerCore.TextRange(
                        start: JSPowerCore.TextPosition(line: range.start.line, column: range.start.column),
                        end: JSPowerCore.TextPosition(line: range.end.line, column: range.end.column)
                    )
                }.filter { $0.start != $0.end }
                let transformed = try TextBufferTransformer().transform(lines: lines, ranges: ranges, recipe: recipe)
                invocation.buffer.lines.removeAllObjects()
                invocation.buffer.lines.addObjects(from: transformed)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
