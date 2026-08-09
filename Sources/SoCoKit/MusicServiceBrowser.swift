import Foundation

/// Read-only browsing of configured Sonos music-service accounts.
///
/// This API is deliberately additive to `MusicService`. The existing music-service
/// implementation remains unchanged; `MusicServiceBrowser` implements the desktop
/// controller's newer account-aware browse flow alongside it.
///
/// Sonos currently exposes two related browse transports. Legacy services use the
/// SMAPI SOAP methods directly. Some newer services advertise a manifest with an
/// authenticated JSON browse endpoint for their home page, then hand child object
/// IDs back to ordinary SMAPI. Credentials for accounts already configured in the
/// household arrive through the encrypted `ThirdPartyMediaServersX` topology event.
///
/// Only read/browse operations are implemented here. In particular, this API does
/// not add, remove, rename, authorize, or otherwise mutate music-service accounts.

private let configuredSMAPINamespace = "http://www.sonos.com/Services/1.1"
private let configuredSOAPNamespace = "http://schemas.xmlsoap.org/soap/envelope/"
private let configuredAccountSalt = Data([
    0x1a, 0x01, 0xa7, 0x31, 0xc9, 0x6e, 0x9e, 0xbd,
    0xe8, 0x47, 0x51, 0x82, 0xb2, 0x74, 0xb7, 0x0e,
])

/// The controller identity used by the desktop browse flow on which this port is
/// based. Some providers are surprisingly strict about Sonos controller identity
/// strings, so this should not be replaced with URLSession's default User-Agent.
private let configuredDesktopUserAgent =
    "Linux UPnP/1.0 Sonos/90.0-77070 "
    + "(WDCR:Microsoft Windows NT 10.0.19045 64-bit)"

// MARK: - Provider values

/// A typed representation of schema-loose provider XML/JSON data.
///
/// Third-party services do not consistently follow one fixed schema at this
/// boundary. Keeping the dynamic shape in one value type avoids spreading
/// `[String: Any]` casts throughout the browsing implementation and still
/// preserves unknown fields for callers that need provider-specific metadata.
public indirect enum MusicServiceBrowseValue: CustomStringConvertible, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: MusicServiceBrowseValue])
    case array([MusicServiceBrowseValue])
    case null

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .string("true"): return true
        case .string("false"): return false
        default: return nil
        }
    }

    public var objectValue: [String: MusicServiceBrowseValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [MusicServiceBrowseValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var description: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        case .object(let value): return String(describing: value)
        case .array(let value): return String(describing: value)
        case .null: return "nil"
        }
    }

    fileprivate static func fromJSON(_ value: Any) -> MusicServiceBrowseValue {
        switch value {
        case let value as Bool:
            return .bool(value)
        case let value as String:
            return .string(value)
        case let value as NSNumber:
            let double = value.doubleValue
            if double.rounded() == double, double <= Double(Int.max), double >= Double(Int.min) {
                return .int(value.intValue)
            }
            return .double(double)
        case let value as [String: Any]:
            return .object(value.mapValues(MusicServiceBrowseValue.fromJSON))
        case let value as [Any]:
            return .array(value.map(MusicServiceBrowseValue.fromJSON))
        case _ as NSNull:
            return .null
        default:
            return .string(String(describing: value))
        }
    }
}

private extension Dictionary where Key == String, Value == MusicServiceBrowseValue {
    func string(_ key: String, default defaultValue: String = "") -> String {
        self[key]?.stringValue ?? defaultValue
    }

    func object(_ key: String) -> [String: MusicServiceBrowseValue] {
        self[key]?.objectValue ?? [:]
    }

    func array(_ key: String) -> [MusicServiceBrowseValue] {
        self[key]?.arrayValue ?? []
    }
}

// MARK: - Configured account discovery

/// Credentials for one music-service account already stored by Sonos.
///
/// This model is intentionally separate from SoCoKit's existing `Account`
/// (`MusicServiceAccount`). That older type represents `/status/accounts`; this
/// type represents the encrypted account record used by the desktop browse path.
/// Keeping them separate ensures this feature does not change existing behavior.
public final class ConfiguredMusicServiceAccount: CustomStringConvertible {
    public let serviceID: Int
    public let serialNumber: Int
    public let udn: String
    public let username: String
    public let password: String
    public private(set) var token: String
    public private(set) var key: String
    public let nickname: String
    public let tier: String
    public let schemaRevision: Int

    public init(
        serviceID: Int,
        serialNumber: Int,
        udn: String,
        username: String = "",
        password: String = "",
        token: String = "",
        key: String = "",
        nickname: String = "",
        tier: String = "",
        schemaRevision: Int = 7
    ) {
        self.serviceID = serviceID
        self.serialNumber = serialNumber
        self.udn = udn
        self.username = username
        self.password = password
        self.token = token
        self.key = key
        self.nickname = nickname
        self.tier = tier
        self.schemaRevision = schemaRevision
    }

    public var description: String {
        "<ConfiguredMusicServiceAccount serviceID=\(serviceID) "
            + "serialNumber=\(serialNumber) nickname=\(String(reflecting: nickname))>"
    }

    /// The account UID encoded in the Sonos account UDN.
    ///
    /// `SerialNum0` is the controller-facing account selector. Native content
    /// sessions instead key their per-account device identity from the hexadecimal
    /// account UID at the end of the token UDN.
    public var accountUID: UInt64 {
        get throws {
            let pattern = #"X_#Svc\d+-([0-9a-fA-F]+)-Token$"#
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(udn.startIndex..<udn.endIndex, in: udn)
            guard let match = regex.firstMatch(in: udn, range: range),
                  let capture = Range(match.range(at: 1), in: udn),
                  let value = UInt64(udn[capture], radix: 16)
            else {
                throw SoCoError.musicServiceAuth(
                    "Account UDN does not contain a numeric AccountUID: \(udn)"
                )
            }
            return value
        }
    }

    /// Build an account from one decrypted `ThirdPartyMediaServersX` node.
    internal convenience init?(element: SoCoXMLElement) {
        let udn = element.attribute("UDN") ?? ""
        let pattern = #"^SA_RINCON(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(udn.startIndex..<udn.endIndex, in: udn)
        guard let match = regex.firstMatch(in: udn, range: range),
              let capture = Range(match.range(at: 1), in: udn),
              let encodedType = Int(udn[capture])
        else { return nil }

        self.init(
            serviceID: encodedType / 256,
            serialNumber: Int(element.attribute("SerialNum0") ?? "0") ?? 0,
            udn: udn,
            username: element.attribute("Username0") ?? "",
            password: element.attribute("Password0") ?? "",
            token: element.attribute("Token0") ?? "",
            key: element.attribute("Key0") ?? "",
            nickname: element.attribute("Nickname0") ?? "",
            tier: element.attribute("Tier0") ?? "",
            schemaRevision: encodedType % 256
        )
    }

