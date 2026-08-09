import Foundation
import XCTest
@testable import SoCoKit

/// Port of upstream `tests/test_metadata_parsing.py`.
final class MetadataParsingTests: XCTestCase {
    private let mediaSources = ["bbc", "cifs", "pandora", "sonos_radio", "tunein", "tunein_2"]

    func testAllUpstreamMediaMetadataFixtures() throws {
        for source in mediaSources {
            let fixture = try loadFixture(source)
            let client = MockHTTPClient()
            client.enqueue(text: soapResponse(
                action: "GetPositionInfo",
                fields: fixture.input.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
            ))
            let soco = try SoCo("192.168.1.101", httpClient: client)

            XCTAssertEqual(
                try soco.currentTrackInfo(),
                fixture.result,
                "Metadata parsing mismatch for upstream fixture \(source).json"
            )
            XCTAssertEqual(client.requests.count, 1)
            XCTAssertTrue(requestBodyText(client.requests[0]).contains("<u:GetPositionInfo"))
            XCTAssertTrue(requestBodyText(client.requests[0]).contains("<Channel>Master</Channel>"))
        }
    }

    private func loadFixture(_ name: String) throws -> (input: [String: String], result: [String: String]) {
        let text = try fixtureText("media_metadata_payloads/\(name).json")
        let data = Data(text.utf8)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let input = json["input"] as? [String: String],
              let result = json["result"] as? [String: String]
        else {
            throw SoCoError.unknown("Invalid media metadata fixture: \(name).json")
        }
        return (input, result)
    }
}
