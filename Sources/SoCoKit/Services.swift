import Foundation

/// Classes representing Sonos UPnP services.
///
/// The original SoCo module demonstrates calls such as `RenderingControl.GetMute`
/// and `ContentDirectory.Browse`. Python can manufacture those methods lazily via
/// `__getattr__`; Swift cannot add methods at runtime, so this port exposes the same
/// dispatcher through `action(named:)` / `dispatch(_:values:)`, while the strongly
/// typed SoCo APIs call `sendCommand` directly.
///
/// UPnP Device Architecture specification:
/// http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.0.pdf

// UNICODE NOTE
// UPnP requires all XML to be transmitted/received with utf-8 encoding. All
// strings used in this module are unicode. In Python the Requests library takes
// care of the necessary encoding and decoding provided the correct encoding
// headers are supplied. Swift's `String` is Unicode and we convert SOAP bodies to
// UTF-8 `Data` only at the HTTP transport boundary, preserving the same rule.

/// A UPnP action variable type with a default value and allowed range/list.
public struct Vartype: Equatable, CustomStringConvertible, Sendable {
    public let datatype: String
    public let defaultValue: String?
    public let allowedValues: [String]?
    public let allowedRange: [String]?

    public init(
        datatype: String,
        defaultValue: String? = nil,
        allowedValues: [String]? = nil,
        allowedRange: [String]? = nil
    ) {
        self.datatype = datatype
        self.defaultValue = defaultValue
        self.allowedValues = allowedValues
        self.allowedRange = allowedRange
    }

    /// Python-compatible alias for `default`.
    public var `default`: String? { defaultValue }
    /// Python-compatible alias for `list`.
    public var list: [String]? { allowedValues }
    /// Python-compatible alias for `range`.
    public var range: [String]? { allowedRange }

    public var description: String {
        if let allowedValues {
            return "[\(allowedValues.joined(separator: ", "))]"
        }
        if let range = allowedRange, range.count >= 2 {
            return "[\(range[0])..\(range[1])]"
        }
        return datatype
    }
}

/// A UPnP argument and its type.
public struct ServiceArgument: Equatable, CustomStringConvertible, Sendable {
    public let name: String
    public let vartype: Vartype

    public init(name: String, vartype: Vartype) {
        self.name = name
        self.vartype = vartype
    }

    public var description: String {
        let argument = vartype.defaultValue.map { "\(name)=\($0)" } ?? name
        return "\(argument): \(vartype)"
    }
}

/// A UPnP Action and its arguments.
public struct ServiceAction: Equatable, CustomStringConvertible, Sendable {
    public let name: String
    public let inputArguments: [ServiceArgument]
    public let outputArguments: [ServiceArgument]

    public init(
        name: String,
        inputArguments: [ServiceArgument] = [],
        outputArguments: [ServiceArgument] = []
    ) {
        self.name = name
        self.inputArguments = inputArguments
        self.outputArguments = outputArguments
    }

    /// Python-compatible alias for `in_args`.
    public var inArgs: [ServiceArgument] { inputArguments }
    /// Python-compatible alias for `out_args`.
    public var outArgs: [ServiceArgument] { outputArguments }

    public var description: String {
        let args = inputArguments.map(\.description).joined(separator: ", ")
        let returns = outputArguments.map(\.description).joined(separator: ", ")
        return "\(name)(\(args)) -> {\(returns)}"
    }
}

/// Familiar names retained from the Python API.
public typealias Action = ServiceAction
public typealias Argument = ServiceArgument

/// A class representing a UPnP service.
///
/// This is the base class for all Sonos Service classes. The Python class has a
/// dynamic method dispatcher: calls to methods which are not explicitly defined
/// are automatically dispatched to the UPnP service action with the same name.
/// Swift has no `__getattr__`, so `action(named:)` returns an equivalent callable
/// closure and `dispatch(_:values:)` performs the same composition directly.
open class Service {
    /// The SoCo instance to which UPnP Actions are sent.
    ///
    /// Keep this weak so the normal `SoCo -> Service` lazy-property graph does
    /// not form a retain cycle. The service also snapshots the address and HTTP
    /// transport below, so a standalone Service remains fully usable even when
    /// its original SoCo wrapper is no longer retained elsewhere.
    public private(set) weak var soco: SoCo?
    public let ipAddress: String
    public let httpClient: HTTPClient

