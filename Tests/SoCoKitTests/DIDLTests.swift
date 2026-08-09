import XCTest
@testable import SoCoKit

final class DIDLTests: XCTestCase {
    func testResourceCreateAndRoundTrip() throws {
        let resource = DidlResource(uri: "a%20uri", protocolInfo: "a:protocol:info:xx", bitrate: 3)
        XCTAssertEqual(resource.uri, "a%20uri")
        XCTAssertEqual(resource.protocolInfo, "a:protocol:info:xx")

        let tree = try XMLTree(try resource.xml())
        let parsed = try DidlResource(element: XCTUnwrap(tree.root))
        XCTAssertEqual(parsed, resource)
    }

    func testResourceDictionary() throws {
        let resource = DidlResource(uri: "a%20uri", protocolInfo: "a:protocol:info:xx")
        let all = resource.dictionary()
        XCTAssertEqual(all["uri"] as? String, "a%20uri")
        XCTAssertEqual(all["protocol_info"] as? String, "a:protocol:info:xx")
        XCTAssertEqual(all.count, 12)

        let compact = resource.dictionary(removeNils: true)
        XCTAssertEqual(compact.count, 2)
        XCTAssertEqual(try DidlResource(dictionary: compact), resource)
    }

    func testResourceQuirkMissingProtocolInfo() throws {
        let generic = try XMLTree("<res>some-uri</res>")
        XCTAssertEqual(try DidlResource(element: XCTUnwrap(generic.root)).protocolInfo, "DUMMY_ADDED_BY_QUIRK")

        let spotify = try XMLTree("<res>x-sonos-spotify:spotify%3atrack%3a123</res>")
        XCTAssertEqual(
            try DidlResource(element: XCTUnwrap(spotify.root)).protocolInfo,
            "sonos.com-spotify:*:audio/x-spotify.*"
        )
    }

    func testObjectRejectsUnknownMetadata() {
        XCTAssertThrowsError(
            try DidlObject(title: "a_title", parentID: "pid", itemID: "iid", metadata: ["bad_args": "other"])
        )
    }

    func testObjectSerializationAndParseRoundTrip() throws {
        let object = try DidlObject(
            title: "a_title",
            parentID: "pid",
            itemID: "iid",
            metadata: ["creator": "a_creator"]
        )
        let document = try toDIDLString([object])
        let parsed = try XCTUnwrap(fromDIDLString(document).first)
        XCTAssertEqual(parsed, object)
    }

