import Foundation
import JavaScriptCore

public struct TextPosition: Codable, Equatable, Hashable, Sendable {
    public var line: Int
    public var column: Int
    public init(line: Int, column: Int) { self.line = line; self.column = column }
}

public struct TextRange: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var start: TextPosition
    public var end: TextPosition
    public init(id: UUID = UUID(), start: TextPosition, end: TextPosition) {
        self.id = id
        self.start = start
        self.end = end
    }
}

public struct RecipeTestCase: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var input: String
    public var selections: [TextRange]
    public var expectedOutput: String
    public var expectedError: String?

    public init(
        id: String = UUID().uuidString,
        name: String = "Example",
        input: String = "let greeting = \"hello\";",
        selections: [TextRange] = [],
        expectedOutput: String = "",
        expectedError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.selections = selections
        self.expectedOutput = expectedOutput
        self.expectedError = expectedError
    }
}

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case builtin, javascript }
    public let id: String
    public var name: String
    public var summary: String
    public var kind: Kind
    public var source: String
    public var isEnabled: Bool
    public var testCases: [RecipeTestCase]

    public init(
        id: String = UUID().uuidString,
        name: String,
        summary: String,
        kind: Kind,
        source: String,
        isEnabled: Bool = true,
        testCases: [RecipeTestCase] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.kind = kind
        self.source = source
        self.isEnabled = isEnabled
        self.testCases = testCases
    }

    private enum CodingKeys: String, CodingKey { case id, name, summary, kind, source, isEnabled, testCases }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        summary = try values.decode(String.self, forKey: .summary)
        kind = try values.decode(Kind.self, forKey: .kind)
        source = try values.decode(String.self, forKey: .source)
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        testCases = try values.decodeIfPresent([RecipeTestCase].self, forKey: .testCases) ?? []
    }
}

public enum RecipeError: LocalizedError, Equatable {
    case inputTooLarge
    case scriptTooLarge
    case unknownBuiltin(String)
    case javaScript(String)
    case invalidResult
    case invalidSelection(String)

    public var errorDescription: String? {
        switch self {
        case .inputTooLarge: "Input is larger than the 5 MB safety limit."
        case .scriptTooLarge: "Recipe source is larger than the 256 KB safety limit."
        case .unknownBuiltin(let name): "Unknown built-in recipe: \(name)."
        case .javaScript(let message): "JavaScript error: \(message)"
        case .invalidResult: "The transform function must return a string."
        case .invalidSelection(let message): "Invalid selection: \(message)"
        }
    }
}

public struct ExecutionRequest: Equatable, Sendable {
    public var text: String
    public var selections: [TextRange]
    public var fileName: String
    public var fileType: String
    public var indentationWidth: Int

    public init(
        text: String,
        selections: [TextRange] = [],
        fileName: String = "Sample.swift",
        fileType: String = "public.swift-source",
        indentationWidth: Int = 4
    ) {
        self.text = text
        self.selections = selections
        self.fileName = fileName
        self.fileType = fileType
        self.indentationWidth = indentationWidth
    }
}

public struct ExecutionLog: Identifiable, Equatable, Sendable {
    public enum Level: String, Sendable { case log, info, warn, error }
    public let id: UUID
    public let level: Level
    public let message: String
    public let timestamp: Date

    public init(id: UUID = UUID(), level: Level, message: String, timestamp: Date = .now) {
        self.id = id
        self.level = level
        self.message = message
        self.timestamp = timestamp
    }
}

public struct ExecutionDiagnostic: Equatable, Sendable {
    public let message: String
    public let line: Int?
    public let column: Int?
    public let stack: String?

    public init(message: String, line: Int? = nil, column: Int? = nil, stack: String? = nil) {
        self.message = message
        self.line = line
        self.column = column
        self.stack = stack
    }
}

public struct ExecutionResult: Equatable, Sendable {
    public let outputText: String
    public let outputSelections: [TextRange]
    public let logs: [ExecutionLog]
    public let duration: TimeInterval
    public let diagnostic: ExecutionDiagnostic?

    public var succeeded: Bool { diagnostic == nil }

    public init(
        outputText: String,
        outputSelections: [TextRange] = [],
        logs: [ExecutionLog] = [],
        duration: TimeInterval = 0,
        diagnostic: ExecutionDiagnostic? = nil
    ) {
        self.outputText = outputText
        self.outputSelections = outputSelections
        self.logs = logs
        self.duration = duration
        self.diagnostic = diagnostic
    }
}

@MainActor
public struct RecipeRunner {
    public init() {}

