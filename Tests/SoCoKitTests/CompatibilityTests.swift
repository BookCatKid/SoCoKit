import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import SoCoKit

private final class CompatibilityMusicService: MusicServiceProviding {
    let serviceName = "Compatibility Service"
    let serviceID = 99
    let serviceType = 25351
    let desc = "SA_RINCON99_X_#Svc99-0-Token"

    func sonosURIFromID(_ itemID: String) -> String { "x-sonos-http:\(itemID).mp3" }
}

final class CompatibilityTests: XCTestCase {
    func testAlarmThrowingCompatibilitySetters() throws {
        let alarm = try Alarm(zone: nil, recurrence: "DAILY", playMode: "NORMAL")
        try alarm.setPlayMode("shuffle")
        XCTAssertEqual(alarm.playMode, "SHUFFLE")
        XCTAssertThrowsError(try alarm.setPlayMode("definitely-not-a-mode"))
        XCTAssertEqual(alarm.playMode, "SHUFFLE")

        try alarm.setRecurrence("ON_036")
        XCTAssertEqual(alarm.recurrence, "ON_036")
        XCTAssertThrowsError(try alarm.setRecurrence("on_036"))
        XCTAssertEqual(alarm.recurrence, "ON_036")
    }

    func testAlarmPropertySetterPreservesValidStateOnInvalidInput() throws {
        let alarm = try Alarm(zone: nil, recurrence: "DAILY", playMode: "NORMAL")
        alarm.playMode = "not-valid"
        alarm.recurrence = "not-valid"
        XCTAssertEqual(alarm.playMode, "NORMAL")
        XCTAssertEqual(alarm.recurrence, "DAILY")
    }

    func testPublicAlarmPayloadParser() throws {
        let zone = try SoCo("10.0.0.201", httpClient: MockHTTPClient())
        zone._uid = "RINCON_COMPAT"
        let xml = """
        <Alarms><Alarm ID="7" StartTime="06:30:00" Duration="" Recurrence="WEEKDAYS" Enabled="1" RoomUUID="RINCON_COMPAT" ProgramURI="x-rincon-buzzer:0" ProgramMetaData="" PlayMode="NORMAL" Volume="17" IncludeLinkedZones="1"/></Alarms>
        """
        let alarms = try parseAlarmPayload(["CurrentAlarmList": xml], zones: [zone])
        XCTAssertEqual(alarms.count, 1)
        XCTAssertTrue(alarms[0].zone === zone)
        XCTAssertNil(alarms[0].programURI)
        XCTAssertEqual(alarms[0].volume, 17)
        XCTAssertTrue(alarms[0].includeLinkedZones)
    }

    func testResourceQuirkHelperAndNamespaceHelper() throws {
        let tree = try XMLTree("<res>x-sonos-spotify:spotify%3atrack%3a123</res>")
        let resource = try XCTUnwrap(tree.root)
        XCTAssertNil(resource.attribute("protocolInfo"))
        XCTAssertTrue(applyResourceQuirks(resource) === resource)
        XCTAssertEqual(resource.attribute("protocolInfo"), "sonos.com-spotify:*:audio/x-spotify.*")
        XCTAssertEqual(nsTag("dc", "title"), "{http://purl.org/dc/elements/1.1/}title")
    }

    func testZoneGroupNormalizationIgnoresGroupAndMemberOrder() throws {
        let first = """
        <ZoneGroupState><ZoneGroups>
          <ZoneGroup Coordinator="B" ID="B:1"><ZoneGroupMember UUID="D"/><ZoneGroupMember UUID="C"/></ZoneGroup>
          <ZoneGroup Coordinator="A" ID="A:1"><ZoneGroupMember UUID="B"/><ZoneGroupMember UUID="A"/></ZoneGroup>
        </ZoneGroups></ZoneGroupState>
        """
        let second = """
        <ZoneGroupState><ZoneGroups>
          <ZoneGroup Coordinator="A" ID="A:1"><ZoneGroupMember UUID="A"/><ZoneGroupMember UUID="B"/></ZoneGroup>
          <ZoneGroup Coordinator="B" ID="B:1"><ZoneGroupMember UUID="C"/><ZoneGroupMember UUID="D"/></ZoneGroup>
        </ZoneGroups></ZoneGroupState>
        """
        XCTAssertEqual(try normalizeZoneGroupStateXML(first), try normalizeZGSXML(second))
    }


    func testRegistryUsesLatestWrapperForAnIPAndResetClearsIt() throws {
        socoReset()
        let first = try SoCo("10.0.0.202", httpClient: MockHTTPClient())
        XCTAssertTrue(SoCoRegistry.shared.existing(ipAddress: "10.0.0.202") === first)
        let second = try SoCo("10.0.0.202", httpClient: MockHTTPClient())
        XCTAssertTrue(SoCoRegistry.shared.existing(ipAddress: "10.0.0.202") === second)
        socoReset()
        XCTAssertNil(SoCoRegistry.shared.existing(ipAddress: "10.0.0.202"))
    }