    func testUnofficialHashSubclassIsIgnored() throws {
        let xml = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="iid" parentID="pid" restricted="true"><dc:title>the_title</dc:title><upnp:class>object.#SubClass</upnp:class><dc:creator>a_creator</dc:creator></item></DIDL-Lite>
        """
        let object = try XCTUnwrap(fromDIDLString(xml).first)
        XCTAssertTrue(type(of: object) == DidlObject.self)
        XCTAssertEqual(object.didlClass, "object")
    }

    func testKnownFixtureTypesAndFields() throws {
        let fixtures: [(String, DidlObject.Type, String)] = [
            ("track.xml", DidlMusicTrack.self, "17 - Track 17"),
            ("album.xml", DidlMusicAlbum.self, "St. Anger"),
            ("artist.xml", DidlMusicArtist.self, "Anne Linnet"),
            ("genre.xml", DidlMusicGenre.self, "Choral"),
            ("share.xml", DidlContainer.self, "//myweb/music"),
            ("playlist.xml", DidlPlaylistContainer.self, "000-christina_aguilera-back_to_basics-2cd-2006.m3u"),
            ("audio_broadcast.xml", DidlAudioBroadcast.self, "DR P3 93.9 (Euro Hits)"),
        ]

        for (file, expectedType, expectedTitle) in fixtures {
            let xml = try fixtureText("data_structures_entry_integration/\(file)")
            let item = try XCTUnwrap(fromDIDLString(xml).first, "No DIDL item in \(file)")
            XCTAssertTrue(type(of: item) == expectedType, "Unexpected type for \(file): \(type(of: item))")
            XCTAssertEqual(item.title, expectedTitle)
        }

        let track = try XCTUnwrap(fromDIDLString(try fixtureText("data_structures_entry_integration/track.xml")).first as? DidlMusicTrack)
        XCTAssertEqual(track.creator, "Den sorte skole")
        XCTAssertEqual(track.album, "Lektion #1 (Mix tape)")
    }

    func testKnownVendorExtendedClasses() throws {
        let fixtures: [(String, DidlObject.Type)] = [
            ("recent_show.xml", DidlRecentShow.self),
            ("album_favorite.xml", DidlMusicAlbumFavorite.self),
            ("album_compilation.xml", DidlMusicAlbumCompilation.self),
            ("composer.xml", DidlComposer.self),
            ("album_list.xml", DidlAlbumList.self),
            ("same_artist.xml", DidlSameArtist.self),
            ("playlist_favorite.xml", DidlPlaylistContainerFavorite.self),
            ("tracklist.xml", DidlPlaylistContainerTracklist.self),
            ("radio_show.xml", DidlRadioShow.self),
        ]
        for (file, expectedType) in fixtures {
            let xml = try fixtureText("data_structures_entry_integration/\(file)")
            let item = try XCTUnwrap(fromDIDLString(xml).first)
            XCTAssertTrue(type(of: item) == expectedType, "Unexpected type for \(file): \(type(of: item))")
        }
    }

    func testMissingUpnpClassRaises() {
        let xml = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="1" parentID="0" restricted="true"><dc:title>A Track Without Class</dc:title></item></DIDL-Lite>
        """
        XCTAssertThrowsError(try fromDIDLString(xml)) { error in
            XCTAssertTrue(error.localizedDescription.contains("upnp:class"))
        }
    }

    func testFavoriteReferenceReturnsPlayableReferencedObject() throws {
        let referenceDIDL = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="riid" parentID="rpid" restricted="true"><dc:title>referenced_title</dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class></item></DIDL-Lite>
        """
        let resource = DidlResource(uri: "x-file-cifs://uri", protocolInfo: "a:b:c:d")
        let favorite = try DidlFavorite(
            title: "a_favorite",
            parentID: "pid",
            itemID: "iid",
            resources: [resource],
            metadata: ["resource_meta_data": referenceDIDL]
        )
        let reference = try favorite.reference
        XCTAssertTrue(reference is DidlMusicTrack)
        XCTAssertEqual(reference.title, "referenced_title")
        XCTAssertEqual(reference.resources, favorite.resources)
    }

    func testFavoriteReferenceSetterRoundTrips() throws {
        let favorite = try DidlFavorite(title: "a_favorite", parentID: "pid", itemID: "iid")
        let track = try DidlMusicTrack(
            title: "referenced_title",
            parentID: "rpid",
            itemID: "riid",
            resources: [DidlResource(uri: "x-file-cifs://uri", protocolInfo: "a:b:c:d")]
        )
        try favorite.setReference(track)
        XCTAssertEqual(try favorite.reference.title, "referenced_title")
        XCTAssertEqual(favorite.resources, track.resources)
    }

    func testFavoriteWithoutReferenceMetadataThrows() throws {
        let favorite = try DidlFavorite(title: "a_favorite", parentID: "pid", itemID: "iid")
        XCTAssertThrowsError(try favorite.reference)
    }

    func testFavoriteWithEmptyReferenceMetadataThrowsNoDIDLItem() throws {
        let favorite = try DidlFavorite(
            title: "a_favorite",
            parentID: "pid",
            itemID: "iid",
            metadata: ["resource_meta_data": "<DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\"/>"]
        )
        XCTAssertThrowsError(try favorite.reference) { error in
            XCTAssertTrue(error.localizedDescription.contains("no DIDL item"))
        }
    }

    func testVendorExtensionPreservesExactClass() throws {
        let xml = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="x" parentID="y" restricted="true"><dc:title>Vendor</dc:title><upnp:class>object.item.audioItem.musicTrack.exampleVendorTrack</upnp:class></item></DIDL-Lite>
        """
        let item = try XCTUnwrap(fromDIDLString(xml).first)
        XCTAssertTrue(item is DidlMusicTrack)
        XCTAssertEqual(item.didlClass, "object.item.audioItem.musicTrack.exampleVendorTrack")
        XCTAssertEqual(item.runtimeClassName, "DidlExampleVendorTrack")
        XCTAssertTrue(try toDIDLString([item]).contains("exampleVendorTrack"))
    }

