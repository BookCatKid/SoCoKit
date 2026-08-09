import Foundation

/// Sonos Music Services interface.
///
/// Known upstream problems are intentionally preserved here because they materially
/// affect callers:
///
/// 1. Not all music services follow the documented authentication layout. Sonos does
///    not enforce perfect data hygiene across third-party services, so individual
///    services may still require compatibility tweaks.
/// 2. SoCo does not currently implement a general "reset authentication" operation.
///    Device/App Link services may therefore require action outside this library if a
///    household's server-side link state and locally stored tokens become inconsistent.
public struct MusicServiceDeviceIdentity {
    public let deviceID: String
    public let householdID: String
    public init(deviceID: String, householdID: String) { self.deviceID = deviceID; self.householdID = householdID }
}

public final class MusicService: MusicServiceProviding, CustomStringConvertible {
    public typealias Descriptor = [String: String]
    public typealias DescriptorLoader = (_ device: SoCo?) throws -> String

    /// Injectable descriptor loader. Tests and apps which already have the descriptor
    /// XML can replace this; by default a Sonos device is discovered and queried.
    public static var descriptorLoader: DescriptorLoader = { device in
        guard let player = try device ?? Discovery.anySoCo() else { throw SoCoError.noDeviceFound }
        let result = try player.musicServices.sendCommand("ListAvailableServices")
        guard let xml = result["AvailableServiceDescriptorList"] else {
            throw SoCoError.musicService("ListAvailableServices returned no descriptor list")
        }
        return xml
    }

    private static let descriptorLock = NSLock()
    private static var cachedDescriptors: [String: Descriptor]?

    public let serviceName: String
    public let uri: String
    public let secureURI: String
    public let capabilities: String
    public let version: String
    public let containerType: String
    public let serviceID: Int
    public let authType: String
    public private(set) var presentationMapURI: String?
    public let manifestURI: String?
    public private(set) var manifestData: [String: Any]?
    public let serviceType: Int
    public let tokenStore: MusicServiceTokenStore
    public let httpClient: HTTPClient
    public let soapClient: MusicServiceSOAPClient

    private var searchPrefixMapCache: [String: String]?
    public private(set) var linkCode: String?
    public private(set) var linkDeviceID: String?

    /// Create a third-party music service by its Sonos service name.
    public init(
        serviceName: String,
        tokenStore: MusicServiceTokenStore? = nil,
        device: SoCo? = nil,
        deviceIdentity: MusicServiceDeviceIdentity? = nil,
        httpClient: HTTPClient = URLSessionHTTPClient.shared
    ) throws {
        self.serviceName = serviceName
        self.tokenStore = try tokenStore ?? JSONFileTokenStore.fromConfigFile()
        self.httpClient = httpClient

        let data = try Self.dataForName(serviceName)
        guard
            let uri = data["Uri"],
            let secureURI = data["SecureUri"],
            let capabilities = data["Capabilities"],
            let version = data["Version"],
            let containerType = data["ContainerType"],
            let idText = data["Id"], let serviceID = Int(idText),
            let authType = data["Auth"],
            let typeText = data["ServiceType"], let serviceType = Int(typeText)
        else {
            throw SoCoError.musicService("Incomplete descriptor for music service \(serviceName)")
        }
        self.uri = uri
        self.secureURI = secureURI
        self.capabilities = capabilities
        self.version = version
        self.containerType = containerType
        self.serviceID = serviceID
        self.authType = authType
        self.presentationMapURI = data["PresentationMapUri"]
        self.manifestURI = data["ManifestUri"]
        self.serviceType = serviceType

        // The Python implementation uses 9 seconds here rather than SoCo's normal
        // 60-second historical default. Music-service endpoints are on the internet;
        // a short failure bound is important for interactive controller apps.
        self.soapClient = try MusicServiceSOAPClient(
            endpoint: secureURI,
            timeout: 9,
            musicServicePlaceholder: MusicServiceSOAPClient.Placeholder(
                serviceName: serviceName,
                serviceID: serviceID,
                serviceType: serviceType,
                authType: authType
            ),
            tokenStore: self.tokenStore,
            device: device,
            deviceIdentity: deviceIdentity,
            httpClient: httpClient
        )
        self.soapClient.attach(to: self)
    }

