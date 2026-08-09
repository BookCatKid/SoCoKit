import XCTest
@testable import SoCoKit

final class UtilitiesTests: XCTestCase {
    func testCamelToUnderscore() {
        XCTAssertEqual(camelToUnderscore("CamelCase"), "camel_case")
        XCTAssertEqual(camelToUnderscore("HTTPRequest"), "http_request")
        XCTAssertEqual(camelToUnderscore("already_lower"), "already_lower")
        XCTAssertEqual(camelToUnderscore("AVTransportURI"), "av_transport_uri")
    }

    func testURLPathEscapingEscapesSlash() {
        XCTAssertEqual(
            urlEscapePath("Foo, bar & baz / the hackers"),
            "Foo%2C%20bar%20%26%20baz%20%2F%20the%20hackers"
        )
    }

    func testFirstCap() {
        XCTAssertEqual(firstCap("hello"), "Hello")
        XCTAssertEqual(firstCap(""), "")
    }

    func testReallyUnicodeAndUTF8() throws {
        let value = "μИⅠℂ☺ΔЄ💋"
        XCTAssertEqual(reallyUnicode(value), value)
        XCTAssertEqual(try reallyUnicode(reallyUTF8(value)), value)
    }

    func testTimeFormattingRoundTrip() {
        XCTAssertEqual(parseTimeInterval("01:02:03"), 3723)
        XCTAssertEqual(formatTimeInterval(3723), "01:02:03")
        XCTAssertNil(parseTimeInterval(nil))
        XCTAssertNil(parseTimeInterval("bad"))
    }
}
