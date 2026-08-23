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

public struct ActionApplicability: Codable, Equatable, Hashable, Sendable {
    public var fileTypes: [String]
    public var requiresSelection: Bool

    public init(fileTypes: [String] = [], requiresSelection: Bool = false) {
        self.fileTypes = fileTypes
        self.requiresSelection = requiresSelection
    }

    public func accepts(_ request: ExecutionRequest) -> Bool {
        (!requiresSelection || !request.selections.isEmpty)
            && (fileTypes.isEmpty || fileTypes.contains(request.fileType))
    }
}

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case builtin, javascript, composed }
    public let id: String
    public var name: String
    public var summary: String
    public var kind: Kind
    public var source: String
    public var isEnabled: Bool
    public var version: Int
    public var applicability: ActionApplicability
    public var parameters: [String: String]
    public var testCases: [RecipeTestCase]
    public var category: String
    public var isFeatured: Bool
    public var isFavorite: Bool
    public var keyboardShortcut: String?
    public var componentIDs: [String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        summary: String,
        kind: Kind,
        source: String,
        isEnabled: Bool = true,
        version: Int = 1,
        applicability: ActionApplicability = .init(),
        parameters: [String: String] = [:],
        testCases: [RecipeTestCase] = [],
        category: String = "Custom Scripts",
        isFeatured: Bool = false,
        isFavorite: Bool = false,
        keyboardShortcut: String? = nil,
        componentIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.kind = kind
        self.source = source
        self.isEnabled = isEnabled
        self.version = version
        self.applicability = applicability
        self.parameters = parameters
        self.testCases = testCases
        self.category = category
        self.isFeatured = isFeatured
        self.isFavorite = isFavorite
        self.keyboardShortcut = keyboardShortcut
        self.componentIDs = componentIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, kind, source, isEnabled, version, applicability, parameters, testCases
        case category, isFeatured, isFavorite, keyboardShortcut, componentIDs
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        summary = try values.decode(String.self, forKey: .summary)
        kind = try values.decode(Kind.self, forKey: .kind)
        source = try values.decode(String.self, forKey: .source)
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        applicability = try values.decodeIfPresent(ActionApplicability.self, forKey: .applicability) ?? .init()
        parameters = try values.decodeIfPresent([String: String].self, forKey: .parameters) ?? [:]
        testCases = try values.decodeIfPresent([RecipeTestCase].self, forKey: .testCases) ?? []
        category = try values.decodeIfPresent(String.self, forKey: .category) ?? (kind == .javascript ? "Custom Scripts" : "Text")
        isFeatured = try values.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        keyboardShortcut = try values.decodeIfPresent(String.self, forKey: .keyboardShortcut)
        componentIDs = try values.decodeIfPresent([String].self, forKey: .componentIDs) ?? []
    }
}

public enum RecipeError: LocalizedError, Equatable {
    case inputTooLarge
    case scriptTooLarge
    case outputTooLarge
    case executionTimedOut
    case notApplicable
    case unknownBuiltin(String)
    case javaScript(String)
    case invalidResult
    case invalidSelection(String)

