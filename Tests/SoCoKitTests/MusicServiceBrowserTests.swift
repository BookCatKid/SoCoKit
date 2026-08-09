import Foundation
import XCTest
@testable import SoCoKit

final class MusicServiceBrowserTests: XCTestCase {
    private let accountXML = """
    <Accounts><Service UDN="SA_RINCON52231_X_#Svc52231-1a2b3c4d-Token" \
    SerialNum0="35" Username0="user" Password0="pass" Token0="old-token" \
    Key0="old-key" Nickname0="Jennifer" Tier0="paid"/></Accounts>
    """

    override func tearDown() {
        MusicService.resetDescriptorCache()
        super.tearDown()
    }

    func testProtocolCryptoKnownVectors() throws {
        XCTAssertEqual(
            MusicServiceBrowseCrypto.md5(Data("abc".utf8)).hexString,
            "900150983cd24fb0d6963f7d28e17f72"
        )
        XCTAssertEqual(
            MusicServiceBrowseCrypto.sha1(Data("abc".utf8)).hexString,
            "a9993e364706816aba3e25717850c26c9cd0d89d"
        )

        let key = Data(hex: "000102030405060708090a0b0c0d0e0f")!
        let iv = Data(hex: "101112131415161718191a1b1c1d1e1f")!
        let ciphertext = Data(hex: "cda122e671f0f91095f426334e422b2b")!
        XCTAssertEqual(
            try MusicServiceBrowseCrypto.aes128CBCDecrypt(
                ciphertext: ciphertext, key: key, iv: iv
            ),
            Data("hello world".utf8)
        )
    }

    func testConfiguredAccountCaptureIgnoresUnrelatedTopologyEvents() throws {
        let device = try SoCo("192.168.1.240", httpClient: MockHTTPClient())
        let service = device.zoneGroupTopology
        let events = EventQueue()
        events.put(Event(
            sid: "sid",
            seq: "1",
            service: service,
            variables: ["zone_group_state": .string("<ZoneGroups/>")]
        ))
        events.put(Event(
            sid: "sid",
            seq: "2",
            service: service,
            variables: ["third_party_media_servers_x": .string("2:payload")]
        ))

        XCTAssertEqual(
            try waitForConfiguredAccountEvent(events, timeout: 0.5),
            "2:payload"
        )
    }

    func testDecryptAndParseConfiguredAccountEnvelope() throws {
        let encoded = "2:ABEiM0RVZneImaq7zN3u/0+jSKC8wEKdyQvTQBvDVQdURsbfT0xUpatFIXc/"
            + "RUfsTOuAwTd4N7iwegKGsUFCmrG4N+ek4v1pPt0hxkr+B/0kRAL/32lU2HyrqVAs"
            + "NTlhljJ9ilnGp9kecAO0eF/e2YOnxRijAgUUN30nK2NIM38BxDCyC5IeSkskHcs9"
            + "zCSq444X9l+Vx6oXuckvWnat0dRd8SNU/JW8xrUxc+GvTnjc1/Mt6IozwadC8f0R+"
            + "Ce05BLgc5o3H3oneytVHapwrtfJeqctX26UDGBmUD3PKdA="
        let payload = try decryptAccountPayload(encoded, householdID: "Sonos_TestHousehold")
        XCTAssertEqual(String(data: payload, encoding: .utf8), accountXML)

        let accounts = try ConfiguredMusicServiceAccount.fromPayload(payload)
        XCTAssertEqual(accounts.count, 1)
        let account = try XCTUnwrap(accounts.first)
        XCTAssertEqual(account.serviceID, 204)
        XCTAssertEqual(account.schemaRevision, 7)
        XCTAssertEqual(account.serialNumber, 35)
        XCTAssertEqual(account.nickname, "Jennifer")
        XCTAssertEqual(account.token, "old-token")
        XCTAssertEqual(account.key, "old-key")
        XCTAssertEqual(try account.accountUID, 0x1a2b3c4d)
        XCTAssertFalse(account.description.contains("old-token"))
    }