    public var description: String { "<MusicService '\(serviceName)'>" }

    /// Clear the process-wide service descriptor cache. Primarily useful when a Sonos
    /// household changes available services while an app remains running.
    public static func resetDescriptorCache() {
        descriptorLock.lock(); defer { descriptorLock.unlock() }
        cachedDescriptors = nil
    }

    /// Fetch and parse the raw service-descriptor XML from a Sonos device.
    public static func musicServicesData(device: SoCo? = nil) throws -> [String: Descriptor] {
        descriptorLock.lock()
        if let cached = cachedDescriptors {
            descriptorLock.unlock()
            return cached
        }
        descriptorLock.unlock()

        let xml = try descriptorLoader(device)
        let tree = try XMLTree(xml)
        guard let root = tree.root else { throw SoCoError.musicService("Empty services descriptor") }
        var result: [String: Descriptor] = [:]

        // A ServiceType is used elsewhere by Sonos (accounts, descriptors, tokens).
        // Its value consistently appears to be `(service ID * 256) + 7`. This is the
        // same inferred relationship used by upstream SoCo.
        for service in (root.children ?? []).compactMap({ $0 as? SoCoXMLElement }).filter({ $0.localNameSafe == "Service" }) {
            var value: Descriptor = [:]
            for attribute in service.attributes ?? [] {
                if let name = attribute.name, let text = attribute.stringValue { value[name] = text }
            }
            guard let idText = value["Id"], let id = Int(idText) else { continue }
            if let policy = service.firstChild(named: "Policy") {
                for attribute in policy.attributes ?? [] {
                    if let name = attribute.name, let text = attribute.stringValue { value[name] = text }
                }
            }
            if let presentationMap = service.descendants(named: "PresentationMap").first,
               let mapURI = presentationMap.attribute("Uri") {
                value["PresentationMapUri"] = mapURI
                // Upstream SoCo historically records the same URI under StringsUri.
                // That may look suspicious, but retaining it avoids silently changing
                // observable descriptor data.
                value["StringsUri"] = mapURI
            }
            if let manifest = service.firstChild(named: "Manifest"), let uri = manifest.attribute("Uri") {
                value["ManifestUri"] = uri
            }
            value["ServiceID"] = idText
            value["ServiceType"] = String(id * 256 + 7)
            result[value["ServiceType"]!] = value
        }

        descriptorLock.lock()
        cachedDescriptors = result
        descriptorLock.unlock()
        return result
    }

    /// Names of all music services known to Sonos. They are not necessarily subscribed.
    public static func allMusicServiceNames(device: SoCo? = nil) throws -> [String] {
        try musicServicesData(device: device).values.compactMap { $0["Name"] }
    }

    /// Descriptor data for a named service.
    public static func dataForName(_ serviceName: String, device: SoCo? = nil) throws -> Descriptor {
        for service in try musicServicesData(device: device).values where service["Name"] == serviceName {
            return service
        }
        throw SoCoError.musicService("Unknown music service: '\(serviceName)'")
    }

    /// Search-category translations from Sonos's presentation map.
    public func searchPrefixMap() throws -> [String: String] {
        if let cached = searchPrefixMapCache { return cached }
        var result: [String: String] = [:]

        // TuneIn is a special case: it has no presentation map but exposes these
        // documented search IDs.
        if serviceName == "TuneIn" {
            result = ["stations": "search:station", "shows": "search:show", "hosts": "search:host"]
            searchPrefixMapCache = result
            return result
        }

        // Some services expose the presentation map indirectly through a JSON
        // manifest rather than a dedicated descriptor field.
        if presentationMapURI == nil, let manifestURI, manifestData == nil {
            guard let url = URL(string: manifestURI) else { throw SoCoError.musicService("Invalid manifest URI: \(manifestURI)") }
            let response = try httpClient.request(method: "GET", url: url, headers: [:], body: nil, timeout: 9)
            guard (200..<300).contains(response.statusCode) else { throw SoCoError.http(status: response.statusCode, body: response.text) }
            guard let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                throw SoCoError.musicService("Music service manifest is not a JSON object")
            }
            manifestData = json
            if let pmap = json["presentationMap"] as? [String: Any], let uri = pmap["uri"] as? String {
                presentationMapURI = uri
            }
        }

