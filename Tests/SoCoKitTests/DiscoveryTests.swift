import XCTest
@testable import SoCoKit
#if os(Linux)
import Glibc
#else
import Darwin
#endif
final class DiscoveryTests: XCTestCase {
    private let interfaces = [
        IPv4InterfaceInfo(address: "192.168.0.1", prefixLength: 24),
        IPv4InterfaceInfo(address: "192.168.1.1", prefixLength: 16),
        IPv4InterfaceInfo(address: "15.100.100.100", prefixLength: 8),
        IPv4InterfaceInfo(address: "127.0.0.1", prefixLength: 24),
        IPv4InterfaceInfo(address: "169.254.1.10", prefixLength: 16),
    ]

    func testPlayerSearchContainsOriginalZonePlayerTarget() {
        XCTAssertTrue(Discovery.playerSearch.contains("M-SEARCH * HTTP/1.1"))
        XCTAssertTrue(Discovery.playerSearch.contains("HOST: 239.255.255.250:1900"))
        XCTAssertTrue(Discovery.playerSearch.contains("MAN: \"ssdp:discover\""))
        XCTAssertTrue(Discovery.playerSearch.contains("MX: 1"))
        XCTAssertTrue(Discovery.playerSearch.contains("ST: urn:schemas-upnp-org:device:ZonePlayer:1"))
    }

    func testFindIPv4NetworksMatchesSoCoRules() {
        let at24 = findIPv4Networks(minNetmask: 24, interfaces: interfaces)
        XCTAssertTrue(at24.contains(IPv4Network(address: "192.168.0.55", prefixLength: 24)))
        XCTAssertTrue(at24.contains(IPv4Network(address: "192.168.1.1", prefixLength: 24)))
        XCTAssertFalse(at24.contains(IPv4Network(address: "192.168.1.1", prefixLength: 16)))

        let at16 = findIPv4Networks(minNetmask: 16, interfaces: interfaces)
        XCTAssertTrue(at16.contains(IPv4Network(address: "192.168.1.1", prefixLength: 16)))
        XCTAssertFalse(at16.contains(IPv4Network(address: "15.100.100.100", prefixLength: 8)))
        XCTAssertFalse(at16.contains(IPv4Network(address: "127.0.0.1", prefixLength: 24)))
        XCTAssertFalse(at16.contains(IPv4Network(address: "169.254.1.10", prefixLength: 16)))
    }

    func testFindIPv4AddressesExcludesOnlyLoopbackAndLinkLocal() {
        XCTAssertEqual(
            findIPv4Addresses(interfaces: interfaces),
            Set(["192.168.0.1", "192.168.1.1", "15.100.100.100"])
        )
    }

    func testIPv4NetworkParsingAndEnumeration() {
        let network = IPv4Network("192.168.7.99/30")
        XCTAssertEqual(network?.description, "192.168.7.96/30")
        XCTAssertEqual(network?.addressCount, 4)
        XCTAssertEqual(network?.address(at: 0), "192.168.7.96")
        XCTAssertEqual(network?.address(at: 3), "192.168.7.99")
        XCTAssertNil(network?.address(at: 4))
        XCTAssertEqual(IPv4Network("10.1.2.3")?.description, "10.1.2.3/32")
        XCTAssertNil(IPv4Network("not_a_network"))
        XCTAssertNil(IPv4Network("192.168.1.1/33"))
        XCTAssertNil(IPv4Network(""))
    }

    func testCheckIPAndPortAgainstRealLocalListener() throws {
        let listener = try makeListeningSocket()
        defer { closeSocket(listener.fd) }

        XCTAssertTrue(
            checkIPAndPort("127.0.0.1", port: listener.port, timeout: 0.2)
        )
        XCTAssertFalse(checkIPAndPort("not-an-ip", port: listener.port, timeout: 0.01))

        // Once the listening socket is closed, the same endpoint should reject
        // new connections instead of being reported as open.
        closeSocket(listener.fd)
        XCTAssertFalse(
            checkIPAndPort("127.0.0.1", port: listener.port, timeout: 0.05)
        )
    }