    /// Parse all configured accounts from decrypted account XML bytes.
    public static func fromPayload(_ payload: Data) throws -> [ConfiguredMusicServiceAccount] {
        guard let xml = String(data: payload, encoding: .utf8) else {
            throw SoCoError.musicService(
                "ThirdPartyMediaServersX account payload is not valid UTF-8"
            )
        }
        let tree: XMLTree
        do { tree = try XMLTree(xml) }
        catch {
            throw SoCoError.musicService(
                "ThirdPartyMediaServersX did not contain valid account XML"
            )
        }
        return (tree.root?.children ?? [])
            .compactMap { $0 as? SoCoXMLElement }
            .compactMap(ConfiguredMusicServiceAccount.init(element:))
    }

    /// Return accounts currently configured in the Sonos household.
    ///
    /// The account payload arrives as the initial ZoneGroupTopology event. This
    /// method reuses SoCoKit's normal event subscription instead of opening a
    /// second callback server. No account or player state is changed.
    public static func accounts(
        device: SoCo? = nil,
        timeout: TimeInterval = 8
    ) throws -> [ConfiguredMusicServiceAccount] {
        guard let player = try device ?? Discovery.anySoCo() else {
            throw SoCoError.noDeviceFound
        }
        let encoded = try captureAccountEvent(device: player, timeout: timeout)
        let payload = try decryptAccountPayload(
            encoded,
            householdID: try player.householdID()
        )
        return try fromPayload(payload)
    }

    internal func replaceCredentials(token: String, key: String) {
        self.token = token
        self.key = key
    }
}

private func captureAccountEvent(device: SoCo, timeout: TimeInterval) throws -> String {
    let subscription = Subscription(service: device.zoneGroupTopology)
    try subscription.subscribe(requestedTimeout: max(timeout + 10, 15))
    defer { _ = try? subscription.unsubscribe() }
    return try waitForConfiguredAccountEvent(subscription.events, timeout: timeout)
}

/// Wait for the topology notification which actually carries account data.
///
/// A subscription may receive an unrelated topology update before the initial
/// `ThirdPartyMediaServersX` value. The desktop capture handler ignores those
/// notifications and keeps waiting, so the Swift path must do the same rather
/// than treating the first event as authoritative.
internal func waitForConfiguredAccountEvent(
    _ events: EventQueue,
    timeout: TimeInterval
) throws -> String {
    let deadline = Date().addingTimeInterval(max(0, timeout))
    while true {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else {
            throw SoCoError.musicService(
                "No ThirdPartyMediaServersX event arrived within \(timeout) seconds"
            )
        }

        let event: Event
        do { event = try events.get(timeout: remaining) }
        catch SoCoError.timeout {
            throw SoCoError.musicService(
                "No ThirdPartyMediaServersX event arrived within \(timeout) seconds"
            )
        }
        if let value = event["third_party_media_servers_x"]?.stringValue,
           !value.isEmpty
        {
            return value
        }
    }
}

internal func decryptAccountPayload(_ encoded: String, householdID: String) throws -> Data {
    let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("2:") else {
        throw SoCoError.musicService("Unsupported ThirdPartyMediaServersX version")
    }
    guard let raw = Data(base64Encoded: String(trimmed.dropFirst(2))) else {
        throw SoCoError.musicService("ThirdPartyMediaServersX contained invalid base64")
    }
    guard raw.count >= 32, (raw.count - 16).isMultiple(of: 16) else {
        throw SoCoError.musicService("Invalid encrypted account payload dimensions")
    }

    let iv = raw.prefix(16)
    let ciphertext = raw.dropFirst(16)
    let globalKey = MusicServiceBrowseCrypto.md5(
        Data(householdID.utf8) + configuredAccountSalt
    )
    let blobKey = MusicServiceBrowseCrypto.md5(Data(iv) + globalKey)
    let checked = try MusicServiceBrowseCrypto.aes128CBCDecrypt(
        ciphertext: Data(ciphertext), key: blobKey, iv: Data(iv)
    )
    guard checked.count >= 4 else {
        throw SoCoError.musicService("Decrypted account payload is too short")
    }

    let payload = checked.dropLast(4)
    let checksum = checked.suffix(4)
    guard MusicServiceBrowseCrypto.md5(Data(payload)).prefix(4) == checksum else {
        throw SoCoError.musicService("Account payload integrity check failed")
    }
    return Data(payload)
}

private func accountContentDeviceID(
    householdID: String,
    account: ConfiguredMusicServiceAccount
) throws -> String {
    let uid = try account.accountUID
    return householdID + "_" + String(format: "%08llx", uid)
}

private func localMusicServiceTimeZone() -> String {
    if let configured = ProcessInfo.processInfo.environment["TZ"], !configured.isEmpty {
        return configured
    }
    return TimeZone.current.identifier
}

// MARK: - Browse models

public enum MusicServiceBrowseTransport: String, Equatable {
    case smapi
    case content
    case contentSection = "content-section"
}

/// One normalized read-only item returned by a configured service.
public struct MusicServiceBrowseItem: Equatable {
    public let itemID: String
    public let title: String
    public let kind: String
    public let itemType: String
    public let artist: String
    public let summary: String
    public let albumArtURI: String
    public let sourceTransport: MusicServiceBrowseTransport
    public let section: String
    public let displayType: String
    public let raw: [String: MusicServiceBrowseValue]

    public init(
        itemID: String,
        title: String,
        kind: String,
        itemType: String = "",
        artist: String = "",
        summary: String = "",
        albumArtURI: String = "",
        sourceTransport: MusicServiceBrowseTransport = .smapi,
        section: String = "",
        displayType: String = "",
        raw: [String: MusicServiceBrowseValue] = [:]
    ) {
        self.itemID = itemID
        self.title = title
        self.kind = kind
        self.itemType = itemType
        self.artist = artist
        self.summary = summary
        self.albumArtURI = albumArtURI
        self.sourceTransport = sourceTransport
        self.section = section
        self.displayType = displayType
        self.raw = raw
    }

    /// Whether selecting this item should request child metadata.
    public var canBrowse: Bool { kind == "mediaCollection" }

    /// Whether the provider says this item can be handed to Sonos for playback.
    /// Tracks often carry the flag inside `trackMetadata`; collections normally
    /// expose it at the top level. Content-endpoint tracks are playable unless
    /// explicitly marked otherwise.
    public var canPlay: Bool {
        if let value = raw["canPlay"]?.boolValue { return value }
        if let value = raw["trackMetadata"]?.objectValue?["canPlay"]?.boolValue { return value }
        if sourceTransport != .smapi, kind == "mediaMetadata" { return true }
        return kind == "mediaMetadata" && itemType.lowercased() == "track"
    }
}

/// A page of items returned by `MusicServiceBrowser`.
public struct MusicServiceBrowseResult: Equatable {
    public let items: [MusicServiceBrowseItem]
    public let index: Int
    public let total: Int
    public let transport: MusicServiceBrowseTransport
    public let requestedID: String
    public let endpoint: String
    public let raw: MusicServiceBrowseValue?