        guard let presentationMapURI else {
            searchPrefixMapCache = result
            return result
        }
        guard let url = URL(string: presentationMapURI) else {
            throw SoCoError.musicService("Invalid presentation map URI: \(presentationMapURI)")
        }
        let response = try httpClient.request(method: "GET", url: url, headers: [:], body: nil, timeout: 9)
        guard (200..<300).contains(response.statusCode) else { throw SoCoError.http(status: response.statusCode, body: response.text) }
        let tree = try XMLTree(response.text)

        for category in tree.root?.descendants(named: "Category") ?? [] {
            guard let id = category.attribute("id") else { continue }
            // Navidrome + bonob have emitted the value on `id` rather than
            // `mappedId`; upstream SoCo intentionally falls back to `id`.
            result[id] = category.attribute("mappedId") ?? id
        }
        for category in tree.root?.descendants(named: "CustomCategory") ?? [] {
            if let stringID = category.attribute("stringId"), let mappedID = category.attribute("mappedId") {
                result[stringID] = mappedID
            }
        }
        searchPrefixMapCache = result
        return result
    }

    public var availableSearchCategories: [String] {
        (try? searchPrefixMap().keys.sorted()) ?? []
    }

    /// Get a URI which can be sent to a Sonos player for playback.
    ///
    /// Real player-generated URIs often use schemes such as `x-sonos-http`, include a
    /// MIME-derived extension, and carry flags. Experiments behind upstream SoCo found
    /// these are not required when asking a player to resolve an SMAPI item: a dummy
    /// `soco://` scheme plus `sid` and serial-number parameters is enough.
    public func sonosURIFromID(_ itemID: String) -> String {
        let quoted = smapiQuote(itemID)
        // SoCo can no longer obtain account serial numbers from current firmware, so
        // it intentionally assumes serial number zero.
        return "soco://\(quoted)?sid=\(serviceID)&sn=0"
    }

    /// The Sonos descriptor placed in DIDL `<desc>` for this service.
    public var desc: String {
        if authType == "DeviceLink" {
            return "SA_RINCON\(serviceType)_X_#Svc\(serviceType)-0-Token"
        }
        return "SA_RINCON\(serviceType)_"
    }

    /// First part of Device/App Link authentication. The same service instance should
    /// normally be used for `completeAuthentication`, because link state is cached here.
    @discardableResult
    public func beginAuthentication() throws -> String {
        let result = try soapClient.beginAuthentication()
        linkCode = result.linkCode
        linkDeviceID = result.linkDeviceID
        return result.registrationURL
    }

    public func completeAuthentication(linkCode: String? = nil, linkDeviceID: String? = nil) throws {
        guard let code = linkCode ?? self.linkCode, !code.isEmpty else {
            throw SoCoError.musicServiceAuth("link_code not provided or cached")
        }
        try soapClient.completeAuthentication(linkCode: code, linkDeviceID: linkDeviceID ?? self.linkDeviceID)
        self.linkCode = nil
        self.linkDeviceID = nil
    }

    // MARK: Common SMAPI SOAP methods

    public func getMetadata(item: String = "root", index: Int = 0, count: Int = 100, recursive: Bool = false) throws -> SMAPI.SearchResult {
        let response = try soapClient.call("getMetadata", arguments: [
            ("id", item), ("index", String(index)), ("count", String(count)), ("recursive", recursive ? "1" : "0")
        ])
        return try SMAPI.parseResponse(service: self, response: response, searchType: "browse")
    }

    public func getMetadata(item: SMAPI.MusicServiceItem, index: Int = 0, count: Int = 100, recursive: Bool = false) throws -> SMAPI.SearchResult {
        try getMetadata(item: item.rawID ?? item.itemID, index: index, count: count, recursive: recursive)
    }

    public func search(category: String, term: String = "", index: Int = 0, count: Int = 100) throws -> SMAPI.SearchResult {
        guard let searchCategory = try searchPrefixMap()[category] else {
            throw SoCoError.musicService("\(serviceName) does not support the '\(category)' search category")
        }
        let response = try soapClient.call("search", arguments: [
            ("id", searchCategory), ("term", term), ("index", String(index)), ("count", String(count))
        ])
        return try SMAPI.parseResponse(service: self, response: response, searchType: category)
    }

    public func getMediaMetadata(itemID: String) throws -> [String: Any]? {
        try soapClient.call("getMediaMetadata", arguments: [("id", itemID)])["getMediaMetadataResult"] as? [String: Any]
    }
    public func getMediaURI(itemID: String) throws -> String? {
        try soapClient.call("getMediaURI", arguments: [("id", itemID)])["getMediaURIResult"] as? String
    }
    public func getLastUpdate() throws -> [String: Any]? {
        try soapClient.call("getLastUpdate")["getLastUpdateResult"] as? [String: Any]
    }
    public func getExtendedMetadata(itemID: String) throws -> [String: Any]? {
        try soapClient.call("getExtendedMetadata", arguments: [("id", itemID)])["getExtendedMetadataResult"] as? [String: Any]
    }
    public func getExtendedMetadataText(itemID: String, metadataType: String) throws -> String? {
        try soapClient.call("getExtendedMetadataText", arguments: [("id", itemID), ("type", metadataType)])["getExtendedMetadataTextResult"] as? String
    }
}

