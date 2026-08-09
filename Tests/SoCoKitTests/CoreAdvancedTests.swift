import XCTest
@testable import SoCoKit

private final class FakeQueueMusicServiceProvider: MusicServiceProviding {
    let serviceName = "Fake"
    let serviceID = 9
    let serviceType = 2311
    let desc = "DESC"
    func sonosURIFromID(_ itemID: String) -> String { "soco://\(smapiQuote(itemID))?sid=9&sn=0" }
}

final class CoreAdvancedTests: XCTestCase {
    private func makeSoCo(_ client: MockHTTPClient = MockHTTPClient(), coordinator: Bool = true) throws -> SoCo {
        let soco = try SoCo("192.168.2.101", httpClient: client)
        soco._isCoordinator = coordinator
        // Unit-test stand-in for a fresh ZoneGroupState cache. Production
        // coordinator checks still call `poll`, matching upstream SoCo.
        soco.zoneGroupState.cacheUntil = .distantFuture
        return soco
    }

    private func enqueueOK(_ client: MockHTTPClient, action: String, service: String = "AVTransport", fields: [(String, String)] = []) {
        client.enqueue(text: soapResponse(action: action, serviceType: service, fields: fields))
    }

    private func browseResponse(_ didl: String, numberReturned: String = "1", totalMatches: String = "1", updateID: String = "0") -> String {
        soapResponse(action: "Browse", serviceType: "ContentDirectory", fields: [
            ("Result", didl), ("NumberReturned", numberReturned), ("TotalMatches", totalMatches), ("UpdateID", updateID)
        ])
    }