    public init(
        items: [MusicServiceBrowseItem],
        index: Int = 0,
        total: Int? = nil,
        transport: MusicServiceBrowseTransport = .smapi,
        requestedID: String = "root",
        endpoint: String = "",
        raw: MusicServiceBrowseValue? = nil
    ) {
        self.items = items
        self.index = index
        self.total = total ?? items.count
        self.transport = transport
        self.requestedID = requestedID
        self.endpoint = endpoint
        self.raw = raw
    }

    public var count: Int { items.count }
}

// MARK: - Configured SMAPI client

private struct ConfiguredBrowseSOAPFault: Error, CustomStringConvertible {
    let code: String
    let message: String
    let httpStatus: Int
    let detail: MusicServiceBrowseValue?

    var description: String { "\(code): \(message) (HTTP \(httpStatus))" }

    var publicError: SoCoError {
        let combined = "\(code) \(message)".lowercased()
        if combined.contains("token") || combined.contains("authorization") || httpStatus == 401 {
            return .musicServiceAuth(description)
        }
        return .musicService(description)
    }
}

internal final class ConfiguredSMAPIClient {
    private enum CredentialMode { case normal, base, refresh }

    let musicService: MusicService
    let account: ConfiguredMusicServiceAccount
    let device: SoCo
    let householdID: String
    let deviceID: String
    let controllerID: String
    let timeZone: String
    let explicitContent: Bool
    let allowCredentialRefresh: Bool
    let httpClient: HTTPClient
    var sessionID = ""

    init(
        musicService: MusicService,
        account: ConfiguredMusicServiceAccount,
        device: SoCo,
        householdID: String,
        deviceID: String,
        controllerID: String,
        timeZone: String,
        explicitContent: Bool,
        allowCredentialRefresh: Bool,
        httpClient: HTTPClient
    ) {
        self.musicService = musicService
        self.account = account
        self.device = device
        self.householdID = householdID
        self.deviceID = deviceID
        self.controllerID = controllerID
        self.timeZone = timeZone
        self.explicitContent = explicitContent
        self.allowCredentialRefresh = allowCredentialRefresh
        self.httpClient = httpClient
    }

    private var capabilities: Int { Int(musicService.capabilities) ?? 0 }

    private func credentials(mode: CredentialMode) -> String {
        var xml = "<credentials xmlns=\"\(configuredSMAPINamespace)\">"
        if capabilities & (1 << 18) != 0, let zonePlayerID = try? device.uid(), !zonePlayerID.isEmpty {
            xml += "<zonePlayerId>\(xmlEscape(zonePlayerID))</zonePlayerId>"
        }
        xml += "<deviceId>\(xmlEscape(deviceID))</deviceId>"
        xml += "<deviceProvider>Sonos</deviceProvider>"

        if mode == .base || musicService.authType == "Anonymous" {
            return xml + "</credentials>"
        }

        if mode == .normal,
           musicService.authType == "UserId" || musicService.authType == "UserIdPassword"
        {
            xml += "<login><username>\(xmlEscape(account.username))</username>"
            xml += "<password>\(xmlEscape(account.password))</password></login>"
            return xml + "</credentials>"
        }

        // Auth=DeviceLink describes how an account is provisioned. Once Sonos
        // has stored Token0/Key0, the desktop controller browses with that pair
        // like an AppLink account. getSessionId is only the no-token fallback.
        if mode == .normal, !account.token.isEmpty {
            xml += "<loginToken>"
            if capabilities & 8 == 0 {
                xml += "<token>\(xmlEscape(account.token))</token>"
                if !account.key.isEmpty { xml += "<key>\(xmlEscape(account.key))</key>" }
            }
            xml += "<householdId>\(xmlEscape(householdID))</householdId></loginToken>"
            return xml + "</credentials>"
        }

        if mode == .normal, musicService.authType == "DeviceLink" {
            if !sessionID.isEmpty { xml += "<sessionId>\(xmlEscape(sessionID))</sessionId>" }
            return xml + "</credentials>"
        }

        if !account.token.isEmpty || !householdID.isEmpty {
            xml += "<loginToken>"
            // Capability bit 3 moves the normal token into an HTTP Bearer
            // header. refreshAuthToken is the exception: the old token/key go
            // back into SOAP even when that capability is present.
            if capabilities & 8 == 0 || mode == .refresh {
                if !account.token.isEmpty { xml += "<token>\(xmlEscape(account.token))</token>" }
                if !account.key.isEmpty { xml += "<key>\(xmlEscape(account.key))</key>" }
            }
            xml += "<householdId>\(xmlEscape(householdID))</householdId></loginToken>"
        }
        return xml + "</credentials>"
    }

    private func envelope(
        action: String,
        fields: [(String, String)],
        credentialMode: CredentialMode
    ) -> Data {
        var header = credentials(mode: credentialMode)
        // The desktop app keys SMAPI context inclusion from capability bit 16.
        if capabilities & (1 << 16) != 0 {
            header += "<context xmlns=\"\(configuredSMAPINamespace)\">"
            header += "<timeZone>\(xmlEscape(timeZone))</timeZone>"
            if capabilities & (1 << 21) != 0, explicitContent {
                header += "<contentFiltering><explicit>true</explicit></contentFiltering>"
            }
            header += "</context>"
        }

        let arguments = fields.map { name, value in
            "<\(name)>\(xmlEscape(value))</\(name)>"
        }.joined()
        let xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            + "<s:Envelope xmlns:s=\"\(configuredSOAPNamespace)\">"
            + "<s:Header>\(header)</s:Header><s:Body>"
            + "<\(action) xmlns=\"\(configuredSMAPINamespace)\">\(arguments)</\(action)>"
            + "</s:Body></s:Envelope>"
        return Data(xml.utf8)
    }

