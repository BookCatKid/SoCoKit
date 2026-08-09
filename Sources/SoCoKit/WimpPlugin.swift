import Foundation

// MARK: - Legacy WiMP music-service plugin

/// Plugin for the WiMP music service (Service ID 20).
///
/// This is a direct port of SoCo's legacy `soco.plugins.wimp` plugin. WiMP was
/// renamed/replaced by TIDAL long ago, but the module remains part of SoCo's public
/// source tree and is therefore retained for source/behavioral completeness.
///
/// There is an apparent inconsistency in the service's use of `albumList`: playlist
/// search results report that type as playable, while items with the same type returned
/// while browsing can instead represent a non-playable list of albums. This class does
/// not attempt to "fix" the server; like Python SoCo, it preserves what the service says.
///
/// WiMP may also list tracks which are unavailable. A containing album can still report
/// itself as playable; attempting to enqueue one of those tracks can result in Sonos
/// UPnP error 802. This behavior belongs to the service/device and is intentionally not
/// hidden here.
public final class Wimp: SoCoPlugin, LegacyMusicServiceProviding {
    public struct ResultPage {
        public let index: String?
        public let count: String?
        public let total: String?
        public let items: [LegacyMusicServiceItem]

        public init(index: String?, count: String?, total: String?, items: [LegacyMusicServiceItem]) {
            self.index = index
            self.count = count
            self.total = total
            self.items = items
        }
    }

    public static let serviceURL = URL(string: "http://client.wimpmusic.com/sonos/services/Sonos")!
    public static let serviceID = 20
    public static let searchPrefix = "00020064%@:%@"

    private let url: URL
    private let serialNumber: String
    private let usernameValue: String
    private let retries: Int
    private let timeout: TimeInterval
    private let sessionID: String
    private let transport: HTTPClient

    /// Initialize the plugin exactly as upstream does: fetch the speaker serial number
    /// and ask Sonos' MusicServices service for a session ID tied to `username`.
    ///
    /// If a phone number is used as the username and login fails, upstream's historical
    /// note recommends trying the country calling code without `+` or `00`, and ensuring
    /// the same form is configured on the Sonos device.
    public init(
        _ soco: SoCo,
        username: String,
        retries: Int = 3,
        timeout: TimeInterval = 3.0,
        httpClient: HTTPClient? = nil
    ) throws {
        let speakerInfo = try soco.getSpeakerInfo()
        let serial = speakerInfo["serial_number"] ?? ""
        let response = try soco.musicServices.sendCommand(
            "GetSessionId",
            arguments: [("ServiceId", String(Self.serviceID)), ("Username", username)]
        )
        guard let session = response["SessionId"] else {
            throw SoCoError.musicServiceAuth("MusicServices.GetSessionId omitted SessionId")
        }
        self.url = Self.serviceURL
        self.serialNumber = serial
        self.usernameValue = username
        self.retries = max(1, retries)
        self.timeout = timeout
        self.sessionID = session
        self.transport = httpClient ?? soco.httpClient
        super.init(soco)
    }

    /// Injectable initializer used by tests, emulators, and applications which already
    /// possess the legacy service session. It is also useful when replaying captured WiMP
    /// traffic without contacting a real Sonos speaker during construction.
    public init(
        _ soco: SoCo,
        username: String,
        serialNumber: String,
        sessionID: String,
        serviceURL: URL = Wimp.serviceURL,
        retries: Int = 3,
        timeout: TimeInterval = 3.0,
        httpClient: HTTPClient? = nil
    ) {
        self.url = serviceURL
        self.serialNumber = serialNumber
        self.usernameValue = username
        self.retries = max(1, retries)
        self.timeout = timeout
        self.sessionID = sessionID
        self.transport = httpClient ?? soco.httpClient
        super.init(soco)
    }

    public required convenience init(_ soco: SoCo) {
        // `SoCoPlugin.fromName` requires a one-argument factory. WiMP cannot be useful
        // without a username/session; keep construction possible but make calls fail in
        // the same obvious way an unauthenticated legacy service would.
        self.init(soco, username: "", serialNumber: "", sessionID: "")
    }

    public override var name: String { "Wimp Plugin for \(usernameValue)" }
    public var username: String { usernameValue }
    public var serviceIDValue: Int { Self.serviceID }
    public var descriptionText: String { "SA_RINCON5127_\(usernameValue)" }

    /// Return the music service description for DIDL metadata, matching the
    /// upstream WiMP plugin's public `description` property.
    public var description: String { descriptionText }

    // LegacyMusicServiceProviding
    public var musicServiceDescription: String { descriptionText }
    public var legacyServiceID: Int { Self.serviceID }

