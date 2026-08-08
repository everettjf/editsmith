import Foundation
import JavaScriptCore

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case builtin, javascript }
    public let id: String
    public var name: String
    public var summary: String
    public var kind: Kind
    public var source: String
    public var isEnabled: Bool

    public init(id: String = UUID().uuidString, name: String, summary: String, kind: Kind, source: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.summary = summary
        self.kind = kind
        self.source = source
        self.isEnabled = isEnabled
    }
}

public enum RecipeError: LocalizedError, Equatable {
    case inputTooLarge
    case scriptTooLarge
    case unknownBuiltin(String)
    case javaScript(String)
    case invalidResult

    public var errorDescription: String? {
        switch self {
        case .inputTooLarge: "Input is larger than the 5 MB safety limit."
        case .scriptTooLarge: "Recipe source is larger than the 256 KB safety limit."
        case .unknownBuiltin(let name): "Unknown built-in recipe: \(name)."
        case .javaScript(let message): "JavaScript error: \(message)"
        case .invalidResult: "The transform function must return a string."
        }
    }
}

public struct RecipeEngine: Sendable {
    public init() {}

    @MainActor
    public func run(_ recipe: Recipe, input: String) throws -> String {
        guard input.utf8.count <= 5 * 1_024 * 1_024 else { throw RecipeError.inputTooLarge }
        return switch recipe.kind {
        case .builtin: try runBuiltin(recipe.source, input: input)
        case .javascript: try runJavaScript(recipe.source, input: input)
        }
    }

    private func runBuiltin(_ name: String, input: String) throws -> String {
        switch name {
        case "sort-lines": input.components(separatedBy: .newlines).sorted().joined(separator: "\n")
        case "trim-trailing-whitespace": input.components(separatedBy: .newlines).map { $0.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) }.joined(separator: "\n")
        case "uppercase": input.uppercased()
        case "lowercase": input.lowercased()
        case "pretty-json":
            String(decoding: try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: Data(input.utf8)), options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
        default: throw RecipeError.unknownBuiltin(name)
        }
    }

    private func runJavaScript(_ source: String, input: String) throws -> String {
        guard source.utf8.count <= 256 * 1_024 else { throw RecipeError.scriptTooLarge }
        guard let context = JSContext() else { throw RecipeError.javaScript("Could not create JavaScript context.") }
        var exception: String?
        context.exceptionHandler = { _, value in exception = value?.toString() }
        context.evaluateScript("'use strict';\n" + source)
        if let exception { throw RecipeError.javaScript(exception) }
        guard let function = context.objectForKeyedSubscript("transform"), !function.isUndefined else {
            throw RecipeError.javaScript("Missing transform(input) function.")
        }
        let value = function.call(withArguments: [input])
        if let exception { throw RecipeError.javaScript(exception) }
        guard let value, value.isString, let result = value.toString() else { throw RecipeError.invalidResult }
        return result
    }
}

public enum BuiltinRecipes {
    public static let all: [Recipe] = [
        .init(id: "builtin.sort-lines", name: "Sort Lines", summary: "Sort selected lines in ascending order.", kind: .builtin, source: "sort-lines"),
        .init(id: "builtin.trim-trailing", name: "Trim Trailing Whitespace", summary: "Remove whitespace at line endings.", kind: .builtin, source: "trim-trailing-whitespace"),
        .init(id: "builtin.pretty-json", name: "Pretty Print JSON", summary: "Format and sort JSON keys.", kind: .builtin, source: "pretty-json"),
        .init(id: "builtin.uppercase", name: "Uppercase", summary: "Convert text to uppercase.", kind: .builtin, source: "uppercase"),
        .init(id: "builtin.lowercase", name: "Lowercase", summary: "Convert text to lowercase.", kind: .builtin, source: "lowercase"),
    ]
}

public struct RecipeStore {
    public static let suiteName = "YPV49M8592.com.everettjf.qvcodefriend"
    private static let key = "swift.recipes.v2"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = UserDefaults(suiteName: Self.suiteName)) {
        self.defaults = defaults ?? .standard
    }

    public func load() -> [Recipe] {
        guard let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode([Recipe].self, from: data) else { return BuiltinRecipes.all }
        return saved
    }

    public func save(_ recipes: [Recipe]) throws {
        defaults.set(try JSONEncoder().encode(recipes), forKey: Self.key)
    }
}

public struct TextPosition: Equatable, Sendable {
    public let line: Int
    public let column: Int
    public init(line: Int, column: Int) { self.line = line; self.column = column }
}

public struct TextRange: Equatable, Sendable {
    public let start: TextPosition
    public let end: TextPosition
    public init(start: TextPosition, end: TextPosition) { self.start = start; self.end = end }
}

public struct TextBufferTransformer: Sendable {
    public init() {}

    @MainActor
    public func transform(lines: [String], ranges: [TextRange], recipe: Recipe) throws -> [String] {
        let original = lines.joined()
        if ranges.isEmpty { return splitLines(try RecipeEngine().run(recipe, input: original)) }
        let mutable = NSMutableString(string: original)
        let offsets = ranges.compactMap { offsetRange($0, lines: lines) }.sorted { $0.location > $1.location }
        for range in offsets {
            let input = mutable.substring(with: range)
            mutable.replaceCharacters(in: range, with: try RecipeEngine().run(recipe, input: input))
        }
        return splitLines(mutable as String)
    }

    private func offsetRange(_ range: TextRange, lines: [String]) -> NSRange? {
        guard lines.indices.contains(range.start.line), lines.indices.contains(range.end.line) else { return nil }
        let starts = lines.indices.map { index in lines[..<index].reduce(0) { $0 + ($1 as NSString).length } }
        let startLength = (lines[range.start.line] as NSString).length
        let endLength = (lines[range.end.line] as NSString).length
        guard range.start.column <= startLength, range.end.column <= endLength else { return nil }
        let start = starts[range.start.line] + range.start.column
        let end = starts[range.end.line] + range.end.column
        guard end >= start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func splitLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [""] }
        let expression = try! NSRegularExpression(pattern: ".*(?:\\r\\n|\\n|\\r)|.+$", options: [])
        let nsText = text as NSString
        let matches = expression.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.map { nsText.substring(with: $0.range) }
    }
}
