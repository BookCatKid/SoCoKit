import XCTest
#if canImport(FoundationXML)
import FoundationXML
#endif
@testable import SoCoKit

final class FakeLegacyMusicService: LegacyMusicServiceProviding {
    let musicServiceDescription = "SA_RINCON5127_4542255535"
    let legacyServiceID = 20

    func idToExtendedID(_ itemID: String, itemClass: LegacyMusicServiceItem.Type) -> String? {
        let prefix: String?
        switch itemClass {
        case is MSTrack.Type: prefix = "00030020"
        case is MSAlbum.Type: prefix = "0004002c"
        case is MSArtist.Type: prefix = "10050024"
        case is MSAlbumList.Type: prefix = "000d006c"
        case is MSPlaylist.Type: prefix = "0006006c"
        case is MSArtistTracklist.Type: prefix = "100f006c"
        default: prefix = nil
        }
        return prefix.map { $0 + itemID }
    }

    func formURI(_ itemContent: [String: Any], itemClass: LegacyMusicServiceItem.Type) -> String? {
        if itemClass == MSTrack.self {
            guard let id = itemContent["item_id"] as? String else { return nil }
            return "x-sonos-http:\(id).mp4?sid=20&flags=32"
        }
        if (itemClass == MSAlbum.self || itemClass == MSAlbumList.self || itemClass == MSPlaylist.self || itemClass == MSArtistTracklist.self),
           let id = itemContent["extended_id"] as? String {
            return "x-rincon-cpcontainer:\(id)"
        }
        return nil
    }
}

final class LegacyMusicServiceDataTests: XCTestCase {
    let service = FakeLegacyMusicService()

    func xml(_ value: String) throws -> SoCoXMLElement { try XCTUnwrap(XMLTree(value).root) }

    func testTrackFromXMLAndDIDL() throws {
        let input = """
        <mediaMetadata xmlns="http://www.sonos.com/Services/1.1">
          <id>trackid_24125935</id><itemType>track</itemType><mimeType>audio/aac</mimeType><title>Pilgrim</title>
          <trackMetadata><artistId>artistid_4816276</artistId><artist>MØ</artist><albumId>albumid_24125922</albumId><album>Nytårsfesten 2014</album><duration>231</duration><canPlay>true</canPlay><canSkip>true</canSkip><canAddToFavorites>true</canAddToFavorites></trackMetadata>
        </mediaMetadata>
        """
        let item = try MSTrack.fromXML(try xml(input), service: service, parentID: "00020064tracksearch:pilgrim")
        XCTAssertEqual(item.itemID, "trackid_24125935")
        XCTAssertEqual(item.extendedID, "00030020trackid_24125935")
        XCTAssertEqual(item.title, "Pilgrim")
        XCTAssertEqual(item.artist, "MØ")
        XCTAssertEqual(item.album, "Nytårsfesten 2014")
        XCTAssertEqual(item.duration, 231)
        XCTAssertTrue(item.canPlay)
        XCTAssertEqual(item.uri, "x-sonos-http:trackid_24125935.mp4?sid=20&flags=32")
        let didl = try item.didlMetadataXML()
        let parsed = try XMLTree(didl)
        XCTAssertEqual(parsed.root?.descendants(named: "title").first?.text, "Pilgrim")
        XCTAssertEqual(parsed.root?.descendants(named: "class").first?.text, "object.item.audioItem.musicTrack")
        XCTAssertEqual(parsed.root?.descendants(named: "desc").first?.text, service.musicServiceDescription)
    }

    func testAlbumFromXML() throws {
        let input = """
        <mediaCollection xmlns="http://www.sonos.com/Services/1.1"><id>albumid_5738780</id><itemType>album</itemType><title>Greatest De Unge År</title><artist>tv·2</artist><canPlay>true</canPlay><canAddToFavorites>true</canAddToFavorites></mediaCollection>
        """
        let item = try MSAlbum.fromXML(try xml(input), service: service, parentID: "parent")
        XCTAssertEqual(item.extendedID, "0004002calbumid_5738780")
        XCTAssertEqual(item.artist, "tv·2")
        XCTAssertTrue(item.canPlay)
        XCTAssertEqual(item.uri, "x-rincon-cpcontainer:0004002calbumid_5738780")
    }

    func testArtistIsNotPlayableAndDIDLThrows() throws {
        let input = """
        <mediaCollection xmlns="http://www.sonos.com/Services/1.1"><id>artistid_4761386</id><itemType>artist</itemType><title>Fritjof Såheim</title><artist>Fritjof Såheim</artist><canAddToFavorites>true</canAddToFavorites></mediaCollection>
        """
        let item = try MSArtist.fromXML(try xml(input), service: service, parentID: "parent")
        XCTAssertFalse(item.canPlay)
        XCTAssertEqual(item.extendedID, "10050024artistid_4761386")
        XCTAssertThrowsError(try item.didlMetadataXML())
    }

    func testGetMSItemDispatchesAlbumList() throws {
        let input = """
        <mediaCollection xmlns="http://www.sonos.com/Services/1.1"><id>playlistid_1</id><itemType>albumList</itemType><title>List</title><canPlay>true</canPlay><canEnumerate>true</canEnumerate></mediaCollection>
        """
        let item = try getMSItem(try xml(input), service: service, parentID: "parent")
        XCTAssertTrue(item is MSAlbumList)
        XCTAssertEqual(item.extendedID, "000d006cplaylistid_1")
    }

    func testUnknownTagRejected() throws {
        let input = "<mediaMetadata xmlns=\"http://www.sonos.com/Services/1.1\"><id>x</id><itemType>track</itemType><title>T</title><weirdField>oops</weirdField></mediaMetadata>"
        XCTAssertThrowsError(try MSTrack.fromXML(try xml(input), service: service, parentID: "p"))
    }

    func testFromDictionaryPreservesContent() throws {
        let dictionary: [String: Any] = [
            "title": "T", "item_id": "i", "extended_id": "e", "uri": "u", "description": "d", "service_id": 20, "can_play": true
        ]
        let item = try MSTrack.fromDictionary(dictionary)
        XCTAssertEqual(Set(item.dictionary.keys), Set(dictionary.keys))
        XCTAssertEqual(item.dictionary["title"] as? String, "T")
        XCTAssertEqual(item.dictionary["can_play"] as? Bool, true)
        XCTAssertTrue(LegacyMusicServiceItem.contentEqual(item, try MSTrack.fromDictionary(dictionary)))
    }
}
