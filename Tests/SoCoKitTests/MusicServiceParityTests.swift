import XCTest
@testable import SoCoKit

/// Protocol/authentication parity tests for upstream `music_services/music_service.py`.
final class MusicServiceParityTests: XCTestCase {
    private let descriptors = """
    <Services SchemaVersion="1">
      <Service Id="9" Name="Spotify" Version="1.1" Uri="http://spotify.example/smapi" SecureUri="https://spotify.example/smapi" ContainerType="MService" Capabilities="2563"><Policy Auth="DeviceLink" PollInterval="30"/><Presentation><Strings Version="1" Uri="https://spotify.example/strings.xml"/><PresentationMap Version="8" Uri="https://spotify.example/pmap.xml"/></Presentation></Service>
      <Service Id="160" Name="AppService" Version="1.1" Uri="http://app.example/smapi" SecureUri="https://app.example/smapi" ContainerType="MService" Capabilities="515"><Policy Auth="AppLink" PollInterval="30"/></Service>
      <Service Id="2" Name="Deezer" Version="1.1" Uri="http://deezer.example/smapi" SecureUri="https://deezer.example/smapi" ContainerType="MService" Capabilities="563"><Policy Auth="UserId" PollInterval="300"/></Service>
    </Services>
    """

    override func setUp() {
        super.setUp()
        MusicService.resetDescriptorCache()
        MusicService.descriptorLoader = { _ in self.descriptors }
    }

    private func service(
        _ name: String,
        http: MockHTTPClient,
        tokens: MusicServiceTokenStore = MemoryMusicServiceTokenStore()
    ) throws -> MusicService {
        try MusicService(
            serviceName: name,
            tokenStore: tokens,
            deviceIdentity: MusicServiceDeviceIdentity(deviceID: "DEVICE-123", householdID: "HH-ABC"),
            httpClient: http
        )
    }