    func testScanWorkerStopsAfterFirstHitUnlessExhaustive() {
        let network = IPv4Network("192.168.0.0/29")!
        let open = Set(["192.168.0.1", "192.168.0.2"])
        let sonos = Set(["192.168.0.1", "192.168.0.2"])

        let first = scanIPAddresses(
            networks: [network],
            maxThreads: 4,
            socketTimeout: 0.1,
            multiHousehold: false,
            portChecker: { ip, _ in open.contains(ip) },
            sonosChecker: { sonos.contains($0) }
        )
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(open.contains(first[0]))

        let all = scanIPAddresses(
            networks: [network],
            maxThreads: 4,
            socketTimeout: 0.1,
            multiHousehold: true,
            portChecker: { ip, _ in open.contains(ip) },
            sonosChecker: { sonos.contains($0) }
        )
        XCTAssertEqual(Set(all), sonos)
    }

    func testScanWorkerWithZeroThreadsFindsNothing() {
        let network = IPv4Network("192.168.0.0/30")!
        XCTAssertEqual(
            scanIPAddresses(
                networks: [network],
                maxThreads: 0,
                socketTimeout: 0.1,
                multiHousehold: true,
                portChecker: { _, _ in true },
                sonosChecker: { _ in true }
            ),
            []
        )
    }

    func testIsSonosUsesConfiguredFactoryAndDeviceProperty() throws {
        let oldFactory = SoCoConfig.socoFactory
        defer { SoCoConfig.socoFactory = oldFactory }

        let client = MockHTTPClient()
        let state = """
        <ZoneGroupState><ZoneGroups>
          <ZoneGroup Coordinator="RINCON_TEST" ID="RINCON_TEST:1">
            <ZoneGroupMember UUID="RINCON_TEST"
              Location="http://192.168.0.1:1400/xml/device_description.xml"
              ZoneName="Kitchen" Invisible="0"/>
          </ZoneGroup>
        </ZoneGroups><VanishedDevices/></ZoneGroupState>
        """
        client.enqueue(text: soapZoneGroupStateResponse(state))

        SoCoConfig.socoFactory = { ip in
            guard ip == "192.168.0.1" else { throw SoCoError.noDeviceFound }
            return try SoCo(ip, httpClient: client)
        }

        XCTAssertTrue(isSonos("192.168.0.1"))
        XCTAssertFalse(isSonos("192.168.0.3"))
    }

    func testScanNetworkIgnoresInvalidExplicitNetworks() throws {
        let options = Discovery.NetworkScanOptions(
            networksToScan: ["not_a_network", ""]
        )
        XCTAssertNil(try Discovery.scanNetwork(options: options))
    }

    func testDiscoverRejectsInvalidInterfaceAddressBeforeOpeningSocket() {
        XCTAssertThrowsError(
            try Discovery.discover(timeout: 0, interfaceAddress: "definitely-not-an-ip")
        ) { error in
            XCTAssertEqual(
                error as? SoCoError,
                .invalidArgument("definitely-not-an-ip is not a valid IP address string")
            )
        }
    }

    func testPublicScanNetworkEndToEndAgainstLocalTCPListener() throws {
        let oldPort = SoCoConfig.sonosPort
        let oldFactory = SoCoConfig.socoFactory
        defer {
            SoCoConfig.sonosPort = oldPort
            SoCoConfig.socoFactory = oldFactory
        }

        let listener = try makeListeningSocket()
        defer { closeSocket(listener.fd) }
        SoCoConfig.sonosPort = listener.port

        let client = MockHTTPClient()
        let zone = try SoCo("127.0.0.1", httpClient: client)
        let state = """
        <ZoneGroupState><ZoneGroups><ZoneGroup Coordinator="RINCON_LOCAL" ID="RINCON_LOCAL:1"><ZoneGroupMember UUID="RINCON_LOCAL" ZoneName="Kitchen" Location="http://127.0.0.1:1400/xml/device_description.xml" Invisible="0"/></ZoneGroup></ZoneGroups></ZoneGroupState>
        """
        try zone.zoneGroupState.processPayload(state, sourceSoCo: zone)
        zone.zoneGroupState.cacheUntil = .distantFuture
        zone._householdID = "Sonos_HOUSE_A"
        SoCoConfig.socoFactory = { ip in
            guard ip == "127.0.0.1" else { throw SoCoError.noDeviceFound }
            return zone
        }

        let options = Discovery.NetworkScanOptions(
            multiHousehold: true,
            maxThreads: 1,
            scanTimeout: 0.2,
            networksToScan: ["127.0.0.1/32"]
        )
        let result = try XCTUnwrap(Discovery.scanNetwork(options: options))
        XCTAssertEqual(result, Set([zone]))
    }