    private func request(
        action: String,
        fields: [(String, String)],
        credentialMode: CredentialMode = .normal
    ) throws -> SoCoXMLElement {
        guard let endpoint = URL(string: musicService.secureURI),
              endpoint.scheme?.lowercased() == "https"
        else {
            throw SoCoError.musicService(
                "SMAPI endpoint must use HTTPS: \(musicService.secureURI)"
            )
        }

        var headers = [
            "Content-Type": "text/xml; charset=\"utf-8\"",
            "Soapaction": "\"\(configuredSMAPINamespace)#\(action)\"",
            "Accept-Language": "en-US",
            "X-Sonos-Controller-ID": controllerID,
            "User-Agent": configuredDesktopUserAgent,
        ]
        if credentialMode != .refresh, capabilities & 8 != 0, !account.token.isEmpty {
            headers["Authorization"] = "Bearer \(account.token)"
        }

        let response: HTTPResponse
        do {
            response = try httpClient.request(
                method: "POST",
                url: endpoint,
                headers: headers,
                body: envelope(action: action, fields: fields, credentialMode: credentialMode),
                timeout: 20
            )
        } catch {
            throw SoCoError.musicService("\(musicService.serviceName) request failed: \(error)")
        }

        let root: SoCoXMLElement
        do {
            let tree = try XMLTree(response.text)
            guard let parsed = tree.root else { throw SoCoError.xml("Missing SMAPI root") }
            root = parsed
        } catch {
            // Sonos Radio has returned xsi:nil without declaring the xsi prefix.
            // The desktop parser tolerates that specific provider defect, so
            // repair only that case before treating the response as corrupt.
            guard let repaired = repairUndeclaredXSIPrefix(response.text) else {
                throw SoCoError.musicService(
                    "\(musicService.serviceName) returned malformed SMAPI XML"
                )
            }
            do {
                let tree = try XMLTree(repaired)
                guard let parsed = tree.root else { throw SoCoError.xml("Missing SMAPI root") }
                root = parsed
            } catch {
                throw SoCoError.musicService(
                    "\(musicService.serviceName) returned malformed SMAPI XML"
                )
            }
        }

        if let fault = root.descendants(named: "Fault").first {
            let detail = fault.descendants(named: "detail").first.map(elementValue)
            throw ConfiguredBrowseSOAPFault(
                code: directChildText(fault, named: "faultcode", default: "SMAPI.Fault"),
                message: directChildText(fault, named: "faultstring", default: "Unknown SMAPI fault"),
                httpStatus: response.statusCode,
                detail: detail
            )
        }
        guard response.statusCode == 200 else {
            throw ConfiguredBrowseSOAPFault(
                code: "HTTP",
                message: "Unexpected status \(response.statusCode)",
                httpStatus: response.statusCode,
                detail: nil
            )
        }
        return root
    }

    private func isExpiredFault(_ fault: ConfiguredBrowseSOAPFault) -> Bool {
        let combined = "\(fault.code) \(fault.message)".lowercased()
        return combined.contains("authtokenexpired")
            || combined.contains("invalidtoken")
            || combined.contains("tokenrefreshrequired")
            || combined.contains("token expired")
            || fault.httpStatus == 401
    }

    private func isInvalidSessionFault(_ fault: ConfiguredBrowseSOAPFault) -> Bool {
        let combined = "\(fault.code) \(fault.message)".lowercased()
        return combined.contains("invalidsession") || combined.contains("invalid session")
    }

    private func isTransientFault(_ fault: ConfiguredBrowseSOAPFault) -> Bool {
        let combined = "\(fault.code) \(fault.message)".lowercased()
        // Apple intermittently returns generic SonosError 999 for a valid
        // collection and succeeds immediately on the identical request.
        let providerRetry = containsSonosError999(fault.detail)
        return providerRetry
            || [408, 429, 502, 503, 504].contains(fault.httpStatus)
            || ["read timed out", "timed out reading", "temporarily unavailable", "try again"]
                .contains(where: combined.contains)
    }

    private func replacementCredentials(
        in value: MusicServiceBrowseValue?
    ) -> (String, String)? {
        guard let value else { return nil }
        switch value {
        case .object(let object):
            let token = object.string("authToken")
            let key = object.string("privateKey")
            if !token.isEmpty, !key.isEmpty { return (token, key) }
            for child in object.values {
                if let replacement = replacementCredentials(in: child) { return replacement }
            }
        case .array(let array):
            for child in array {
                if let replacement = replacementCredentials(in: child) { return replacement }
            }
        default:
            break
        }
        return nil
    }

    private func replaceCredentials(token: String, key: String) {
        account.replaceCredentials(token: token, key: key)
        sessionID = ""
    }

    /// Refresh browse credentials in memory without writing the player.
    ///
    /// This is the normal browse behavior because several current providers return
    /// stale seed credentials until `refreshAuthToken` is called. The refreshed
    /// token/key pair is kept only by this browser/account object; SoCoKit does not
    /// invoke a player account mutation or persist it to the legacy token store.
    func refreshAuthToken() throws {
        if account.token == "needs_reauth" {
            throw SoCoError.musicServiceAuth(
                "The Sonos household stores needs_reauth instead of a usable token"
            )
        }
        let root = try request(action: "refreshAuthToken", fields: [], credentialMode: .refresh)
        let result = root.descendants(named: "refreshAuthTokenResult").first ?? root
        let token = directChildText(result, named: "authToken")
        let key = directChildText(result, named: "privateKey")
        guard !token.isEmpty, !key.isEmpty else {
            throw SoCoError.musicServiceAuth(
                "refreshAuthToken returned no authToken/privateKey pair"
            )
        }
        replaceCredentials(token: token, key: key)
    }

    private func refresh(from fault: ConfiguredBrowseSOAPFault) throws {
        if capabilities & 8 != 0 {
            try refreshAuthToken()
            return
        }
        if let replacement = replacementCredentials(in: fault.detail) {
            replaceCredentials(token: replacement.0, key: replacement.1)
            return
        }
        // Some current providers advertise the embedded-replacement branch but
        // return a plain Token Expired fault. Their explicit refresh operation is
        // still available; Sonos Radio is a live example.
        try refreshAuthToken()
    }

    private func getSessionID() throws {
        guard musicService.authType == "DeviceLink" else {
            throw SoCoError.musicServiceAuth(
                "getSessionId is only valid for DeviceLink services"
            )
        }
        let root = try request(
            action: "getSessionId",
            fields: [("username", account.username), ("password", account.password)],
            credentialMode: .base
        )
        let value = root.descendants(named: "getSessionIdResult").first?.text
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else {
            throw SoCoError.musicServiceAuth(
                "getSessionId response did not contain a session ID"
            )
        }
        sessionID = value
    }

    private func ensureSession() throws {
        if musicService.authType == "DeviceLink", account.token.isEmpty, sessionID.isEmpty {
            try getSessionID()
        }
    }

    private func requestWithRefresh(
        action: String,
        fields: [(String, String)]
    ) throws -> SoCoXMLElement {
        if account.token == "needs_reauth" {
            throw SoCoError.musicServiceAuth(
                "The Sonos household stores needs_reauth instead of a usable token"
            )
        }
        try ensureSession()
        do {
            return try request(action: action, fields: fields)
        } catch let fault as ConfiguredBrowseSOAPFault {
            if musicService.authType == "DeviceLink", isInvalidSessionFault(fault) {
                sessionID = ""
                try ensureSession()
                return try request(action: action, fields: fields)
            }
            if musicService.authType == "Anonymous" || !isExpiredFault(fault) { throw fault }
            guard allowCredentialRefresh else { throw fault }
            try refresh(from: fault)
            try ensureSession()
            return try request(action: action, fields: fields)
        }
    }

