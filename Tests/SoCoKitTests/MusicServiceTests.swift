import XCTest
@testable import SoCoKit

private let serviceDescriptorXML = """
<Services SchemaVersion="1">
  <Service Id="163" Name="Spreaker" Version="1.1" Uri="http://spreaker.example/v1" SecureUri="https://spreaker.example/v1" ContainerType="MService" Capabilities="513" MaxMessagingChars="0">
    <Policy Auth="Anonymous" PollInterval="30" />
  </Service>
  <Service Id="9" Name="Spotify" Version="1.1" Uri="http://spotify.example/v1" SecureUri="https://spotify.example/v1" ContainerType="MService" Capabilities="2049" MaxMessagingChars="0">
    <Policy Auth="DeviceLink" PollInterval="30" />
    <Presentation><PresentationMap Version="2" Uri="https://spotify.example/pmap.xml" /></Presentation>
  </Service>
  <Service Id="2" Name="Deezer" Version="1.1" Uri="http://deezer.example/v1" SecureUri="https://deezer.example/v1" ContainerType="MService" Capabilities="513" MaxMessagingChars="0">
    <Policy Auth="UserId" PollInterval="30" />
    <Presentation><PresentationMap Version="2" Uri="https://deezer.example/pmap.xml" /></Presentation>
  </Service>
  <Service Id="254" Name="TuneIn" Version="1.1" Uri="http://tunein.example/v1" SecureUri="https://tunein.example/v1" ContainerType="MService" Capabilities="513" MaxMessagingChars="0">
    <Policy Auth="Anonymous" PollInterval="30" />
  </Service>
  <Service Id="160" Name="ManifestService" Version="1.1" Uri="http://manifest.example/v1" SecureUri="https://manifest.example/v1" ContainerType="MService" Capabilities="513" MaxMessagingChars="0">
    <Policy Auth="AppLink" PollInterval="30" />
    <Manifest Uri="https://manifest.example/manifest.json" />
  </Service>
</Services>
"""

final class MusicServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MusicService.resetDescriptorCache()
        MusicService.descriptorLoader = { _ in serviceDescriptorXML }
    }

    func makeService(_ name: String, http: HTTPClient = MockHTTPClient(), tokenStore: MusicServiceTokenStore = MemoryMusicServiceTokenStore()) throws -> MusicService {
        try MusicService(
            serviceName: name,
            tokenStore: tokenStore,
            deviceIdentity: MusicServiceDeviceIdentity(deviceID: "DEVICE", householdID: "HH1"),
            httpClient: http
        )
    }

    func testDescriptorParsing() throws {
        let data = try MusicService.musicServicesData()
        XCTAssertEqual(data.count, 5)
        let deezer = try XCTUnwrap(data["519"])
        XCTAssertEqual(deezer["Name"], "Deezer")
        XCTAssertEqual(deezer["Auth"], "UserId")
        XCTAssertEqual(deezer["PresentationMapUri"], "https://deezer.example/pmap.xml")
        XCTAssertEqual(deezer["ServiceID"], "2")
        XCTAssertEqual(deezer["ServiceType"], "519")
    }

    func testNamesAndUnknownService() throws {
        let names = try MusicService.allMusicServiceNames()
        XCTAssertEqual(Set(names), Set(["Spreaker", "Spotify", "Deezer", "TuneIn", "ManifestService"]))
        XCTAssertThrowsError(try MusicService.dataForName("NOPE"))
    }

    func testServicePropertiesURIAndDescriptor() throws {
        let spotify = try makeService("Spotify")
        XCTAssertEqual(spotify.serviceID, 9)
        XCTAssertEqual(spotify.serviceType, 2311)
        XCTAssertEqual(spotify.authType, "DeviceLink")
        XCTAssertEqual(spotify.sonosURIFromID("spotify:track:2qs5ZcLByNTctJKbhAZ9JE"), "soco://spotify%3Atrack%3A2qs5ZcLByNTctJKbhAZ9JE?sid=9&sn=0")
        XCTAssertEqual(spotify.sonosURIFromID("spotify: track\u{2}qc%ünicøde?"), "soco://spotify%3A%20track%02qc%25%C3%BCnic%C3%B8de%3F?sid=9&sn=0")
        XCTAssertEqual(spotify.desc, "SA_RINCON2311_X_#Svc2311-0-Token")

        let spreaker = try makeService("Spreaker")
        XCTAssertEqual(spreaker.desc, "SA_RINCON41735_")
    }

    func testTuneInSearchMap() throws {
        let tuneIn = try makeService("TuneIn")
        XCTAssertEqual(try tuneIn.searchPrefixMap(), ["stations": "search:station", "shows": "search:show", "hosts": "search:host"])
    }

    func testPresentationMapAndNavidromeFallback() throws {
        let http = MockHTTPClient()
        http.enqueue(text: """
        <PresentationMap><SearchCategories>
          <Category id="albums" mappedId="ALB"/>
          <Category id="tracks"/>
          <CustomCategory stringId="Blogs" mappedId="SBLG"/>
        </SearchCategories></PresentationMap>
        """)
        let spotify = try makeService("Spotify", http: http)
        let map = try spotify.searchPrefixMap()
        XCTAssertEqual(map["albums"], "ALB")
        XCTAssertEqual(map["tracks"], "tracks")
        XCTAssertEqual(map["Blogs"], "SBLG")
        XCTAssertEqual(http.requests.count, 1)
        XCTAssertEqual(try spotify.searchPrefixMap(), map)
        XCTAssertEqual(http.requests.count, 1, "presentation map should be cached")
    }

    func testManifestCanSupplyPresentationMap() throws {
        let http = MockHTTPClient()
        http.enqueue(text: #"{"presentationMap":{"uri":"https://manifest.example/pmap.xml"}}"#)
        http.enqueue(text: "<PresentationMap><SearchCategories><Category id=\"artists\" mappedId=\"ART\"/></SearchCategories></PresentationMap>")
        let service = try makeService("ManifestService", http: http)
        XCTAssertEqual(try service.searchPrefixMap()["artists"], "ART")
        XCTAssertEqual(service.presentationMapURI, "https://manifest.example/pmap.xml")
        XCTAssertEqual(http.requests.count, 2)
    }

    func testSOAPHeaderAnonymousAndTokenAuth() throws {
        let anonymous = try makeService("Spreaker")
        let anonymousHeader = try anonymous.soapClient.soapHeader()
        XCTAssertTrue(anonymousHeader.contains("<deviceId>DEVICE</deviceId>"))
        XCTAssertFalse(anonymousHeader.contains("loginToken"))

        let tokens = MemoryMusicServiceTokenStore()
        try tokens.saveTokenPair(musicServiceID: 9, householdID: "HH1", tokenPair: ("tok<&", "key>"))
        let spotify = try makeService("Spotify", tokenStore: tokens)
        let header = try spotify.soapClient.soapHeader()
        XCTAssertTrue(header.contains("<context></context>"))
        XCTAssertTrue(header.contains("<token>tok&lt;&amp;</token>"))
        XCTAssertTrue(header.contains("<key>key&gt;</key>"))
        XCTAssertTrue(header.contains("<householdId>HH1</householdId>"))
    }

    func testSearchRejectsUnsupportedCategoryBeforeSOAP() throws {
        let spotify = try makeService("Spotify", http: MockHTTPClient())
        XCTAssertThrowsError(try spotify.search(category: "potatoes", term: "x"))
    }
}