    public func getTracks(_ search: String, start: Int = 0, maxItems: Int = 100) throws -> ResultPage {
        try getMusicServiceInformation(searchType: "tracks", search: search, start: start, maxItems: maxItems)
    }

    public func getAlbums(_ search: String, start: Int = 0, maxItems: Int = 100) throws -> ResultPage {
        try getMusicServiceInformation(searchType: "albums", search: search, start: start, maxItems: maxItems)
    }

    public func getArtists(_ search: String, start: Int = 0, maxItems: Int = 100) throws -> ResultPage {
        try getMusicServiceInformation(searchType: "artists", search: search, start: start, maxItems: maxItems)
    }

    /// Unintuitively, playlist searches may return `MSAlbumList` items. See the class
    /// documentation above; this preserves the server's historical behavior.
    public func getPlaylists(_ search: String, start: Int = 0, maxItems: Int = 100) throws -> ResultPage {
        try getMusicServiceInformation(searchType: "playlists", search: search, start: start, maxItems: maxItems)
    }

    /// Search the legacy service. Valid search types are artists, albums, tracks and
    /// playlists. Python SoCo transforms e.g. `tracks` to the odd server token
    /// `tracksearch` (by dropping the trailing `s` and appending `search`).
    public func getMusicServiceInformation(
        searchType: String,
        search: String,
        start: Int = 0,
        maxItems: Int = 100
    ) throws -> ResultPage {
        guard ["artists", "albums", "tracks", "playlists"].contains(searchType) else {
            throw SoCoError.invalidArgument("The requested search \(searchType) is not valid")
        }
        let singular = String(searchType.dropLast())
        let serverSearchType = singular + "search"
        let parentID = "00020064\(serverSearchType):\(search)"
        let body = searchBody(searchType: serverSearchType, searchTerm: search, start: start, maxItems: maxItems)
        let response = try post(headers: Self.header(for: .search), body: body)
        try checkForErrors(response)
        let tree = try XMLTree(response.text)
        guard let result = tree.root?.descendants(named: "searchResult").first else {
            throw SoCoError.xml("WiMP search response omitted searchResult")
        }
        let itemName = serverSearchType == "tracksearch" ? "mediaMetadata" : "mediaCollection"
        var items: [LegacyMusicServiceItem] = []
        for item in result.children?.compactMap({ $0 as? SoCoXMLElement }).filter({ $0.localNameSafe == itemName }) ?? [] {
            items.append(try getMSItem(item, service: self, parentID: parentID))
        }
        return ResultPage(
            index: result.firstChild(named: "index")?.text,
            count: result.firstChild(named: "count")?.text,
            total: result.firstChild(named: "total")?.text,
            items: items
        )
    }

    /// Return children of an item, or the service root when `item` is nil.
    ///
    /// Browsing an `MSTrack` can return the track itself. As in upstream, parent IDs for
    /// `MSFavorites` and `MSCollection` cannot always be reconstructed correctly.
    public func browse(_ item: LegacyMusicServiceItem? = nil) throws -> ResultPage {
        if let item, item.serviceID != Self.serviceID {
            throw SoCoError.invalidArgument("This music service item is not for this service")
        }
        let searchID = item?.itemID ?? "root"
        let parentID = item?.extendedID ?? (item == nil ? "0" : "")
        let response = try post(headers: Self.header(for: .getMetadata), body: browseBody(searchID: searchID))
        try checkForErrors(response)
        let tree = try XMLTree(response.text)
        let candidates = tree.root?.descendants(named: "getMetadataResult") ?? []
        guard candidates.count == 1, let result = candidates.first else {
            throw SoCoError.xml("The results XML has more than 1 'getMetadataResult'. This is unexpected and parsing will dis-continue.")
        }
        var items: [LegacyMusicServiceItem] = []
        for element in result.children?.compactMap({ $0 as? SoCoXMLElement }) ?? []
            where element.localNameSafe == "mediaCollection" || element.localNameSafe == "mediaMetadata" {
            items.append(try getMSItem(element, service: self, parentID: parentID))
        }
        return ResultPage(
            index: result.firstChild(named: "index")?.text,
            count: result.firstChild(named: "count")?.text,
            total: result.firstChild(named: "total")?.text,
            items: items
        )
    }

    /// Return the extended ID from an ID. For classes whose prefix was never known in
    /// upstream SoCo (`MSFavorites`, `MSCollection`) this intentionally returns nil.
    public func idToExtendedID(_ itemID: String, itemClass: LegacyMusicServiceItem.Type) -> String? {
        let prefix: String?
        if itemClass == MSTrack.self { prefix = "00030020" }
        else if itemClass == MSAlbum.self { prefix = "0004002c" }
        else if itemClass == MSArtist.self { prefix = "10050024" }
        else if itemClass == MSAlbumList.self { prefix = "000d006c" }
        else if itemClass == MSPlaylist.self { prefix = "0006006c" }
        else if itemClass == MSArtistTracklist.self { prefix = "100f006c" }
        else { prefix = nil }
        return prefix.map { $0 + itemID }
    }