    func getMetadata(
        objectID: String = "root",
        index: Int = 0,
        count: Int = 100,
        recursive: Bool = false
    ) throws -> (records: [[String: MusicServiceBrowseValue]], index: Int, total: Int) {
        var fields = [("id", objectID), ("index", String(index)), ("count", String(count))]
        if recursive { fields.append(("recursive", "true")) }

        let root: SoCoXMLElement
        var lastFault: ConfiguredBrowseSOAPFault?
        for attempt in 0..<3 {
            do {
                root = try requestWithRefresh(action: "getMetadata", fields: fields)
                return parseMetadataPage(root: root, fallbackIndex: index)
            } catch let fault as ConfiguredBrowseSOAPFault {
                lastFault = fault
                if attempt == 2 || !isTransientFault(fault) {
                    if isExpiredFault(fault) { throw SoCoError.musicServiceAuth(fault.description) }
                    throw fault.publicError
                }
            }
        }
        if let lastFault { throw lastFault.publicError }
        throw SoCoError.musicService("getMetadata retry exhausted")
    }

    func search(
        categoryID: String,
        term: String,
        index: Int = 0,
        count: Int = 100
    ) throws -> (records: [[String: MusicServiceBrowseValue]], index: Int, total: Int) {
        let boundedCount = min(count, max(0, 1000 - index))
        let root: SoCoXMLElement
        do {
            root = try requestWithRefresh(
                action: "search",
                fields: [
                    ("id", categoryID), ("term", term),
                    ("index", String(index)), ("count", String(boundedCount)),
                ]
            )
        } catch let fault as ConfiguredBrowseSOAPFault {
            if isExpiredFault(fault) { throw SoCoError.musicServiceAuth(fault.description) }
            throw fault.publicError
        }
        let result = root.descendants(named: "searchResult").first ?? root
        let records = parseLegacyRecords(result)
        let total = min(1000, Int(directChildText(result, named: "total", default: String(records.count))) ?? records.count)
        return (records, index, total)
    }

    func getMediaMetadata(objectID: String) throws -> [String: MusicServiceBrowseValue] {
        let root: SoCoXMLElement
        do {
            root = try requestWithRefresh(
                action: "getMediaMetadata", fields: [("id", objectID)]
            )
        } catch let fault as ConfiguredBrowseSOAPFault {
            if isExpiredFault(fault) { throw SoCoError.musicServiceAuth(fault.description) }
            throw fault.publicError
        }
        guard let result = root.descendants(named: "getMediaMetadataResult").first else {
            throw SoCoError.musicService(
                "getMediaMetadata response did not contain a result"
            )
        }
        let value = elementValue(result)
        if case .object(var object) = value {
            object["album_art_uri"] = .string(artworkURI(object))
            return object
        }
        return ["value": value]
    }

    func getMediaURI(objectID: String) throws -> String? {
        let root: SoCoXMLElement
        do {
            root = try requestWithRefresh(action: "getMediaURI", fields: [("id", objectID)])
        } catch let fault as ConfiguredBrowseSOAPFault {
            if isExpiredFault(fault) { throw SoCoError.musicServiceAuth(fault.description) }
            throw fault.publicError
        }
        guard let result = root.descendants(named: "getMediaURIResult").first else { return nil }
        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private func parseMetadataPage(
        root: SoCoXMLElement,
        fallbackIndex: Int
    ) -> (records: [[String: MusicServiceBrowseValue]], index: Int, total: Int) {
        let result = root.descendants(named: "getMetadataResult").first ?? root
        let records = parseLegacyRecords(result)
        let parsedIndex = Int(directChildText(result, named: "index", default: String(fallbackIndex)))
            ?? fallbackIndex
        let total = Int(directChildText(result, named: "total", default: String(records.count)))
            ?? records.count
        return (records, parsedIndex, total)
    }

    private func parseLegacyRecords(_ result: SoCoXMLElement) -> [[String: MusicServiceBrowseValue]] {
        var records: [[String: MusicServiceBrowseValue]] = []
        for node in (result.children ?? []).compactMap({ $0 as? SoCoXMLElement }) {
            let providerKind = node.localNameSafe
            guard providerKind == "mediaCollection" || providerKind == "mediaMetadata",
                  case .object(var record) = elementValue(node)
            else { continue }
            record["provider_kind"] = .string(providerKind)
            record["kind"] = .string(legacyItemKind(providerKind: providerKind, record: record))
            record["album_art_uri"] = .string(artworkURI(record))
            records.append(record)
        }
        return records
    }
}

// MARK: - Public browser

/// Browse one configured music-service account without changing it.
///
/// `MusicService` remains the existing legacy SMAPI implementation. This class is
/// an opt-in companion for applications which need to browse accounts already
/// configured by the Sonos controller, including services which use the newer
/// manifest/content home page.
///
/// If more than one account for the service is configured, pass the desired
/// `ConfiguredMusicServiceAccount` explicitly.
public struct MusicServicePlaybackDescriptor: Equatable {
    public let uri: String
    public let metadata: String
    public let title: String

    public init(uri: String, metadata: String, title: String) {
        self.uri = uri
        self.metadata = metadata
        self.title = title
    }
}

public final class MusicServiceBrowser {
    public let device: SoCo
    public let musicService: MusicService
    public let account: ConfiguredMusicServiceAccount
    public let allowCredentialRefresh: Bool
    public let explicitContent: Bool
    public let timeZone: String
    public let deviceID: String
    public let controllerID: String

    private let householdID: String
    private let httpClient: HTTPClient
    private let contentEndpoint: String
    private var contentViews: [String: MusicServiceBrowseResult] = [:]
    private var client: ConfiguredSMAPIClient

    public init(
        serviceName: String,
        account: ConfiguredMusicServiceAccount? = nil,
        device: SoCo? = nil,
        allowCredentialRefresh: Bool = true,
        explicitContent: Bool = false,
        timeZone: String? = nil
    ) throws {
        guard let resolvedDevice = try device ?? Discovery.anySoCo() else {
            throw SoCoError.noDeviceFound
        }
        let resolvedMusicService = try MusicService(
            serviceName: serviceName,
            tokenStore: MemoryMusicServiceTokenStore(),
            device: resolvedDevice,
            httpClient: resolvedDevice.httpClient
        )
        let resolvedHouseholdID = resolvedMusicService.soapClient.householdID
        let resolvedDeviceID = resolvedMusicService.soapClient.deviceID
        self.device = resolvedDevice
        self.httpClient = resolvedDevice.httpClient
        self.musicService = resolvedMusicService
        self.householdID = resolvedHouseholdID
        self.deviceID = resolvedDeviceID
        self.allowCredentialRefresh = allowCredentialRefresh
        self.explicitContent = explicitContent
        self.timeZone = timeZone ?? localMusicServiceTimeZone()
        self.controllerID = stableControllerID(
            householdID: resolvedHouseholdID,
            deviceID: resolvedDeviceID
        )

        if let account {
            self.account = account
        } else if resolvedMusicService.authType == "Anonymous" {
            // Anonymous services do not need the encrypted account event. Avoid
            // the subscription entirely so this companion remains lightweight.
            self.account = ConfiguredMusicServiceAccount(
                serviceID: resolvedMusicService.serviceID, serialNumber: 0, udn: ""
            )
        } else {
            let matches = try ConfiguredMusicServiceAccount.accounts(device: resolvedDevice)
                .filter { $0.serviceID == resolvedMusicService.serviceID }
            guard !matches.isEmpty else {
                throw SoCoError.musicServiceAuth(
                    "No configured \(resolvedMusicService.serviceName) account was found in this household"
                )
            }
            guard matches.count == 1 else {
                throw SoCoError.musicServiceAuth(
                    "Multiple \(resolvedMusicService.serviceName) accounts are configured; pass an account explicitly"
                )
            }
            self.account = matches[0]
        }
        guard self.account.serviceID == resolvedMusicService.serviceID else {
            throw SoCoError.musicService(
                "Account belongs to service \(self.account.serviceID), not \(resolvedMusicService.serviceID)"
            )
        }

        self.client = ConfiguredSMAPIClient(
            musicService: resolvedMusicService,
            account: self.account,
            device: resolvedDevice,
            householdID: resolvedHouseholdID,
            deviceID: resolvedDeviceID,
            controllerID: self.controllerID,
            timeZone: self.timeZone,
            explicitContent: explicitContent,
            allowCredentialRefresh: allowCredentialRefresh,
            httpClient: resolvedDevice.httpClient
        )
        self.contentEndpoint = try MusicServiceBrowser.findContentEndpoint(
            musicService: resolvedMusicService,
            httpClient: resolvedDevice.httpClient
        )
    }

