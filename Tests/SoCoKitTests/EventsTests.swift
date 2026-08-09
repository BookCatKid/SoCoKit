import XCTest
@testable import SoCoKit
#if os(Linux)
import Glibc
#else
import Darwin
#endif

private final class FakeEventListener: EventListening {
    var isRunning = false
    var address: (ip: String, port: UInt16)? = ("192.168.1.50", 1400)
    var startCount = 0
    var stopCount = 0

    func start(anyZone: SoCo) throws {
        startCount += 1
        isRunning = true
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }
}


private final class RecordingEventNotifyHandler: EventNotifyHandler {
    var logs: [(seq: String, serviceID: String, timestamp: TimeInterval)] = []

    override func logEvent(seq: String, serviceID: String, timestamp: TimeInterval) {
        logs.append((seq, serviceID, timestamp))
    }
}

final class EventsTests: XCTestCase {
    func testEventObjectIsReadOnlyAndSubscriptExposesVariables() throws {
        let soco = try SoCo("192.168.1.101", httpClient: MockHTTPClient())
        let service = DeviceProperties(soco)
        let event = Event(
            sid: "123",
            seq: "456",
            service: service,
            timestamp: 123456.7,
            variables: ["zone": .string("kitchen")]
        )

        XCTAssertEqual(event.sid, "123")
        XCTAssertEqual(event.seq, "456")
        XCTAssertEqual(event.timestamp, 123456.7)
        XCTAssertTrue(event.service === service)
        XCTAssertEqual(event["zone"]?.stringValue, "kitchen")
        XCTAssertNil(event["non_existent"])
    }

    func testEventParsingBasicProperties() throws {
        let xml = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property><AlarmRunSequence>RINCON_000EXXXXXX0:56:0</AlarmRunSequence></e:property>
          <e:property><ZoneGroupName>Kitchen</ZoneGroupName></e:property>
          <e:property><ZoneGroupID>RINCON_000XXXX01400:57</ZoneGroupID></e:property>
          <e:property><ZoneGroupState>&lt;ZoneGroups&gt;&lt;/ZoneGroups&gt;</ZoneGroupState></e:property>
        </e:propertyset>
        """
        let values = try parseEventXML(xml)
        XCTAssertNotNil(values["zone_group_state"]?.stringValue)
        XCTAssertEqual(values["alarm_run_sequence"]?.stringValue, "RINCON_000EXXXXXX0:56:0")
        XCTAssertEqual(values["zone_group_id"]?.stringValue, "RINCON_000XXXX01400:57")
    }

    func testEventParsingLineInDIDL() throws {
        let xml = try fixtureText("data_structures_entry_integration/source_linein.xml")
        let values = try parseEventXML(xml)
        let lineIn = try XCTUnwrap(values["av_transport_uri_meta_data"]?.didlObject as? DidlAudioLineIn)
        XCTAssertEqual(lineIn.didlClass, "object.item.audioItem.linein")
        XCTAssertEqual(lineIn.title, "loadLineIn")
    }

    func testEventParsingNullLastChangeValue() throws {
        let xml = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0"><e:property><LastChange>
        &lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
        &lt;InstanceID val="0"&gt;&lt;CurrentTrackURI/&gt;&lt;/InstanceID&gt;&lt;/Event&gt;
        </LastChange></e:property></e:propertyset>
        """
        let values = try parseEventXML(xml)
        XCTAssertNotNil(values["current_track_uri"])
        XCTAssertNil(values["current_track_uri"]?.stringValue)
    }