    /// The UPnP service type.
    public var serviceType: String
    /// The UPnP service version.
    public var version = 1
    public var serviceID: String
    /// The base URL for sending UPnP Actions.
    public var baseURL: URL { URL(string: "http://\(ipAddress):1400")! }
    /// The UPnP Control URL.
    public var controlURL: String
    /// The service control protocol description URL.
    public var scpdURL: String
    /// The service eventing subscription URL.
    public var eventSubscriptionURL: String

    /// A cache for storing the result of network calls. By default this is a
    /// TimedCache with a default timeout of zero.
    public var cache: SoCoCache

    public var defaultArguments: [String: String] = [:]
    public var additionalHeaders: [String: String] = [:]
    public var upnpErrors: [Int: String] = Service.standardUPnPErrors

    // Caching variables for actions and event_vars, filled when they are
    // requested for the first time.
    private var actionCache: [ServiceAction]?
    private var eventVarCache: [(String, String)]?

    // From table 3.3 in
    // http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.1.pdf
    // This list may not be complete, but should be good enough to be going on
    // with. Error codes between 700-799 are defined for particular services and
    // may be overridden in subclasses. Error codes >800 are generally SONOS
    // specific. NB It may well be that SONOS does not use some of these codes.
    public static let standardUPnPErrors: [Int: String] = [
        400: "Bad Request",
        401: "Invalid Action",
        402: "Invalid Args",
        404: "Invalid Var",
        412: "Precondition Failed",
        501: "Action Failed",
        600: "Argument Value Invalid",
        601: "Argument Value Out of Range",
        602: "Optional Action Not Implemented",
        603: "Out Of Memory",
        604: "Human Intervention Required",
        605: "String Argument Too Long",
        606: "Action Not Authorized",
        607: "Signature Failure",
        608: "Signature Missing",
        609: "Not Encrypted",
        610: "Invalid Sequence",
        611: "Invalid Control URL",
        612: "No Such Session",
    ]

    /// The Python class name is part of the wire-level default URLs. A few Swift
    /// type names omit Python underscores or avoid a stdlib name collision, so
    /// map those names back before deriving URLs.
    private static func pythonServiceClassName(for swiftName: String) -> String {
        switch swiftName {
        case "MSConnectionManager": return "MS_ConnectionManager"
        case "MRConnectionManager": return "MR_ConnectionManager"
        case "QueueService": return "Queue"
        default: return swiftName
        }
    }

    /// Create a service attached to a SoCo speaker.
    public required init(_ soco: SoCo) {
        self.soco = soco
        self.ipAddress = soco.ipAddress
        self.httpClient = soco.httpClient

        // Some defaults. Some or all these will need to be overridden
        // specifically in a subclass. There is other information we could
        // record, but this will do for the moment. Info about a Sonos device is
        // available at <IP_address>/xml/device_description.xml in <service> tags.
        let swiftName = String(describing: Self.self)
        let serviceName = Self.pythonServiceClassName(for: swiftName)
        serviceType = serviceName
        serviceID = serviceName
        controlURL = "/\(serviceName)/Control"
        scpdURL = "/xml/\(serviceName)1.xml"
        eventSubscriptionURL = "/\(serviceName)/Event"
        cache = Cache.make(defaultTimeout: 0)
    }

    /// Wrap a list of tuples in XML ready to pass into a SOAP request.
    ///
    /// The values can be strings or values already converted to their string
    /// representation. XML-sensitive characters are escaped before each value
    /// is wrapped in its argument tag.
    public static func wrapArguments(_ args: [(String, String)] = []) -> String {
        args.map { name, value in
            "<\(name)>\(xmlEscape(value))</\(name)>"
        }.joined()
    }

    /// Extract arguments and their values from a SOAP response.
    ///
    /// A UPnP SOAP response has an Envelope, Body, then an action-specific
    /// `...Response` element. The children of that element become the returned
    /// name/value dictionary. XML unescaping is performed by SoCoKit’s portable XML parser.
    public static func unwrapArguments(_ xmlResponse: String) throws -> [String: String] {
        let tree = try XMLTree(xmlResponse)
        guard
            let body = tree.root?.descendants(named: "Body").first,
            let actionResponse = body.children?.compactMap({ $0 as? SoCoXMLElement }).first
        else {
            throw SoCoError.xml("Invalid SOAP response")
        }

        var result: [String: String] = [:]
        for child in actionResponse.children?.compactMap({ $0 as? SoCoXMLElement }) ?? [] {
            result[child.localNameSafe] = child.text
        }
        return result
    }

