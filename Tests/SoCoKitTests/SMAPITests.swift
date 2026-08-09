import XCTest
@testable import SoCoKit

private final class FakeMusicServiceProvider: MusicServiceProviding {
    let serviceName = "Fake"
    let serviceID = 9
    let serviceType = 2311
    let desc = "DESC"
    var requestedIDs: [String] = []
    func sonosURIFromID(_ itemID: String) -> String { "soco://\(smapiQuote(itemID))?sid=9&sn=0" }
}

final class SMAPITests: XCTestCase {
    func testClassFactoryReturnsExpectedStableTypes() throws {
        XCTAssertTrue(try SMAPI.itemClass(for: "MediaMetadataTrack") == SMAPI.MSTrack.self)
        XCTAssertTrue(try SMAPI.itemClass(for: "MediaCollectionArtist") == SMAPI.MSArtist.self)
        XCTAssertThrowsError(try SMAPI.itemClass(for: "Nonsense"))
    }

    func testBoolStringStrictConversion() throws {
        XCTAssertEqual(try smapiBool("true"), true)
        XCTAssertEqual(try smapiBool("false"), false)
        XCTAssertThrowsError(try smapiBool("dummy"))
    }

    func testMetadataNormalizesNamesAndConvertsTypes() throws {
        let track = try SMAPI.TrackMetadata(metadataDictionary: [
            "artistId": "artist/1", "duration": "464", "canPlay": "true", "trackNumber": "1"
        ])
        XCTAssertEqual(track["artist_id"], .string("artist/1"))
        XCTAssertEqual(track["duration"], .int(464))
        XCTAssertEqual(track["can_play"], .bool(true))
        XCTAssertEqual(track["track_number"], .int(1))
        XCTAssertNil(track["does_not_exist"])
    }

    func testFormURINonTrackAndTrack() {
        let service = FakeMusicServiceProvider()
        XCTAssertEqual(smapiFormURI(itemID: "dummy_id", service: service, isTrack: false), "x-rincon-cpcontainer:dummy_id")
        XCTAssertEqual(smapiFormURI(itemID: "dummy_id", service: service, isTrack: true), "soco://dummy_id?sid=9&sn=0")
    }

    func testParseCollectionResponse() throws {
        let response: [String: Any] = [
            "searchResult": [
                "index": "0", "count": "2", "total": "17230",
                "mediaCollection": [
                    ["id": "album/43820695", "itemType": "album", "title": "Black Mosque", "canPlay": "true"],
                    ["id": "album/50340580", "itemType": "album", "title": "Black Hippy 2", "canPlay": "true"]
                ]
            ]
        ]
        let service = FakeMusicServiceProvider()
        let result = try SMAPI.parseResponse(service: service, response: response, searchType: "albums")
        XCTAssertEqual(result.numberReturned, 2)
        XCTAssertEqual(result.searchType, "albums")
        XCTAssertEqual(result.items.count, 2)
        XCTAssertTrue(result.items.allSatisfy { $0 is SMAPI.MSAlbum })
        XCTAssertTrue(result.items.allSatisfy { $0.musicService === service })
    }

    func testParseSingleMetadataDictionaryIssue988() throws {
        let response: [String: Any] = [
            "searchResult": [
                "index": "0", "count": "1", "total": "1",
                "mediaMetadata": [
                    "id": "track/amazon123", "title": "Single Result Track", "itemType": "track", "mimeType": "audio/mp4",
                    "trackMetadata": ["duration": "300", "canPlay": "true", "trackNumber": "1"]
                ]
            ]
        ]
        let service = FakeMusicServiceProvider()
        let result = try SMAPI.parseResponse(service: service, response: response, searchType: "albums")
        XCTAssertEqual(result.items.count, 1)
        let item = try XCTUnwrap(result.items.first as? SMAPI.MSTrack)
        XCTAssertEqual(item.title, "Single Result Track")
        XCTAssertEqual(item.itemID, "0ffffffftrack/amazon123")
        XCTAssertTrue(item.musicService === service)
        XCTAssertEqual(item["track_metadata"]?.dictionaryValue?["duration"], .int(300))
    }

    func testParseBadResponseShape() {
        XCTAssertThrowsError(try SMAPI.parseResponse(service: FakeMusicServiceProvider(), response: [:], searchType: "albums"))
    }

    func testMusicServiceItemToElementMatchesUpstreamPublicAPI() throws {
        let service = FakeMusicServiceProvider()
        let item = try SMAPI.MSTrack.fromMusicService(service, contentDictionary: [
            "id": "track:1", "itemType": "track", "title": "T"
        ])
        let element = try item.toElement(includeNamespaces: true)
        XCTAssertEqual(element.localNameSafe, "item")
        XCTAssertEqual(element.attribute("id"), item.itemID)
        XCTAssertEqual(element.descendants(named: "title").first?.text, "DUMMY")
        XCTAssertEqual(element.descendants(named: "class").first?.text, "object.item")
        XCTAssertEqual(element.descendants(named: "desc").first?.text, "DESC")
    }

    func testFromMusicServiceQuotesUnicodeAndProducesDIDL() throws {
        let service = FakeMusicServiceProvider()
        let item = try SMAPI.MSTrack.fromMusicService(service, contentDictionary: [
            "id": "spotify:träck 1", "itemType": "track", "title": "T"
        ])
        XCTAssertEqual(item.itemID, "0fffffffspotify%3Atr%C3%A4ck%201")
        XCTAssertEqual(item.uri, "soco://0fffffffspotify%253Atr%25C3%25A4ck%25201?sid=9&sn=0")
        let xml = try item.didlXML(includeNamespaces: true)
        XCTAssertTrue(xml.contains("id=\"0fffffffspotify%3Atr%C3%A4ck%201\""))
        XCTAssertTrue(xml.contains("<desc"))
        XCTAssertTrue(xml.contains("DESC"))
    }
}