    func testEventParsingPerChannelValues() throws {
        let xml = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0"><e:property><LastChange>
        &lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/RCS/"&gt;
        &lt;InstanceID val="0"&gt;
        &lt;Volume channel="Master" val="36"/&gt;
        &lt;Volume channel="LF" val="100"/&gt;
        &lt;Volume channel="RF" val="100"/&gt;
        &lt;/InstanceID&gt;&lt;/Event&gt;
        </LastChange></e:property></e:propertyset>
        """
        let channels = try XCTUnwrap(try parseEventXML(xml)["volume"]?.channelValues)
        XCTAssertEqual(channels["Master"]?.stringValue, "36")
        XCTAssertEqual(channels["LF"]?.stringValue, "100")
        XCTAssertEqual(channels["RF"]?.stringValue, "100")
    }

    func testIllegalDIDLBecomesSoCoFaultRatherThanFailingWholeEvent() throws {
        let xml = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0"><e:property><LastChange>
        &lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
        &lt;InstanceID val="0"&gt;
        &lt;CurrentTrackMetaData val="&amp;lt;DIDL-Lite&amp;gt;&amp;lt;broken&amp;gt;"/&gt;
        &lt;/InstanceID&gt;&lt;/Event&gt;
        </LastChange></e:property></e:propertyset>
        """
        let value = try XCTUnwrap(try parseEventXML(xml)["current_track_meta_data"])
        guard case .fault = value else {
            return XCTFail("Expected malformed embedded DIDL to become SoCoFault")
        }
        XCTAssertThrowsError(try value.resolvedDIDL())
    }

    func testEventQueueBlockingGetAndTimeout() throws {
        let queue = EventQueue()
        XCTAssertThrowsError(try queue.get(timeout: 0.01)) { error in
            XCTAssertEqual(error as? SoCoError, .timeout)
        }

        let soco = try SoCo("192.168.1.101", httpClient: MockHTTPClient())
        let event = Event(sid: "s", seq: "1", service: DeviceProperties(soco))
        queue.put(event)
        XCTAssertEqual(try queue.get(timeout: 0.01).sid, "s")
        XCTAssertEqual(queue.count, 0)
    }

    func testSubscribeRenewUnsubscribeLifecycleAndHeaders() throws {
        let client = MockHTTPClient()
        client.enqueue(headers: ["SID": "uuid:sub-1", "TIMEOUT": "Second-86400"], text: "")
        client.enqueue(headers: ["TIMEOUT": "Second-600"], text: "")
        client.enqueue(statusCode: 200, text: "")

        let soco = try SoCo("192.168.1.101", httpClient: client)
        let listener = FakeEventListener()
        let map = SubscriptionsMap()
        let subscription = Subscription(
            service: soco.zoneGroupTopology,
            eventListener: listener,
            subscriptionsMap: map
        )

        try subscription.subscribe(requestedTimeout: 300)
        XCTAssertEqual(listener.startCount, 1)
        XCTAssertEqual(subscription.sid, "uuid:sub-1")
        XCTAssertEqual(subscription.timeout, 86400)
        XCTAssertTrue(subscription.isSubscribed)
        XCTAssertEqual(map.count, 1)
        XCTAssertTrue(soco.zoneGroupState.hasSubscriptions)

        let subscribeRequest = client.requests[0]
        XCTAssertEqual(subscribeRequest.method, "SUBSCRIBE")
        XCTAssertEqual(subscribeRequest.url.absoluteString, "http://192.168.1.101:1400/ZoneGroupTopology/Event")
        XCTAssertEqual(subscribeRequest.headers["Callback"], "<http://192.168.1.50:1400>")
        XCTAssertEqual(subscribeRequest.headers["NT"], "upnp:event")
        XCTAssertEqual(subscribeRequest.headers["TIMEOUT"], "Second-300")

        try subscription.renew(requestedTimeout: 600)
        XCTAssertEqual(subscription.timeout, 600)
        XCTAssertEqual(client.requests[1].headers["SID"], "uuid:sub-1")
        XCTAssertEqual(client.requests[1].headers["TIMEOUT"], "Second-600")

        try subscription.unsubscribe()
        XCTAssertFalse(subscription.isSubscribed)
        XCTAssertEqual(map.count, 0)
        XCTAssertFalse(soco.zoneGroupState.hasSubscriptions)
        XCTAssertEqual(listener.stopCount, 1)
        XCTAssertEqual(client.requests[2].method, "UNSUBSCRIBE")
        XCTAssertEqual(client.requests[2].headers["SID"], "uuid:sub-1")
        XCTAssertThrowsError(try subscription.subscribe())
    }