    public func execute(_ request: ExecutionRequest, recipe: Recipe) -> ExecutionResult {
        let startedAt = ContinuousClock.now
        var logs: [ExecutionLog] = []
        do {
            guard request.text.utf8.count <= 5 * 1_024 * 1_024 else { throw RecipeError.inputTooLarge }
            let transformed = try transform(request: request, recipe: recipe, logs: &logs)
            return ExecutionResult(
                outputText: transformed.text,
                outputSelections: transformed.selections,
                logs: logs,
                duration: elapsedSeconds(since: startedAt)
            )
        } catch let failure as JavaScriptFailure {
            return ExecutionResult(
                outputText: request.text,
                logs: logs,
                duration: elapsedSeconds(since: startedAt),
                diagnostic: failure.diagnostic
            )
        } catch {
            return ExecutionResult(
                outputText: request.text,
                logs: logs,
                duration: elapsedSeconds(since: startedAt),
                diagnostic: ExecutionDiagnostic(message: error.localizedDescription)
            )
        }
    }

    private func elapsedSeconds(since start: ContinuousClock.Instant) -> TimeInterval {
        let duration = start.duration(to: .now)
        return TimeInterval(duration.components.seconds) + TimeInterval(duration.components.attoseconds) / 1e18
    }

    private func transform(
        request: ExecutionRequest,
        recipe: Recipe,
        logs: inout [ExecutionLog]
    ) throws -> (text: String, selections: [TextRange]) {
        guard !request.selections.isEmpty else {
            return (try run(recipe, input: request.text, request: request, logs: &logs), [])
        }

        let lines = splitLines(request.text)
        let ranges = try request.selections.map { selection in
            guard let range = offsetRange(selection, lines: lines) else {
                throw RecipeError.invalidSelection("\(selection.start.line + 1):\(selection.start.column)–\(selection.end.line + 1):\(selection.end.column)")
            }
            return (selection, range)
        }.sorted { $0.1.location < $1.1.location }

        for pair in zip(ranges, ranges.dropFirst()) where NSIntersectionRange(pair.0.1, pair.1.1).length > 0 {
            throw RecipeError.invalidSelection("Selections must not overlap.")
        }

        let mutable = NSMutableString(string: request.text)
        var delta = 0
        var outputOffsets: [NSRange] = []
        for (_, originalRange) in ranges {
            let adjusted = NSRange(location: originalRange.location + delta, length: originalRange.length)
            let input = mutable.substring(with: adjusted)
            let output = try run(recipe, input: input, request: request, logs: &logs)
            mutable.replaceCharacters(in: adjusted, with: output)
            let outputLength = (output as NSString).length
            outputOffsets.append(NSRange(location: adjusted.location, length: outputLength))
            delta += outputLength - adjusted.length
        }
        let outputText = mutable as String
        return (outputText, outputOffsets.compactMap { textRange(from: $0, text: outputText) })
    }

    private func run(_ recipe: Recipe, input: String, request: ExecutionRequest, logs: inout [ExecutionLog]) throws -> String {
        switch recipe.kind {
        case .builtin: return try runBuiltin(recipe.source, input: input)
        case .javascript: return try runJavaScript(recipe.source, input: input, request: request, logs: &logs)
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

    private func runJavaScript(
        _ source: String,
        input: String,
        request: ExecutionRequest,
        logs: inout [ExecutionLog]
    ) throws -> String {
        guard source.utf8.count <= 256 * 1_024 else { throw RecipeError.scriptTooLarge }
        guard let context = JSContext() else { throw RecipeError.javaScript("Could not create JavaScript context.") }
        var exception: JSValue?
        context.exceptionHandler = { _, value in exception = value }

        var capturedLogs: [ExecutionLog] = []
        let logBlock: @convention(block) (String, String) -> Void = { level, message in
            capturedLogs.append(ExecutionLog(level: ExecutionLog.Level(rawValue: level) ?? .log, message: message))
        }
        context.setObject(logBlock, forKeyedSubscript: "__jspowerLog" as NSString)
        context.setObject([
            "fileName": request.fileName,
            "fileType": request.fileType,
            "indentationWidth": request.indentationWidth,
        ], forKeyedSubscript: "environment" as NSString)
        context.evaluateScript(Self.consolePrelude)
        context.evaluateScript(source, withSourceURL: URL(string: "jspower://recipe.js"))
        if let exception {
            logs.append(contentsOf: capturedLogs)
            throw JavaScriptFailure(value: exception)
        }

        guard let function = context.objectForKeyedSubscript("transform"), !function.isUndefined else {
            throw RecipeError.javaScript("Missing transform(input) function.")
        }
        let value = function.call(withArguments: [input])
        logs.append(contentsOf: capturedLogs)
        if let exception { throw JavaScriptFailure(value: exception) }
        guard let value, value.isString, let result = value.toString() else { throw RecipeError.invalidResult }
        return result
    }

    private static let consolePrelude = """
    const console = {};
    for (const level of ['log', 'info', 'warn', 'error']) {
      console[level] = (...values) => __jspowerLog(level, values.map(value => {
        if (typeof value === 'string') return value;
        try { return JSON.stringify(value); } catch (_) { return String(value); }
      }).join(' '));
    }
    """

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

    private func textRange(from offset: NSRange, text: String) -> TextRange? {
        let lines = splitLines(text)
        func position(at location: Int) -> TextPosition? {
            var cursor = 0
            for (index, line) in lines.enumerated() {
                let length = (line as NSString).length
                if location <= cursor + length { return TextPosition(line: index, column: location - cursor) }
                cursor += length
            }
            let lastLineLength = ((lines.last ?? "") as NSString).length
            return location == cursor ? TextPosition(line: max(lines.count - 1, 0), column: lastLineLength) : nil
        }
        guard let start = position(at: offset.location), let end = position(at: offset.location + offset.length) else { return nil }
        return TextRange(start: start, end: end)
    }

    private func splitLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [""] }
        let expression = try! NSRegularExpression(pattern: ".*(?:\\r\\n|\\n|\\r)|.+$", options: [])
        let nsText = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { nsText.substring(with: $0.range) }
    }
}