    func testTokenStoreCompatibilityAliasesCompileAndPersist() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("tokens.json")
        let store: JsonFileTokenStore = try JSONFileTokenStore(fileURL: url)
        let base: any TokenStoreBase = store
        try base.saveTokenPair(musicServiceID: 42, householdID: "Sonos_1", tokenPair: ("token", "key"))
        XCTAssertTrue(base.hasToken(musicServiceID: 42, householdID: "Sonos_1"))
        let pair = try base.loadTokenPair(musicServiceID: 42, householdID: "Sonos_1")
        XCTAssertEqual(pair.0, "token")
        XCTAssertEqual(pair.1, "key")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
    func testPackageMetadataConstantsAndDebugRepresentation() throws {
        XCTAssertEqual(SoCoKitMetadata.author, "The SoCo-Team <python-soco@googlegroups.com>")
        XCTAssertEqual(SoCoKitMetadata.version, "0.32.0-dev")
        XCTAssertEqual(SoCoKitMetadata.website, "https://github.com/SoCo/SoCo")
        XCTAssertEqual(SoCoKitMetadata.license, "MIT License")

        XCTAssertEqual(SoCoConstants.radioStations, 0)
        XCTAssertEqual(SoCoConstants.radioShows, 1)
        XCTAssertEqual(SoCoConstants.sonosFavorites, 2)
        XCTAssertEqual(SoCoConstants.arcUltraProductName, "arc ultra")
        XCTAssertEqual(SoCoConstants.audioInputFormats[59], "Dolby Atmos (DD+)")
        XCTAssertEqual(SoCoConstants.audioInputFormats[118489148], "Dolby TrueHD 7.1")

        let speaker = try SoCo("10.0.0.203", httpClient: MockHTTPClient())
        XCTAssertEqual(speaker.description, "<SoCo object at ip 10.0.0.203>")
        XCTAssertEqual(speaker.debugDescription, "SoCo(\"10.0.0.203\")")
    }

    func testAlarmGetAndDynamicUpdateCompatibility() throws {
        Alarms.shared.reset()
        XCTAssertNil(Alarms.shared.get("missing"))

        let alarm = try Alarm(zone: nil, recurrence: "DAILY", playMode: "NORMAL", volume: 20)
        try alarm.update([
            "start_time": try AlarmTime(hour: 6, minute: 45),
            "duration": try AlarmTime(hour: 1, minute: 30),
            "recurrence": "ON_135",
            "enabled": false,
            "program_uri": "x-rincon-buzzer:0",
            "program_metadata": "metadata",
            "play_mode": "shuffle",
            "volume": "150",
            "include_linked_zones": true,
            "room_uuid": "RINCON_ROOM",
        ])
        XCTAssertEqual(alarm.startTime, try AlarmTime(hour: 6, minute: 45))
        XCTAssertEqual(alarm.duration, try AlarmTime(hour: 1, minute: 30))
        XCTAssertEqual(alarm.recurrence, "ON_135")
        XCTAssertFalse(alarm.enabled)
        XCTAssertEqual(alarm.programURI, "x-rincon-buzzer:0")
        XCTAssertEqual(alarm.programMetadata, "metadata")
        XCTAssertEqual(alarm.playMode, "SHUFFLE")
        XCTAssertEqual(alarm.volume, 100)
        XCTAssertTrue(alarm.includeLinkedZones)
        XCTAssertEqual(alarm.roomUUID, "RINCON_ROOM")

        try alarm.update(["duration": NSNull(), "program_uri": NSNull(), "room_uuid": NSNull()])
        XCTAssertNil(alarm.duration)
        XCTAssertNil(alarm.programURI)
        XCTAssertNil(alarm.roomUUID)
        XCTAssertThrowsError(try alarm.update(["not_an_alarm_attribute": true]))
    }

    func testFromDictCompatibilitySpellings() throws {
        let didl = try DidlMusicTrack.fromDict([
            "title": "Track",
            "parent_id": "A:ALBUM",
            "item_id": "A:TRACK",
            "restricted": true,
            "resources": [],
        ])
        XCTAssertEqual(didl.title, "Track")
        XCTAssertEqual(didl.itemID, "A:TRACK")

        let legacy = try MSTrack.fromDict([
            "title": "Legacy Track",
            "item_id": "legacy-id",
            "extended_id": "00032020legacy-id",
            "uri": "x-sonos-http:legacy-id.mp3",
            "description": "SA_RINCON20",
            "service_id": 20,
        ])
        XCTAssertEqual(legacy.title, "Legacy Track")
        XCTAssertEqual(legacy.itemID, "legacy-id")
    }

    func testTopLevelSMAPICompatibilityHelpers() throws {
        let service = CompatibilityMusicService()
        XCTAssertEqual(formURI(itemID: "track-id", service: service, isTrack: true), "x-sonos-http:track-id.mp3")
        XCTAssertEqual(formURI(itemID: "album-id", service: service, isTrack: false), "x-rincon-cpcontainer:album-id")

        let response: [String: Any] = [
            "searchResult": [
                "count": 1,
                "mediaMetadata": [
                    "id": "track-id",
                    "itemType": "track",
                    "title": "Track",
                    "canPlay": true,
                ],
            ],
        ]
        let result = try parseResponse(service: service, response: response, searchType: "tracks")
        XCTAssertEqual(result.numberReturned, 1)
        XCTAssertEqual(result.searchType, "tracks")
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].title, "Track")
    }

    func testMuteAndWimpDescriptionCompatibilityAliases() throws {
        let http = MockHTTPClient()
        http.enqueue(text: soapResponse(action: "GetMute", serviceType: "RenderingControl", fields: [("CurrentMute", "1")]))
        http.enqueue(text: soapResponse(action: "SetMute", serviceType: "RenderingControl"))
        let speaker = try SoCo("10.0.0.204", httpClient: http)
        XCTAssertTrue(try speaker.mute())
        try speaker.setMute(false)
        XCTAssertTrue(requestBodyText(http.requests[1]).contains("<DesiredMute>0</DesiredMute>"))

        let wimp = Wimp(speaker, username: "user", serialNumber: "SERIAL", sessionID: "SESSION", httpClient: http)
        XCTAssertEqual(wimp.description, "SA_RINCON5127_user")
        XCTAssertEqual(wimp.musicServiceDescription, wimp.description)
    }

}