/// SOAP client for third-party Sonos music services. It owns authentication mechanics;
/// normal applications interact with it through `MusicService` rather than directly.
public final class MusicServiceSOAPClient {
    public struct Placeholder {
        let serviceName: String
        let serviceID: Int
        let serviceType: Int
        let authType: String
    }
    public struct AuthenticationStart: Equatable {
        public let registrationURL: String
        public let linkCode: String
        public let linkDeviceID: String?
    }

    public let endpoint: URL
    public let timeout: TimeInterval
    public let tokenStore: MusicServiceTokenStore
    public let namespace = "http://www.sonos.com/Services/1.1"
    public let httpHeaders: [String: String]
    public let device: SoCo?
    public let deviceID: String
    public let householdID: String
    public let httpClient: HTTPClient

    private weak var musicService: MusicService?
    private let placeholder: Placeholder
    private let lock = NSRecursiveLock()
    private var cachedSOAPHeader: String?

    fileprivate init(
        endpoint: String,
        timeout: TimeInterval,
        musicServicePlaceholder: Placeholder,
        tokenStore: MusicServiceTokenStore,
        device: SoCo?,
        deviceIdentity: MusicServiceDeviceIdentity?,
        httpClient: HTTPClient
    ) throws {
        guard let endpointURL = URL(string: endpoint) else { throw SoCoError.musicService("Invalid music service endpoint: \(endpoint)") }
        self.endpoint = endpointURL
        self.timeout = timeout
        self.placeholder = musicServicePlaceholder
        self.tokenStore = tokenStore
        self.httpClient = httpClient

        // Spotify uses gzip. Others may as well. Upstream SoCo also preserves this
        // deliberately old Sonos/iOS User-Agent because Google Play historically
        // rejected otherwise valid requests when the firmware/user-agent differed.
        self.httpHeaders = [
            "Accept-Encoding": "gzip, deflate",
            "User-Agent": "Linux UPnP/1.0 Sonos/29.3-87071 (ICRU_iPhone7,1); iOS/Version 8.2 (Build 12D508)"
        ]

        if let deviceIdentity {
            self.device = device
            self.deviceID = deviceIdentity.deviceID
            self.householdID = deviceIdentity.householdID
        } else {
            guard let resolvedDevice = try device ?? Discovery.anySoCo() else { throw SoCoError.noDeviceFound }
            self.device = resolvedDevice
            let trial = try resolvedDevice.systemProperties.sendCommand("GetString", arguments: [("VariableName", "R_TrialZPSerial")])
            self.deviceID = trial["StringValue"] ?? ""
            self.householdID = try resolvedDevice.householdID()
        }
    }