    func testBrowserEnablesCredentialRefreshByDefault() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in self.descriptorXML() }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.23", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)

        let browser = try MusicServiceBrowser(
            serviceName: "Example",
            account: configuredAccount(),
            device: device
        )

        XCTAssertTrue(browser.allowCredentialRefresh)
    }

    func testStableControllerIDMatchesPythonUUID5() {
        XCTAssertEqual(
            stableControllerID(householdID: "Sonos_Test", deviceID: "DEV123"),
            "d61e7cb6-bef3-5f9d-a474-81f2686f7ce3"
        )
    }

    func testSMAPIDefaultRefreshUsesBearerThenRetriesInMemory() throws {
        let context = try makeService(
            name: "Amazon Music",
            serviceID: 201,
            auth: "AppLink",
            capabilities: 8
        )
        let account = configuredAccount(serviceID: 201)
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: account,
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "America/Los_Angeles",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )

        context.http.enqueue(statusCode: 500, text: tokenRefreshFault)
        context.http.enqueue(text: refreshResponse(token: "new-token", key: "new-key"))
        context.http.enqueue(text: metadataResponse)

        let page = try client.getMetadata()

        XCTAssertEqual(page.records.count, 2)
        XCTAssertEqual(account.token, "new-token")
        XCTAssertEqual(account.key, "new-key")
        let requests = Array(context.http.requests.dropFirst())
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[0].headers["Authorization"], "Bearer old-token")
        XCTAssertNil(requests[1].headers["Authorization"])
        XCTAssertTrue(requestBodyText(requests[1]).contains("<token>old-token</token>"))
        XCTAssertTrue(requestBodyText(requests[1]).contains("<key>old-key</key>"))
        XCTAssertEqual(requests[2].headers["Authorization"], "Bearer new-token")
    }

    func testSMAPILegacyNormalizationAndArtwork() throws {
        let context = try makeService(capabilities: 1 << 16)
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: configuredAccount(),
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "America/Los_Angeles",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )
        context.http.enqueue(text: metadataResponse)

        let page = try client.getMetadata()

        XCTAssertEqual(page.records[0]["kind"]?.stringValue, "mediaCollection")
        XCTAssertEqual(page.records[0]["album_art_uri"]?.stringValue, "https://img/400/400")
        XCTAssertEqual(page.records[1]["kind"]?.stringValue, "mediaMetadata")
        let body = requestBodyText(try XCTUnwrap(context.http.requests.last))
        XCTAssertTrue(body.contains("<timeZone>America/Los_Angeles</timeZone>"))
    }

    func testAppleSonosError999RetriesIdenticalMetadataRequest() throws {
        let context = try makeService()
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: configuredAccount(),
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "UTC",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )
        context.http.enqueue(text: transient999Fault)
        context.http.enqueue(text: metadataResponse)

        let page = try client.getMetadata()

        XCTAssertEqual(page.records.count, 2)
        XCTAssertEqual(context.http.requests.count, 3) // GetString + two metadata attempts.
    }

    func testDeviceLinkWithoutStoredTokenUsesSessionID() throws {
        let context = try makeService(auth: "DeviceLink")
        let account = ConfiguredMusicServiceAccount(
            serviceID: 204,
            serialNumber: 3,
            udn: "SA_RINCON52231_X_#Svc204-00abcdef-Token",
            username: "user",
            password: "password"
        )
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: account,
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "UTC",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )
        context.http.enqueue(text: sessionResponse)
        context.http.enqueue(text: metadataResponse)

        _ = try client.getMetadata()

        let requests = Array(context.http.requests.dropFirst())
        XCTAssertTrue(requestBodyText(requests[0]).contains("<getSessionId"))
        XCTAssertTrue(requestBodyText(requests[1]).contains("<sessionId>session-123</sessionId>"))
    }

    func testUserIDPasswordCredentialsStayInSOAP() throws {
        let context = try makeService(auth: "UserIdPassword")
        let account = ConfiguredMusicServiceAccount(
            serviceID: 204,
            serialNumber: 3,
            udn: "SA_RINCON52231_X_#Svc204-00abcdef-Token",
            username: "user",
            password: "password"
        )
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: account,
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "UTC",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )
        context.http.enqueue(text: metadataResponse)

        _ = try client.getMetadata()

        let request = try XCTUnwrap(context.http.requests.last)
        XCTAssertNil(request.headers["Authorization"])
        XCTAssertTrue(requestBodyText(request).contains("<username>user</username>"))
        XCTAssertTrue(requestBodyText(request).contains("<password>password</password>"))
    }

    func testEmbeddedReplacementCredentialsAreUsed() throws {
        let context = try makeService(capabilities: 0)
        let account = configuredAccount()
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: account,
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "UTC",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )
        context.http.enqueue(statusCode: 500, text: embeddedRefreshFault)
        context.http.enqueue(text: metadataResponse)

        _ = try client.getMetadata()

        XCTAssertEqual(account.token, "replacement-token")
        XCTAssertEqual(account.key, "replacement-key")
        XCTAssertEqual(context.http.requests.count, 3)
    }


    func testCredentialRefreshCanBeExplicitlyDisabled() throws {
        let context = try makeService(
            name: "Amazon Music",
            serviceID: 201,
            auth: "AppLink",
            capabilities: 8
        )
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: configuredAccount(serviceID: 201),
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "UTC",
            explicitContent: false,
            allowCredentialRefresh: false,
            httpClient: context.http
        )
        context.http.enqueue(statusCode: 500, text: tokenRefreshFault)

        XCTAssertThrowsError(try client.getMetadata()) { error in
            guard case SoCoError.musicServiceAuth(let message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message.contains("TokenRefreshRequired"))
        }
        XCTAssertEqual(context.http.requests.count, 2)
    }

    func testAnonymousBrowserDoesNotNeedConfiguredAccountCapture() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in
            self.descriptorXML(auth: "Anonymous")
        }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.23", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)

        let browser = try MusicServiceBrowser(serviceName: "Example", device: device)

        XCTAssertEqual(browser.account.serialNumber, 0)
        XCTAssertEqual(browser.account.token, "")
        XCTAssertEqual(http.requests.count, 1)
    }

    func testSearchUsesExistingPresentationMap() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in
            self.descriptorXML(
                presentationMapURI: "https://example.invalid/pmap.xml"
            )
        }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.24", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        http.enqueue(text: """
        <Presentation><PresentationMap type="Search"><Match>
          <SearchCategories><Category id="tracks" mappedId="search:track"/></SearchCategories>
        </Match></PresentationMap></Presentation>
        """)
        http.enqueue(text: searchResponse)

        let browser = try MusicServiceBrowser(
            serviceName: "Example",
            account: configuredAccount(),
            device: device
        )
        let result = try browser.search(category: "tracks", term: "hello")

        XCTAssertEqual(result.items.first?.itemID, "track:1")
        XCTAssertEqual(result.items.first?.artist, "Artist")
        let body = requestBodyText(try XCTUnwrap(http.requests.last))
        XCTAssertTrue(body.contains("<id>search:track</id>"))
        XCTAssertTrue(body.contains("<term>hello</term>"))
    }

    func testContent401RefreshAndAppleContentToSMAPIHandoff() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in
            self.descriptorXML(
                name: "Apple Music",
                serviceID: 204,
                auth: "AppLink",
                capabilities: 8,
                manifestURI: "https://content.invalid/manifest.json"
            )
        }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.20", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        http.enqueue(text: #"{"endpoints":[{"type":"browse","uri":"https://content.invalid/browse/v1"}]}"#)
        http.enqueue(statusCode: 401, text: "")
        http.enqueue(text: refreshResponse(token: "new-token", key: "new-key"))
        http.enqueue(text: contentRootJSON)
        http.enqueue(text: artistMetadataResponse)

        let account = configuredAccount()
        let browser = try MusicServiceBrowser(
            serviceName: "Apple Music",
            account: account,
            device: device
        )
        XCTAssertEqual(browser.rootTransport, .content)

        let root = try browser.getMetadata()
        XCTAssertEqual(root.transport, .content)
        let library = try XCTUnwrap(root.items.first)
        XCTAssertEqual(library.sourceTransport, .contentSection)

        let embedded = try browser.getMetadata(item: library)
        let artists = try XCTUnwrap(embedded.items.first)
        XCTAssertEqual(artists.itemID, "libraryfolder:f.1")
        XCTAssertEqual(artists.sourceTransport, .content)

        let artistsPage = try browser.getMetadata(item: artists)
        XCTAssertEqual(artistsPage.transport, .smapi)
        XCTAssertEqual(artistsPage.items.first?.title, "A Fine Frenzy")

        let requests = Array(http.requests.dropFirst())
        XCTAssertEqual(requests[1].headers["Authorization"], "Bearer old-token")
        XCTAssertEqual(requests[1].headers["X-Sonos-Device-Id"], "Sonos_Test_1a2b3c4d")
        XCTAssertNil(requests[2].headers["Authorization"])
        XCTAssertEqual(requests[3].headers["Authorization"], "Bearer new-token")
        XCTAssertEqual(requests[4].headers["Authorization"], "Bearer new-token")
        XCTAssertTrue(
            requestBodyText(requests[4]).contains(
                "<householdId>Sonos_Test_1a2b3c4d</householdId>"
            )
        )
    }

    func testManifestWithoutBrowseEndpointFallsBackToSMAPI() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in
            self.descriptorXML(
                manifestURI: "https://content.invalid/manifest.json"
            )
        }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.21", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        http.enqueue(text: #"{"endpoints":[]}"#)
        http.enqueue(text: metadataResponse)

        let browser = try MusicServiceBrowser(
            serviceName: "Example",
            account: configuredAccount(),
            device: device
        )
        XCTAssertEqual(browser.rootTransport, .smapi)
        XCTAssertEqual(try browser.getMetadata().transport, .smapi)
    }

    func testGetMediaMetadataRemainsReadOnly() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in self.descriptorXML() }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.22", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        http.enqueue(text: mediaMetadataResponse)

        let browser = try MusicServiceBrowser(
            serviceName: "Example",
            account: configuredAccount(),
            device: device
        )
        let metadata = try browser.getMediaMetadata(itemID: "track:1")

        XCTAssertEqual(metadata["id"]?.stringValue, "track:1")
        XCTAssertEqual(metadata["album_art_uri"]?.stringValue, "https://img/cover.jpg")
        let body = requestBodyText(try XCTUnwrap(http.requests.last))
        XCTAssertTrue(body.contains("<getMediaMetadata"))
        XCTAssertFalse(body.contains("AddAccountX"))
        XCTAssertFalse(body.contains("AddOAuthAccountX"))
    }

    func testMalformedSonosRadioXSIPrefixIsTolerated() throws {
        let context = try makeService()
        let client = ConfiguredSMAPIClient(
            musicService: context.service,
            account: configuredAccount(),
            device: context.device,
            householdID: "Sonos_Test",
            deviceID: "DEV123",
            controllerID: "controller",
            timeZone: "UTC",
            explicitContent: false,
            allowCredentialRefresh: true,
            httpClient: context.http
        )
        context.http.enqueue(
            text: metadataResponse.replacingOccurrences(
                of: "<index>0</index>",
                with: #"<index xsi:nil="true">0</index>"#
            )
        )
        XCTAssertEqual(try client.getMetadata().records.count, 2)
    }

    func testBrowseItemPlayabilityCoversSMAPIAndContentTracks() {
        let smapi = MusicServiceBrowseItem(
            itemID: "track:1", title: "Track", kind: "mediaMetadata", itemType: "track"
        )
        let content = MusicServiceBrowseItem(
            itemID: "content:1", title: "Track", kind: "mediaMetadata",
            sourceTransport: .content
        )
        let explicitlyDisabled = MusicServiceBrowseItem(
            itemID: "track:2", title: "Disabled", kind: "mediaMetadata", itemType: "track",
            raw: ["canPlay": .bool(false)]
        )

        XCTAssertTrue(smapi.canPlay)
        XCTAssertTrue(content.canPlay)
        XCTAssertFalse(explicitlyDisabled.canPlay)
    }

    func testPlaybackDescriptorPrefersProviderMediaURIAndCarriesAccountDescriptor() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in self.descriptorXML() }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.25", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        http.enqueue(text: mediaURIResponse("x-sonos-http:provider-track"))

        let browser = try MusicServiceBrowser(
            serviceName: "Example", account: configuredAccount(), device: device
        )
        let item = MusicServiceBrowseItem(
            itemID: "track:abc", title: "Playable", kind: "mediaMetadata", itemType: "track"
        )
        let descriptor = try browser.playbackDescriptor(for: item)

        XCTAssertEqual(descriptor.uri, "x-sonos-http:provider-track")
        XCTAssertTrue(descriptor.metadata.contains("SA_RINCON52231_X_#Svc52231-1a2b3c4d-Token"))
        XCTAssertTrue(descriptor.metadata.contains("Playable"))
        XCTAssertTrue(requestBodyText(try XCTUnwrap(http.requests.last)).contains("<getMediaURI"))
        XCTAssertTrue(requestBodyText(try XCTUnwrap(http.requests.last)).contains("<id>track:abc</id>"))
    }

    func testPlaybackDescriptorFallbackUsesActualAccountSerialNumber() throws {
        let oldLoader = MusicService.descriptorLoader
        defer {
            MusicService.descriptorLoader = oldLoader
            MusicService.resetDescriptorCache()
        }
        MusicService.descriptorLoader = { _ in self.descriptorXML() }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.26", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        http.enqueue(statusCode: 500, text: "provider failure")

        let browser = try MusicServiceBrowser(
            serviceName: "Example", account: configuredAccount(), device: device
        )
        let item = MusicServiceBrowseItem(
            itemID: "track:abc", title: "Playable", kind: "mediaMetadata", itemType: "track"
        )
        let descriptor = try browser.playbackDescriptor(for: item)

        XCTAssertTrue(descriptor.uri.hasPrefix("soco://0ffffffftrack%3Aabc"))
        XCTAssertTrue(descriptor.uri.contains("sid=204"))
        XCTAssertTrue(descriptor.uri.contains("sn=35"))
    }

    private func mediaURIResponse(_ uri: String) -> String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><getMediaURIResponse xmlns="http://www.sonos.com/Services/1.1">
            <getMediaURIResult>\(uri)</getMediaURIResult>
          </getMediaURIResponse></s:Body>
        </s:Envelope>
        """
    }

    // MARK: Fixtures

    private func makeService(
        name: String = "Example",
        serviceID: Int = 204,
        auth: String = "AppLink",
        capabilities: Int = 0
    ) throws -> (service: MusicService, device: SoCo, http: MockHTTPClient) {
        let oldLoader = MusicService.descriptorLoader
        MusicService.descriptorLoader = { _ in
            self.descriptorXML(
                name: name,
                serviceID: serviceID,
                auth: auth,
                capabilities: capabilities
            )
        }
        MusicService.resetDescriptorCache()

        let http = MockHTTPClient()
        let device = try SoCo("192.0.2.10", httpClient: http)
        device._householdID = "Sonos_Test"
        device._uid = "RINCON_TEST"
        http.enqueue(text: playerDeviceIDResponse)
        let service = try MusicService(
            serviceName: name,
            tokenStore: MemoryMusicServiceTokenStore(),
            device: device,
            httpClient: http
        )
        MusicService.descriptorLoader = oldLoader
        return (service, device, http)
    }

    private func descriptorXML(
        name: String = "Example",
        serviceID: Int = 204,
        auth: String = "AppLink",
        capabilities: Int = 0,
        manifestURI: String? = nil,
        presentationMapURI: String? = nil
    ) -> String {
        let manifest = manifestURI.map { #"<Manifest Uri="\#($0)"/>"# } ?? ""
        let presentationMap = presentationMapURI.map {
            #"<Presentation><PresentationMap Uri="\#($0)"/></Presentation>"#
        } ?? ""
        return """
        <Services>
          <Service Id="\(serviceID)" Name="\(name)" Version="1.1"
                   Uri="http://example.invalid/smapi"
                   SecureUri="https://example.invalid/smapi"
                   Capabilities="\(capabilities)" ContainerType="MService" Auth="\(auth)">
            <Policy Auth="\(auth)"/>\(presentationMap)\(manifest)
          </Service>
        </Services>
        """
    }

    private func configuredAccount(serviceID: Int = 204) -> ConfiguredMusicServiceAccount {
        ConfiguredMusicServiceAccount(
            serviceID: serviceID,
            serialNumber: 35,
            udn: "SA_RINCON52231_X_#Svc52231-1a2b3c4d-Token",
            username: "user",
            password: "password",
            token: "old-token",
            key: "old-key",
            nickname: "Jennifer"
        )
    }

    private var playerDeviceIDResponse: String {
        soapResponse(
            action: "GetString",
            serviceType: "SystemProperties",
            fields: [("StringValue", "DEV123")]
        )
    }

    private var metadataResponse: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><getMetadataResponse xmlns="http://www.sonos.com/Services/1.1">
            <getMetadataResult><index>0</index><count>2</count><total>2</total>
              <mediaCollection><id>library</id><itemType>container</itemType>
                <title>Library</title><canEnumerate>true</canEnumerate>
                <albumArtURI>https://img/${width}/${height}</albumArtURI>
              </mediaCollection>
              <mediaCollection><id>upsell-banner/foo</id><itemType>container</itemType>
                <title>Upgrade</title><canPlay>true</canPlay></mediaCollection>
            </getMetadataResult>
          </getMetadataResponse></s:Body>
        </s:Envelope>
        """
    }

    private var artistMetadataResponse: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><getMetadataResponse xmlns="http://www.sonos.com/Services/1.1">
            <getMetadataResult><index>0</index><count>1</count><total>94</total>
              <mediaCollection><id>libraryartist:r.PJmkKgo</id><itemType>artist</itemType>
                <title>A Fine Frenzy</title><canEnumerate>true</canEnumerate>
              </mediaCollection>
            </getMetadataResult>
          </getMetadataResponse></s:Body>
        </s:Envelope>
        """
    }

    private var tokenRefreshFault: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><s:Fault><faultcode>soap:Client.TokenRefreshRequired</faultcode>
            <faultstring>Client.TokenRefreshRequired</faultstring></s:Fault></s:Body>
        </s:Envelope>
        """
    }

    private var transient999Fault: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><s:Fault><faultcode>Server</faultcode><faultstring>Temporary</faultstring>
            <detail><SonosError>999</SonosError></detail></s:Fault></s:Body>
        </s:Envelope>
        """
    }

    private var embeddedRefreshFault: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><s:Fault><faultcode>Client.TokenRefreshRequired</faultcode>
            <faultstring>Token Expired</faultstring><detail>
              <RefreshAuthTokenResult xmlns="http://www.sonos.com/Services/1.1">
                <authToken>replacement-token</authToken>
                <privateKey>replacement-key</privateKey>
              </RefreshAuthTokenResult>
            </detail></s:Fault></s:Body>
        </s:Envelope>
        """
    }

    private func refreshResponse(token: String, key: String) -> String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><refreshAuthTokenResponse xmlns="http://www.sonos.com/Services/1.1">
            <refreshAuthTokenResult><authToken>\(token)</authToken>
              <privateKey>\(key)</privateKey></refreshAuthTokenResult>
          </refreshAuthTokenResponse></s:Body>
        </s:Envelope>
        """
    }

    private var sessionResponse: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><getSessionIdResponse xmlns="http://www.sonos.com/Services/1.1">
            <getSessionIdResult>session-123</getSessionIdResult>
          </getSessionIdResponse></s:Body>
        </s:Envelope>
        """
    }

    private var contentRootJSON: String {
        #"{"views":[{"id":{"objectId":"browseviewlibraryroot:libraryroot"},"content":{"container":{"name":"Library"}},"displayType":"hero","total":1,"items":[{"id":{"objectId":"libraryfolder:f.1"},"content":{"container":{"name":"Artists","type":"container","canEnumerate":true,"imageUrl":"https://img/${width}/${height}/${ratio}"}}}]}]}"#
    }

    private var searchResponse: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><searchResponse xmlns="http://www.sonos.com/Services/1.1">
            <searchResult><count>1</count><total>1</total>
              <mediaMetadata><id>track:1</id><itemType>track</itemType><title>Result</title>
                <trackMetadata><artist>Artist</artist></trackMetadata></mediaMetadata>
            </searchResult>
          </searchResponse></s:Body>
        </s:Envelope>
        """
    }

    private var mediaMetadataResponse: String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body><getMediaMetadataResponse xmlns="http://www.sonos.com/Services/1.1">
            <getMediaMetadataResult><id>track:1</id><itemType>track</itemType>
              <title>Result</title><trackMetadata>
                <albumArtURI>https://img/cover.jpg</albumArtURI>
              </trackMetadata></getMediaMetadataResult>
          </getMediaMetadataResponse></s:Body>
        </s:Envelope>
        """
    }
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
