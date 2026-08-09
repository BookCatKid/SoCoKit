import Foundation
#if canImport(FoundationXML)
import FoundationXML // XMLParser lives here in swift-corelibs-foundation (Linux).
#endif

public enum XMLNamespace {
    public static let namespaces: [String: String] = [
        "dc": "http://purl.org/dc/elements/1.1/",
        "upnp": "urn:schemas-upnp-org:metadata-1-0/upnp/",
        "": "urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/",
        "ms": "http://www.sonos.com/Services/1.1",
        "r": "urn:schemas-rinconnetworks-com:metadata-1-0/"
    ]
    public static func tag(_ namespace: String, _ tag: String) -> String {
        guard let uri = namespaces[namespace] else { return tag }
        return "{\(uri)}\(tag)"
    }
}

public func sanitizeXML(_ string: String) -> String {
    String(string.unicodeScalars.filter { scalar in
        let v = scalar.value
        if v == 0x9 || v == 0xA || v == 0xD { return true }
        if v >= 0x20 && v <= 0xD7FF { return true }
        if v >= 0xE000 && v <= 0xFFFD { return true }
        return v >= 0x10000 && v <= 0x10FFFF && (v & 0xFFFF) != 0xFFFE && (v & 0xFFFF) != 0xFFFF
    })
}


/// Best-effort recovery for the malformed *bare attributes* occasionally emitted
/// inside Sonos DIDL metadata.
///
/// Python SoCo intentionally parses DIDL with lxml's `recover=True`. A real
/// example captured from a Sonos line-in event contains `<res x-rincon-stream>`,
/// where `x-rincon-stream` is neither an XML attribute nor valid element text.
/// lxml recovers by discarding that token. Foundation's `XMLParser` is strict,
/// so on Apple platforms we perform the same narrow recovery before retrying.
/// We deliberately do not make every XML parse forgiving: SOAP/SCPD/event
/// envelopes remain strict, while DIDL opts in just as upstream SoCo does.
internal func recoverMalformedBareAttributes(_ xml: String) -> String {
    let pattern = #"\s+[A-Za-z_:][A-Za-z0-9_.:-]*(?=(?:\s+[A-Za-z_:][A-Za-z0-9_.:-]*\s*=|\s*/?>))"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return xml }
    var recovered = xml
    // A tag can contain more than one malformed token. Re-run until stable,
    // matching lxml's tendency to continue after each recoverable syntax error.
    for _ in 0..<16 {
        let range = NSRange(recovered.startIndex..<recovered.endIndex, in: recovered)
        let next = regex.stringByReplacingMatches(in: recovered, range: range, withTemplate: "")
        if next == recovered { break }
        recovered = next
    }
    return recovered
}

// MARK: - Portable XML DOM

/// A deliberately small XML node used internally and publicly by SoCoKit.
///
/// Python SoCo relies on ElementTree, while the first Swift port used
/// `Foundation.XMLDocument`/`XMLElement`. Those DOM classes are not available on
/// iOS, so SoCoKit owns this tiny DOM and builds it with `XMLParser`, which is
/// available on both iOS and macOS (and through FoundationXML on Linux).
///
/// The API intentionally mirrors only the subset of Foundation's XML node API
/// which SoCo actually needs. That keeps all Sonos XML handling portable without
/// adding a third-party dependency to applications embedding SoCoKit.
open class SoCoXMLNode: CustomStringConvertible {
    public enum Kind { case element, attribute }

    public let kind: Kind
    public var name: String?
    public var stringValue: String?
    public var children: [SoCoXMLNode]?

    public var localName: String? {
        guard let name else { return nil }
        return name.split(separator: ":").last.map(String.init) ?? name
    }

    internal init(kind: Kind, name: String?, stringValue: String? = nil) {
        self.kind = kind
        self.name = name
        self.stringValue = stringValue
        self.children = kind == .element ? [] : nil
    }

    public static func attribute(withName name: String, stringValue: String?) -> SoCoXMLNode {
        SoCoXMLNode(kind: .attribute, name: name, stringValue: stringValue)
    }

    open var xmlString: String {
        switch kind {
        case .attribute:
            return "\(name ?? "")=\"\(xmlEscape(stringValue ?? ""))\""
        case .element:
            return stringValue.map(xmlEscape) ?? ""
        }
    }

    public var localNameSafe: String {
        if let localName, !localName.isEmpty { return localName }
        return name ?? ""
    }

    public var text: String { stringValue ?? "" }

    public func firstChild(named local: String) -> SoCoXMLElement? {
        children?.compactMap { $0 as? SoCoXMLElement }.first { $0.localNameSafe == local }
    }

    public func descendants(named local: String) -> [SoCoXMLElement] {
        var output: [SoCoXMLElement] = []
        func walk(_ node: SoCoXMLNode) {
            for child in node.children ?? [] {
                if let element = child as? SoCoXMLElement, element.localNameSafe == local {
                    output.append(element)
                }
                walk(child)
            }
        }
        walk(self)
        return output
    }