    /// Compose the argument list from a dictionary, respecting default values.
    ///
    /// - Throws: `SoCoError.unsupported` if the service does not expose the
    ///   action, or an argument error if supplied names do not match its SCPD
    ///   signature.
    public func composeArguments(
        action actionName: String,
        values: [String: String]
    ) throws -> [(String, String)] {
        guard let action = try actions().first(where: { $0.name == actionName }) else {
            throw SoCoError.unsupported("Unknown Action: \(actionName)")
        }

        // Check for given argument names which do not occur in the expected
        // argument list.
        let expected = Set(action.inputArguments.map(\.name))
        if let unexpected = values.keys.first(where: { !expected.contains($0) }) {
            throw SoCoError.invalidArgument(
                "Unexpected argument '\(unexpected)'. Method signature: \(action)"
            )
        }

        // List the (name, value) tuples for each argument in the action's
        // declared argument order. Sonos generally tolerates little variation
        // here, so retaining SCPD order is intentional.
        var composed: [(String, String)] = []
        for argument in action.inputArguments {
            if let value = values[argument.name] {
                composed.append((argument.name, value))
                continue
            }
            if let value = defaultArguments[argument.name] {
                composed.append((argument.name, value))
                continue
            }
            if let value = argument.vartype.defaultValue {
                composed.append((argument.name, value))
                continue
            }
            throw SoCoError.missingArgument(
                "Missing argument '\(argument.name)'. Method signature: \(action)"
            )
        }
        return composed
    }

    /// Build a SOAP request.
    ///
    /// Does not set Content-Length or Host headers; URLSession completes those
    /// when the request is sent.
    public func buildCommand(
        action: String,
        arguments: [(String, String)] = []
    ) -> (headers: [String: String], body: String) {
        let argumentsXML = Self.wrapArguments(arguments)
        let body = "<?xml version=\"1.0\"?>"
            + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\""
            + " s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
            + "<s:Body>"
            + "<u:\(action) xmlns:u=\"urn:schemas-upnp-org:service:\(serviceType):\(version)\">"
            + argumentsXML
            + "</u:\(action)>"
            + "</s:Body>"
            + "</s:Envelope>"

        var headers = [
            "Content-Type": "text/xml; charset=\"utf-8\"",
            "SOAPACTION": "urn:schemas-upnp-org:service:\(serviceType):\(version)#\(action)",
        ]
        if !additionalHeaders.isEmpty {
            additionalHeaders.forEach { headers[$0] = $1 }
        }

        // Note that although charset is utf-8, `body` is still a Swift Unicode
        // String. It is converted to bytes only when sent over the network.
        return (headers, body)
    }

    /// Send a command to a Sonos device.
    ///
    /// A cache is operated so the result may be stored for `cacheTimeout`
    /// seconds. A subsequent call with the same action and arguments within that
    /// period is returned from the cache, saving a network call. The cache may
    /// be invalidated or primed by another part of the program (for example when
    /// an event indicates that speaker state has changed).
    @discardableResult
    public func sendCommand(
        _ action: String,
        arguments: [(String, String)] = [],
        cache explicitCache: SoCoCache? = nil,
        cacheTimeout: TimeInterval? = nil,
        timeout: TimeInterval? = nil
    ) throws -> [String: String] {
        let selectedCache = explicitCache ?? cache
        let key: [AnyHashable] = [action] + arguments.map { "\($0.0)=\($0.1)" as AnyHashable }
        if let cached = selectedCache.get(keyParts: key) as? [String: String] {
            return cached
        }

        // Cache miss, so go ahead and make a network call.
        let command = buildCommand(action: action, arguments: arguments)
        let url = URL(string: controlURL, relativeTo: baseURL)!.absoluteURL
        let response = try httpClient.request(
            method: "POST",
            url: url,
            headers: command.headers,
            body: Data(command.body.utf8),
            timeout: timeout ?? SoCoConfig.requestTimeout
        )

        switch response.statusCode {
        case 200:
            // An empty dictionary is a valid Swift result: it simply means the
            // action returned no output arguments. Python used `or True` because
            // its historical dynamic dispatcher needed a truthy sentinel.
            let result = try Self.unwrapArguments(response.text)
            // There is no need to cache errors, since a later call should retry
            // the actual device.
            selectedCache.put(result, keyParts: key, timeout: cacheTimeout)
            return result
        case 405:
            throw SoCoError.unsupported("\(action) not supported on \(ipAddress)")
        case 500:
            // UPnP requires HTTP 500 when a device rejects an action. The body
            // is a SOAP Fault; parse it and raise the specific UPnP error.
            try handleUPnPError(response.text)
        default:
            throw SoCoError.http(status: response.statusCode, body: response.text)
        }
    }