    func testPublicHouseholdScanUsesSubstringMatchingLikeUpstream() throws {
        let oldPort = SoCoConfig.sonosPort
        let oldFactory = SoCoConfig.socoFactory
        defer {
            SoCoConfig.sonosPort = oldPort
            SoCoConfig.socoFactory = oldFactory
        }
        let listener = try makeListeningSocket()
        defer { closeSocket(listener.fd) }
        SoCoConfig.sonosPort = listener.port

        let zone = try SoCo("127.0.0.1", httpClient: MockHTTPClient())
        let state = "<ZoneGroups><ZoneGroup Coordinator=\"RINCON_LOCAL2\" ID=\"RINCON_LOCAL2:1\"><ZoneGroupMember UUID=\"RINCON_LOCAL2\" ZoneName=\"Study\" Location=\"http://127.0.0.1:1400/xml/device_description.xml\" Invisible=\"0\"/></ZoneGroup></ZoneGroups>"
        try zone.zoneGroupState.processPayload(state, sourceSoCo: zone)
        zone.zoneGroupState.cacheUntil = .distantFuture
        zone._householdID = "Sonos_ABCDEF"
        SoCoConfig.socoFactory = { _ in zone }

        let options = Discovery.NetworkScanOptions(maxThreads: 1, scanTimeout: 0.2, networksToScan: ["127.0.0.1/32"])
        XCTAssertEqual(try Discovery.scanNetworkByHouseholdID("ABC", options: options), Set([zone]))
    }

    func testContactableChecksForSuccessfulTopologyAccessNotVisibilityTruthiness() throws {
        let reachable = try SoCo("192.168.55.1", httpClient: MockHTTPClient())
        let state = "<ZoneGroups><ZoneGroup Coordinator=\"RINCON_REACHABLE\" ID=\"RINCON_REACHABLE:1\"><ZoneGroupMember UUID=\"RINCON_REACHABLE\" ZoneName=\"Hidden-but-contactable\" Location=\"http://192.168.55.1:1400/xml/device_description.xml\" Invisible=\"1\"/></ZoneGroup></ZoneGroups>"
        try reachable.zoneGroupState.processPayload(state, sourceSoCo: reachable)
        reachable.zoneGroupState.cacheUntil = .distantFuture

        let unreachable = try SoCo("192.168.55.2", httpClient: MockHTTPClient())
        let result = Discovery.contactable(Set([reachable, unreachable]))
        XCTAssertTrue(result.contains(reachable), "upstream treats a successful is_visible read as contactable even when the value itself is false")
        XCTAssertFalse(result.contains(unreachable))
        XCTAssertEqual(Discovery.contactable(nil), [])
    }

    private func soapZoneGroupStateResponse(_ state: String) -> String {
        """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
              <ZoneGroupState>\(xmlEscape(state))</ZoneGroupState>
            </u:GetZoneGroupStateResponse>
          </s:Body>
        </s:Envelope>
        """
    }

    private func makeListeningSocket() throws -> (fd: Int32, port: UInt16) {
        #if os(Linux)
        let kind = Int32(SOCK_STREAM.rawValue)
        #else
        let kind = SOCK_STREAM
        #endif
        let fd = socket(AF_INET, kind, 0)
        guard fd >= 0 else { throw SoCoError.unknown("Could not create test socket") }

        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        _ = "127.0.0.1".withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                systemBind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 4) == 0 else {
            closeSocket(fd)
            throw SoCoError.unknown("Could not bind/listen on test socket")
        }

        var actual = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &actual) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard got == 0 else {
            closeSocket(fd)
            throw SoCoError.unknown("Could not inspect test socket")
        }
        return (fd, UInt16(bigEndian: actual.sin_port))
    }

    private func closeSocket(_ fd: Int32) {
        #if os(Linux)
        _ = Glibc.close(fd)
        #else
        _ = Darwin.close(fd)
        #endif
    }
}