    fileprivate func attach(to musicService: MusicService) { self.musicService = musicService }

    private var serviceName: String { musicService?.serviceName ?? placeholder.serviceName }
    private var serviceID: Int { musicService?.serviceID ?? placeholder.serviceID }
    private var authType: String { musicService?.authType ?? placeholder.authType }

    /// Generate the authentication SOAP header required by SMAPI.
    public func soapHeader() throws -> String {
        lock.lock(); defer { lock.unlock() }
        if let cachedSOAPHeader { return cachedSOAPHeader }

        var xml = "<credentials xmlns=\"\(namespace)\">"
        xml += "<deviceId>\(xmlEscape(deviceID))</deviceId><deviceProvider>Sonos</deviceProvider>"
        if authType == "DeviceLink" || authType == "AppLink" {
            xml += "<context></context>"
            if tokenStore.hasToken(musicServiceID: serviceID, householdID: householdID) {
                let pair = try tokenStore.loadTokenPair(musicServiceID: serviceID, householdID: householdID)
                xml += "<loginToken><token>\(xmlEscape(pair.0))</token><key>\(xmlEscape(pair.1))</key>"
                xml += "<householdId>\(xmlEscape(householdID))</householdId></loginToken>"
            }
        }
        // UserId authentication is intentionally not synthesized here. Current Sonos
        // firmware no longer exposes the account credentials that old controllers used.
        // Anonymous authentication needs no additional elements.
        xml += "</credentials>"
        cachedSOAPHeader = xml
        return xml
    }

    /// Call a music-service SOAP method and convert its XML result to Swift dictionaries.
    public func call(_ method: String, arguments: [(String, String)] = []) throws -> [String: Any] {
        func invoke() throws -> SoCoXMLElement {
            let message = SoapMessage(
                endpoint: endpoint,
                method: method,
                parameters: arguments,
                httpHeaders: httpHeaders,
                soapAction: "http://www.sonos.com/Services/1.1#\(method)",
                soapHeader: try soapHeader(),
                namespace: namespace,
                timeout: timeout,
                httpClient: httpClient
            )
            return try message.call()
        }

        let element: SoCoXMLElement
        do {
            element = try invoke()
        } catch let fault as SoapFault {
            if fault.faultCode.contains("Client.AuthTokenExpired") {
                throw SoCoError.musicServiceAuth(
                    "Authorization for \(serviceName) expired, is invalid or has not yet been completed: [\(fault.faultCode) / \(fault.faultString) / \(fault.detailXML ?? "")]"
                )
            }
            if fault.faultCode.contains("Client.TokenRefreshRequired") {
                guard authType == "DeviceLink" || authType == "AppLink" else {
                    throw SoCoError.musicServiceAuth("Token-refresh not supported for music service auth type: \(authType)")
                }
                guard let detail = fault.detailXML else {
                    throw SoCoError.musicServiceAuth("Got a TokenRefreshRequired but no detail was returned")
                }
                let tree = try XMLTree(detail)
                let token = tree.root?.descendants(named: "authToken").first?.text ?? (tree.root?.localNameSafe == "authToken" ? tree.root?.text : nil)
                let key = tree.root?.descendants(named: "privateKey").first?.text ?? (tree.root?.localNameSafe == "privateKey" ? tree.root?.text : nil)
                guard let token, !token.isEmpty, let key, !key.isEmpty else {
                    throw SoCoError.musicServiceAuth("Got a TokenRefreshRequired but no new token was found in the reply: \(detail)")
                }
                try tokenStore.saveTokenPair(musicServiceID: serviceID, householdID: householdID, tokenPair: (token, key))
                lock.lock(); cachedSOAPHeader = nil; lock.unlock()
                element = try invoke()
            } else {
                throw SoCoError.musicService("\(fault.faultString) [\(fault.faultCode)]")
            }
        } catch SoCoError.xml {
            throw SoCoError.musicServiceAuth("Got empty response to request, likely because the service is not authenticated")
        }
        return smapiElementDictionary(element)
    }