    /// Return configured accounts without constructing a browser.
    public static func getAccounts(
        device: SoCo? = nil,
        timeout: TimeInterval = 8
    ) throws -> [ConfiguredMusicServiceAccount] {
        try ConfiguredMusicServiceAccount.accounts(device: device, timeout: timeout)
    }

    /// `content` for a manifest home page, otherwise `smapi`.
    public var rootTransport: MusicServiceBrowseTransport {
        contentEndpoint.isEmpty ? .smapi : .content
    }

    /// Search categories are delegated to the existing `MusicService` parser.
    public var availableSearchCategories: [String] {
        musicService.availableSearchCategories
    }

    /// Browse a plain SMAPI ID. `root` automatically uses a manifest content home
    /// page when the service advertises one.
    public func getMetadata(
        itemID: String = "root",
        index: Int = 0,
        count: Int = 100,
        recursive: Bool = false
    ) throws -> MusicServiceBrowseResult {
        try browse(
            objectID: itemID,
            fromContentPage: false,
            index: index,
            count: count,
            recursive: recursive
        )
    }

    /// Browse an item returned by a previous page while preserving the transport
    /// provenance required by modern content providers.
    public func getMetadata(
        item: MusicServiceBrowseItem,
        index: Int = 0,
        count: Int = 100,
        recursive: Bool = false
    ) throws -> MusicServiceBrowseResult {
        try browse(
            objectID: item.itemID,
            fromContentPage: item.sourceTransport == .content
                || item.sourceTransport == .contentSection,
            index: index,
            count: count,
            recursive: recursive
        )
    }

    /// Search using the category mapping already provided by `MusicService`.
    public func search(
        category: String,
        term: String = "",
        index: Int = 0,
        count: Int = 100
    ) throws -> MusicServiceBrowseResult {
        let prefixMap = try musicService.searchPrefixMap()
        guard let categoryID = prefixMap[category] else {
            throw SoCoError.musicService(
                "Unknown search category \(String(reflecting: category)); available categories: "
                    + prefixMap.keys.sorted().joined(separator: ", ")
            )
        }
        let page = try client.search(
            categoryID: categoryID, term: term, index: index, count: count
        )
        return MusicServiceBrowseResult(
            items: page.records.map { legacyItem($0) },
            index: page.index,
            total: page.total,
            transport: .smapi,
            requestedID: categoryID,
            raw: .object([
                "index": .int(page.index), "total": .int(page.total),
                "items": .array(page.records.map(MusicServiceBrowseValue.object)),
            ])
        )
    }

    /// Return provider metadata for one item without changing playback.
    public func getMediaMetadata(
        itemID: String
    ) throws -> [String: MusicServiceBrowseValue] {
        try client.getMediaMetadata(objectID: itemID)
    }

    public func getMediaMetadata(
        item: MusicServiceBrowseItem
    ) throws -> [String: MusicServiceBrowseValue] {
        try getMediaMetadata(itemID: item.itemID)
    }

    /// Resolve a browsed service item into the URI + DIDL metadata Sonos expects
    /// for playback. This keeps account serial numbers and token descriptors from
    /// the configured household account instead of assuming serial number zero.
    public func playbackDescriptor(for item: MusicServiceBrowseItem) throws -> MusicServicePlaybackDescriptor {
        guard item.canPlay else {
            throw SoCoError.musicService("This item is not marked playable by the music service")
        }

        let rawID = item.itemID
        let quoted = smapiQuote(rawID)
        let didlID = "0fffffff\(quoted)"
        let itemType = item.itemType.lowercased()
        let isTrack = itemType == "track" || (item.kind == "mediaMetadata" && itemType != "stream")

        let fallbackURI: String
        if isTrack {
            fallbackURI = "soco://\(didlID)?sid=\(account.serviceID)&sn=\(account.serialNumber)"
        } else {
            fallbackURI = "x-rincon-cpcontainer:\(didlID)"
        }
        let uri = (isTrack ? (try? client.getMediaURI(objectID: rawID)) ?? nil : nil) ?? fallbackURI

        let didl = try DidlItem(
            title: item.title.isEmpty ? "DUMMY" : item.title,
            parentID: "DUMMY",
            itemID: didlID,
            resources: [DidlResource(uri: uri, protocolInfo: "DUMMY")],
            desc: account.udn
        )
        return MusicServicePlaybackDescriptor(
            uri: uri,
            metadata: try toDIDLString([didl]),
            title: item.title
        )
    }

    private func browse(
        objectID: String,
        fromContentPage: Bool,
        index: Int,
        count: Int,
        recursive: Bool
    ) throws -> MusicServiceBrowseResult {
        if let cached = contentViews[objectID] { return cached }
        if objectID.isEmpty || objectID == "root", !contentEndpoint.isEmpty {
            return try contentRoot()
        }

        var activeClient = client
        if fromContentPage {
            // Content-session objects are handed to SMAPI with the account's
            // OAuth device identity as loginToken.householdId. Returning to the
            // bare household ID makes Apple accept /browse/v1 but reject Library
            // children as InvalidTokenException.
            activeClient = makeClient(
                householdID: try accountContentDeviceID(
                    householdID: householdID, account: account
                )
            )
            activeClient.sessionID = client.sessionID
        }
        defer {
            if activeClient !== client { client.sessionID = activeClient.sessionID }
        }

        let page = try activeClient.getMetadata(
            objectID: objectID,
            index: index,
            count: count,
            recursive: recursive
        )
        let source: MusicServiceBrowseTransport = fromContentPage ? .content : .smapi
        return MusicServiceBrowseResult(
            items: page.records.map { legacyItem($0, sourceTransport: source) },
            index: page.index,
            total: page.total,
            transport: .smapi,
            requestedID: objectID,
            raw: .object([
                "index": .int(page.index), "total": .int(page.total),
                "items": .array(page.records.map(MusicServiceBrowseValue.object)),
            ])
        )
    }