private struct JavaScriptFailure: Error {
    let diagnostic: ExecutionDiagnostic

    init(value: JSValue) {
        let message = value.forProperty("message")?.toString() ?? value.toString() ?? "Unknown JavaScript error"
        let rawLine = value.forProperty("line")?.toInt32() ?? 0
        let rawColumn = value.forProperty("column")?.toInt32() ?? 0
        let line = rawLine > 0 ? Int(rawLine) : nil
        let column = rawColumn > 0 ? Int(rawColumn) : nil
        let stack = value.forProperty("stack")?.toString()
        diagnostic = ExecutionDiagnostic(message: message, line: line, column: column, stack: stack)
    }
}

public struct RecipeEngine: Sendable {
    public init() {}

    @MainActor
    public func run(_ recipe: Recipe, input: String) throws -> String {
        let result = RecipeRunner().execute(ExecutionRequest(text: input), recipe: recipe)
        if let diagnostic = result.diagnostic {
            switch diagnostic.message {
            case RecipeError.inputTooLarge.localizedDescription: throw RecipeError.inputTooLarge
            case RecipeError.scriptTooLarge.localizedDescription: throw RecipeError.scriptTooLarge
            case RecipeError.invalidResult.localizedDescription: throw RecipeError.invalidResult
            default: throw RecipeError.javaScript(diagnostic.message)
            }
        }
        return result.outputText
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

public struct TextBufferTransformer: Sendable {
    public init() {}

    @MainActor
    public func transform(lines: [String], ranges: [TextRange], recipe: Recipe) throws -> [String] {
        let result = RecipeRunner().execute(ExecutionRequest(text: lines.joined(), selections: ranges), recipe: recipe)
        if let diagnostic = result.diagnostic { throw RecipeError.javaScript(diagnostic.message) }
        return splitLines(result.outputText)
    }

    private func splitLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [""] }
        let expression = try! NSRegularExpression(pattern: ".*(?:\\r\\n|\\n|\\r)|.+$", options: [])
        let nsText = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { nsText.substring(with: $0.range) }
    }
}

public struct RecipeTestResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let passed: Bool
    public let execution: ExecutionResult
    public let expectedOutput: String
    public let expectedError: String?

    public init(testCase: RecipeTestCase, execution: ExecutionResult) {
        id = testCase.id
        name = testCase.name
        self.execution = execution
        expectedOutput = testCase.expectedOutput
        expectedError = testCase.expectedError
        if let expectedError = testCase.expectedError {
            passed = execution.diagnostic?.message.localizedCaseInsensitiveContains(expectedError) == true
        } else {
            passed = execution.diagnostic == nil && execution.outputText == testCase.expectedOutput
        }
    }
}

@MainActor
public struct RecipeTestRunner {
    public init() {}

    public func runAll(recipe: Recipe) -> [RecipeTestResult] {
        recipe.testCases.map { testCase in
            let execution = RecipeRunner().execute(
                ExecutionRequest(text: testCase.input, selections: testCase.selections),
                recipe: recipe
            )
            return RecipeTestResult(testCase: testCase, execution: execution)
        }
    }
}