final class MusicServiceTokenStoreTests: XCTestCase {
    func testMemoryStore() throws {
        let store = MemoryMusicServiceTokenStore(tokenCollection: "x")
        XCTAssertFalse(store.hasToken(musicServiceID: 9, householdID: "HH"))
        try store.saveTokenPair(musicServiceID: 9, householdID: "HH", tokenPair: ("a", "b"))
        XCTAssertTrue(store.hasToken(musicServiceID: 9, householdID: "HH"))
        let pair = try store.loadTokenPair(musicServiceID: 9, householdID: "HH")
        XCTAssertEqual(pair.0, "a")
        XCTAssertEqual(pair.1, "b")
    }

    func testJSONFileStorePublicSaveCollection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("tokens.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try JSONFileTokenStore(fileURL: url, tokenCollection: "public-save")
        try store.saveCollection()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        XCTAssertEqual(object?.count, 0)
    }

    func testJSONFileStorePersistsCollections() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("tokens.json")
        let a = try JSONFileTokenStore(fileURL: url, tokenCollection: "app-a")
        try a.saveTokenPair(musicServiceID: 9, householdID: "HH", tokenPair: ("token", "key"))
        let b = try JSONFileTokenStore(fileURL: url, tokenCollection: "app-a")
        let pair = try b.loadTokenPair(musicServiceID: 9, householdID: "HH")
        XCTAssertEqual(pair.0, "token")
        XCTAssertEqual(pair.1, "key")
        let other = try JSONFileTokenStore(fileURL: url, tokenCollection: "app-b")
        XCTAssertFalse(other.hasToken(musicServiceID: 9, householdID: "HH"))
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

final class MusicServiceAccountTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MusicServiceAccount.resetCache()
    }

    func testAccountsParseDeletedAndSyntheticTuneIn() throws {
        MusicServiceAccount.xmlLoader = { _ in """
        <ZPSupportInfo type="User"><Accounts Version="8">
          <Account Type="2311" SerialNum="1"><UN>12345678</UN><MD>1</MD><NN>Spotify</NN><OADevID></OADevID><Key>k</Key></Account>
          <Account Type="41735" SerialNum="3" Deleted="1"><UN></UN><MD>1</MD><NN>Deleted</NN><OADevID></OADevID><Key></Key></Account>
        </Accounts></ZPSupportInfo>
        """ }
        let accounts = try MusicServiceAccount.accounts()
        XCTAssertEqual(Set(accounts.keys), Set(["0", "1"]))
        XCTAssertEqual(accounts["1"]?.serviceType, "2311")
        XCTAssertEqual(accounts["1"]?.username, "12345678")
        XCTAssertEqual(accounts["0"]?.serviceType, "65031")
        XCTAssertEqual(accounts["0"]?.serialNumber, "0")
    }

    func testAccountObjectsAreUpdatedAndReused() throws {
        var nickname = "Old"
        MusicServiceAccount.xmlLoader = { _ in "<Root><Account Type=\"2311\" SerialNum=\"1\"><UN>u</UN><MD>m</MD><NN>\(nickname)</NN><OADevID></OADevID><Key></Key></Account></Root>" }
        let first = try XCTUnwrap(MusicServiceAccount.accounts()["1"])
        nickname = "New"
        let second = try XCTUnwrap(MusicServiceAccount.accounts()["1"])
        XCTAssertTrue(first === second)
        XCTAssertEqual(second.nickname, "New")
    }
}