    private func makeClient(householdID: String) -> ConfiguredSMAPIClient {
        ConfiguredSMAPIClient(
            musicService: musicService,
            account: account,
            device: device,
            householdID: householdID,
            deviceID: deviceID,
            controllerID: controllerID,
            timeZone: timeZone,
            explicitContent: explicitContent,
            allowCredentialRefresh: allowCredentialRefresh,
            httpClient: httpClient
        )
    }

    private static func findContentEndpoint(
        musicService: MusicService,
        httpClient: HTTPClient
    ) throws -> String {
        guard musicService.manifestURI != nil else { return "" }
        // A manifest is optional browse metadata. If it does not advertise a
        // usable browse endpoint, preserve legacy SMAPI as the fallback.
        do { return try browseContentEndpoint(musicService: musicService, httpClient: httpClient) }
        catch { return "" }
    }

    private func contentRoot() throws -> MusicServiceBrowseResult {
        let contentDeviceID = try account.udn.isEmpty
            ? deviceID
            : accountContentDeviceID(householdID: householdID, account: account)
        var headers = contentHeaders(deviceID: contentDeviceID)
        var response: HTTPResponse?

        for attempt in 0..<2 {
            guard let endpointURL = URL(string: contentEndpoint) else {
                throw SoCoError.musicService("Invalid content browse endpoint: \(contentEndpoint)")
            }
            do {
                response = try httpClient.request(
                    method: "GET", url: endpointURL, headers: headers,
                    body: nil, timeout: 20
                )
            } catch {
                throw SoCoError.musicService(
                    "\(musicService.serviceName) content browse failed: \(error)"
                )
            }
            guard response?.statusCode == 401, attempt == 0 else { break }
            guard allowCredentialRefresh else {
                throw SoCoError.musicServiceAuth(
                    "\(musicService.serviceName) content browse returned HTTP 401"
                )
            }
            try client.refreshAuthToken()
            headers = contentHeaders(deviceID: contentDeviceID)
        }

        guard let response else {
            throw SoCoError.musicService("\(musicService.serviceName) content browse returned no response")
        }
        guard response.statusCode == 200 else {
            throw SoCoError.musicService(
                "\(musicService.serviceName) content browse returned HTTP \(response.statusCode)"
            )
        }

        let rootValue: MusicServiceBrowseValue
        do {
            rootValue = MusicServiceBrowseValue.fromJSON(
                try JSONSerialization.jsonObject(with: response.data)
            )
        } catch {
            throw SoCoError.musicService(
                "\(musicService.serviceName) content browse returned invalid JSON"
            )
        }
        guard case .object(let page) = rootValue else {
            throw SoCoError.musicService("Content browse root was not an object")
        }

        var sections: [MusicServiceBrowseItem] = []
        contentViews.removeAll(keepingCapacity: true)
        for viewValue in page.array("views") {
            guard case .object(let view) = viewValue else { continue }
            let identity = view.object("id")
            let content = view.object("content")
            let container = content.object("container")
            let objectID = identity.string("objectId")
            guard !container.isEmpty, !objectID.isEmpty else { continue }

            let embedded = view.array("items").compactMap { value -> MusicServiceBrowseItem? in
                guard case .object(let item) = value else { return nil }
                return contentItem(item)
            }
            let title = container.string("name", default: objectID)
            let section = MusicServiceBrowseItem(
                itemID: objectID,
                title: title,
                kind: "mediaCollection",
                itemType: "section",
                albumArtURI: embedded.first?.albumArtURI ?? "",
                sourceTransport: .contentSection,
                displayType: view.string("displayType"),
                raw: view
            )
            sections.append(section)
            contentViews[objectID] = MusicServiceBrowseResult(
                items: embedded,
                total: view["total"]?.intValue ?? embedded.count,
                transport: .content,
                requestedID: objectID,
                endpoint: contentEndpoint,
                raw: viewValue
            )
        }

        return MusicServiceBrowseResult(
            items: sections,
            total: sections.count,
            transport: .content,
            requestedID: "root",
            endpoint: contentEndpoint,
            raw: rootValue
        )
    }

