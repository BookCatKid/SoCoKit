import XCTest
@testable import SoCoKit

/// Additional parity tests translated from upstream `tests/test_core.py`.
///
/// These deliberately focus on stateful/topology-dependent branches which are
/// easy to get subtly wrong when translating Python properties to Swift methods.
final class CoreParityTests: XCTestCase {
    private func makeSoCo(_ client: MockHTTPClient = MockHTTPClient(), coordinator: Bool = true) throws -> SoCo {
        let soco = try SoCo("192.168.9.10", httpClient: client)
        soco._isCoordinator = coordinator
        soco.zoneGroupState.cacheUntil = .distantFuture
        return soco
    }

    private func enqueueOK(
        _ client: MockHTTPClient,
        action: String,
        service: String = "AVTransport",
        fields: [(String, String)] = []
    ) {
        client.enqueue(text: soapResponse(action: action, serviceType: service, fields: fields))
    }

    private func zoneGroupStateXML(
        currentCoordinator: Bool = true,
        invisible: Bool = false,
        channelMap: String? = nil,
        htSatChanMap: String? = nil,
        bootSeq: Int = 162,
        voiceConfigState: String = "0",
        micEnabled: String = "0"
    ) -> String {
        let currentUID = "RINCON_CURRENT"
        let otherUID = "RINCON_OTHER"
        let coordinatorUID = currentCoordinator ? currentUID : otherUID
        let channel = channelMap.map { " ChannelMapSet=\"\($0)\"" } ?? ""
        let htChannel = htSatChanMap.map { " HTSatChanMapSet=\"\($0)\"" } ?? ""
        let other = currentCoordinator ? "" : "<ZoneGroupMember UUID=\"\(otherUID)\" ZoneName=\"Other\" Location=\"http://192.168.9.11:1400/xml/device_description.xml\" Invisible=\"0\" BootSeq=\"1\"/>"
        return """
        <ZoneGroups><ZoneGroup Coordinator="\(coordinatorUID)" ID="\(coordinatorUID):1">
          <ZoneGroupMember UUID="\(currentUID)" ZoneName="Kitchen" Location="http://192.168.9.10:1400/xml/device_description.xml" Invisible="\(invisible ? "1" : "0")" BootSeq="\(bootSeq)" VoiceConfigState="\(voiceConfigState)" MicEnabled="\(micEnabled)"\(channel)\(htChannel)/>
          \(other)
        </ZoneGroup></ZoneGroups>
        """
    }

    private func enqueueZGS(_ client: MockHTTPClient, _ xml: String) {
        enqueueOK(client, action: "GetZoneGroupState", service: "ZoneGroupTopology", fields: [("ZoneGroupState", xml)])
    }