    public var errorDescription: String? {
        switch self {
        case .inputTooLarge: "Input is larger than the 5 MB safety limit."
        case .scriptTooLarge: "Recipe source is larger than the 256 KB safety limit."
        case .outputTooLarge: "Recipe output is larger than the 5 MB safety limit."
        case .executionTimedOut: "Recipe exceeded the 1 second execution limit."
        case .notApplicable: "This action is not available for the current file or selection."
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
            guard recipe.applicability.accepts(request) else { throw RecipeError.notApplicable }
            let transformed = try transform(request: request, recipe: recipe, logs: &logs)
            guard transformed.text.utf8.count <= 5 * 1_024 * 1_024 else { throw RecipeError.outputTooLarge }
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
        case .builtin: return try BuiltinTransformer.transform(input, recipe: recipe)
        case .javascript: return try runJavaScript(recipe.source, input: input, request: request, logs: &logs)
        case .composed:
            return try recipe.componentIDs.reduce(input) { value, identifier in
                guard let component = BuiltinRecipes.all.first(where: { $0.id == identifier }) else {
                    throw RecipeError.unknownBuiltin(identifier)
                }
                return try BuiltinTransformer.transform(value, recipe: component)
            }
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
        var didTimeOut = false
        return try withUnsafeMutablePointer(to: &didTimeOut) { timeoutFlag in
            let group = JSContextGetGroup(context.jsGlobalContextRef)
            JSContextGroupSetExecutionTimeLimit(group, 1, editSmithShouldTerminate, timeoutFlag)
            defer { JSContextGroupClearExecutionTimeLimit(group) }

            var exception: JSValue?
            context.exceptionHandler = { _, value in exception = value }

            var capturedLogs: [ExecutionLog] = []
            let logBlock: @convention(block) (String, String) -> Void = { level, message in
                capturedLogs.append(ExecutionLog(level: ExecutionLog.Level(rawValue: level) ?? .log, message: message))
            }
            let builtinBlock: @convention(block) (String, String, JSValue) -> String = { source, value, parametersValue in
                let parameters = parametersValue.toDictionary() as? [String: String] ?? [:]
                let builtin = Recipe(name: source, summary: "Script API", kind: .builtin, source: source, parameters: parameters)
                return (try? BuiltinTransformer.transform(value, recipe: builtin)) ?? value
            }
            context.setObject(logBlock, forKeyedSubscript: "__editSmithLog" as NSString)
            context.setObject(builtinBlock, forKeyedSubscript: "__editSmithRunBuiltin" as NSString)
            context.setObject([
                "fileName": request.fileName,
                "fileType": request.fileType,
                "indentationWidth": request.indentationWidth,
            ], forKeyedSubscript: "environment" as NSString)
            context.evaluateScript(Self.apiPrelude)
            context.evaluateScript(source, withSourceURL: URL(string: "editsmith://recipe.js"))
            if timeoutFlag.pointee { throw RecipeError.executionTimedOut }
            if let exception {
                logs.append(contentsOf: capturedLogs)
                throw JavaScriptFailure(value: exception)
            }

            guard let function = context.objectForKeyedSubscript("transform"), !function.isUndefined else {
                throw RecipeError.javaScript("Missing transform(input) function.")
            }
            let value = function.call(withArguments: [input])
            logs.append(contentsOf: capturedLogs)
            if timeoutFlag.pointee { throw RecipeError.executionTimedOut }
            if let exception { throw JavaScriptFailure(value: exception) }
            guard let value, value.isString, let result = value.toString() else { throw RecipeError.invalidResult }
            return result
        }
    }

    private static let apiPrelude = """
    const console = {};
    for (const level of ['log', 'info', 'warn', 'error']) {
      console[level] = (...values) => __editSmithLog(level, values.map(value => {
        if (typeof value === 'string') return value;
        try { return JSON.stringify(value); } catch (_) { return String(value); }
      }).join(' '));
    }
    const EditSmith = Object.freeze({
      runBuiltin: (identifier, input, parameters = {}) => __editSmithRunBuiltin(identifier, input, parameters)
    });
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

private typealias JSShouldTerminateCallback = @convention(c) (JSContextRef?, UnsafeMutableRawPointer?) -> Bool

@_silgen_name("JSContextGroupSetExecutionTimeLimit")
private func JSContextGroupSetExecutionTimeLimit(
    _ group: JSContextGroupRef?,
    _ limit: Double,
    _ callback: JSShouldTerminateCallback?,
    _ context: UnsafeMutableRawPointer?
)

@_silgen_name("JSContextGroupClearExecutionTimeLimit")
private func JSContextGroupClearExecutionTimeLimit(_ group: JSContextGroupRef?)

private func editSmithShouldTerminate(_: JSContextRef?, context: UnsafeMutableRawPointer?) -> Bool {
    context?.assumingMemoryBound(to: Bool.self).pointee = true
    return true
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

public enum RecipeTemplates {
    public static let javascript: [Recipe] = [
        .init(id: "template.wrap-main-actor", name: "Wrap in MainActor Task", summary: "Wrap selected Swift code in a MainActor task.", kind: .javascript, source: "function transform(input) { return 'Task { @MainActor in\\n' + input.split('\\n').map(line => '    ' + line).join('\\n') + '\\n}'; }", isEnabled: false, testCases: [.init(input: "updateUI()", expectedOutput: "Task { @MainActor in\n    updateUI()\n}")]),
        .init(id: "template.localize-literal", name: "Localize String Literal", summary: "Convert a selected Swift string literal to String(localized:).", kind: .javascript, source: "function transform(input) { return 'String(localized: ' + input.trim() + ')'; }", isEnabled: false, testCases: [.init(input: "\"Save\"", expectedOutput: "String(localized: \"Save\")")]),
        .init(id: "template.markdown-table", name: "CSV to Markdown Table", summary: "Turn comma-separated lines into a Markdown table.", kind: .javascript, source: "function transform(input) { const rows = input.trim().split(/\\r?\\n/).map(r => r.split(',').map(c => c.trim())); if (!rows.length) return input; return '| ' + rows[0].join(' | ') + ' |\\n| ' + rows[0].map(() => '---').join(' | ') + ' |\\n' + rows.slice(1).map(r => '| ' + r.join(' | ') + ' |').join('\\n'); }", isEnabled: false)
    ]
}

public struct ExtensionChangeSnapshot: Codable, Equatable, Sendable {
    public let date: Date; public let recipeName: String; public let before: String; public let after: String
    public init(date: Date = .now, recipeName: String, before: String, after: String) { self.date = date; self.recipeName = recipeName; self.before = before; self.after = after }
}

public struct ExtensionPreferences {
    private let defaults: UserDefaults
    private static let dryRunKey = "swift.extension.dryRun"
    private static let snapshotKey = "swift.extension.lastSnapshot"
    public init(defaults: UserDefaults? = UserDefaults(suiteName: RecipeStore.suiteName)) { self.defaults = defaults ?? .standard }
    public var dryRun: Bool { get { defaults.bool(forKey: Self.dryRunKey) } set { defaults.set(newValue, forKey: Self.dryRunKey) } }
    public var lastSnapshot: ExtensionChangeSnapshot? { get { defaults.data(forKey: Self.snapshotKey).flatMap { try? JSONDecoder().decode(ExtensionChangeSnapshot.self, from: $0) } } set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.snapshotKey) } }
}

public struct RecipeStore {
    public static let suiteName = "group.com.xnu.editsmith"
    private static let key = "swift.recipes.v2"
    private static let catalogVersionKey = "swift.capabilityCatalogVersion"
    private static let currentCatalogVersion = 3
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = UserDefaults(suiteName: Self.suiteName)) {
        self.defaults = defaults ?? .standard
    }

    public func load() -> [Recipe] {
        guard let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode([Recipe].self, from: data) else {
            defaults.set(Self.currentCatalogVersion, forKey: Self.catalogVersionKey)
            return BuiltinRecipes.all
        }
        let catalogIDs = Set(BuiltinRecipes.all.map(\.id))
        guard saved.contains(where: { catalogIDs.contains($0.id) }) else { return saved }
        let isUpgradingLegacyCatalog = defaults.integer(forKey: Self.catalogVersionKey) < Self.currentCatalogVersion
        let savedByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        let mergedBuiltins = BuiltinRecipes.all.map { catalogRecipe -> Recipe in
            guard let existing = savedByID[catalogRecipe.id] else { return catalogRecipe }
            var merged = catalogRecipe
            if !isUpgradingLegacyCatalog { merged.isEnabled = existing.isEnabled }
            merged.isFavorite = existing.isFavorite
            merged.keyboardShortcut = existing.keyboardShortcut
            merged.parameters.merge(existing.parameters) { _, savedValue in savedValue }
            return merged
        }
        let migrated = mergedBuiltins + saved.filter { $0.kind == .javascript && !catalogIDs.contains($0.id) }
        if isUpgradingLegacyCatalog {
            defaults.set(try? JSONEncoder().encode(migrated), forKey: Self.key)
        }
        defaults.set(Self.currentCatalogVersion, forKey: Self.catalogVersionKey)
        return migrated
    }

    public func save(_ recipes: [Recipe]) throws {
        defaults.set(try JSONEncoder().encode(recipes), forKey: Self.key)
        defaults.set(Self.currentCatalogVersion, forKey: Self.catalogVersionKey)
    }
}

public struct RecipeArchive: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public var formatVersion: Int
    public var recipes: [Recipe]

    public init(formatVersion: Int = Self.currentFormatVersion, recipes: [Recipe]) {
        self.formatVersion = formatVersion
        self.recipes = recipes
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> RecipeArchive {
        guard data.count <= 2 * 1_024 * 1_024 else { throw RecipeArchiveError.archiveTooLarge }
        let archive = try JSONDecoder().decode(RecipeArchive.self, from: data)
        guard archive.formatVersion == currentFormatVersion else {
            throw RecipeArchiveError.unsupportedFormat(archive.formatVersion)
        }
        guard !archive.recipes.isEmpty else { throw RecipeArchiveError.emptyArchive }
        guard archive.recipes.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RecipeArchiveError.invalidRecipeName
        }
        guard archive.recipes.allSatisfy({ $0.kind == .javascript && $0.source.utf8.count <= 256 * 1_024 }) else {
            throw RecipeArchiveError.unsafeRecipe
        }
        guard archive.recipes.allSatisfy({ ScriptSecurityValidator.isSafe($0.source) }) else {
            throw RecipeArchiveError.unsafeRecipe
        }
        return archive
    }
}

public enum RecipeArchiveError: LocalizedError, Equatable {
    case unsupportedFormat(Int)
    case emptyArchive
    case invalidRecipeName
    case archiveTooLarge
    case unsafeRecipe

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let version): "Unsupported EditSmith archive version: \(version)."
        case .emptyArchive: "The EditSmith archive does not contain any actions."
        case .invalidRecipeName: "Every imported action must have a name."
        case .archiveTooLarge: "The action archive is larger than the 2 MB import limit."
        case .unsafeRecipe: "The archive contains unsupported or unsafe script content."
        }
    }
}

public enum ScriptSecurityValidator {
    public static func isSafe(_ source: String) -> Bool {
        let forbidden = ["eval(", "Function(", "import(", "XMLHttpRequest", "fetch(", "WebSocket", "require(", "process.", "Deno."]
        return forbidden.allSatisfy { !source.localizedCaseInsensitiveContains($0) }
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
