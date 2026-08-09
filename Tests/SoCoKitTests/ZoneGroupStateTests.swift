import XCTest
@testable import SoCoKit

final class ZoneGroupStateTests: XCTestCase {
    private let payload = """
    <ZoneGroupState>
      <ZoneGroups>
        <ZoneGroup Coordinator="RINCON_MAIN" ID="RINCON_MAIN:1">
          <ZoneGroupMember BootSeq="44" Location="http://192.168.1.101:1400/xml/device_description.xml" UUID="RINCON_MAIN" ZoneName="Living Room" VoiceConfigState="1" MicEnabled="1" HTSatChanMapSet="RINCON_MAIN:LF,RF;RINCON_REAR:LR">
            <Satellite BootSeq="9" Location="http://192.168.1.103:1400/xml/device_description.xml" UUID="RINCON_REAR" ZoneName="Rear Left" Invisible="1" />
          </ZoneGroupMember>
          <ZoneGroupMember BootSeq="52" Location="http://192.168.1.102:1400/xml/device_description.xml" UUID="RINCON_KITCHEN" ZoneName="Kitchen" IsZoneBridge="0" />
        </ZoneGroup>
      </ZoneGroups>
      <VanishedDevices/>
    </ZoneGroupState>
    """

    override func setUp() {
        super.setUp()
        socoReset()
        SoCoConfig.zoneGroupTopologyEventFallback = true
    }

    func testProcessesMembersSatellitesVisibilityChannelsAndIdentity() throws {
        let client = MockHTTPClient()
        let source = try SoCo("192.168.1.101", httpClient: client)
        let state = source.zoneGroupState
        try state.processPayload(payload, sourceSoCo: source)

        XCTAssertEqual(state.groups.count, 1)
        XCTAssertEqual(state.allZones.count, 3)
        XCTAssertEqual(state.visibleZones.count, 2)
        XCTAssertTrue(state.allZones.contains(source), "The source IP should reuse the already-live SoCo wrapper")
        XCTAssertEqual(source._uid, "RINCON_MAIN")
        XCTAssertEqual(source._playerName, "Living Room")
        XCTAssertEqual(source._bootSeqnum, 44)
        XCTAssertEqual(source._channel, "LF,RF")
        XCTAssertTrue(source._isCoordinator == true)
        XCTAssertTrue(source._hasSatellites)
        XCTAssertTrue(source.zoneGroupState === state)

        let group = try XCTUnwrap(state.groups.first)
        XCTAssertTrue(group.coordinator === source)
        XCTAssertEqual(group.uid, "RINCON_MAIN:1")
        XCTAssertEqual(group.members.count, 3)

        let kitchen = try XCTUnwrap(group.members.first { $0.ipAddress == "192.168.1.102" })
        XCTAssertFalse(kitchen._isCoordinator ?? true)
        XCTAssertTrue(kitchen.zoneGroupState === state)

        let satellite = try XCTUnwrap(group.members.first { $0.ipAddress == "192.168.1.103" })
        XCTAssertTrue(satellite._isSatellite)
        XCTAssertTrue(satellite._satelliteParent === source)
        XCTAssertFalse(state.visibleZones.contains(satellite))
        XCTAssertTrue(satellite.zoneGroupState === state)
    }

    func testPublicUpdateAndMemberParserCompatibilityAPIs() throws {
        let client = MockHTTPClient()
        let source = try SoCo("192.168.1.101", httpClient: client)
        let state = source.zoneGroupState
        let root = try XCTUnwrap(try XMLTree(payload).root)
        let member = try XCTUnwrap(root.descendants(named: "ZoneGroupMember").first)

        let parsed = try state.parseZoneGroupMember(member, httpClient: client)
        XCTAssertTrue(parsed === source)
        XCTAssertEqual(parsed._uid, "RINCON_MAIN")

        state.updateSoCoInstances(root: root, sourceSoCo: source)
        XCTAssertEqual(state.groups.count, 1)
        XCTAssertEqual(state.allZones.count, 3)
        XCTAssertTrue(state.groups.first?.coordinator === source)

        // updateSoCoInstances mirrors the upstream low-level helper and does
        // not itself advance the five-second polling cache. Mark this fixture
        // fresh so bootSeqnum exercises the public compatibility spelling
        // without inventing a network response.
        state.cacheUntil = .distantFuture
        XCTAssertEqual(try source.bootSeqnum(), 44)
    }