    func testFormName() throws {
        XCTAssertEqual(try formDIDLName("object.item.audioItem.audioBroadcast.sonos-favorite"), "DidlAudioBroadcastFavorite")
        XCTAssertEqual(try formDIDLName("object.container.playlistContainer.sameArtist"), "DidlSameArtist")
        XCTAssertThrowsError(try formDIDLName("nonsense"))
    }

    func testResourceCompatibilityElementAndDictionaryEntryPoints() throws {
        let resource = DidlResource(uri: "a%20uri", protocolInfo: "a:protocol:info:xx", bitrate: 3)
        let element = try resource.toElement()
        XCTAssertEqual(element.localNameSafe, "res")
        XCTAssertEqual(element.attribute("protocolInfo"), "a:protocol:info:xx")
        XCTAssertEqual(element.attribute("bitrate"), "3")
        XCTAssertEqual(element.text, "a%20uri")
        XCTAssertEqual(try DidlResource.fromElement(element), resource)
        XCTAssertEqual(try DidlResource.fromDict(resource.dictionary()), resource)
        XCTAssertEqual(try DidlResource.fromDict(resource.dictionary(removeNils: true)), resource)
    }

    func testObjectDictionaryMatchesUpstreamSparseMetadataBehavior() throws {
        let object = try DidlObject(
            title: "a_title",
            parentID: "pid",
            itemID: "iid",
            metadata: ["creator": "a_creator"]
        )
        let dictionary = object.dictionary()
        XCTAssertEqual(dictionary["title"] as? String, "a_title")
        XCTAssertEqual(dictionary["creator"] as? String, "a_creator")
        XCTAssertNil(dictionary["write_status"])
        XCTAssertEqual(dictionary.count, 6) // title, parent_id, item_id, restricted, creator, desc

        let noDescriptor = try DidlObject(title: "x", parentID: "p", itemID: "i", desc: nil)
        XCTAssertTrue(noDescriptor.dictionary(removeNils: true)["desc"] is NSNull)
    }

    func testObjectFromDictionaryRoundTripsResources() throws {
        let dictionary: [String: Any] = [
            "title": "a_title",
            "parent_id": "pid",
            "item_id": "iid",
            "creator": "a_creator",
            "restricted": true,
            "desc": "dummy",
            "resources": [[
                "uri": "a%20uri",
                "protocol_info": "a:protocol:info:xx",
            ]],
        ]
        let object = try DidlObject.fromDictionary(dictionary)
        XCTAssertEqual(object.title, "a_title")
        XCTAssertEqual(object.creator, "a_creator")
        XCTAssertEqual(object.resources, [DidlResource(uri: "a%20uri", protocolInfo: "a:protocol:info:xx")])
        XCTAssertEqual(object.desc, "dummy")
        XCTAssertEqual(try DidlObject.fromDictionary(object.dictionary()), object)
        XCTAssertThrowsError(try DidlObject.fromDictionary(dictionary.merging(["bad_args": "other"]) { _, new in new }))
    }