    /// Form the Sonos URI for a legacy music-service item.
    public func formURI(_ itemContent: [String: Any], itemClass: LegacyMusicServiceItem.Type) -> String? {
        let itemID = itemContent["item_id"] as? String ?? ""
        let extendedID = itemContent["extended_id"] as? String ?? ""
        let serviceID = itemContent["service_id"] as? Int ?? Int(itemContent["service_id"] as? String ?? "") ?? Self.serviceID
        if itemClass == MSTrack.self {
            let mime = itemContent["mime_type"] as? String
            let ext = mime == "audio/aac" ? "mp4" : nil
            guard let ext else { return nil }
            return "x-sonos-http:\(itemID).\(ext)?sid=\(serviceID)&flags=32"
        }
        if itemClass == MSAlbum.self || itemClass == MSAlbumList.self || itemClass == MSPlaylist.self || itemClass == MSArtistTracklist.self {
            return "x-rincon-cpcontainer:\(extendedID)"
        }
        return nil
    }

    enum Action { case search, getMetadata }

    /// Return the HTTP header for the requested SOAP action.
    ///
    /// Upstream notes that deriving Accept-Language from the process locale is flawed;
    /// account country probably controls availability anyway. We preserve the intent but
    /// use Foundation's current locale identifier when it carries a language component.
    static func header(for action: Action, locale: Locale = .current) -> [String: String] {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let prefix = identifier.isEmpty || identifier == "en-US-POSIX" ? "" : identifier + ", "
        let soapAction = action == .search
            ? "\"http://www.sonos.com/Services/1.1#search\""
            : "\"http://www.sonos.com/Services/1.1#getMetadata\""
        return [
            "CONNECTION": "close",
            "ACCEPT-ENCODING": "gzip",
            "ACCEPT-LANGUAGE": "\(prefix)en-US;q=0.9",
            "Content-Type": "text/xml; charset=\"utf-8\"",
            "SOAPACTION": soapAction,
        ]
    }

    /// Base SOAP envelope containing the session credentials expected by WiMP.
    func baseBody(innerBody: String = "") -> String {
        """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Header><credentials xmlns="http://www.sonos.com/Services/1.1"><sessionId>\(xmlEscape(sessionID))</sessionId><deviceId>\(xmlEscape(serialNumber))</deviceId><deviceProvider>Sonos</deviceProvider></credentials></s:Header>\(innerBody)</s:Envelope>
        """
    }

    func searchBody(searchType: String, searchTerm: String, start: Int, maxItems: Int) -> String {
        let body = "<s:Body><search xmlns=\"http://www.sonos.com/Services/1.1\"><id>\(xmlEscape(searchType))</id><term>\(xmlEscape(searchTerm))</term><index>\(start)</index><count>\(maxItems)</count></search></s:Body>"
        return baseBody(innerBody: body)
    }

    /// Although this body contains index/count, upstream observed that the service did
    /// not seem to respect them, so they remain fixed at 0 and 100 and are not arguments.
    func browseBody(searchID: String) -> String {
        let body = "<s:Body><getMetadata xmlns=\"http://www.sonos.com/Services/1.1\"><id>\(xmlEscape(searchID))</id><index>0</index><count>100</count></getMetadata></s:Body>"
        return baseBody(innerBody: body)
    }

    /// Try the request up to `retries` times on timeouts, mirroring the workaround in
    /// the Python plugin for requests/socket timeout behavior.
    private func post(headers: [String: String], body: String) throws -> HTTPResponse {
        var lastError: Error = SoCoError.timeout
        for attempt in 0..<retries {
            do {
                return try transport.request(method: "POST", url: url, headers: headers, body: Data(body.utf8), timeout: timeout)
            } catch {
                lastError = error
                let isTimeout: Bool
                if let socoError = error as? SoCoError, socoError == .timeout { isTimeout = true }
                else if let urlError = error as? URLError, urlError.code == .timedOut { isTimeout = true }
                else { isTimeout = false }
                if !isTimeout || attempt + 1 == retries { throw error }
            }
        }
        throw lastError
    }

    private func checkForErrors(_ response: HTTPResponse) throws {
        guard response.statusCode == 200 else {
            let tree = try XMLTree(response.text)
            let description = tree.root?.descendants(named: "faultstring").first?.text ?? "unknown"
            let code: String
            switch description {
            case "ItemNotFound": code = "20001"
            case "unknown": code = "20000"
            default: code = "20000"
            }
            throw SoCoError.upnp(code: code, description: description, xml: response.text)
        }
    }
}
