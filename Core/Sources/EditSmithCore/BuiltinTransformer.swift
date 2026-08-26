import CryptoKit
import Foundation

public enum BuiltinTransformer {
    public static func transform(_ input: String, recipe: Recipe) throws -> String {
        let lines = input.components(separatedBy: .newlines)
        switch recipe.source {
        case "trim": return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case "trim-lines": return lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        case "remove-empty-lines": return lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
        case "collapse-blank-lines": return regex(input, #"(?:\r?\n)[ \t]*(?:\r?\n)+"#, "\n\n")
        case "collapse-whitespace": return regex(input, #"\s+"#, " ").trimmingCharacters(in: .whitespacesAndNewlines)
        case "sort-lines": return lines.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n")
        case "reverse-lines": return lines.reversed().joined(separator: "\n")
        case "shuffle-lines": return lines.shuffled().joined(separator: "\n")
        case "remove-duplicate-lines":
            return lines.reduce(into: (Set<String>(), [String]())) { result, line in
                if result.0.insert(line).inserted { result.1.append(line) }
            }.1.joined(separator: "\n")
        case "add-line-numbers": return lines.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case "remove-line-numbers": return lines.map { regex($0, #"^\s*\d+[.):\-]?\s*"#, "") }.joined(separator: "\n")
        case "prefix-lines": return lines.map { (recipe.parameters["prefix"] ?? "") + $0 }.joined(separator: "\n")
        case "suffix-lines": return lines.map { $0 + (recipe.parameters["suffix"] ?? "") }.joined(separator: "\n")
        case "join-lines": return lines.joined(separator: recipe.parameters["separator"] ?? ", ")
        case "split-delimiter": return input.components(separatedBy: recipe.parameters["delimiter"] ?? ",").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")

        case "uppercase": return input.uppercased()
        case "lowercase": return input.lowercased()
        case "title-case": return input.capitalized
        case "sentence-case": return sentenceCase(input)
        case "camel-case": return identifier(input, style: "camel")
        case "pascal-case": return identifier(input, style: "pascal")
        case "snake-case": return identifier(input, style: "snake")
        case "screaming-snake": return identifier(input, style: "snake").uppercased()
        case "kebab-case": return identifier(input, style: "kebab")
        case "dot-case": return identifier(input, style: "dot")
        case "identifier-style": return identifier(input, style: recipe.parameters["style"] ?? "camel")

        case "pretty-json", "sort-json-keys": return try jsonString(input, pretty: true)
        case "minify-json": return try jsonString(input, pretty: false)
        case "validate-json":
            _ = try JSONSerialization.jsonObject(with: Data(input.utf8)); return "Valid JSON"
        case "escape-json-string":
            let data = try JSONEncoder().encode(input); return String(decoding: data, as: UTF8.self)
        case "json-to-yaml": return yaml(try json(input))
        case "json-to-csv": return try table(input, markdown: false)
        case "json-to-markdown": return try table(input, markdown: true)
        case "json-to-swift": return try typeDefinition(input, language: "swift")
        case "json-to-typescript": return try typeDefinition(input, language: "typescript")
        case "json-to-kotlin": return try typeDefinition(input, language: "kotlin")
        case "json-path": return try jsonPath(input, path: recipe.parameters["path"] ?? "")

        case "url-encode": return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=?+#"))) ?? input
        case "url-decode": return input.removingPercentEncoding ?? input
        case "base64-encode": return Data(input.utf8).base64EncodedString()
        case "base64-decode": return Data(base64Encoded: input).map { String(decoding: $0, as: UTF8.self) } ?? input
        case "html-escape": return input.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
        case "html-unescape": return input.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&amp;", with: "&")
        case "unicode-escape": return input.unicodeScalars.map { $0.isASCII ? String($0) : String(format: "\\u%04X", $0.value) }.joined()
        case "unicode-unescape": return decodeUnicodeEscapes(input)
        case "hex-encode": return input.utf8.map { String(format: "%02x", $0) }.joined()
        case "hex-decode": return String(decoding: stride(from: 0, to: input.count - input.count % 2, by: 2).compactMap { index in UInt8(input.substring(index, length: 2), radix: 16) }, as: UTF8.self)

        case "sql-format": return sqlFormat(input)
        case "sql-minify": return regex(input, #"\s+"#, " ").trimmingCharacters(in: .whitespacesAndNewlines)
        case "format-xml": return xmlFormat(input)
        case "format-yaml": return lines.map { $0.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }.joined(separator: "\n")
        case "format-markdown": return regex(regex(input, #"(?m)^#{1,6}(?=\S)"#, "$0 "), #"\n{3,}"#, "\n\n").replacingOccurrences(of: "\n* ", with: "\n- ")
        case "uuid": return UUID().uuidString
        case "sha256": return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
        case "regex-extract": return try matches(input, pattern: recipe.parameters["pattern"] ?? "").joined(separator: "\n")
        case "regex-replace": return try replacing(input, pattern: recipe.parameters["pattern"] ?? "", replacement: recipe.parameters["replacement"] ?? "")
        case "strip-comments": return regex(regex(input, #"(?s)/\*.*?\*/"#, ""), #"(?m)//.*$"#, "")
        case "tabs-spaces": return input.replacingOccurrences(of: "\t", with: String(repeating: " ", count: Int(recipe.parameters["width"] ?? "4") ?? 4))
        case "normalize-endings": return input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        case "toggle-line-comment":
            return lines.map { line in
                let indentation = line.prefix { $0 == " " || $0 == "\t" }
                let content = line.dropFirst(indentation.count)
                return content.hasPrefix("//")
                    ? indentation + content.dropFirst(2).drop(while: { $0 == " " })
                    : indentation + "// " + content
            }.joined(separator: "\n")
        case "wrap-selection": return (recipe.parameters["prefix"] ?? "") + input + (recipe.parameters["suffix"] ?? "")

        case "extract-urls": return try matches(input, pattern: #"https?://[^\s<>)\]]+"#).joined(separator: "\n")
        case "extract-emails": return try matches(input, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive]).joined(separator: "\n")
        case "extract-ips": return try matches(input, pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#).joined(separator: "\n")
        case "extract-numbers": return try matches(input, pattern: #"[-+]?\b\d+(?:\.\d+)?\b"#).joined(separator: "\n")
        case "extract-hashtags": return try matches(input, pattern: #"(?<!\w)#[\p{L}\p{N}_]+"#).joined(separator: "\n")
        case "extract-markdown-links": return try capture(input, pattern: #"\[[^\]]+\]\(([^)]+)\)"#, group: 1).joined(separator: "\n")
        case "strip-html": return regex(input, #"<[^>]+>"#, "")
        case "strip-markdown": return regex(regex(input, #"\[([^\]]+)\]\([^)]+\)"#, "$1"), #"(?m)^(?:#{1,6}\s*|[-*+]\s+)|[*_~`]"#, "")

        case "redact-emails": return try replacing(input, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, replacement: "[REDACTED EMAIL]", options: [.caseInsensitive])
        case "redact-phones": return try replacing(input, pattern: #"(?<!\w)\+?[\d() .-]{8,}\d"#, replacement: "[REDACTED PHONE]")
        case "redact-tokens": return try replacing(input, pattern: #"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*[^\s,;]+"#, replacement: "$1=[REDACTED]")
        case "redact-sensitive":
            let email = try transform(input, recipe: derived(recipe, source: "redact-emails"))
            let phone = try transform(email, recipe: derived(recipe, source: "redact-phones"))
            return try transform(phone, recipe: derived(recipe, source: "redact-tokens"))

        case "unix-timestamp":
            guard let seconds = TimeInterval(input.trimmingCharacters(in: .whitespacesAndNewlines)) else { return input }
            return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: seconds))
        case "iso-date":
            guard let date = ISO8601DateFormatter().date(from: input.trimmingCharacters(in: .whitespacesAndNewlines)) else { return input }
            return ISO8601DateFormatter().string(from: date)
        case "csv-column": return csvColumn(input, index: Int(recipe.parameters["column"] ?? "0") ?? 0)
        case "csv-sort": return csvSort(input, index: Int(recipe.parameters["column"] ?? "0") ?? 0)
        case "markdown-checklist": return lines.map { "- [ ] " + $0 }.joined(separator: "\n")
        case "json-array": return String(decoding: try JSONEncoder().encode(lines), as: UTF8.self)
        case "word-stats":
            let words = input.split { $0.isWhitespace }.count
            return "Lines: \(lines.count)\nWords: \(words)\nCharacters: \(input.count)\nBytes: \(input.utf8.count)"

        case "leet-speak": return leetspeak(input)
        case "rot13": return rot13(input)
        case "fullwidth-text": return unicodeStyle(input, uppercase: 0xFF21, lowercase: 0xFF41, digits: 0xFF10, space: 0x3000)
        case "circled-text": return circled(input)
        case "monospace-unicode": return unicodeStyle(input, uppercase: 0x1D670, lowercase: 0x1D68A, digits: 0x1D7F6)
        case "bold-unicode": return unicodeStyle(input, uppercase: 0x1D400, lowercase: 0x1D41A, digits: 0x1D7CE)
        case "italic-unicode": return unicodeStyle(input, uppercase: 0x1D434, lowercase: 0x1D44E)
        case "small-caps": return smallCaps(input)
        case "upside-down": return upsideDown(input)
        case "reverse-characters": return lines.map { String($0.reversed()) }.joined(separator: "\n")
        case "zalgo": return zalgo(input, intensity: Int(recipe.parameters["intensity"] ?? "2") ?? 2)
        case "binary-text": return input.utf8.map { byte in
            let bits = String(byte, radix: 2)
            return String(repeating: "0", count: 8 - bits.count) + bits
        }.joined(separator: " ")
        case "morse-code": return morse(input)
        case "ascii-box": return asciiBox(input)
        case "ascii-banner": return asciiBanner(input)
        default: throw RecipeError.unknownBuiltin(recipe.source)
        }
    }

    private static func unicodeStyle(_ input: String, uppercase: UInt32, lowercase: UInt32, digits: UInt32? = nil, space: UInt32? = nil) -> String {
        input.unicodeScalars.map { scalar in
            let value = scalar.value
            if (65...90).contains(value), let mapped = UnicodeScalar(uppercase + value - 65) { return String(mapped) }
            if (97...122).contains(value), let mapped = UnicodeScalar(lowercase + value - 97) { return String(mapped) }
            if let digits, (48...57).contains(value), let mapped = UnicodeScalar(digits + value - 48) { return String(mapped) }
            if let space, value == 32, let mapped = UnicodeScalar(space) { return String(mapped) }
            return String(scalar)
        }.joined()
    }

    private static func circled(_ input: String) -> String {
        input.unicodeScalars.map { scalar in
            let value = scalar.value
            if (65...90).contains(value), let mapped = UnicodeScalar(0x24B6 + value - 65) { return String(mapped) }
            if (97...122).contains(value), let mapped = UnicodeScalar(0x24D0 + value - 97) { return String(mapped) }
            if value == 48 { return "⓪" }
            if (49...57).contains(value), let mapped = UnicodeScalar(0x2460 + value - 49) { return String(mapped) }
            return String(scalar)
        }.joined()
    }

    private static func leetspeak(_ input: String) -> String {
        let map: [Character: String] = ["a": "4", "b": "8", "e": "3", "g": "6", "i": "1", "l": "1", "o": "0", "s": "5", "t": "7", "z": "2"]
        return input.map { map[Character($0.lowercased())] ?? String($0) }.joined()
    }

    private static func rot13(_ input: String) -> String {
        input.unicodeScalars.map { scalar in
            let value = scalar.value
            if (65...90).contains(value) { return String(UnicodeScalar(65 + (value - 65 + 13) % 26)!) }
            if (97...122).contains(value) { return String(UnicodeScalar(97 + (value - 97 + 13) % 26)!) }
            return String(scalar)
        }.joined()
    }

    private static func smallCaps(_ input: String) -> String {
        let map = Dictionary(uniqueKeysWithValues: zip(Array("abcdefghijklmnopqrstuvwxyz"), Array("ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀꜱᴛᴜᴠᴡxʏᴢ")))
        return input.lowercased().map { map[$0].map(String.init) ?? String($0) }.joined()
    }

    private static func upsideDown(_ input: String) -> String {
        let normal = Array("abcdefghijklmnopqrstuvwxyz0123456789!?.,")
        let flipped = Array("ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz0ƖᄅƐㄣϛ9ㄥ86¡¿˙'")
        let map = Dictionary(uniqueKeysWithValues: zip(normal, flipped))
        return input.lowercased().reversed().map { map[$0].map(String.init) ?? String($0) }.joined()
    }

    private static func zalgo(_ input: String, intensity: Int) -> String {
        let marks = ["\u{0301}", "\u{0308}", "\u{0336}"]
        let count = min(3, max(1, intensity))
        return input.map { $0.isWhitespace ? String($0) : String($0) + marks.prefix(count).joined() }.joined()
    }

    private static func morse(_ input: String) -> String {
        let keys = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let values = [".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....", "..", ".---", "-.-", ".-..", "--", "-.", "---", ".--.", "--.-", ".-.", "...", "-", "..-", "...-", ".--", "-..-", "-.--", "--..", "-----", ".----", "..---", "...--", "....-", ".....", "-....", "--...", "---..", "----."]
        let map = Dictionary(uniqueKeysWithValues: zip(keys, values))
        return input.uppercased().map { $0 == " " ? "/" : map[$0] ?? String($0) }.joined(separator: " ")
    }

    private static func asciiBox(_ input: String) -> String {
        let lines = input.components(separatedBy: .newlines)
        let width = lines.map(\.count).max() ?? 0
        let border = "+" + String(repeating: "-", count: width + 2) + "+"
        return ([border] + lines.map { "| \($0.padding(toLength: width, withPad: " ", startingAt: 0)) |" } + [border]).joined(separator: "\n")
    }

    private static func asciiBanner(_ input: String) -> String {
        let patterns: [Character: String] = [
            "A":"0111010001111111000110001", "B":"1111010001111101000111110", "C":"0111110000100001000001111",
            "D":"1111010001100011000111110", "E":"1111110000111101000011111", "F":"1111110000111101000010000",
            "G":"0111110000101111000101111", "H":"1000110001111111000110001", "I":"1111100100001000010011111",
            "J":"0011100010000101001001100", "K":"1000110010111001001010001", "L":"1000010000100001000011111",
            "M":"1000111011101011000110001", "N":"1000111001101011001110001", "O":"0111010001100011000101110",
            "P":"1111010001111101000010000", "Q":"0111010001101011001001101", "R":"1111010001111101001010001",
            "S":"0111110000011100000111110", "T":"1111100100001000010000100", "U":"1000110001100011000101110",
            "V":"1000110001100010101000100", "W":"1000110001101011101110001", "X":"1000101010001000101010001",
            "Y":"1000101010001000010000100", "Z":"1111100010001000100011111", " ":"0000000000000000000000000"
        ]
        let characters = Array(input.uppercased().prefix(24))
        return (0..<5).map { row in
            characters.map { character in
                let pattern = patterns[character] ?? "0000000000000000000000000"
                let start = pattern.index(pattern.startIndex, offsetBy: row * 5)
                let end = pattern.index(start, offsetBy: 5)
                return pattern[start..<end].map { $0 == "1" ? "█" : " " }.joined()
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    private static func regex(_ input: String, _ pattern: String, _ replacement: String) -> String {
        (try? replacing(input, pattern: pattern, replacement: replacement)) ?? input
    }

    private static func replacing(_ input: String, pattern: String, replacement: String, options: NSRegularExpression.Options = []) throws -> String {
        let expression = try NSRegularExpression(pattern: pattern, options: options)
        return expression.stringByReplacingMatches(in: input, range: NSRange(input.startIndex..., in: input), withTemplate: replacement)
    }

    private static func matches(_ input: String, pattern: String, options: NSRegularExpression.Options = []) throws -> [String] {
        try capture(input, pattern: pattern, group: 0, options: options)
    }

    private static func capture(_ input: String, pattern: String, group: Int, options: NSRegularExpression.Options = []) throws -> [String] {
        let expression = try NSRegularExpression(pattern: pattern, options: options)
        let ns = input as NSString
        return expression.matches(in: input, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard group < match.numberOfRanges, match.range(at: group).location != NSNotFound else { return nil }
            return ns.substring(with: match.range(at: group))
        }
    }

    private static func identifier(_ input: String, style: String) -> String {
        let expanded = regex(input, #"([a-z0-9])([A-Z])"#, "$1 $2")
        let words = expanded.split { !$0.isLetter && !$0.isNumber }.map { $0.lowercased() }
        guard let first = words.first else { return "" }
        switch style.lowercased() {
        case "pascal": return words.map(\.capitalized).joined()
        case "snake": return words.joined(separator: "_")
        case "kebab": return words.joined(separator: "-")
        case "dot": return words.joined(separator: ".")
        default: return first + words.dropFirst().map(\.capitalized).joined()
        }
    }

    private static func sentenceCase(_ input: String) -> String {
        var capitalize = true
        return String(input.lowercased().map { character in
            defer { if ".!?".contains(character) { capitalize = true } else if !character.isWhitespace { capitalize = false } }
            return capitalize && character.isLetter ? Character(character.uppercased()) : character
        })
    }

    private static func json(_ input: String) throws -> Any { try JSONSerialization.jsonObject(with: Data(input.utf8)) }

    private static func jsonString(_ input: String, pretty: Bool) throws -> String {
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed]
        if pretty { options.insert(.prettyPrinted) }
        return String(decoding: try JSONSerialization.data(withJSONObject: json(input), options: options), as: UTF8.self)
    }

    private static func yaml(_ value: Any, indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().map { key in
                let child = dictionary[key]!
                return child is [String: Any] || child is [Any] ? "\(pad)\(key):\n\(yaml(child, indent: indent + 1))" : "\(pad)\(key): \(scalar(child))"
            }.joined(separator: "\n")
        }
        if let array = value as? [Any] { return array.map { "\(pad)- \(scalar($0))" }.joined(separator: "\n") }
        return pad + scalar(value)
    }

    private static func scalar(_ value: Any) -> String {
        if let string = value as? String { return string }
        if value is NSNull { return "null" }
        return String(describing: value)
    }

    private static func table(_ input: String, markdown: Bool) throws -> String {
        guard let rows = try json(input) as? [[String: Any]], let first = rows.first else { return input }
        let keys = first.keys.sorted()
        let values = rows.map { row in keys.map { scalar(row[$0] ?? "") } }
        if markdown {
            return "| \(keys.joined(separator: " | ")) |\n| \(keys.map { _ in "---" }.joined(separator: " | ")) |\n" + values.map { "| \($0.joined(separator: " | ")) |" }.joined(separator: "\n")
        }
        return ([keys] + values).map { $0.map(csvEscape).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        value.contains(where: { ",\"\n".contains($0) }) ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" : value
    }

    private static func typeDefinition(_ input: String, language: String) throws -> String {
        guard let object = try json(input) as? [String: Any] else { return input }
        let fields = object.keys.sorted().map { key -> String in
            let value = object[key]!
            let type: String
            switch value { case is Bool: type = language == "typescript" ? "boolean" : "Bool"; case is NSNumber: type = language == "typescript" ? "number" : (language == "kotlin" ? "Double" : "Double"); default: type = "String" }
            if language == "swift" { return "    let \(key): \(type)" }
            if language == "kotlin" { return "    val \(key): \(type)" }
            return "  \(key): \(type);"
        }.joined(separator: language == "kotlin" ? ",\n" : "\n")
        switch language {
        case "swift": return "struct Root: Codable {\n\(fields)\n}"
        case "kotlin": return "data class Root(\n\(fields)\n)"
        default: return "interface Root {\n\(fields)\n}"
        }
    }

    private static func jsonPath(_ input: String, path: String) throws -> String {
        var value: Any = try json(input)
        for component in path.split(separator: ".") {
            if let dictionary = value as? [String: Any], let next = dictionary[String(component)] { value = next }
            else if let array = value as? [Any], let index = Int(component), array.indices.contains(index) { value = array[index] }
            else { return "" }
        }
        if JSONSerialization.isValidJSONObject(value) { return String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self) }
        return scalar(value)
    }

    private static func decodeUnicodeEscapes(_ input: String) -> String {
        let pattern = try! NSRegularExpression(pattern: #"\\u\{?([0-9A-Fa-f]{4,8})\}?"#)
        let mutable = NSMutableString(string: input)
        for match in pattern.matches(in: input, range: NSRange(location: 0, length: (input as NSString).length)).reversed() {
            let hex = (input as NSString).substring(with: match.range(at: 1))
            if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) { mutable.replaceCharacters(in: match.range, with: String(scalar)) }
        }
        return mutable as String
    }

    private static func sqlFormat(_ input: String) -> String {
        let keywords = ["select", "from", "where", "group by", "order by", "having", "limit", "join", "left join", "right join", "inner join", "union", "values", "set"]
        var result = regex(input, #"\s+"#, " ").trimmingCharacters(in: .whitespacesAndNewlines)
        for keyword in keywords {
            result = regex(result, "(?i)\\s*\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b\\s*", "\n\(keyword.uppercased()) ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func xmlFormat(_ input: String) -> String {
        let tokens = regex(input, #">\s*<"#, ">\n<").components(separatedBy: "\n")
        var depth = 0
        return tokens.map { token in
            if token.hasPrefix("</") { depth = max(0, depth - 1) }
            let output = String(repeating: "  ", count: depth) + token
            if token.hasPrefix("<"), !token.hasPrefix("</"), !token.hasPrefix("<?"), !token.hasSuffix("/>") && !token.contains("</") { depth += 1 }
            return output
        }.joined(separator: "\n")
    }

    private static func csvColumn(_ input: String, index: Int) -> String {
        input.components(separatedBy: .newlines).compactMap { row in
            let columns = row.split(separator: ",", omittingEmptySubsequences: false)
            return columns.indices.contains(index) ? String(columns[index]).trimmingCharacters(in: .whitespaces) : nil
        }.joined(separator: "\n")
    }

    private static func csvSort(_ input: String, index: Int) -> String {
        var rows = input.components(separatedBy: .newlines)
        guard let header = rows.first else { return input }
        rows.removeFirst()
        rows.sort { lhs, rhs in
            let left = lhs.split(separator: ",", omittingEmptySubsequences: false)
            let right = rhs.split(separator: ",", omittingEmptySubsequences: false)
            guard left.indices.contains(index), right.indices.contains(index) else { return lhs < rhs }
            return left[index].localizedStandardCompare(right[index]) == .orderedAscending
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func derived(_ recipe: Recipe, source: String) -> Recipe {
        var copy = recipe; copy.source = source; return copy
    }
}

private extension String {
    func substring(_ start: Int, length: Int) -> String {
        let startIndex = index(self.startIndex, offsetBy: start)
        return String(self[startIndex..<index(startIndex, offsetBy: length)])
    }
}