    /// Swift equivalent of Python's dynamic dispatcher.
    ///
    /// This reads the action signature from SCPD, fills defaults and retains the
    /// action's declared argument order before sending the command.
    @discardableResult
    public func dispatch(
        _ action: String,
        values: [String: Any] = [:],
        cache: SoCoCache? = nil,
        cacheTimeout: TimeInterval? = nil,
        timeout: TimeInterval? = nil
    ) throws -> [String: String] {
        let stringValues = values.mapValues { String(describing: $0) }
        let arguments = try composeArguments(action: action, values: stringValues)
        return try sendCommand(
            action,
            arguments: arguments,
            cache: cache,
            cacheTimeout: cacheTimeout,
            timeout: timeout
        )
    }

    /// Return a callable for an arbitrary action name, mirroring Python's
    /// lazily-created bound method as closely as Swift permits.
    public func action(
        named actionName: String
    ) -> (_ values: [String: Any], _ cacheTimeout: TimeInterval?) throws -> [String: String] {
        { [unowned self] values, cacheTimeout in
            try self.dispatch(actionName, values: values, cacheTimeout: cacheTimeout)
        }
    }

    /// Convenience retained from the first Swift implementation.
    @discardableResult
    public func call(
        _ action: String,
        _ values: [String: Any] = [:],
        cacheTimeout: TimeInterval? = nil,
        timeout: TimeInterval? = nil
    ) throws -> [String: String] {
        try dispatch(action, values: values, cacheTimeout: cacheTimeout, timeout: timeout)
    }

    /// Dissect a UPnP error and throw an appropriate error.
    ///
    /// Sonos does not reliably use the optional SOAP `errorDescription`; the
    /// numeric `errorCode` is mapped against the standard/service-specific table
    /// just as in SoCo.
    public func handleUPnPError(_ xmlError: String) throws -> Never {
        do {
            let tree = try XMLTree(xmlError)
            guard
                let rawCode = tree.root?.descendants(named: "errorCode").first?.text,
                let code = Int(rawCode)
            else {
                throw SoCoError.unknown(
                    "Error parsing UPnP error response from \(ipAddress): \(xmlError)"
                )
            }
            throw SoCoError.upnp(
                code: rawCode,
                description: upnpErrors[code] ?? "",
                xml: xmlError
            )
        } catch SoCoError.upnp(let code, let description, let xml) {
            throw SoCoError.upnp(code: code, description: description, xml: xml)
        } catch {
            // Parsing errors, missing codes and malformed/empty responses are all
            // UnknownSoCoException in the original implementation.
            throw SoCoError.unknown(
                "Error parsing UPnP error response from \(ipAddress): \(xmlError)"
            )
        }
    }

    /// The service's supported actions, cached after the first SCPD fetch.
    public func actions() throws -> [ServiceAction] {
        if let actionCache { return actionCache }
        let response = try fetchSCPD()
        let parsed = try Self.parseSCPDActions(response)
        actionCache = parsed
        return parsed
    }

    /// Python-compatible iterator spelling, represented as the eager Swift
    /// collection returned by `actions()`.
    public func iterActions() throws -> [ServiceAction] { try actions() }

    /// The service's eventable variables as `(variable name, data type)` tuples.
    public func eventVariables() throws -> [(String, String)] {
        if let eventVarCache { return eventVarCache }
        let response = try fetchSCPD()
        let parsed = try Self.parseSCPDEventVariables(response)
        eventVarCache = parsed
        return parsed
    }

    /// Python-compatible iterator spelling.
    public func iterEventVariables() throws -> [(String, String)] { try eventVariables() }