    func testSpeakerInfoFetchCacheAndRefresh() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let first = """
        <root><device><roomName>Kitchen</roomName><url>/img/icon.png</url><serialNum>AA:BB:CC:DD:EE:FF:1</serialNum><softwareVersion>96.0-1</softwareVersion><hardwareVersion>1.2</hardwareVersion><modelNumber>S17</modelNumber><modelName>Sonos Move</modelName><displayVersion>17.0</displayVersion><UDN>uuid:RINCON_AA</UDN></device></root>
        """
        client.enqueue(text: first)
        let info = try soco.getSpeakerInfo(timeout: 12)
        XCTAssertEqual(info["zone_name"], "Kitchen")
        XCTAssertEqual(info["model_name"], "Sonos Move")
        XCTAssertEqual(info["uid"], "RINCON_AA")
        XCTAssertEqual(info["mac_address"], "AA")
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].timeout, 12)

        _ = try soco.getSpeakerInfo()
        XCTAssertEqual(client.requests.count, 1, "cached speaker info must avoid a second GET")

        client.enqueue(text: first.replacingOccurrences(of: "Kitchen", with: "Study"))
        let refreshed = try soco.getSpeakerInfo(refresh: true)
        XCTAssertEqual(refreshed["zone_name"], "Study")
        XCTAssertEqual(client.requests.count, 2)
    }

    func testQueueSizeReadsContainerChildCount() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><container id="Q:0" parentID="Q:" childCount="123"><dc:title>Queue</dc:title><upnp:class>object.container</upnp:class></container></DIDL-Lite>
        """
        client.enqueue(text: browseResponse(didl))
        XCTAssertEqual(try soco.queueSize, 123)
        let body = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(body.contains("<BrowseFlag>BrowseMetadata</BrowseFlag>"))
        XCTAssertTrue(body.contains("<RequestedCount>1</RequestedCount>"))
    }

    func testAddModernSMAPIItemToQueueUsesMusicServiceDIDL() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "AddURIToQueue", fields: [("FirstTrackNumberEnqueued", "7")])
        let service = FakeQueueMusicServiceProvider()
        let item = try SMAPI.MSTrack.fromMusicService(service, contentDictionary: [
            "id": "track:abc", "itemType": "track", "title": "Modern Track"
        ])

        XCTAssertEqual(try soco.addToQueue(item, position: 3, asNext: true), 7)
        let body = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(body.contains("<EnqueuedURI>soco://0ffffffftrack%253Aabc?sid=9&amp;sn=0</EnqueuedURI>"))
        XCTAssertTrue(body.contains("<DesiredFirstTrackNumberEnqueued>3</DesiredFirstTrackNumberEnqueued>"))
        XCTAssertTrue(body.contains("<EnqueueAsNext>1</EnqueueAsNext>"))
        XCTAssertTrue(body.contains("0ffffffftrack%3Aabc"))
        XCTAssertTrue(body.contains("DUMMY"))
        XCTAssertTrue(body.contains("DESC"))
    }

    func testAddMultipleModernSMAPIItemsToQueue() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "AddMultipleURIsToQueue")
        let service = FakeQueueMusicServiceProvider()
        let items: [SMAPI.MusicServiceItem] = try (0..<2).map { index in
            try SMAPI.MSTrack.fromMusicService(service, contentDictionary: [
                "id": "track:\(index)", "itemType": "track", "title": "Modern \(index)"
            ])
        }

        try soco.addMultipleToQueue(items)
        XCTAssertEqual(client.requests.count, 1)
        let body = requestBodyText(client.requests[0])
        XCTAssertTrue(body.contains("<NumberOfURIs>2</NumberOfURIs>"))
        XCTAssertTrue(body.contains("0ffffffftrack%3A0"))
        XCTAssertTrue(body.contains("0ffffffftrack%3A1"))
        XCTAssertTrue(body.contains("DESC"))
    }

    func testAddMultipleToQueueChunksAtSixteenItems() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "AddMultipleURIsToQueue")
        enqueueOK(client, action: "AddMultipleURIsToQueue")
        let items: [DidlObject] = try (0..<17).map { index in
            try DidlMusicTrack(
                title: "Track \(index)", parentID: "A:TRACKS", itemID: "A:TRACKS/\(index)",
                resources: [DidlResource(uri: "x-file-cifs://server/\(index).mp3", protocolInfo: "x-file-cifs:*:audio/mpeg:*")]
            )
        }
        try soco.addMultipleToQueue(items)
        XCTAssertEqual(client.requests.count, 2)
        let first = requestBodyText(client.requests[0])
        let second = requestBodyText(client.requests[1])
        XCTAssertTrue(first.contains("<NumberOfURIs>16</NumberOfURIs>"))
        XCTAssertTrue(second.contains("<NumberOfURIs>1</NumberOfURIs>"))
        XCTAssertTrue(second.contains("x-file-cifs://server/16.mp3"))
    }

    func testPlaylistLookupByTitleAndItemID() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><container id="SQ:42" parentID="SQ:" restricted="true"><dc:title>Bench Mix</dc:title><upnp:class>object.container.playlistContainer</upnp:class><res protocolInfo="x-rincon-playlist:*:*:*">file:///jffs/settings/savedqueues.rsq#42</res></container></DIDL-Lite>
        """
        client.enqueue(text: browseResponse(didl))
        XCTAssertEqual(try soco.getSonosPlaylistByAttribute("title", matching: "Bench Mix").itemID, "SQ:42")
        client.enqueue(text: browseResponse(didl))
        XCTAssertEqual(try soco.getSonosPlaylistByAttribute("item_id", matching: "SQ:42").title, "Bench Mix")
        client.enqueue(text: browseResponse(didl))
        XCTAssertThrowsError(try soco.getSonosPlaylistByAttribute("bogus", matching: "x"))
    }

    func testTrueplayVoiceAndMicrophoneStates() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "GetRoomCalibrationStatus", service: "RenderingControl", fields: [
            ("RoomCalibrationAvailable", "0"), ("RoomCalibrationEnabled", "0")
        ])
        XCTAssertNil(try soco.trueplay())
        enqueueOK(client, action: "GetRoomCalibrationStatus", service: "RenderingControl", fields: [
            ("RoomCalibrationAvailable", "1"), ("RoomCalibrationEnabled", "1")
        ])
        XCTAssertEqual(try soco.trueplay(), true)

        let zgs = """
        <ZoneGroups><ZoneGroup Coordinator="RINCON_MIC" ID="RINCON_MIC:1"><ZoneGroupMember UUID="RINCON_MIC" ZoneName="Kitchen" Location="http://192.168.2.101:1400/xml/device_description.xml" Invisible="0" VoiceConfigState="1" MicEnabled="1"/></ZoneGroup></ZoneGroups>
        """
        client.enqueue(text: soapResponse(action: "GetZoneGroupState", serviceType: "ZoneGroupTopology", fields: [("ZoneGroupState", zgs)]))
        soco.zoneGroupState.clearCache()
        XCTAssertEqual(try soco.voiceServiceConfigured(), true)
        XCTAssertEqual(try soco.micEnabled(), true)
    }


    func testRawPlaylistReorderPreservesCommaLists() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "ReorderTracksInSavedQueue", fields: [
            ("QueueLengthChange", "-1"), ("NewUpdateID", "44"), ("NewQueueLength", "2")
        ])
        let result = try soco.reorderSonosPlaylist(
            itemID: "SQ:42", tracks: "0,2", newPositions: ",0", updateID: 43
        )
        XCTAssertEqual(result, PlaylistReorderResult(change: -1, updateID: 44, length: 2))
        let body = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(body.contains("<TrackList>0,2</TrackList>"))
        XCTAssertTrue(body.contains("<NewPositionList>,0</NewPositionList>"))
        XCTAssertTrue(body.contains("<UpdateID>43</UpdateID>"))
    }

    func testClearPlaylistUsesOneBulkRemovalCommand() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let playlist = try DidlPlaylistContainer(title: "Bulk", parentID: "SQ:", itemID: "SQ:9")
        let empty = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"></DIDL-Lite>
        """
        client.enqueue(text: browseResponse(empty, numberReturned: "0", totalMatches: "3", updateID: "9"))
        enqueueOK(client, action: "ReorderTracksInSavedQueue", fields: [
            ("QueueLengthChange", "-3"), ("NewUpdateID", "10"), ("NewQueueLength", "0")
        ])
        let result = try soco.clearSonosPlaylist(playlist, updateID: 9)
        XCTAssertEqual(result, PlaylistReorderResult(change: -3, updateID: 10, length: 0))
        XCTAssertEqual(client.requests.count, 2)
        let body = requestBodyText(client.requests[1])
        XCTAssertTrue(body.contains("<TrackList>0,1,2</TrackList>"))
        XCTAssertTrue(body.contains("<NewPositionList></NewPositionList>"))
    }

    func testGetQueueQualifiesAlbumArtAndMetadata() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="Q:0/1" parentID="Q:0" restricted="true"><dc:title>One</dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class><upnp:albumArtURI>/getaa?u=x</upnp:albumArtURI><res protocolInfo="x-file-cifs:*:audio/mpeg:*">x-file-cifs://server/one.mp3</res></item></DIDL-Lite>
        """
        client.enqueue(text: browseResponse(didl, numberReturned: "1", totalMatches: "9", updateID: "33"))
        let queue = try soco.getQueue(start: 3, maxItems: 2, fullAlbumArtURI: true)
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.numberReturned, "1")
        XCTAssertEqual(queue.totalMatches, "9")
        XCTAssertEqual(queue.updateID, "33")
        XCTAssertEqual(queue.items[0].albumArtURI, "http://192.168.2.101:1400/getaa?u=x")
        let body = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(body.contains("<StartingIndex>3</StartingIndex>"))
        XCTAssertTrue(body.contains("<RequestedCount>2</RequestedCount>"))
    }
}