    func testInfiniteSubscriptionTimeout() throws {
        let client = MockHTTPClient()
        client.enqueue(headers: ["sid": "uuid:infinite", "timeout": "infinite"], text: "")
        let soco = try SoCo("192.168.1.101", httpClient: client)
        let listener = FakeEventListener()
        let subscription = Subscription(
            service: soco.deviceProperties,
            eventListener: listener,
            subscriptionsMap: SubscriptionsMap()
        )
        try subscription.subscribe()
        XCTAssertNil(subscription.timeout)
        XCTAssertEqual(subscription.timeLeft, .infinity)
    }

    func testNotifyHandlerRoutesEventBySID() throws {
        let client = MockHTTPClient()
        client.enqueue(headers: ["SID": "uuid:notify-1", "TIMEOUT": "Second-60"], text: "")
        let soco = try SoCo("192.168.1.101", httpClient: client)
        let listener = FakeEventListener()
        let map = SubscriptionsMap()
        let subscription = Subscription(
            service: soco.deviceProperties,
            eventListener: listener,
            subscriptionsMap: map
        )
        try subscription.subscribe()

        let xml = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property><ZoneName>Kitchen</ZoneName></e:property>
        </e:propertyset>
        """
        let handler = EventNotifyHandler(subscriptionsMap: map)
        let event = try XCTUnwrap(try handler.handleNotification(
            headers: ["SID": "uuid:notify-1", "SEQ": "7"],
            content: xml
        ))
        XCTAssertEqual(event.seq, "7")
        XCTAssertEqual(event["zone_name"]?.stringValue, "Kitchen")
        XCTAssertEqual(try subscription.events.get(timeout: 0.01).seq, "7")
    }

    func testNotifyForUnknownSubscriptionIsIgnored() throws {
        let handler = EventNotifyHandler(subscriptionsMap: SubscriptionsMap())
        let result = try handler.handleNotification(
            headers: ["SID": "uuid:missing", "SEQ": "1"],
            content: "<e:propertyset xmlns:e=\"urn:schemas-upnp-org:event-1-0\"/>"
        )
        XCTAssertNil(result)
    }

    func testNativeEventListenerAcceptsRealHTTPNotify() throws {
        let oldListenerIP = SoCoConfig.eventListenerIP
        defer { SoCoConfig.eventListenerIP = oldListenerIP }
        SoCoConfig.eventListenerIP = "127.0.0.1"

        let client = MockHTTPClient()
        client.enqueue(headers: ["SID": "uuid:native-listener", "TIMEOUT": "Second-60"], text: "")
        client.enqueue(statusCode: 200, text: "")

        let soco = try SoCo("127.0.0.1", httpClient: client)
        let map = SubscriptionsMap()
        let handler = EventNotifyHandler(subscriptionsMap: map)
        let requestedPort = try reserveEphemeralPort()
        let listener = EventListener(requestedPortNumber: requestedPort, handler: handler)
        defer { listener.stop() }

        let subscription = Subscription(
            service: soco.deviceProperties,
            eventListener: listener,
            subscriptionsMap: map
        )
        try subscription.subscribe()
        let address = try XCTUnwrap(listener.address)
        XCTAssertEqual(address.ip, "127.0.0.1")

        let eventXML = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property><ZoneName>Native Listener</ZoneName></e:property>
        </e:propertyset>
        """
        let response = try sendRawHTTP(
            host: address.ip,
            port: address.port,
            request: """
            NOTIFY / HTTP/1.1\r
            HOST: \(address.ip):\(address.port)\r
            SID: uuid:native-listener\r
            SEQ: 42\r
            CONTENT-TYPE: text/xml; charset=utf-8\r
            CONTENT-LENGTH: \(eventXML.utf8.count)\r
            \r
            \(eventXML)
            """
        )
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200 OK"))

        let event = try subscription.events.get(timeout: 1)
        XCTAssertEqual(event.seq, "42")
        XCTAssertEqual(event["zone_name"]?.stringValue, "Native Listener")

        try subscription.unsubscribe()
        XCTAssertFalse(listener.isRunning)
    }