    private func smapiResponse(_ method: String, inner: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
          <\(method)Response xmlns="http://www.sonos.com/Services/1.1">\(inner)</\(method)Response>
        </s:Body></s:Envelope>
        """
    }

    private func smapiFault(code: String, string: String = "Fault", detail: String = "") -> String {
        """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault><faultcode>\(code)</faultcode><faultstring>\(string)</faultstring><detail>\(detail)</detail></s:Fault></s:Body></s:Envelope>
        """
    }

    func testDescriptorCacheAndHistoricalStringsURIAlias() throws {
        var loads = 0
        MusicService.descriptorLoader = { _ in loads += 1; return self.descriptors }
        let first = try MusicService.musicServicesData()
        let second = try MusicService.musicServicesData()
        XCTAssertEqual(loads, 1)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first["2311"]?["PresentationMapUri"], "https://spotify.example/pmap.xml")
        // This odd alias is present in upstream SoCo and deliberately retained.
        XCTAssertEqual(first["2311"]?["StringsUri"], "https://spotify.example/pmap.xml")
    }

    func testDeviceLinkBeginAndCompleteAuthentication() throws {
        let http = MockHTTPClient()
        let tokens = MemoryMusicServiceTokenStore()
        let spotify = try service("Spotify", http: http, tokens: tokens)
        http.enqueue(text: smapiResponse("getDeviceLinkCode", inner: "<getDeviceLinkCodeResult><regUrl>https://auth.example/</regUrl><linkCode>ABCD</linkCode><linkDeviceId>LINK-DEVICE</linkDeviceId></getDeviceLinkCodeResult>"))

        XCTAssertEqual(try spotify.beginAuthentication(), "https://auth.example/")
        XCTAssertEqual(spotify.linkCode, "ABCD")
        XCTAssertEqual(spotify.linkDeviceID, "LINK-DEVICE")
        XCTAssertTrue(requestBodyText(http.requests[0]).contains("<householdId>HH-ABC</householdId>"))
        XCTAssertTrue(requestBodyText(http.requests[0]).contains("<context></context>"))

        http.enqueue(text: smapiResponse("getDeviceAuthToken", inner: "<getDeviceAuthTokenResult><authToken>TOKEN</authToken><privateKey>PRIVATE</privateKey></getDeviceAuthTokenResult>"))
        try spotify.completeAuthentication()
        XCTAssertNil(spotify.linkCode)
        XCTAssertNil(spotify.linkDeviceID)
        XCTAssertEqual(try tokens.loadTokenPair(musicServiceID: 9, householdID: "HH-ABC").0, "TOKEN")
        let completeBody = requestBodyText(http.requests[1])
        XCTAssertTrue(completeBody.contains("<linkCode>ABCD</linkCode>"))
        XCTAssertTrue(completeBody.contains("<linkDeviceId>LINK-DEVICE</linkDeviceId>"))
    }

    func testAppLinkAuthenticationUnwrapsNestedDeviceLink() throws {
        let http = MockHTTPClient()
        let app = try service("AppService", http: http)
        http.enqueue(text: smapiResponse("getAppLink", inner: "<getAppLinkResult><authorizeAccount><deviceLink><regUrl>https://app.example/link</regUrl><linkCode>XYZ</linkCode><linkDeviceId>APP-DEVICE</linkDeviceId></deviceLink></authorizeAccount></getAppLinkResult>"))
        XCTAssertEqual(try app.beginAuthentication(), "https://app.example/link")
        XCTAssertEqual(app.linkCode, "XYZ")
        XCTAssertEqual(app.linkDeviceID, "APP-DEVICE")
    }

    func testCompleteAuthenticationFallsBackToPhysicalDeviceID() throws {
        let http = MockHTTPClient()
        let spotify = try service("Spotify", http: http)
        http.enqueue(text: smapiResponse("getDeviceAuthToken", inner: "<getDeviceAuthTokenResult><authToken>T</authToken><privateKey>K</privateKey></getDeviceAuthTokenResult>"))
        try spotify.completeAuthentication(linkCode: "CODE", linkDeviceID: nil)
        XCTAssertTrue(requestBodyText(http.requests[0]).contains("<linkDeviceId>DEVICE-123</linkDeviceId>"))
    }

    func testTokenRefreshSavesNewPairRebuildsHeaderAndRetriesExactlyOnce() throws {
        let http = MockHTTPClient()
        let tokens = MemoryMusicServiceTokenStore()
        try tokens.saveTokenPair(musicServiceID: 9, householdID: "HH-ABC", tokenPair: ("OLD", "OLDKEY"))
        let spotify = try service("Spotify", http: http, tokens: tokens)

        http.enqueue(statusCode: 500, text: smapiFault(
            code: "s:Client.TokenRefreshRequired",
            detail: "<ms:RefreshAuthTokenResult xmlns:ms=\"http://www.sonos.com/Services/1.1\"><ms:authToken>NEW&amp;TOKEN</ms:authToken><ms:privateKey>NEWKEY</ms:privateKey></ms:RefreshAuthTokenResult>"
        ))
        http.enqueue(text: smapiResponse("getLastUpdate", inner: "<getLastUpdateResult><catalog>7</catalog><favorites>8</favorites></getLastUpdateResult>"))

        let result = try spotify.getLastUpdate()
        XCTAssertEqual(result?["catalog"] as? String, "7")
        XCTAssertEqual(http.requests.count, 2)
        let stored = try tokens.loadTokenPair(musicServiceID: 9, householdID: "HH-ABC")
        XCTAssertEqual(stored.0, "NEW&TOKEN")
        XCTAssertEqual(stored.1, "NEWKEY")
        XCTAssertTrue(requestBodyText(http.requests[0]).contains("<token>OLD</token>"))
        XCTAssertTrue(requestBodyText(http.requests[1]).contains("<token>NEW&amp;TOKEN</token>"))
    }

    func testTokenRefreshWithoutTokensBecomesAuthError() throws {
        let http = MockHTTPClient()
        let spotify = try service("Spotify", http: http)
        http.enqueue(statusCode: 500, text: smapiFault(code: "s:Client.TokenRefreshRequired", detail: "<somethingElse/>"))
        XCTAssertThrowsError(try spotify.getLastUpdate()) { error in
            guard case SoCoError.musicServiceAuth(let message) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(message.contains("no new token"))
        }
    }

    func testTokenRefreshIsRejectedForUnsupportedAuthType() throws {
        let http = MockHTTPClient()
        let deezer = try service("Deezer", http: http)
        http.enqueue(statusCode: 500, text: smapiFault(code: "s:Client.TokenRefreshRequired"))
        XCTAssertThrowsError(try deezer.getLastUpdate()) { error in
            guard case SoCoError.musicServiceAuth(let message) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(message.contains("not supported"))
        }
    }

    func testAuthTokenExpiredAndGenericSOAPFaultMappings() throws {
        let http = MockHTTPClient()
        let spotify = try service("Spotify", http: http)
        http.enqueue(statusCode: 500, text: smapiFault(code: "s:Client.AuthTokenExpired", string: "expired", detail: "<why>old</why>"))
        XCTAssertThrowsError(try spotify.getLastUpdate()) { error in
            guard case SoCoError.musicServiceAuth(let message) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(message.contains("Spotify"))
            XCTAssertTrue(message.contains("AuthTokenExpired"))
        }

        http.enqueue(statusCode: 500, text: smapiFault(code: "s:Server.Busy", string: "try later"))
        XCTAssertThrowsError(try spotify.getLastUpdate()) { error in
            guard case SoCoError.musicService(let message) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(message.contains("try later"))
            XCTAssertTrue(message.contains("s:Server.Busy"))
        }
    }

    func testEmptySOAPResponseMapsToAuthenticationFailure() throws {
        let http = MockHTTPClient()
        let spotify = try service("Spotify", http: http)
        http.enqueue(text: "")
        XCTAssertThrowsError(try spotify.getLastUpdate()) { error in
            guard case SoCoError.musicServiceAuth(let message) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(message.contains("empty response"))
        }
    }

    func testBeginAuthenticationRejectsUserIDAndCompleteRequiresCode() throws {
        let deezer = try service("Deezer", http: MockHTTPClient())
        XCTAssertThrowsError(try deezer.beginAuthentication())

        let spotify = try service("Spotify", http: MockHTTPClient())
        XCTAssertThrowsError(try spotify.completeAuthentication()) { error in
            guard case SoCoError.musicServiceAuth(let message) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertTrue(message.contains("link_code"))
        }
    }

    func testSOAPClientUsesHistoricalUserAgentAndNineSecondTimeout() throws {
        let http = MockHTTPClient()
        let spotify = try service("Spotify", http: http)
        http.enqueue(text: smapiResponse("getMediaURI", inner: "<getMediaURIResult>https://cdn.example/song.mp3</getMediaURIResult>"))
        XCTAssertEqual(try spotify.getMediaURI(itemID: "track:1"), "https://cdn.example/song.mp3")
        XCTAssertEqual(http.requests[0].timeout, 9)
        XCTAssertEqual(http.requests[0].headers["Accept-Encoding"], "gzip, deflate")
        XCTAssertTrue(http.requests[0].headers["User-Agent"]?.contains("Sonos/29.3-87071") == true)
        XCTAssertTrue(http.requests[0].headers["SOAPACTION"]?.contains("#getMediaURI") == true)
    }
}
