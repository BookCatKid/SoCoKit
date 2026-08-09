import Foundation

/// Make a string Unicode. Really.
///
/// Python SoCo needed progressively relaxed byte decoding for Python 2/3 compatibility.
/// Swift strings are already Unicode, so the direct String overload is intentionally a no-op.
public func reallyUnicode(_ string: String) -> String { string }

/// Decode bytes in the same spirit as SoCo's `really_unicode` helper.
/// UTF-8 is preferred; ISO-8859-1 is the compatibility fallback used by the Python code.
public func reallyUnicode(_ data: Data) throws -> String {
    if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
    if let latin1 = String(data: data, encoding: .isoLatin1) { return latin1 }
    return String(decoding: data, as: UTF8.self)
}

/// Encode a string as UTF-8, mirroring SoCo's `really_utf8` helper.
public func reallyUTF8(_ string: String) -> Data { Data(string.utf8) }

/// Convert camelcase to lowercase and underscore.
///
/// Recipe in the original project came from http://stackoverflow.com/a/1176023.
public func camelToUnderscore(_ value: String) -> String {
    guard !value.isEmpty else { return value }
    var result = ""
    let chars = Array(value)
    for index in chars.indices {
        let current = chars[index]
        if current.isUppercase, index > 0 {
            let previous = chars[index - 1]
            let nextIsLower = index + 1 < chars.count && chars[index + 1].isLowercase
            if previous.isLowercase || previous.isNumber || nextIsLower {
                result.append("_")
            }
        }
        result.append(contentsOf: current.lowercased())
    }
    return result
}

/// Return a pretty-printed version of an XML string. Useful for debugging.
public func prettify(_ xml: String) throws -> String {
    let root = try XMLTree(xml).root
    guard let root else { return xml }

    func render(_ element: SoCoXMLElement, depth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        let name = element.name ?? ""
        let attributes = (element.attributes ?? []).map(\.xmlString)
        let attributeText = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")
        let children = (element.children ?? []).compactMap { $0 as? SoCoXMLElement }
        let text = element.text
        if children.isEmpty {
            return "\(indent)<\(name)\(attributeText)>\(xmlEscape(text))</\(name)>"
        }
        var lines = ["\(indent)<\(name)\(attributeText)>"]
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("\(String(repeating: "  ", count: depth + 1))\(xmlEscape(text))")
        }
        lines.append(contentsOf: children.map { render($0, depth: depth + 1) })
        lines.append("\(indent)</\(name)>")
        return lines.joined(separator: "\n")
    }
    return render(root, depth: 0)
}

/// Escape a string value for a URL request path.
///
/// The original SoCo helper intentionally percent-escapes `/` as `%2F`, unlike
/// `CharacterSet.urlPathAllowed`, because the supplied value is a *path component*,
/// not a complete path.
public func urlEscapePath(_ path: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
}

/// Return an upper-cased first character.
public func firstCap(_ value: String) -> String {
    guard let first = value.first else { return value }
    return first.uppercased() + value.dropFirst()
}

/// Escape text for element content / attribute values in the minimal SOAP and DIDL
/// writers. This matches the escaping behavior used by the Python implementation.
public func xmlEscape(_ value: Any) -> String {
    let string = String(describing: value)
    return string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

/// Parse the UPnP `HH:MM:SS` time representation used throughout Sonos APIs.
public func parseTimeInterval(_ hhmmss: String?) -> TimeInterval? {
    guard let hhmmss, !hhmmss.isEmpty else { return nil }
    let parts = hhmmss.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 3,
          let hours = Double(parts[0]),
          let minutes = Double(parts[1]),
          let seconds = Double(parts[2]) else { return nil }
    return hours * 3600 + minutes * 60 + seconds
}

/// Format a duration using Sonos' `HH:MM:SS` representation.
public func formatTimeInterval(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.towardZero)))
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

public extension Dictionary where Key == String, Value == String {
    func int(_ key: String, default defaultValue: Int = 0) -> Int {
        Int(self[key] ?? "") ?? defaultValue
    }

    func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        guard let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return defaultValue
        }
        switch value {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return defaultValue
        }
    }
}

/// Pretty-print XML to standard output.
///
/// Like SoCo's `show_xml`, this exists only as a development convenience and
/// is not used by the library itself.
public func showXML(_ xml: String) throws {
    print(try prettify(xml))
}