    func testEventListenerPublicListenStartsAndReturnsBoundPort() throws {
        let requestedPort = try reserveEphemeralPort()
        let listener = EventListener(requestedPortNumber: requestedPort)
        defer { listener.stop() }

        let actualPort = try listener.listen(ipAddress: "127.0.0.1")
        XCTAssertEqual(actualPort, requestedPort)
        XCTAssertTrue(listener.isRunning)
        XCTAssertEqual(listener.address?.ip, "127.0.0.1")
        XCTAssertEqual(listener.address?.port, actualPort)

        // Python EventListenerBase.start/listen are idempotent once running.
        XCTAssertEqual(try listener.listen(ipAddress: "127.0.0.1"), actualPort)
    }

    func testNotifyHandlerCallsUpstreamLoggingHook() throws {
        let client = MockHTTPClient()
        client.enqueue(headers: ["SID": "uuid:notify-log", "TIMEOUT": "Second-60"], text: "")
        let soco = try SoCo("192.168.1.101", httpClient: client)
        let listener = FakeEventListener()
        let map = SubscriptionsMap()
        let subscription = Subscription(
            service: soco.deviceProperties,
            eventListener: listener,
            subscriptionsMap: map
        )
        try subscription.subscribe()

        let handler = RecordingEventNotifyHandler(subscriptionsMap: map)
        _ = try handler.handleNotification(
            headers: ["SID": "uuid:notify-log", "SEQ": "9"],
            content: "<e:propertyset xmlns:e=\"urn:schemas-upnp-org:event-1-0\"/>"
        )

        XCTAssertEqual(handler.logs.count, 1)
        XCTAssertEqual(handler.logs.first?.seq, "9")
        XCTAssertEqual(handler.logs.first?.serviceID, soco.deviceProperties.serviceID)
        XCTAssertGreaterThan(handler.logs.first?.timestamp ?? 0, 0)
        handler.logMessage("ignored %s", "access log")
    }


    private func reserveEphemeralPort() throws -> UInt16 {
        let fd = socket(AF_INET, testStreamSocketType, 0)
        guard fd >= 0 else { throw SoCoError.unknown("Could not create test socket") }
        defer { testClose(fd) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        _ = "127.0.0.1".withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { throw SoCoError.unknown("Could not reserve test port") }

        var actual = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &actual) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard got == 0 else { throw SoCoError.unknown("Could not inspect test port") }
        return UInt16(bigEndian: actual.sin_port)
    }

    private func sendRawHTTP(host: String, port: UInt16, request: String) throws -> String {
        let fd = socket(AF_INET, testStreamSocketType, 0)
        guard fd >= 0 else { throw SoCoError.unknown("Could not create HTTP test socket") }
        defer { testClose(fd) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard host.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else {
            throw SoCoError.invalidArgument("Invalid test host")
        }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { throw SoCoError.unknown("Could not connect to event listener") }

        let bytes = Array(request.utf8)
        let sent = bytes.withUnsafeBytes { buffer -> Int in
            #if os(Linux)
            return send(fd, buffer.baseAddress, buffer.count, Int32(MSG_NOSIGNAL))
            #else
            return send(fd, buffer.baseAddress, buffer.count, 0)
            #endif
        }
        guard sent == bytes.count else { throw SoCoError.unknown("Short write to event listener") }

        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count <= 0 { break }
            response.append(contentsOf: buffer.prefix(Int(count)))
        }
        return String(data: response, encoding: .utf8) ?? ""
    }

    private var testStreamSocketType: Int32 {
        #if os(Linux)
        Int32(SOCK_STREAM.rawValue)
        #else
        SOCK_STREAM
        #endif
    }

    private func testClose(_ fd: Int32) {
        #if os(Linux)
        _ = Glibc.close(fd)
        #else
        _ = Darwin.close(fd)
        #endif
    }

}