    private func contentHeaders(deviceID: String) -> [String: String] {
        var headers = [
            "Accept-Language": "en-US",
            "X-Sonos-Device-Id": deviceID,
            "X-Sonos-Corr-Id": UUID().uuidString.lowercased(),
            "X-Sonos-Controller-ID": controllerID,
            "User-Agent": configuredDesktopUserAgent,
            "Connection": "keep-alive",
        ]
        if !account.token.isEmpty { headers["Authorization"] = "Bearer \(account.token)" }
        let capabilities = Int(musicService.capabilities) ?? 0
        if capabilities & (1 << 16) != 0, !timeZone.isEmpty {
            headers["X-Sonos-Context-TimeZone"] = timeZone
        }
        if capabilities & (1 << 21) != 0, explicitContent {
            headers["X-Sonos-Context-ContentFiltering"] = "explicit"
        }
        return headers
    }
}

// MARK: - Provider normalization helpers

private func directChildText(
    _ node: SoCoXMLElement,
    named name: String,
    default defaultValue: String = ""
) -> String {
    node.firstChild(named: name)?.text ?? defaultValue
}

private func elementValue(_ node: SoCoXMLElement) -> MusicServiceBrowseValue {
    let children = (node.children ?? []).compactMap { $0 as? SoCoXMLElement }
    guard !children.isEmpty else { return .string(node.text) }

    var object: [String: MusicServiceBrowseValue] = [:]
    for child in children {
        let name = child.localNameSafe
        let value = elementValue(child)
        if let existing = object[name] {
            if case .array(var array) = existing {
                array.append(value)
                object[name] = .array(array)
            } else {
                object[name] = .array([existing, value])
            }
        } else {
            object[name] = value
        }
    }
    return .object(object)
}

private func explicitBool(_ value: MusicServiceBrowseValue?) -> Bool? {
    value?.boolValue
}

private func artworkURI(_ record: [String: MusicServiceBrowseValue]) -> String {
    for key in ["album_art_uri", "albumArtURI", "albumArtUri", "imageUrl", "logo"] {
        if let value = record[key]?.stringValue, !value.isEmpty {
            return value
                .replacingOccurrences(of: "${width}", with: "400")
                .replacingOccurrences(of: "${height}", with: "400")
                .replacingOccurrences(of: "${ratio}", with: "1x1")
        }
    }
    for key in ["streamMetadata", "trackMetadata", "metadata", "container", "track", "album"] {
        if let child = record[key]?.objectValue {
            let value = artworkURI(child)
            if !value.isEmpty { return value }
        }
    }
    return ""
}

private func legacyItemKind(
    providerKind: String,
    record: [String: MusicServiceBrowseValue]
) -> String {
    guard providerKind == "mediaCollection" else { return providerKind }

    let objectID = record.string("id").lowercased()
    // These provider records are controller actions, not browse containers.
    if objectID.hasPrefix("upsell-banner/") || objectID.hasPrefix("refmarketplace:") {
        return "mediaMetadata"
    }
    if let canEnumerate = explicitBool(record["canEnumerate"]) {
        return canEnumerate ? providerKind : "mediaMetadata"
    }
    let itemType = record.string("itemType").lowercased()
    if ["program", "stream", "track"].contains(itemType) { return "mediaMetadata" }
    if explicitBool(record["canPlay"]) == true,
       !["album", "albumlist", "collection", "container", "playlist"].contains(itemType)
    {
        return "mediaMetadata"
    }
    return providerKind
}

private func contentItem(
    _ item: [String: MusicServiceBrowseValue],
    section: String = ""
) -> MusicServiceBrowseItem? {
    let identity = item.object("id")
    let content = item.object("content")
    let objectID = identity.string("objectId")
    guard !objectID.isEmpty else { return nil }

    var record = content.object("container")
    var contentKind = "container"
    if record.isEmpty {
        record = content.object("track")
        contentKind = "track"
    }
    guard !record.isEmpty else { return nil }

    let itemType = record.string("type", default: contentKind)
    let collectionTypes: Set<String> = ["album", "artist", "container", "playlist", "show"]
    let isCollection = contentKind == "container"
        && (record["canEnumerate"]?.boolValue == true || collectionTypes.contains(itemType))
    let artist = record.object("artist").string("name")
    return MusicServiceBrowseItem(
        itemID: objectID,
        title: record.string("name", default: objectID),
        kind: isCollection ? "mediaCollection" : "mediaMetadata",
        itemType: itemType,
        artist: artist,
        summary: record.string("summary"),
        albumArtURI: artworkURI(record),
        sourceTransport: .content,
        section: section,
        displayType: item.string("displayType"),
        raw: item
    )
}

private func legacyItem(
    _ record: [String: MusicServiceBrowseValue],
    sourceTransport: MusicServiceBrowseTransport = .smapi
) -> MusicServiceBrowseItem {
    let trackMetadata = record.object("trackMetadata")
    let streamMetadata = record.object("streamMetadata")
    let metadata = trackMetadata.isEmpty ? streamMetadata : trackMetadata
    let artist = metadata.string("artist", default: record.string("artist"))
    let title = record.string("title").isEmpty
        ? (record.string("name").isEmpty ? record.string("id") : record.string("name"))
        : record.string("title")
    return MusicServiceBrowseItem(
        itemID: record.string("id"),
        title: title,
        kind: record.string("kind", default: record.string("provider_kind", default: "mediaMetadata")),
        itemType: record.string("itemType"),
        artist: artist,
        summary: record.string("summary"),
        albumArtURI: record.string("album_art_uri"),
        sourceTransport: sourceTransport,
        raw: record
    )
}

private func containsSonosError999(_ value: MusicServiceBrowseValue?) -> Bool {
    guard let value else { return false }
    switch value {
    case .object(let object):
        if object["SonosError"]?.stringValue == "999" || object["SonosError"]?.intValue == 999 {
            return true
        }
        return object.values.contains(where: { containsSonosError999($0) })
    case .array(let values):
        return values.contains(where: { containsSonosError999($0) })
    default:
        return false
    }
}

private func repairUndeclaredXSIPrefix(_ xml: String) -> String? {
    guard xml.contains("xsi:"), !xml.contains("xmlns:xsi") else { return nil }
    let pattern = #"(<(?:[A-Za-z_][\w.-]*:)?Envelope)(\s)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
    let repaired = regex.stringByReplacingMatches(
        in: xml,
        range: range,
        withTemplate: #"$1 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"$2"#
    )
    return repaired == xml ? nil : repaired
}

private func serviceManifest(
    musicService: MusicService,
    httpClient: HTTPClient
) throws -> [String: MusicServiceBrowseValue] {
    guard let manifestURI = musicService.manifestURI, !manifestURI.isEmpty else { return [:] }
    guard let url = URL(string: manifestURI) else {
        throw SoCoError.musicService("Invalid manifest URI: \(manifestURI)")
    }
    let response: HTTPResponse
    do {
        response = try httpClient.request(
            method: "GET",
            url: url,
            headers: ["Accept": "application/json", "Accept-Language": "en-US"],
            body: nil,
            timeout: 20
        )
    } catch {
        throw SoCoError.musicService(
            "\(musicService.serviceName) manifest request failed: \(error)"
        )
    }
    guard (200..<300).contains(response.statusCode) else {
        throw SoCoError.musicService(
            "\(musicService.serviceName) manifest request failed with HTTP \(response.statusCode)"
        )
    }
    let value: MusicServiceBrowseValue
    do {
        value = MusicServiceBrowseValue.fromJSON(
            try JSONSerialization.jsonObject(with: response.data)
        )
    } catch {
        throw SoCoError.musicService(
            "\(musicService.serviceName) manifest was not valid JSON"
        )
    }
    guard case .object(let manifest) = value else {
        throw SoCoError.musicService(
            "\(musicService.serviceName) manifest root was not an object"
        )
    }
    return manifest
}

private func browseContentEndpoint(
    musicService: MusicService,
    httpClient: HTTPClient,
    endpointType: String = "browse"
) throws -> String {
    let manifest = try serviceManifest(musicService: musicService, httpClient: httpClient)
    for value in manifest.array("endpoints") {
        guard case .object(let endpoint) = value,
              endpoint.string("type") == endpointType
        else { continue }
        let uri = endpoint.string("uri")
        if !uri.isEmpty { return uri }
    }
    throw SoCoError.musicService(
        "\(musicService.serviceName) manifest has no \(endpointType) endpoint"
    )
}

internal func stableControllerID(householdID: String, deviceID: String) -> String {
    // UUID v5 with RFC 4122's URL namespace, matching Python uuid.uuid5.
    let namespaceBytes: [UInt8] = [
        0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
        0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
    ]
    let name = "soco-music-service-browser:\(householdID):\(deviceID)"
    var hash = [UInt8](MusicServiceBrowseCrypto.sha1(Data(namespaceBytes) + Data(name.utf8)))
    hash[6] = (hash[6] & 0x0f) | 0x50
    hash[8] = (hash[8] & 0x3f) | 0x80
    let bytes = hash.prefix(16).map { String(format: "%02x", $0) }
    return [
        bytes[0...3].joined(), bytes[4...5].joined(), bytes[6...7].joined(),
        bytes[8...9].joined(), bytes[10...15].joined(),
    ].joined(separator: "-")
}