    public func beginAuthentication() throws -> AuthenticationStart {
        switch authType {
        case "DeviceLink":
            guard let result = try call("getDeviceLinkCode", arguments: [("householdId", householdID)])["getDeviceLinkCodeResult"] as? [String: Any],
                  let regURL = result["regUrl"] as? String,
                  let code = result["linkCode"] as? String else {
                throw SoCoError.musicServiceAuth("Invalid getDeviceLinkCode response")
            }
            return AuthenticationStart(registrationURL: regURL, linkCode: code, linkDeviceID: result["linkDeviceId"] as? String)
        case "AppLink":
            guard let result = try call("getAppLink", arguments: [("householdId", householdID)])["getAppLinkResult"] as? [String: Any],
                  let authorize = result["authorizeAccount"] as? [String: Any],
                  let deviceLink = authorize["deviceLink"] as? [String: Any],
                  let regURL = deviceLink["regUrl"] as? String,
                  let code = deviceLink["linkCode"] as? String else {
                throw SoCoError.musicServiceAuth("Invalid getAppLink response")
            }
            return AuthenticationStart(registrationURL: regURL, linkCode: code, linkDeviceID: deviceLink["linkDeviceId"] as? String)
        default:
            throw SoCoError.musicServiceAuth("beginAuthentication is not implemented for auth type \(authType)")
        }
    }

    public func completeAuthentication(linkCode: String, linkDeviceID: String? = nil) throws {
        guard let result = try call("getDeviceAuthToken", arguments: [
            ("householdId", householdID), ("linkCode", linkCode), ("linkDeviceId", linkDeviceID ?? deviceID)
        ])["getDeviceAuthTokenResult"] as? [String: Any],
              let token = result["authToken"] as? String,
              let key = result["privateKey"] as? String else {
            throw SoCoError.musicServiceAuth("Invalid getDeviceAuthToken response")
        }
        try tokenStore.saveTokenPair(musicServiceID: serviceID, householdID: householdID, tokenPair: (token, key))
        lock.lock(); cachedSOAPHeader = nil; lock.unlock()
    }
}

/// Convert an XML element into the ordered-dictionary-like shape used by Python
/// `xmltodict`: leaf elements become strings; nested elements become dictionaries;
/// repeated child names become arrays. Attributes are included with `@` prefixes only
/// when present because a few SMAPI services return meaningful attributes.
private func smapiElementDictionary(_ element: SoCoXMLElement) -> [String: Any] {
    func convert(_ node: SoCoXMLElement) -> Any {
        let childElements = (node.children ?? []).compactMap { $0 as? SoCoXMLElement }
        if childElements.isEmpty {
            return node.stringValue ?? ""
        }
        var dictionary: [String: Any] = [:]
        for attribute in node.attributes ?? [] {
            if let name = attribute.name, let value = attribute.stringValue { dictionary["@\(name)"] = value }
        }
        for child in childElements {
            let key = child.localNameSafe
            let value = convert(child)
            if let existing = dictionary[key] {
                if var array = existing as? [Any] { array.append(value); dictionary[key] = array }
                else { dictionary[key] = [existing, value] }
            } else {
                dictionary[key] = value
            }
        }
        return dictionary
    }

    guard let result = convert(element) as? [String: Any] else { return [:] }
    return result
}