    func testCoordinatorStatusAlwaysConsultsTopologyCacheLayer() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client, coordinator: true)
        soco.zoneGroupState.cacheUntil = .distantPast
        enqueueZGS(client, zoneGroupStateXML(currentCoordinator: false))

        // Upstream `is_coordinator` always calls zone_group_state.poll rather
        // than short-circuiting on the previous `_is_coordinator` value.
        XCTAssertFalse(try soco.isCoordinator())
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertFalse(soco._isCoordinator ?? true)
    }

    func testPlayerNameSetterDoesNotInventTopologyCacheUpdate() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._playerName = "Old topology name"
        enqueueOK(client, action: "SetZoneAttributes", service: "DeviceProperties")

        try soco.setPlayerName("New name")
        XCTAssertEqual(soco._playerName, "Old topology name")
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredZoneName>New name</DesiredZoneName>"))
    }

    func testTopologyBackedIdentityProperties() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco.zoneGroupState.cacheUntil = .distantPast
        enqueueZGS(client, zoneGroupStateXML(
            channelMap: "RINCON_CURRENT:RF,RF",
            bootSeq: 162,
            voiceConfigState: "1",
            micEnabled: "1"
        ))

        XCTAssertEqual(try soco.bootSequenceNumber(), 162)
        XCTAssertEqual(try soco.playerName(), "Kitchen")
        XCTAssertEqual(try soco.uid(), "RINCON_CURRENT")
        XCTAssertTrue(try soco.isVisible())
        XCTAssertFalse(try soco.isBridge())
        XCTAssertTrue(try soco.isCoordinator())
        XCTAssertFalse(try soco.isSatellite())
        XCTAssertFalse(try soco.hasSatellites())
        XCTAssertEqual(try soco.channel(), "RF")
        XCTAssertFalse(try soco.isSubwoofer())
        XCTAssertEqual(try soco.voiceServiceConfigured(), true)
        XCTAssertEqual(try soco.micEnabled(), true)
        XCTAssertEqual(client.requests.count, 1, "five-second ZoneGroupState cache should serve repeated identity reads")
    }

    func testSoundbarModelDetectionMatchesUpstreamMatrix() throws {
        let cases: [(String, Bool)] = [
            ("Play:5", false), ("Sonos One", false), ("PLAYBAR", true),
            ("Sonos Beam", true), ("Sonos Playbar", true), ("Sonos Playbase", true),
            ("Sonos Arc", true), ("Sonos Arc SL", true), ("Sonos Arc Ultra", true),
            ("Sonos Ray", true), ("Sonos Amp", true),
        ]
        for (model, expected) in cases {
            let soco = try makeSoCo()
            soco.speakerInfo["model_name"] = model
            soco._isSoundbar = nil
            XCTAssertEqual(try soco.isSoundbar(), expected, model)
        }
    }

    func testShuffleAndRepeatMappingsPreserveSonosOddities() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)

        enqueueOK(client, action: "GetTransportSettings", fields: [("PlayMode", "NORMAL")])
        XCTAssertFalse(try soco.shuffle())

        enqueueOK(client, action: "GetTransportSettings", fields: [("PlayMode", "NORMAL")])
        enqueueOK(client, action: "SetPlayMode")
        try soco.setShuffle(true)
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<NewPlayMode>SHUFFLE_NOREPEAT</NewPlayMode>"))

        enqueueOK(client, action: "GetTransportSettings", fields: [("PlayMode", "SHUFFLE_NOREPEAT")])
        enqueueOK(client, action: "SetPlayMode")
        try soco.setRepeatMode(.all)
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<NewPlayMode>SHUFFLE</NewPlayMode>"), "Sonos SHUFFLE means shuffle + repeat-all")

        enqueueOK(client, action: "GetTransportSettings", fields: [("PlayMode", "SHUFFLE")])
        XCTAssertEqual(try soco.repeatMode(), .all)
    }

    func testPlayFromQueueUsesOneBasedSeekAndOptionalStart() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco.speakerInfo["model_name"] = "Sonos One"
        soco._uid = "RINCON_QUEUE"
        enqueueOK(client, action: "SetAVTransportURI")
        enqueueOK(client, action: "Seek")

        try soco.playFromQueue(index: 0, start: false)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertTrue(requestBodyText(client.requests[0]).contains("<CurrentURI>x-rincon-queue:RINCON_QUEUE#0</CurrentURI>"))
        XCTAssertTrue(requestBodyText(client.requests[1]).contains("<Target>1</Target>"))
    }

    func testSoundbarEQAndSurroundBranches() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._isSoundbar = true
        enqueueOK(client, action: "GetEQ", service: "RenderingControl", fields: [("CurrentValue", "1")])
        XCTAssertEqual(try soco.surroundEnabled(), true)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setSurroundEnabled(false)
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<EQType>SurroundEnable</EQType>"))
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<DesiredValue>0</DesiredValue>"))

        enqueueOK(client, action: "GetEQ", service: "RenderingControl", fields: [("CurrentValue", "-6")])
        XCTAssertEqual(try soco.surroundVolumeTV(), -6)
        XCTAssertThrowsError(try soco.setSurroundVolumeTV(16))
        XCTAssertThrowsError(try soco.setSurroundVolumeMusic(-16))
    }

    func testSonosAmpSubwooferCrossoverAndGain() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco.speakerInfo["model_name"] = "Sonos Amp"

        enqueueOK(client, action: "GetEQ", service: "RenderingControl", fields: [("CurrentValue", "80")])
        XCTAssertEqual(try soco.subCrossover(), 80)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setSubCrossover(110)
        XCTAssertThrowsError(try soco.setSubCrossover(111))

        enqueueOK(client, action: "GetEQ", service: "RenderingControl", fields: [("CurrentValue", "-3")])
        XCTAssertEqual(try soco.subGain(), -3)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setSubGain(15)
        XCTAssertThrowsError(try soco.setSubGain(-16))
    }

    func testUnsupportedSoundbarFeaturesDoNotSendEQRequests() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._isSoundbar = false
        XCTAssertNil(try soco.nightMode())
        XCTAssertNil(try soco.dialogMode())
        XCTAssertNil(try soco.audioDelay())
        XCTAssertNil(try soco.surroundFullVolumeEnabled())
        XCTAssertEqual(client.requests.count, 0)
        XCTAssertThrowsError(try soco.setNightMode(true))
        XCTAssertThrowsError(try soco.setAudioDelay(1))
        XCTAssertEqual(client.requests.count, 0)
    }

    func testSoundbarAudioInputKnownAndUnknownFormats() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._isSoundbar = true
        enqueueOK(client, action: "GetZoneInfo", service: "DeviceProperties", fields: [("HTAudioIn", "0")])
        XCTAssertEqual(try soco.soundbarAudioInputFormat(), SoCoConstants.audioInputFormats[0])
        enqueueOK(client, action: "GetZoneInfo", service: "DeviceProperties", fields: [("HTAudioIn", "99999")])
        XCTAssertEqual(try soco.soundbarAudioInputFormat(), "Unknown audio input format: 99999")
    }

    func testCurrentMediaInfoParsesChannelTitle() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let metadata = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item><dc:title>BBC Radio 4</dc:title></item></DIDL-Lite>
        """
        enqueueOK(client, action: "GetMediaInfo", fields: [("CurrentURI", "x-rincon-mp3radio://example"), ("CurrentURIMetaData", metadata)])
        let result = try soco.currentMediaInfo()
        XCTAssertEqual(result["uri"], "x-rincon-mp3radio://example")
        XCTAssertEqual(result["channel"], "BBC Radio 4")
    }

    func testCurrentMediaInfoParsesAlbumArtFromMediaMetadata() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        // Radio streams advertise station artwork in GetMediaInfo metadata even
        // though GetPositionInfo TrackMetaData omits it. Both absolute URLs and
        // player-relative /getaa paths must be resolved.
        let absoluteMetadata = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item><dc:title>KSLC All Classical Portland</dc:title><upnp:class>object.item.audioItem.audioBroadcast</upnp:class><upnp:albumArtURI>https://static.mytuner-radio.net/media/tvos_radios/083/kslc-903.2c277c6d.png</upnp:albumArtURI></item></DIDL-Lite>
        """
        enqueueOK(client, action: "GetMediaInfo", fields: [("CurrentURI", "x-sonosapi-stream:r%3a401083?sid=268"), ("CurrentURIMetaData", absoluteMetadata)])
        let result = try soco.currentMediaInfo()
        XCTAssertEqual(result["channel"], "KSLC All Classical Portland")
        XCTAssertEqual(result["album_art"], "https://static.mytuner-radio.net/media/tvos_radios/083/kslc-903.2c277c6d.png")

        let relativeMetadata = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item><dc:title>Station</dc:title><upnp:albumArtURI>/getaa?u=x</upnp:albumArtURI></item></DIDL-Lite>
        """
        enqueueOK(client, action: "GetMediaInfo", fields: [("CurrentURI", "x-rincon-mp3radio://example"), ("CurrentURIMetaData", relativeMetadata)])
        let relativeResult = try soco.currentMediaInfo()
        XCTAssertEqual(relativeResult["album_art"], "http://192.168.9.10:1400/getaa?u=x")
    }

    func testCurrentMediaInfoOmitsAlbumArtWhenAbsent() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let metadata = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item><dc:title>BBC Radio 4</dc:title></item></DIDL-Lite>
        """
        enqueueOK(client, action: "GetMediaInfo", fields: [("CurrentURI", "x-rincon-mp3radio://example"), ("CurrentURIMetaData", metadata)])
        let result = try soco.currentMediaInfo()
        XCTAssertNil(result["album_art"])
    }

    func testQueueRemovalAndClearUseOneBasedObjectID() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "RemoveTrackFromQueue")
        try soco.removeFromQueue(index: 0)
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<ObjectID>Q:0/1</ObjectID>"))
        enqueueOK(client, action: "RemoveAllTracksFromQueue")
        try soco.clearQueue()
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<u:RemoveAllTracksFromQueue"))
    }

    func testPlaylistCreateSaveAndDestroyWireContract() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "CreateSavedQueue", fields: [("AssignedObjectID", "SQ:12")])
        let empty = try soco.createSonosPlaylist(title: "Road Trip")
        XCTAssertEqual(empty.itemID, "SQ:12")
        XCTAssertEqual(empty.resources.first?.uri, "file:///jffs/settings/savedqueues.rsq#12")

        enqueueOK(client, action: "SaveQueue", fields: [("AssignedObjectID", "SQ:13")])
        let saved = try soco.createSonosPlaylistFromQueue(title: "Current Queue")
        XCTAssertEqual(saved.itemID, "SQ:13")

        enqueueOK(client, action: "DestroyObject", service: "ContentDirectory")
        try soco.removeSonosPlaylist(saved)
        XCTAssertTrue(requestBodyText(client.requests.last!).contains("<ObjectID>SQ:13</ObjectID>"))
    }

    func testLegacyFavoriteBrowseObjectIDs() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="R:0/0/1" parentID="R:0/0"><dc:title>Station</dc:title><upnp:class>object.item.audioItem.audioBroadcast</upnp:class><res protocolInfo="x-rincon-mp3radio:*:*:*">x-rincon-mp3radio://station</res></item></DIDL-Lite>
        """
        func browse(_ objectID: String) throws -> FavoriteResult {
            client.enqueue(text: soapResponse(action: "Browse", serviceType: "ContentDirectory", fields: [("Result", didl), ("NumberReturned", "1"), ("TotalMatches", "1"), ("UpdateID", "1")]))
            let result: FavoriteResult
            switch objectID {
            case "R:0/1": result = try soco.getFavoriteRadioShows()
            case "R:0/0": result = try soco.getFavoriteRadioStations()
            default: result = try soco.getSonosFavorites()
            }
            XCTAssertTrue(requestBodyText(client.requests.last!).contains("<ObjectID>\(objectID)</ObjectID>"))
            return result
        }
        XCTAssertEqual(try browse("R:0/1").favorites.first?.title, "Station")
        XCTAssertEqual(try browse("R:0/0").favorites.first?.uri, "x-rincon-mp3radio://station")
        XCTAssertEqual(try browse("FV:2").total, 1)
    }
}
