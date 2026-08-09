import XCTest
@testable import SoCoKit

final class XMLTests: XCTestCase {
    func testNamespaceTag() {
        XCTAssertEqual(XMLNamespace.tag("dc", "testtag"), "{http://purl.org/dc/elements/1.1/}testtag")
        XCTAssertEqual(XMLNamespace.tag("upnp", "testtag"), "{urn:schemas-upnp-org:metadata-1-0/upnp/}testtag")
        XCTAssertEqual(XMLNamespace.tag("", "testtag"), "{urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/}testtag")
    }

    func testSanitizeXMLDropsInvalidControlCharacters() throws {
        let bad = "<root>hello\u{0001}world</root>"
        let tree = try XMLTree(bad)
        XCTAssertEqual(tree.root?.text, "helloworld")
    }
}