    private func fetchSCPD() throws -> String {
        let url = URL(string: scpdURL, relativeTo: baseURL)!.absoluteURL
        let response = try httpClient.request(
            method: "GET",
            url: url,
            headers: [:],
            body: nil,
            timeout: 10
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SoCoError.http(status: response.statusCode, body: response.text)
        }
        return response.text
    }

    /// Parse actions from a UPnP service control protocol description document.
    public static func parseSCPDActions(_ xml: String) throws -> [ServiceAction] {
        let tree = try XMLTree(xml)

        // Parse the state variables to get the relevant variable types.
        var vartypes: [String: Vartype] = [:]
        for state in tree.root?.descendants(named: "stateVariable") ?? [] {
            guard
                let name = state.firstChild(named: "name")?.text.nilIfEmpty,
                let datatype = state.firstChild(named: "dataType")?.text.nilIfEmpty
            else { continue }

            let defaultValue = state.firstChild(named: "defaultValue")?.text.nilIfEmpty
            let valueList = childElementTexts(of: state.firstChild(named: "allowedValueList"))
            let valueRange = childElementTexts(of: state.firstChild(named: "allowedValueRange"))
            vartypes[name] = Vartype(
                datatype: datatype,
                defaultValue: defaultValue,
                allowedValues: valueList.isEmpty ? nil : valueList,
                allowedRange: valueRange.isEmpty ? nil : valueRange
            )
        }

        // Find all the actions and connect each argument to its related state
        // variable type.
        var result: [ServiceAction] = []
        for actionNode in tree.root?.descendants(named: "action") ?? [] {
            guard let actionName = actionNode.firstChild(named: "name")?.text.nilIfEmpty else {
                continue
            }

            var inArgs: [ServiceArgument] = []
            var outArgs: [ServiceArgument] = []
            if let argumentList = actionNode.firstChild(named: "argumentList") {
                for argument in argumentList.children?.compactMap({ $0 as? SoCoXMLElement }) ?? []
                where argument.localNameSafe == "argument" {
                    guard
                        let name = argument.firstChild(named: "name")?.text.nilIfEmpty,
                        let direction = argument.firstChild(named: "direction")?.text.nilIfEmpty,
                        let related = argument.firstChild(named: "relatedStateVariable")?.text.nilIfEmpty,
                        let vartype = vartypes[related]
                    else { continue }

                    let parsed = ServiceArgument(name: name, vartype: vartype)
                    if direction == "in" {
                        inArgs.append(parsed)
                    } else {
                        outArgs.append(parsed)
                    }
                }
            }

            result.append(
                ServiceAction(
                    name: actionName,
                    inputArguments: inArgs,
                    outputArguments: outArgs
                )
            )
        }
        return result
    }

    /// Parse eventable variables from a service SCPD document.
    public static func parseSCPDEventVariables(_ xml: String) throws -> [(String, String)] {
        let tree = try XMLTree(xml)
        var result: [(String, String)] = []

        // We are only interested if `sendEvents` is `yes`, i.e. this is an
        // eventable variable.
        for state in tree.root?.descendants(named: "stateVariable") ?? []
        where state.attribute("sendEvents") == "yes" {
            guard
                let name = state.firstChild(named: "name")?.text.nilIfEmpty,
                let datatype = state.firstChild(named: "dataType")?.text.nilIfEmpty
            else { continue }
            result.append((name, datatype))
        }
        return result
    }

    private static func childElementTexts(of element: SoCoXMLElement?) -> [String] {
        element?.children?.compactMap { child in
            guard let element = child as? SoCoXMLElement else { return nil }
            return element.text.nilIfEmpty
        } ?? []
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Sonos alarm service, for setting and getting time and alarms.
open class AlarmClock: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        upnpErrors[801] = "Already an alarm for this time"
    }
}

/// Sonos music services service, for functions related to 3rd party music services.
open class MusicServices: Service {}

/// Sonos audio in service, for functions related to RCA audio input.
open class AudioIn: Service {}

/// Sonos device properties service, for functions relating to zones, LED state,
/// stereo pairs etc.
open class DeviceProperties: Service {}

/// Sonos system properties service, for functions relating to authentication etc.
open class SystemProperties: Service {}

/// Sonos zone group topology service, for functions relating to network topology,
/// diagnostics and updates.
open class ZoneGroupTopology: Service {}

/// Sonos group management service, for services relating to groups.
open class GroupManagement: Service {}