    func testNormalizedDuplicateIgnoresMemberOrdering() throws {
        let client = MockHTTPClient()
        let source = try SoCo("192.168.1.101", httpClient: client)
        let state = source.zoneGroupState
        try state.processPayload(payload, sourceSoCo: source)
        XCTAssertEqual(state.processedCount, 1)

        let reordered = """
        <ZoneGroupState>
          <ZoneGroups>
            <ZoneGroup Coordinator="RINCON_MAIN" ID="RINCON_MAIN:1">
              <ZoneGroupMember BootSeq="52" Location="http://192.168.1.102:1400/xml/device_description.xml" UUID="RINCON_KITCHEN" ZoneName="Kitchen" IsZoneBridge="0" />
              <ZoneGroupMember BootSeq="44" Location="http://192.168.1.101:1400/xml/device_description.xml" UUID="RINCON_MAIN" ZoneName="Living Room" VoiceConfigState="1" MicEnabled="1" HTSatChanMapSet="RINCON_MAIN:LF,RF;RINCON_REAR:LR">
                <Satellite BootSeq="9" Location="http://192.168.1.103:1400/xml/device_description.xml" UUID="RINCON_REAR" ZoneName="Rear Left" Invisible="1" />
              </ZoneGroupMember>
            </ZoneGroup>
          </ZoneGroups>
          <VanishedDevices/>
        </ZoneGroupState>
        """
        try state.processPayload(reordered, sourceSoCo: source)
        XCTAssertEqual(state.totalRequests, 2)
        XCTAssertEqual(state.processedCount, 1, "Reordering equivalent ZGS children must not force reprocessing")
    }

    func testPollCachesForFiveSecondsAndReturnsGroupPropertiesWithoutExtraPolls() throws {
        let client = MockHTTPClient()
        let source = try SoCo("192.168.1.101", httpClient: client)
        client.enqueue(text: soapResponse(action: "GetZoneGroupState", serviceType: "ZoneGroupTopology", fields: [("ZoneGroupState", payload)]))
        try source.zoneGroupState.poll(source)
        try source.zoneGroupState.poll(source)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(source.zoneGroupState.totalRequests, 2)

        // Parsed members share this same cached state, so labels should not make
        // one GetZoneGroupState request per speaker.
        let group = try XCTUnwrap(try source.group())
        XCTAssertEqual(group.label, "Kitchen, Living Room, Rear Left")
        XCTAssertEqual(group.shortLabel, "Kitchen + 2")
        XCTAssertEqual(client.requests.count, 1)
    }

    func testSatellitePollUsesParent() throws {
        let client = MockHTTPClient()
        let parent = try SoCo("192.168.1.101", httpClient: client)
        let satellite = try SoCo("192.168.1.103", httpClient: client)
        satellite._isSatellite = true
        satellite._satelliteParent = parent
        satellite.zoneGroupState = parent.zoneGroupState

        client.enqueue(text: soapResponse(action: "GetZoneGroupState", serviceType: "ZoneGroupTopology", fields: [("ZoneGroupState", payload)]))
        try satellite.zoneGroupState.poll(satellite)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].url.host, "192.168.1.101")
    }

    func testLargeSystemFallbackCanBeDisabled() throws {
        let client = MockHTTPClient()
        let source = try SoCo("192.168.1.101", httpClient: client)
        client.enqueue(statusCode: 501, text: "failure")
        SoCoConfig.zoneGroupTopologyEventFallback = false
        defer { SoCoConfig.zoneGroupTopologyEventFallback = true }
        XCTAssertThrowsError(try source.zoneGroupState.poll(source)) { error in
            guard case SoCoError.unsupported = error else { return XCTFail("Expected unsupported, got \(error)") }
        }
    }

    func testGroupVolumeMuteAndRelativeVolumeWireContract() throws {
        let client = MockHTTPClient()
        let coordinator = try SoCo("192.168.1.101", httpClient: client)
        coordinator._playerName = "Kitchen"
        let group = ZoneGroup(uid: "group", coordinator: coordinator, members: [coordinator])

        client.enqueue(text: soapResponse(action: "SnapshotGroupVolume", serviceType: "GroupRenderingControl"))
        client.enqueue(text: soapResponse(action: "GetGroupVolume", serviceType: "GroupRenderingControl", fields: [("CurrentVolume", "42")]))
        XCTAssertEqual(try group.volume(), 42)

        client.enqueue(text: soapResponse(action: "SnapshotGroupVolume", serviceType: "GroupRenderingControl"))
        client.enqueue(text: soapResponse(action: "SetGroupVolume", serviceType: "GroupRenderingControl"))
        try group.setVolume(123)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredVolume>100</DesiredVolume>"))

        client.enqueue(text: soapResponse(action: "GetGroupMute", serviceType: "GroupRenderingControl", fields: [("CurrentMute", "1")]))
        XCTAssertTrue(try group.muted())
        client.enqueue(text: soapResponse(action: "SetGroupMute", serviceType: "GroupRenderingControl"))
        try group.setMuted(false)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredMute>0</DesiredMute>"))

        client.enqueue(text: soapResponse(action: "SnapshotGroupVolume", serviceType: "GroupRenderingControl"))
        client.enqueue(text: soapResponse(action: "SetRelativeGroupVolume", serviceType: "GroupRenderingControl", fields: [("NewVolume", "35")]))
        XCTAssertEqual(try group.setRelativeVolume(-7), 35)
    }
}