    public func attribute(_ name: String) -> String? {
        guard let element = self as? SoCoXMLElement else { return nil }
        return element.attributes?.first { attribute in
            attribute.localName == name || attribute.name == name
        }?.stringValue
    }

    public var description: String { xmlString }
}

/// Element node in SoCoKit's portable XML tree.
public final class SoCoXMLElement: SoCoXMLNode {
    public var attributes: [SoCoXMLNode]?

    public init(name: String, stringValue: String? = nil) {
        self.attributes = []
        super.init(kind: .element, name: name, stringValue: stringValue)
    }

    public func addAttribute(_ attribute: SoCoXMLNode) {
        guard attribute.kind == .attribute else { return }
        if let existing = attributes?.firstIndex(where: { $0.name == attribute.name }) {
            attributes?[existing] = attribute
        } else {
            if attributes == nil { attributes = [] }
            attributes?.append(attribute)
        }
    }

    public func addChild(_ child: SoCoXMLNode) {
        if children == nil { children = [] }
        children?.append(child)
    }

    public override var xmlString: String {
        let elementName = name ?? ""
        let renderedAttributes = (attributes ?? []).map(\.xmlString).filter { !$0.isEmpty }
        let attributeText = renderedAttributes.isEmpty ? "" : " " + renderedAttributes.joined(separator: " ")
        let childXML = (children ?? []).map(\.xmlString).joined()
        let ownText = stringValue.map(xmlEscape) ?? ""
        if childXML.isEmpty && ownText.isEmpty {
            return "<\(elementName)\(attributeText)></\(elementName)>"
        }
        return "<\(elementName)\(attributeText)>\(ownText)\(childXML)</\(elementName)>"
    }
}

/// Document wrapper retained so `XMLTree.document` remains a useful public API.
public final class SoCoXMLDocument {
    private let rootNode: SoCoXMLElement?
    internal init(root: SoCoXMLElement?) { self.rootNode = root }
    public func rootElement() -> SoCoXMLElement? { rootNode }
    public var xmlString: String { rootNode?.xmlString ?? "" }
}

private final class SoCoXMLParserDelegate: NSObject, XMLParserDelegate {
    private(set) var root: SoCoXMLElement?
    private var stack: [SoCoXMLElement] = []
    private(set) var parseError: Error?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Namespace processing is disabled so prefixes are retained verbatim.
        // Sonos parsing compares local names, while serialization needs the
        // original prefix spelling for SOAP/DIDL payloads.
        let element = SoCoXMLElement(name: qName ?? elementName)
        for (name, value) in attributeDict {
            element.addAttribute(.attribute(withName: name, stringValue: value))
        }
        if let parent = stack.last { parent.addChild(element) }
        else { root = element }
        stack.append(element)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let current = stack.last else { return }
        current.stringValue = (current.stringValue ?? "") + string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8), let current = stack.last else { return }
        current.stringValue = (current.stringValue ?? "") + string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        _ = stack.popLast()
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

private func parsePortableXML(_ xml: String) throws -> SoCoXMLElement {
    let delegate = SoCoXMLParserDelegate()
    let parser = XMLParser(data: Data(xml.utf8))
    parser.delegate = delegate
    parser.shouldProcessNamespaces = false
    parser.shouldReportNamespacePrefixes = false
    parser.shouldResolveExternalEntities = false
    guard parser.parse(), let root = delegate.root else {
        let error = delegate.parseError ?? parser.parserError
        throw SoCoError.xml("Invalid XML: \(error?.localizedDescription ?? "unknown parser error")")
    }
    return root
}

public final class XMLTree {
    public let document: SoCoXMLDocument

    /// Parse XML into SoCoKit's portable tree.
    ///
    /// - Parameter recoverMalformedAttributes: If true, retry after removing
    ///   malformed bare attributes. This is intended for DIDL only and mirrors
    ///   Python SoCo's use of lxml `XMLParser(recover=True)` there.
    public init(_ xml: String, recoverMalformedAttributes: Bool = false) throws {
        guard !xml.isEmpty else { throw SoCoError.xml("Invalid XML: empty document") }

        var candidates = [xml]
        let sanitized = sanitizeXML(xml)
        if sanitized != xml { candidates.append(sanitized) }
        if recoverMalformedAttributes {
            let recovered = recoverMalformedBareAttributes(sanitized)
            if !candidates.contains(recovered) { candidates.append(recovered) }
        }

        var lastError: Error = SoCoError.xml("Invalid XML")
        for candidate in candidates {
            do {
                document = SoCoXMLDocument(root: try parsePortableXML(candidate))
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    public var root: SoCoXMLElement? { document.rootElement() }
}

/// Form a namespace-qualified tag in the same `{namespace}tag` notation used
/// by Python's ElementTree helpers.
public func nsTag(_ namespace: String, _ tag: String) -> String {
    XMLNamespace.tag(namespace, tag)
}