/// Sonos Tencent QPlay service (a Chinese music service).
open class QPlay: Service {}

/// UPnP standard Content Directory service, for functions relating to browsing,
/// searching and listing available music.
open class ContentDirectory: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        controlURL = "/MediaServer/ContentDirectory/Control"
        eventSubscriptionURL = "/MediaServer/ContentDirectory/Event"

        // For error codes, see table 2.7.16 in the UPnP ContentDirectory v1
        // service specification.
        [
            701: "No such object",
            702: "Invalid CurrentTagValue",
            703: "Invalid NewTagValue",
            704: "Required tag",
            705: "Read only tag",
            706: "Parameter Mismatch",
            708: "Unsupported or invalid search criteria",
            709: "Unsupported or invalid sort criteria",
            710: "No such container",
            711: "Restricted object",
            712: "Bad metadata",
            713: "Restricted parent object",
            714: "No such source resource",
            715: "Resource access denied",
            716: "Transfer busy",
            717: "No such file transfer",
            718: "No such destination resource",
            719: "Destination resource access denied",
            720: "Cannot process the request",
        ].forEach { upnpErrors[$0] = $1 }

        additionalHeaders = ["USER-AGENT": "Sonos/83.1-61210"]
    }
}

/// UPnP standard connection manager service for the media server.
open class MSConnectionManager: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        serviceType = "ConnectionManager"
        controlURL = "/MediaServer/ConnectionManager/Control"
        eventSubscriptionURL = "/MediaServer/ConnectionManager/Event"
    }
}

/// UPnP standard rendering control service, for functions relating to playback
/// rendering, eg bass, treble, volume and EQ.
open class RenderingControl: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        controlURL = "/MediaRenderer/RenderingControl/Control"
        eventSubscriptionURL = "/MediaRenderer/RenderingControl/Event"
        defaultArguments["InstanceID"] = "0"
    }
}

/// UPnP standard connection manager service for the media renderer.
open class MRConnectionManager: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        serviceType = "ConnectionManager"
        controlURL = "/MediaRenderer/ConnectionManager/Control"
        eventSubscriptionURL = "/MediaRenderer/ConnectionManager/Event"
    }
}

/// UPnP standard AV Transport service, for functions relating to transport
/// management, eg play, stop, seek, playlists etc.
open class AVTransport: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        controlURL = "/MediaRenderer/AVTransport/Control"
        eventSubscriptionURL = "/MediaRenderer/AVTransport/Event"

        // For error codes, see the UPnP AVTransport v1 service specification.
        [
            701: "Transition not available",
            702: "No contents",
            703: "Read error",
            704: "Format not supported for playback",
            705: "Transport is locked",
            706: "Write error",
            707: "Media is protected or not writeable",
            708: "Format not supported for recording",
            709: "Media is full",
            710: "Seek mode not supported",
            711: "Illegal seek target",
            712: "Play mode not supported",
            713: "Record quality not supported",
            714: "Illegal MIME-Type",
            715: "Content \"BUSY\"",
            716: "Resource Not found",
            717: "Play speed not supported",
            718: "Invalid InstanceID",
            737: "No DNS Server",
            738: "Bad Domain Name",
            739: "Server Error",
        ].forEach { upnpErrors[$0] = $1 }
        defaultArguments["InstanceID"] = "0"
    }
}

/// Sonos queue service, for functions relating to queue management, saving queues etc.
///
/// The Swift type is named `QueueService` to avoid confusion with generic queue
/// types, but its on-wire service identity remains exactly `Queue`.
open class QueueService: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        controlURL = "/MediaRenderer/Queue/Control"
        eventSubscriptionURL = "/MediaRenderer/Queue/Event"
    }
}

/// Sonos group rendering control service, for functions relating to group volume etc.
open class GroupRenderingControl: Service {
    public required init(_ soco: SoCo) {
        super.init(soco)
        controlURL = "/MediaRenderer/GroupRenderingControl/Control"
        eventSubscriptionURL = "/MediaRenderer/GroupRenderingControl/Event"
        defaultArguments["InstanceID"] = "0"
    }
}

// Python service-class spellings retained where Swift's identifier rules allow
// them. The on-wire SCPD names are already preserved by `Service` itself.
public typealias MS_ConnectionManager = MSConnectionManager
public typealias MR_ConnectionManager = MRConnectionManager
