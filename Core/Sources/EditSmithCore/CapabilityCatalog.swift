import Foundation

public enum CapabilityCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case text = "Text"
    case naming = "Naming"
    case data = "JSON & Data"
    case encoding = "Encoding"
    case developer = "Developer"
    case extract = "Extract"
    case privacy = "Privacy"
    case timeAndLists = "Time & Lists"

    public var id: Self { self }
}

public struct CapabilityOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let defaultValue: String

    public init(_ id: String, title: String, defaultValue: String) {
        self.id = id
        self.title = title
        self.defaultValue = defaultValue
    }
}

public struct CapabilityExample: Identifiable, Hashable, Sendable {
    public let id: String
    public let input: String
    public let output: String

    public init(input: String, output: String) {
        id = input + "\u{0}" + output
        self.input = input
        self.output = output
    }
}

public struct CapabilityDescriptor: Identifiable, Hashable, Sendable {
    public let recipe: Recipe
    public let systemImage: String
    public let tags: [String]
    public let options: [CapabilityOption]
    public let examples: [CapabilityExample]

    public var id: String { recipe.id }
}

public enum BuiltinRecipes {
    public static let descriptors: [CapabilityDescriptor] = [
        // Text (15)
        make("trim", "Trim Text", "Remove whitespace around the text.", .text, defaultOn: true, featured: false, sample: "  hello  "),
        make("trim-lines", "Trim Each Line", "Remove whitespace around every line.", .text, defaultOn: true, sample: "  alpha  \n beta "),
        make("remove-empty-lines", "Remove Empty Lines", "Remove lines containing no visible text.", .text, sample: "alpha\n\n beta"),
        make("collapse-blank-lines", "Collapse Blank Lines", "Keep at most one blank line between paragraphs.", .text, sample: "a\n\n\n\nb"),
        make("collapse-whitespace", "Collapse Whitespace", "Replace repeated whitespace with one space.", .text, sample: "one   two\nthree"),
        make("sort-lines", "Sort Lines", "Sort lines in ascending order.", .text, defaultOn: true, sample: "zeta\nalpha"),
        make("reverse-lines", "Reverse Lines", "Reverse the order of lines.", .text, sample: "one\ntwo"),
        make("shuffle-lines", "Shuffle Lines", "Randomize line order.", .text, sample: "one\ntwo\nthree"),
        make("remove-duplicate-lines", "Remove Duplicate Lines", "Keep the first occurrence of each line.", .text, defaultOn: true, sample: "a\nb\na"),
        make("add-line-numbers", "Add Line Numbers", "Prefix every line with its number.", .text, sample: "alpha\nbeta"),
        make("remove-line-numbers", "Remove Line Numbers", "Remove common numeric line prefixes.", .text, sample: "1. alpha\n2. beta"),
        make("prefix-lines", "Prefix Each Line", "Add configurable text before every line.", .text, options: [.init("prefix", title: "Prefix", defaultValue: "- ")], sample: "alpha\nbeta"),
        make("suffix-lines", "Suffix Each Line", "Add configurable text after every line.", .text, options: [.init("suffix", title: "Suffix", defaultValue: ";")], sample: "alpha\nbeta"),
        make("join-lines", "Join Lines", "Join lines with a configurable separator.", .text, options: [.init("separator", title: "Separator", defaultValue: ", ")], sample: "alpha\nbeta"),
        make("split-delimiter", "Split by Delimiter", "Split text into one value per line.", .text, options: [.init("delimiter", title: "Delimiter", defaultValue: ",")], sample: "alpha,beta"),

        // Naming (11)
        make("uppercase", "Uppercase", "Convert text to uppercase.", .naming, sample: "Hello world"),
        make("lowercase", "Lowercase", "Convert text to lowercase.", .naming, sample: "Hello WORLD"),
        make("title-case", "Title Case", "Capitalize the first letter of every word.", .naming, sample: "hello from editsmith"),
        make("sentence-case", "Sentence Case", "Capitalize the beginning of each sentence.", .naming, sample: "hello. welcome home."),
        make("camel-case", "camelCase", "Convert words to a camel-case identifier.", .naming, sample: "hello world"),
        make("pascal-case", "PascalCase", "Convert words to a Pascal-case identifier.", .naming, sample: "hello world"),
        make("snake-case", "snake_case", "Convert words to a snake-case identifier.", .naming, sample: "Hello world"),
        make("screaming-snake", "SCREAMING_SNAKE_CASE", "Convert words to an uppercase snake identifier.", .naming, sample: "Hello world"),
        make("kebab-case", "kebab-case", "Convert words to a kebab-case identifier.", .naming, sample: "Hello world"),
        make("dot-case", "dot.case", "Convert words to a dot-separated identifier.", .naming, sample: "Hello world"),
        make("identifier-style", "Convert Identifier Style", "Convert any identifier to a chosen style.", .naming, options: [.init("style", title: "Target Style", defaultValue: "camel")], sample: "hello_world"),

        // JSON & Data (12)
        make("pretty-json", "Format JSON", "Pretty-print JSON with stable key ordering.", .data, defaultOn: true, featured: true, sample: "{\"b\":2,\"a\":1}"),
        make("minify-json", "Minify JSON", "Remove insignificant JSON whitespace.", .data, defaultOn: true, sample: "{ \"a\": 1 }"),
        make("sort-json-keys", "Sort JSON Keys", "Recursively sort object keys.", .data, sample: "{\"z\":0,\"a\":1}"),
        make("validate-json", "Validate JSON", "Return a validation summary for JSON input.", .data, sample: "{\"valid\":true}"),
        make("escape-json-string", "Escape JSON String", "Encode text as a JSON string literal.", .data, sample: "hello\nworld"),
        make("json-to-yaml", "JSON to YAML", "Convert common JSON objects and arrays to YAML.", .data, sample: "{\"name\":\"EditSmith\",\"enabled\":true}"),
        make("json-to-csv", "JSON to CSV", "Convert an array of JSON objects to CSV.", .data, sample: "[{\"name\":\"A\",\"score\":1}]"),
        make("json-to-markdown", "JSON to Markdown Table", "Convert an array of objects to a Markdown table.", .data, featured: true, sample: "[{\"name\":\"A\",\"score\":1}]"),
        make("json-to-swift", "JSON to Swift Codable", "Generate a Swift Codable structure from JSON.", .data, featured: true, sample: "{\"name\":\"EditSmith\",\"count\":3}"),
        make("json-to-typescript", "JSON to TypeScript", "Generate a TypeScript interface from JSON.", .data, featured: true, sample: "{\"name\":\"EditSmith\",\"count\":3}"),
        make("json-to-kotlin", "JSON to Kotlin Data Class", "Generate a Kotlin data class from JSON.", .data, sample: "{\"name\":\"EditSmith\",\"count\":3}"),
        make("json-path", "JSON Path Extractor", "Extract a value using a dot-separated path.", .data, options: [.init("path", title: "Path", defaultValue: "user.name")], sample: "{\"user\":{\"name\":\"Ada\"}}"),

        // Encoding (10)
        make("url-encode", "URL Encode", "Percent-encode text for a URL component.", .encoding, defaultOn: true, sample: "hello world?"),
        make("url-decode", "URL Decode", "Decode URL percent escapes.", .encoding, sample: "hello%20world%3F"),
        make("base64-encode", "Base64 Encode", "Encode UTF-8 text as Base64.", .encoding, defaultOn: true, sample: "EditSmith"),
        make("base64-decode", "Base64 Decode", "Decode Base64 into UTF-8 text.", .encoding, sample: "RWRpdFNtaXRo"),
        make("html-escape", "HTML Escape", "Escape HTML-sensitive characters.", .encoding, sample: "<p>Me & you</p>"),
        make("html-unescape", "HTML Unescape", "Decode common HTML entities.", .encoding, sample: "&lt;p&gt;Me &amp; you&lt;/p&gt;"),
        make("unicode-escape", "Unicode Escape", "Convert non-ASCII scalars to Unicode escapes.", .encoding, sample: "Hello 世界"),
        make("unicode-unescape", "Unicode Unescape", "Decode Unicode escape sequences.", .encoding, sample: "Hello \\u4E16\\u754C"),
        make("hex-encode", "Hex Encode", "Encode UTF-8 bytes as hexadecimal.", .encoding, sample: "Edit"),
        make("hex-decode", "Hex Decode", "Decode hexadecimal UTF-8 bytes.", .encoding, sample: "45646974"),

        // Developer (12)
        make("sql-format", "SQL Formatter", "Format common SQL clauses and indentation.", .developer, defaultOn: true, featured: true, sample: "select id,name from users where active=1 order by name"),
        make("sql-minify", "SQL Minifier", "Collapse SQL whitespace into a compact statement.", .developer, sample: "SELECT id, name\nFROM users\nWHERE active = 1"),
        make("format-xml", "Format XML", "Indent XML elements for readability.", .developer, sample: "<root><item>1</item></root>"),
        make("format-yaml", "Normalize YAML", "Normalize YAML whitespace and trailing spaces.", .developer, sample: "name:   EditSmith  \nenabled: true"),
        make("format-markdown", "Format Markdown", "Normalize headings, lists, and blank lines.", .developer, sample: "#Title\n\n\n* item"),
        make("uuid", "Generate UUID", "Replace the selection with a new UUID.", .developer, sample: ""),
        make("sha256", "Generate SHA-256", "Generate a SHA-256 digest of the text.", .developer, sample: "EditSmith"),
        make("regex-extract", "Regex Match Extractor", "Return every regular-expression match.", .developer, featured: true, options: [.init("pattern", title: "Pattern", defaultValue: #"\w+@\w+\.\w+"#)], sample: "Mail a@example.com or b@example.com"),
        make("regex-replace", "Regex Replace", "Apply a configured regular-expression replacement.", .developer, options: [.init("pattern", title: "Pattern", defaultValue: #"(?m)\s+$"#), .init("replacement", title: "Replacement", defaultValue: "")], sample: "hello   "),
        make("strip-comments", "Strip Code Comments", "Remove common line and block comments.", .developer, sample: "let a = 1 // note\n/* block */\nlet b = 2"),
        make("tabs-spaces", "Convert Tabs and Spaces", "Convert tabs to the configured number of spaces.", .developer, options: [.init("width", title: "Tab Width", defaultValue: "4")], sample: "\tlet value = 1"),
        make("normalize-endings", "Normalize Line Endings", "Convert CRLF and CR endings to LF.", .developer, defaultOn: true, sample: "one\r\ntwo\rthree"),
        make("toggle-line-comment", "Toggle Line Comments", "Add or remove Swift-style line comments.", .developer, sample: "value"),
        make("wrap-selection", "Wrap Selection", "Wrap text with configurable prefix and suffix.", .developer, options: [.init("prefix", title: "Prefix", defaultValue: "("), .init("suffix", title: "Suffix", defaultValue: ")")], sample: "value"),

        // Extract (8)
        make("extract-urls", "Extract URLs", "Return web URLs found in the text.", .extract, featured: true, sample: "Visit https://example.com and https://openai.com"),
        make("extract-emails", "Extract Email Addresses", "Return email addresses found in the text.", .extract, sample: "Mail a@example.com and b@example.com"),
        make("extract-ips", "Extract IP Addresses", "Return IPv4 addresses found in the text.", .extract, sample: "Local 127.0.0.1, remote 8.8.8.8"),
        make("extract-numbers", "Extract Numbers", "Return numeric values found in the text.", .extract, sample: "There are 12 items at 3.5 each"),
        make("extract-hashtags", "Extract Hashtags", "Return hashtags found in the text.", .extract, sample: "Build with #Swift and #Xcode"),
        make("extract-markdown-links", "Extract Markdown Links", "Return destinations from Markdown links.", .extract, sample: "[OpenAI](https://openai.com)"),
        make("strip-html", "Strip HTML Tags", "Remove HTML tags while preserving text.", .extract, sample: "<p>Hello <strong>world</strong></p>"),
        make("strip-markdown", "Strip Markdown Formatting", "Remove common Markdown markers.", .extract, sample: "# Hello **world** [site](https://example.com)"),

        // Privacy (4)
        make("redact-emails", "Redact Email Addresses", "Replace email addresses with a placeholder.", .privacy, sample: "Contact ada@example.com"),
        make("redact-phones", "Redact Phone Numbers", "Replace likely phone numbers with a placeholder.", .privacy, sample: "Call +1 415 555 0123"),
        make("redact-tokens", "Redact API Keys and Tokens", "Replace likely credentials with a placeholder.", .privacy, sample: "api_key=sk-example123456789"),
        make("redact-sensitive", "Redact Sensitive Data", "Redact emails, phones, and likely secrets.", .privacy, featured: true, sample: "ada@example.com +1 415 555 0123 api_key=secret123456"),

        // Time & Lists (8)
        make("unix-timestamp", "Convert Unix Timestamp", "Convert seconds since 1970 to an ISO date.", .timeAndLists, featured: true, sample: "0"),
        make("iso-date", "Normalize ISO 8601 Date", "Normalize an ISO date to UTC.", .timeAndLists, sample: "2024-01-01T10:30:00+02:00"),
        make("csv-column", "CSV Column Extractor", "Extract a zero-based CSV column.", .timeAndLists, options: [.init("column", title: "Column", defaultValue: "0")], sample: "name,score\nAda,10"),
        make("csv-sort", "CSV Column Sorter", "Sort CSV rows by a zero-based column.", .timeAndLists, options: [.init("column", title: "Column", defaultValue: "0")], sample: "name,score\nZoe,8\nAda,10"),
        make("markdown-checklist", "List to Markdown Checklist", "Turn lines into Markdown tasks.", .timeAndLists, sample: "Design\nBuild"),
        make("json-array", "List to JSON Array", "Convert lines to a JSON string array.", .timeAndLists, sample: "alpha\nbeta"),
        make("word-stats", "Word and Character Statistics", "Report line, word, character, and byte counts.", .timeAndLists, sample: "Hello EditSmith"),
        composed("clean-and-sort", "Clean and Sort Lines", "Trim, remove blanks and duplicates, then sort.", [.init("builtin.trim-lines"), .init("builtin.remove-empty-lines"), .init("builtin.remove-duplicate-lines"), .init("builtin.sort-lines")])
    ]

    public static let all = descriptors.map(\.recipe)
    public static let featured = descriptors.filter { $0.recipe.isFeatured }
    public static let defaultEnabledIDs = Set(all.filter(\.isEnabled).map(\.id))

    public static func descriptor(for id: String) -> CapabilityDescriptor? {
        descriptors.first { $0.id == id }
    }

    public static func scriptSource(for recipe: Recipe) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: recipe.parameters, options: [.sortedKeys])) ?? Data("{}".utf8)
        let parameters = String(decoding: data, as: UTF8.self)
        return """
        // Copied from EditSmith's \(recipe.name) built-in. Customize and add tests before enabling.
        function transform(input) {
          const parameters = \(parameters);
          return EditSmith.runBuiltin("\(recipe.source)", input, parameters);
        }
        """
    }

    private static func make(
        _ source: String,
        _ name: String,
        _ summary: String,
        _ category: CapabilityCategory,
        defaultOn: Bool = false,
        featured: Bool = false,
        options: [CapabilityOption] = [],
        sample: String
    ) -> CapabilityDescriptor {
        let parameters = Dictionary(uniqueKeysWithValues: options.map { ($0.id, $0.defaultValue) })
        var recipe = Recipe(
            id: "builtin.\(source)", name: name, summary: summary, kind: .builtin, source: source,
            isEnabled: defaultOn, parameters: parameters, category: category.rawValue, isFeatured: featured
        )
        let output = (try? BuiltinTransformer.transform(sample, recipe: recipe)) ?? sample
        if source != "uuid" && source != "shuffle-lines" {
            recipe.testCases = [.init(name: "Built-in example", input: sample, expectedOutput: output)]
        }
        return CapabilityDescriptor(recipe: recipe, systemImage: icon(for: category), tags: [category.rawValue, name, source], options: options, examples: [.init(input: sample, output: output)])
    }

    private static func composed(_ source: String, _ name: String, _ summary: String, _ ids: [Recipe.ID]) -> CapabilityDescriptor {
        let recipe = Recipe(id: "builtin.\(source)", name: name, summary: summary, kind: .composed, source: source, isEnabled: false, testCases: [.init(input: " b \n\na\nb ", expectedOutput: "a\nb")], category: CapabilityCategory.text.rawValue, isFeatured: true, componentIDs: ids)
        return CapabilityDescriptor(recipe: recipe, systemImage: "square.stack.3d.up", tags: ["compose", "pipeline", "clean"], options: [], examples: [.init(input: " b \n\na\nb ", output: "a\nb")])
    }

    private static func icon(for category: CapabilityCategory) -> String {
        switch category {
        case .text: "text.alignleft"
        case .naming: "character.cursor.ibeam"
        case .data: "curlybraces.square"
        case .encoding: "lock.open.display"
        case .developer: "hammer"
        case .extract: "text.magnifyingglass"
        case .privacy: "hand.raised"
        case .timeAndLists: "list.bullet.rectangle"
        }
    }
}
