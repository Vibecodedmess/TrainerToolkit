import Foundation

/// A parsed CSV file: header names plus rows of raw string values.
public struct CSVTable: Sendable, Equatable {
    public let headers: [String]
    public let rows: [[String]]
    public let delimiter: Character

    /// Column index by header name (case- and space-insensitive), or nil.
    public func column(_ name: String) -> Int? {
        let wanted = CSVReader.normalizeHeader(name)
        return headers.firstIndex { CSVReader.normalizeHeader($0) == wanted }
    }

    /// Value of `column` in `row`, trimmed; nil when missing or empty.
    public func value(_ row: [String], _ column: Int?) -> String? {
        guard let column, column < row.count else { return nil }
        let value = row[column].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

public enum CSVError: Error, Equatable, LocalizedError {
    case empty
    case unreadableEncoding

    public var errorDescription: String? {
        switch self {
        case .empty: return "The file is empty."
        case .unreadableEncoding: return "The file isn't readable text (expected UTF-8 or UTF-16)."
        }
    }
}

/// RFC 4180-style CSV reader. Column-agnostic: handles quoting, escaped quotes, line breaks inside
/// quotes, CRLF/LF, a UTF-8 byte-order mark, and comma, semicolon or tab delimiters (auto-detected).
public enum CSVReader {
    public static func read(_ data: Data) throws -> CSVTable {
        guard let text = decode(data) else { throw CSVError.unreadableEncoding }
        return try read(text)
    }

    public static func read(_ text: String) throws -> CSVTable {
        var content = text
        if content.hasPrefix("\u{FEFF}") { content.removeFirst() }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CSVError.empty }
        let delimiter = detectDelimiter(content)
        var records = parse(content, delimiter: delimiter)
        // Drop fully empty lines (common at the end of exports).
        records.removeAll { $0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard let header = records.first else { throw CSVError.empty }
        return CSVTable(headers: header.map { $0.trimmingCharacters(in: .whitespaces) },
                        rows: Array(records.dropFirst()), delimiter: delimiter)
    }

    static func decode(_ data: Data) -> String? {
        // UTF-16 first: its bytes can also pass as (NUL-filled) UTF-8.
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        return String(data: data, encoding: .windowsCP1252)
    }

    /// Picks whichever of , ; or tab occurs most often (outside quotes) in the header line.
    static func detectDelimiter(_ text: String) -> Character {
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0]
        var inQuotes = false
        for char in text {
            if char == "\"" { inQuotes.toggle(); continue }
            // Note: Swift treats "\r\n" as one Character.
            if !inQuotes && (char == "\n" || char == "\r" || char == "\r\n") { break }
            if !inQuotes, counts[char] != nil { counts[char, default: 0] += 1 }
        }
        let best = counts.max { a, b in a.value < b.value || (a.value == b.value && rank(a.key) > rank(b.key)) }
        return (best?.value ?? 0) > 0 ? best!.key : ","
    }

    private static func rank(_ c: Character) -> Int {
        switch c {
        case ",": return 0
        case ";": return 1
        default: return 2
        }
    }

    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text)
        chars.append("\n") // flush the last record
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == "\"" && field.isEmpty {
                inQuotes = true
            } else if c == delimiter {
                record.append(field)
                field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                record.append(field)
                records.append(record)
                record = []
                field = ""
            } else {
                field.append(c)
            }
            i += 1
        }
        // The appended "\n" can leave a trailing empty record when the file already ended with a newline.
        if let last = records.last, last == [""] { records.removeLast() }
        return records
    }

    static func normalizeHeader(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Parses numbers written as "12", "12.5" or "12,5" (decimal comma, common in semicolon CSVs).
    public static func number(_ text: String?) -> Double? {
        guard var t = text?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        t = t.replacingOccurrences(of: "%", with: "")
        if t.contains(",") && !t.contains(".") { t = t.replacingOccurrences(of: ",", with: ".") }
        return Double(t)
    }
}
