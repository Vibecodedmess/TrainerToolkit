import Foundation

/// Any JSON value. Used for loosely structured fields (like ScrapedDuck's `extraData`)
/// and to skip over array elements that fail to decode.
public enum JSONValue: Decodable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self { return dict[key] }
        return nil
    }
}

/// Decodes a JSON array, skipping elements that don't match `Element` instead of failing.
/// `failures` counts the skipped elements so validation can spot a changed format.
public struct LossyArray<Element: Decodable>: Decodable {
    public var elements: [Element] = []
    public var failures = 0

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                failures += 1
                _ = try container.decode(JSONValue.self) // step past the bad element
            }
        }
    }
}