    func testObjectFromElementMatchesClassValidationAndUnofficialSubclassRules() throws {
        let xml = """
        <item xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
              id="iid" parentID="pid" restricted="true">
          <dc:title>the_title</dc:title>
          <upnp:class>object</upnp:class>
          <dc:creator>a_creator</dc:creator>
          <desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">DUMMY</desc>
        </item>
        """
        let root = try XCTUnwrap(XMLTree(xml).root)
        let object = try DidlObject.fromElement(root)
        XCTAssertEqual(object.title, "the_title")
        XCTAssertEqual(object.parentID, "pid")
        XCTAssertEqual(object.itemID, "iid")
        XCTAssertEqual(object.creator, "a_creator")
        XCTAssertEqual(object.desc, "DUMMY")

        let unofficial = try XCTUnwrap(XMLTree(xml.replacingOccurrences(of: ">object<", with: ">object.#SubClass<")).root)
        XCTAssertEqual(try DidlObject.fromElement(unofficial).didlClass, "object")

        let wrong = try XCTUnwrap(XMLTree(xml.replacingOccurrences(of: ">object<", with: ">object.item<")).root)
        XCTAssertThrowsError(try DidlObject.fromElement(wrong)) { error in
            XCTAssertTrue(error.localizedDescription.contains("UPnP class is incorrect"))
        }
        let res = try XCTUnwrap(XMLTree("<res>URI</res>").root)
        XCTAssertThrowsError(try DidlObject.fromElement(res))
    }

    func testDIDLParserRejectsEmptyAndIllegalRootChildrenLikeUpstream() throws {
        XCTAssertThrowsError(try fromDIDLString(""))
        let illegal = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><desc>not accepted here</desc></DIDL-Lite>
        """
        XCTAssertThrowsError(try fromDIDLString(illegal)) { error in
            XCTAssertTrue(String(describing: error).contains("Illegal child of DIDL element"))
        }
    }

    func testDIDLRecoverParserMatchesUpstreamLXMLBehavior() throws {
        let malformed = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="playback" parentID="0" restricted="false"><dc:title>loadLineIn</dc:title><upnp:class>object.item.audioItem.linein</upnp:class><res x-rincon-stream>x-rincon-stream:RINCON_TEST</res></item></DIDL-Lite>
        """
        XCTAssertThrowsError(try XMLTree(malformed), "non-DIDL XML parsing remains strict")
        let item = try XCTUnwrap(try fromDIDLString(malformed).first as? DidlAudioLineIn)
        XCTAssertEqual(item.title, "loadLineIn")
        XCTAssertEqual(item.resources.first?.uri, "x-rincon-stream:RINCON_TEST")
        XCTAssertEqual(item.resources.first?.protocolInfo, "DUMMY_ADDED_BY_QUIRK")
    }

    func testDIDLRestrictedZeroMatchesUpstreamStringSemantics() throws {
        let xml = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
                   xmlns:dc="http://purl.org/dc/elements/1.1/"
                   xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
          <item id="iid" parentID="pid" restricted="0">
            <dc:title>the_title</dc:title>
            <upnp:class>object.item</upnp:class>
          </item>
        </DIDL-Lite>
        """
        let item = try XCTUnwrap(fromDIDLString(xml).first)
        XCTAssertTrue(item.restricted)
    }

    func testObjectToElementIncludesExpectedNamespacesAndMetadata() throws {
        let object = try DidlObject(
            title: "a_title",
            parentID: "pid",
            itemID: "iid",
            metadata: ["creator": "a_creator"]
        )
        let element = try object.toElement(includeNamespaces: true)
        XCTAssertEqual(element.localNameSafe, "item")
        XCTAssertEqual(element.attribute("id"), "iid")
        XCTAssertEqual(element.attribute("parentID"), "pid")
        XCTAssertEqual(element.attribute("restricted"), "true")
        XCTAssertEqual(element.descendants(named: "title").first?.text, "a_title")
        XCTAssertEqual(element.descendants(named: "creator").first?.text, "a_creator")
        XCTAssertEqual(element.descendants(named: "class").first?.text, "object")
        XCTAssertEqual(element.descendants(named: "desc").first?.text, "RINCON_AssociatedZPUDN")
        XCTAssertTrue(element.xmlString.contains("xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\""))
    }

}
