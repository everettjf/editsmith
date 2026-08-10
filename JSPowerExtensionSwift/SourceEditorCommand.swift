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
                let request = ExecutionRequest(
                    text: lines.joined(),
                    selections: ranges,
                    fileName: "Xcode Buffer",
                    fileType: invocation.buffer.contentUTI,
                    indentationWidth: invocation.buffer.tabWidth
                )
                let result = RecipeRunner().execute(request, recipe: recipe)
                if let diagnostic = result.diagnostic {
                    var message = diagnostic.message
                    if let line = diagnostic.line { message += " (line \(line)" }
                    if let column = diagnostic.column { message += ", column \(column)" }
                    if diagnostic.line != nil { message += ")" }
                    throw RecipeError.javaScript(message)
                }
                invocation.buffer.lines.removeAllObjects()
                invocation.buffer.lines.addObjects(from: splitLines(result.outputText))
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    private func splitLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [""] }
        let expression = try! NSRegularExpression(pattern: ".*(?:\\r\\n|\\n|\\r)|.+$", options: [])
        let nsText = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map {
            nsText.substring(with: $0.range)
        }
    }
}
