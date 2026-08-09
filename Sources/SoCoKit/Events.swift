import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// A failed object instantiation carried inside an event.
///
/// Python SoCo uses `SoCoFault`, a proxy which rethrows its parsing exception on
/// common use. Swift has explicit error handling, so this object exposes the
/// stored error via `throwException()` / `resolved()` rather than pretending to
/// be the object which failed to parse.
public struct SoCoFault: CustomStringConvertible {
    public let exception: Error

    public init(_ exception: Error) { self.exception = exception }

    public func throwException<T>() throws -> T { throw exception }

    public var description: String { "<SoCoFault: \(exception)>" }
}

/// Error raised when metadata embedded in an event cannot be parsed.
public struct EventParseFault: Error, CustomStringConvertible {
    public let tag: String
    public let metadata: String
    public let cause: Error

    public init(tag: String, metadata: String, cause: Error) {
        self.tag = tag
        self.metadata = metadata
        self.cause = cause
    }

    public var description: String { "Invalid metadata for '\(tag)'" }
}

/// A value carried by a UPnP event variable.
///
/// Most values are strings. RenderingControl LastChange events can contain a
/// dictionary keyed by audio channel, and metadata values can be parsed into a
/// `DidlObject`. Invalid DIDL is represented by a `SoCoFault`, exactly as the
/// original event parser preserves the event instead of failing it wholesale.
public indirect enum EventValue: CustomStringConvertible {
    case string(String?)
    case channels([String: EventValue])
    case didl(DidlObject)
    case fault(SoCoFault)

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var channelValues: [String: EventValue]? {
        if case .channels(let values) = self { return values }
        return nil
    }

    public var didlObject: DidlObject? {
        if case .didl(let value) = self { return value }
        return nil
    }

    /// Resolve a DIDL event value. If metadata parsing failed, rethrow the
    /// original event parse error; non-DIDL values return nil.
    public func resolvedDIDL() throws -> DidlObject? {
        switch self {
        case .didl(let value): return value
        case .fault(let fault): return try fault.throwException()
        default: return nil
        }
    }

    public var description: String {
        switch self {
        case .string(let value): return value ?? "nil"
        case .channels(let values): return String(describing: values)
        case .didl(let value): return value.description
        case .fault(let fault): return fault.description
        }
    }
}

public typealias EventVariables = [String: EventValue]

/// Parse the body of a UPnP event.
///
/// The relevant value is usually a string representation of the variable's
/// value, but may be a per-channel dictionary, a `DidlObject`, or a `SoCoFault`
/// if illegal embedded metadata could not be parsed.
public func parseEventXML(_ xmlEvent: String) throws -> EventVariables {
    if let cached = EventXMLParseCache.shared.get(xmlEvent) { return cached }

    let tree = try XMLTree(xmlEvent)
    guard let root = tree.root else { throw SoCoError.eventParse("Missing event root") }
    var result: EventVariables = [:]

    // Property values sit directly beneath `e:propertyset`; namespace prefixes
    // vary, so SoCoKit's portable XML local names are used throughout.
    let properties = root.children?.compactMap { $0 as? SoCoXMLElement }
        .filter { $0.localNameSafe == "property" } ?? []

    for property in properties {
        for variable in property.children?.compactMap({ $0 as? SoCoXMLElement }) ?? [] {
            if variable.localNameSafe == "LastChange" {
                let lastChangeXML = variable.stringValue ?? ""
                guard !lastChangeXML.isEmpty else { continue }
                let lastChangeTree = try XMLTree(lastChangeXML)
                guard let lastRoot = lastChangeTree.root else { continue }

                // We assume there is only one InstanceID tag. This is true for
                // Sonos as far as SoCo knows. Queue events call it QueueID.
                var instanceCandidates: [SoCoXMLElement] = []
                if lastRoot.localNameSafe == "InstanceID" || lastRoot.localNameSafe == "QueueID" {
                    instanceCandidates.append(lastRoot)
                }
                instanceCandidates.append(contentsOf: lastRoot.descendants(named: "InstanceID"))
                instanceCandidates.append(contentsOf: lastRoot.descendants(named: "QueueID"))
                let instance = instanceCandidates.first
                guard let instance else {
                    throw SoCoError.eventParse("LastChange event has no InstanceID or QueueID")
                }

                for lastChangeVariable in instance.children?.compactMap({ $0 as? SoCoXMLElement }) ?? [] {
                    // Remove namespaces, then un-camel-case the variable name.
                    let tag = camelToUnderscore(lastChangeVariable.localNameSafe)

                    // UPnP says LastChange values use the `val` attribute, but
                    // Sonos sometimes uses text instead. A completely empty
                    // element is a real nil value and must not crash DIDL
                    // detection (regression covered by the original test).
                    let rawValue: String?
                    if let attributeValue = lastChangeVariable.attribute("val") {
                        rawValue = attributeValue
                    } else if let textValue = lastChangeVariable.stringValue, !textValue.isEmpty {
                        rawValue = textValue
                    } else {
                        // ElementTree reports `.text == None` for an empty
                        // element such as <CurrentTrackURI/>. Preserve that
                        // distinction instead of turning it into an empty string.
                        rawValue = nil
                    }
                    var value: EventValue
                    if let rawValue, rawValue.hasPrefix("<DIDL-Lite") {
                        do {
                            guard let object = try fromDIDLString(rawValue).first else {
                                throw SoCoError.didlMetadata("DIDL event metadata contained no objects")
                            }
                            value = .didl(object)
                        } catch {
                            let parseFault = EventParseFault(tag: tag, metadata: rawValue, cause: error)
                            value = .fault(SoCoFault(parseFault))
                        }
                    } else {
                        value = .string(rawValue)
                    }

                    if let channel = lastChangeVariable.attribute("channel") {
                        var channels = result[tag]?.channelValues ?? [:]
                        channels[channel] = value
                        result[tag] = .channels(channels)
                    } else {
                        result[tag] = value
                    }
                }
            } else {
                result[camelToUnderscore(variable.localNameSafe)] = .string(variable.stringValue)
            }
        }
    }

    EventXMLParseCache.shared.put(xmlEvent, value: result)
    return result
}

/// Bytes overload matching the original parser's UTF-8 input contract.
public func parseEventXML(_ data: Data) throws -> EventVariables {
    guard let xml = String(data: data, encoding: .utf8) else {
        throw SoCoError.eventParse("Event body is not valid UTF-8")
    }
    return try parseEventXML(xml)
}

/// Small 128-entry LRU cache mirroring Python's `@lru_cache()` on the parser.
private final class EventXMLParseCache {
    static let shared = EventXMLParseCache()
    private let lock = NSLock()
    private var values: [String: EventVariables] = [:]
    private var order: [String] = []
    private let capacity = 128

    func get(_ key: String) -> EventVariables? {
        lock.lock(); defer { lock.unlock() }
        guard let value = values[key] else { return nil }
        if let index = order.firstIndex(of: key) { order.remove(at: index) }
        order.append(key)
        return value
    }

    func put(_ key: String, value: EventVariables) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
        if let index = order.firstIndex(of: key) { order.remove(at: index) }
        order.append(key)
        while order.count > capacity {
            values.removeValue(forKey: order.removeFirst())
        }
    }
}

/// A read-only object representing a received event.
///
/// Python additionally provides dynamic attribute lookup (`event.transport_state`).
/// Swift has no safe equivalent, so variables are available through the immutable
/// `variables` dictionary or `event["transport_state"]` subscript.
public struct Event {
    public let sid: String
    public let seq: String
    public let timestamp: TimeInterval
    public let service: Service
    public let variables: EventVariables

    public init(
        sid: String,
        seq: String,
        service: Service,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        variables: EventVariables = [:]
    ) {
        self.sid = sid
        self.seq = seq
        self.service = service
        self.timestamp = timestamp
        self.variables = variables
    }

    public subscript(_ name: String) -> EventValue? { variables[name] }
}

/// Thread-safe queue on which received events are placed.
///
/// It supports the blocking `get(timeout:)` behavior used by Python SoCo and an
/// `AsyncStream` surface for native Swift concurrency.
public final class EventQueue {
    private let condition = NSCondition()
    private var storage: [Event] = []
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

    public func put(_ event: Event) {
        condition.lock()
        storage.append(event)
        let streams = Array(continuations.values)
        condition.broadcast()
        condition.unlock()
        streams.forEach { $0.yield(event) }
    }

    public func get(timeout: TimeInterval? = nil) throws -> Event {
        condition.lock()
        defer { condition.unlock() }
        if let timeout {
            let deadline = Date().addingTimeInterval(max(0, timeout))
            while storage.isEmpty {
                if !condition.wait(until: deadline) { throw SoCoError.timeout }
            }
        } else {
            while storage.isEmpty { condition.wait() }
        }
        return storage.removeFirst()
    }

    public var count: Int {
        condition.lock(); defer { condition.unlock() }; return storage.count
    }

    public func stream() -> AsyncStream<Event> {
        let id = UUID()
        return AsyncStream { continuation in
            condition.lock()
            continuations[id] = continuation
            condition.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.condition.lock()
                self?.continuations.removeValue(forKey: id)
                self?.condition.unlock()
            }
        }
    }
}

/// Maintains a weak mapping of subscription IDs to Subscription instances.
/// Event handlers use this map to route incoming NOTIFY requests.
public final class SubscriptionsMap {
    private final class WeakBox {
        weak var value: Subscription?
        init(_ value: Subscription) { self.value = value }
    }

    private let lock = NSLock()
    private var subscriptions: [String: WeakBox] = [:]

    public init() {}

    public func register(_ subscription: Subscription) {
        guard let sid = subscription.sid else { return }
        lock.lock(); defer { lock.unlock() }
        subscriptions[sid] = WeakBox(subscription)
        pruneLocked()
    }

    public func unregister(_ subscription: Subscription) {
        guard let sid = subscription.sid else { return }
        lock.lock(); subscriptions.removeValue(forKey: sid); lock.unlock()
    }

    public func subscription(for sid: String) -> Subscription? {
        lock.lock(); defer { lock.unlock() }
        pruneLocked()
        return subscriptions[sid]?.value
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        pruneLocked()
        return subscriptions.count
    }

    private func pruneLocked() {
        subscriptions = subscriptions.filter { $0.value.value != nil }
    }
}

public let subscriptionsMap = SubscriptionsMap()

/// Handle an HTTP NOTIFY by building an Event and routing it to its Subscription.
open class EventNotifyHandler {
    public let subscriptionsMap: SubscriptionsMap

    public init(subscriptionsMap: SubscriptionsMap = SoCoKit.subscriptionsMap) {
        self.subscriptionsMap = subscriptionsMap
    }

    /// Logging hook matching Python SoCo's `log_event(seq, service_id, timestamp)`.
    ///
    /// The threaded Python backend logs the receiving thread here, while the
    /// Twisted/asyncio backends log their own execution context. SoCoKit does not
    /// impose a logging framework on host apps, so the default implementation is
    /// intentionally empty and subclasses may override it.
    open func logEvent(seq: String, serviceID: String, timestamp: TimeInterval) {}

    /// Compatibility hook for `BaseHTTPRequestHandler.log_message`.
    ///
    /// Python overrides this method only to divert the standard library HTTP
    /// server's access log to SoCo's debug logger. The native Swift listener has
    /// no equivalent implicit access log, so this is a no-op extension point.
    open func logMessage(_ format: String, _ arguments: Any...) {}

    @discardableResult
    public func handleNotification(headers: [String: String], content: String) throws -> Event? {
        let normalized = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        guard let seq = normalized["seq"], let sid = normalized["sid"] else {
            throw SoCoError.eventParse("NOTIFY is missing SID or SEQ")
        }
        guard let subscription = subscriptionsMap.subscription(for: sid) else {
            // It may have been removed by another thread between network receipt
            // and dispatch. This is normal during unsubscribe races.
            return nil
        }

        let timestamp = Date().timeIntervalSince1970
        logEvent(seq: seq, serviceID: subscription.service.serviceID, timestamp: timestamp)
        let variables = try parseEventXML(content)
        let event = Event(sid: sid, seq: seq, service: subscription.service, timestamp: timestamp, variables: variables)
        subscription.service.updateCacheOnEvent(event)

        // ZoneGroupState event payloads are identical to polling payloads. Feed
        // them directly into the shared state cache as the asyncio backend in
        // modern SoCo does, avoiding a redundant GetZoneGroupState round trip.
        if case .string(let payload)? = variables["zone_group_state"], let payload,
           let parent = subscription.service.soco
        {
            try? parent.zoneGroupState.processPayload(payload, sourceSoCo: parent)
        }

        subscription.sendEvent(event)
        return event
    }
}

/// Minimal interface used by Subscription so listener startup is mockable in
/// unit tests and custom app hosts can provide their own callback server.
public protocol EventListening: AnyObject {
    var isRunning: Bool { get }
    var address: (ip: String, port: UInt16)? { get }
    func start(anyZone: SoCo) throws
    func stop()
}

/// HTTP listener which receives Sonos UPnP event NOTIFY requests.
///
/// Python SoCo has separate threaded, asyncio and Twisted listener modules.
/// Swift's native concurrency model makes that split unnecessary: this listener
/// accepts requests on a background concurrent queue, while each Subscription's
/// EventQueue can also be consumed as an AsyncStream.
public final class EventListener: EventListening, @unchecked Sendable {
    public static let shared = EventListener()

    private let lock = NSLock()
    private let handler: EventNotifyHandler
    private var listeningFD: Int32 = -1
    private var running = false
    private var currentAddress: (ip: String, port: UInt16)?
    private let acceptQueue = DispatchQueue(label: "SoCoKit.events.listener", qos: .utility)
    private let clientQueue = DispatchQueue(label: "SoCoKit.events.clients", qos: .utility, attributes: .concurrent)

    public var requestedPortNumber: UInt16

    public init(
        requestedPortNumber: UInt16 = SoCoConfig.eventListenerPort,
        handler: EventNotifyHandler = EventNotifyHandler()
    ) {
        self.requestedPortNumber = requestedPortNumber
        self.handler = handler
    }

    public var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }; return running
    }

    public var address: (ip: String, port: UInt16)? {
        lock.lock(); defer { lock.unlock() }; return currentAddress
    }

    /// Start the event listener on a local interface reachable by `anyZone`.
    public func start(anyZone: SoCo) throws {
        lock.lock()
        if running { lock.unlock(); return }
        lock.unlock()

        guard let ipAddress = getListenIP(anyZone.ipAddress) else {
            throw SoCoError.unknown("Could not start Event Listener: check network")
        }
        _ = try listen(ipAddress: ipAddress)
    }

    /// Start the event listener on a specific local network interface.
    ///
    /// This is the Swift counterpart of Python SoCo's public `listen(ip_address)`.
    /// It tries `requestedPortNumber` and the following 99 ports, starts the
    /// callback server, and returns the port which was actually selected.
    @discardableResult
    public func listen(ipAddress: String) throws -> UInt16 {
        lock.lock()
        if running {
            let port = currentAddress?.port ?? requestedPortNumber
            lock.unlock()
            return port
        }
        lock.unlock()

        let (fd, port) = try bindListeningSocket(ipAddress: ipAddress)

        lock.lock()
        // Another thread may have won the startup race while we were binding.
        if running {
            let existingPort = currentAddress?.port ?? requestedPortNumber
            lock.unlock()
            eventClose(fd)
            return existingPort
        }
        listeningFD = fd
        currentAddress = (ipAddress, port)
        running = true
        lock.unlock()

        acceptQueue.async { [weak self] in self?.acceptLoop(fd: fd) }
        return port
    }

    /// Stop the listener. Closing the listening socket wakes a blocked accept.
    public func stop() {
        lock.lock()
        guard running else { lock.unlock(); return }
        running = false
        let fd = listeningFD
        listeningFD = -1
        currentAddress = nil
        lock.unlock()

        if fd >= 0 {
            _ = shutdown(fd, Int32(SHUT_RDWR))
            eventClose(fd)
        }
    }

    private func bindListeningSocket(ipAddress: String) throws -> (Int32, UInt16) {
        let upper = min(Int(UInt16.max), Int(requestedPortNumber) + 99)
        for rawPort in Int(requestedPortNumber)...upper {
            let fd = socket(AF_INET, eventStreamSocketType, 0)
            guard fd >= 0 else { continue }
            var reuse: Int32 = 1
            _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
            #if !os(Linux)
            var noSigPipe: Int32 = 1
            _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            #endif

            var local = sockaddr_in()
            local.sin_family = sa_family_t(AF_INET)
            local.sin_port = UInt16(rawPort).bigEndian
            guard ipAddress.withCString({ inet_pton(AF_INET, $0, &local.sin_addr) }) == 1 else {
                eventClose(fd)
                throw SoCoError.invalidArgument("\(ipAddress) is not a valid IP address string")
            }
            let bindResult = withUnsafePointer(to: &local) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if bindResult == 0, DarwinOrGlibcListen(fd, backlog: 16) == 0 {
                return (fd, UInt16(rawPort))
            }
            let bindError = errno
            eventClose(fd)
            if bindError != EADDRINUSE { throw SoCoError.unknown("Event listener bind failed: errno \(bindError)") }
        }
        throw SoCoError.unknown("No event-listener port available in requested 100-port range")
    }

    private func acceptLoop(fd: Int32) {
        while true {
            lock.lock(); let shouldRun = running && listeningFD == fd; lock.unlock()
            if !shouldRun { return }
            let clientFD = accept(fd, nil, nil)
            if clientFD < 0 {
                lock.lock(); let stillRunning = running; lock.unlock()
                if !stillRunning { return }
                if errno == EINTR { continue }
                // Avoid spinning forever on an unrecoverable accept error.
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }
            clientQueue.async { [weak self] in
                self?.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { eventClose(fd) }
        setReceiveTimeout(fd, seconds: 3)
        guard let request = readHTTPRequest(fd) else {
            sendHTTPResponse(fd, status: 400, reason: "Bad Request")
            return
        }
        if request.method.uppercased() == "NOTIFY" {
            _ = try? handler.handleNotification(headers: request.headers, content: request.body)
        }
        // Python's handler acknowledges notifications after dispatch. Sonos only
        // requires a successful empty HTTP response here.
        sendHTTPResponse(fd, status: 200, reason: "OK")
    }
}

public let eventListener = EventListener.shared

/// A subscription to one Sonos UPnP service's event stream.
public final class Subscription: @unchecked Sendable {
    public let service: Service
    public private(set) var sid: String?
    /// Amount of time in seconds until expiry. `nil` means infinite.
    public private(set) var timeout: TimeInterval?
    public private(set) var isSubscribed = false
    public let events: EventQueue
    public private(set) var requestedTimeout: TimeInterval?
    public var autoRenewFail: ((Error) -> Void)?
    public var callback: ((Event) -> Void)?
    public private(set) var lastError: Error?

    private let listener: EventListening
    private let map: SubscriptionsMap
    private let lock = NSRecursiveLock()
    private var hasBeenUnsubscribed = false
    private var timestamp: Date?
    private var autoRenewTimer: DispatchSourceTimer?

    public init(
        service: Service,
        eventQueue: EventQueue? = nil,
        eventListener: EventListening = SoCoKit.eventListener,
        subscriptionsMap: SubscriptionsMap = SoCoKit.subscriptionsMap
    ) {
        self.service = service
        self.events = eventQueue ?? EventQueue()
        self.listener = eventListener
        self.map = subscriptionsMap
    }

    /// Subscribe to the service.
    ///
    /// If a timeout is requested, Sonos is free to allocate a different value;
    /// inspect `timeout` after subscription to learn the actual period. Sonos
    /// commonly allocates 86400 seconds regardless of the request.
    @discardableResult
    public func subscribe(
        requestedTimeout: TimeInterval? = nil,
        autoRenew: Bool = false,
        strict: Bool = true
    ) throws -> Subscription {
        do {
            try subscribeImpl(requestedTimeout: requestedTimeout, autoRenew: autoRenew)
        } catch {
            lastError = error
            if strict { throw error }
        }
        return self
    }

    private func subscribeImpl(requestedTimeout: TimeInterval?, autoRenew: Bool) throws {
        lock.lock(); defer { lock.unlock() }
        self.requestedTimeout = requestedTimeout
        if isSubscribed {
            throw SoCoError.invalidArgument("Cannot subscribe Subscription instance more than once. Use renew instead")
        }
        if hasBeenUnsubscribed {
            throw SoCoError.invalidArgument("Cannot resubscribe Subscription instance once unsubscribed")
        }
        guard let parent = service.soco else {
            throw SoCoError.unknown("Cannot subscribe after the parent SoCo instance has been released")
        }

        if !listener.isRunning { try listener.start(anyZone: parent) }
        guard let listenerAddress = listener.address else {
            throw SoCoError.unknown("Event Listener did not provide a callback address")
        }
        let advertisedIP = SoCoConfig.eventAdvertiseIP ?? listenerAddress.ip
        var headers = [
            "Callback": "<http://\(advertisedIP):\(listenerAddress.port)>",
            "NT": "upnp:event",
        ]
        if let requestedTimeout { headers["TIMEOUT"] = "Second-\(timeoutHeaderNumber(requestedTimeout))" }

        let response = try eventRequest(method: "SUBSCRIBE", headers: headers)
        guard let sid = header(response.headers, named: "sid"),
              let timeoutHeader = header(response.headers, named: "timeout")
        else { throw SoCoError.eventParse("SUBSCRIBE response missing SID or TIMEOUT") }

        self.sid = sid
        timeout = parseSubscriptionTimeout(timeoutHeader)
        timestamp = Date()
        isSubscribed = true
        map.register(self)
        parent.zoneGroupState.addSubscription(self)

        if autoRenew, let timeout, timeout.isFinite {
            autoRenewStart(interval: timeout * 0.85)
        }
    }

    /// Renew an active event subscription.
    @discardableResult
    public func renew(
        requestedTimeout: TimeInterval? = nil,
        isAutoRenew: Bool = false,
        strict: Bool = true
    ) throws -> Subscription {
        do {
            try renewImpl(requestedTimeout: requestedTimeout)
        } catch {
            lastError = error
            if isAutoRenew { autoRenewFail?(error) }
            if strict { throw error }
        }
        return self
    }

    private func renewImpl(requestedTimeout: TimeInterval?) throws {
        lock.lock(); defer { lock.unlock() }
        if hasBeenUnsubscribed { throw SoCoError.invalidArgument("Cannot renew subscription once unsubscribed") }
        if !isSubscribed { throw SoCoError.invalidArgument("Cannot renew subscription before subscribing") }
        if timeLeft == 0 { throw SoCoError.invalidArgument("Cannot renew subscription after expiry") }
        guard let sid else { throw SoCoError.eventParse("Subscribed object has no SID") }

        var headers = ["SID": sid]
        let desired = requestedTimeout ?? self.requestedTimeout
        if let desired { headers["TIMEOUT"] = "Second-\(timeoutHeaderNumber(desired))" }
        let response = try eventRequest(method: "SUBSCRIBE", headers: headers)
        guard let timeoutHeader = header(response.headers, named: "timeout") else {
            throw SoCoError.eventParse("Renew response missing TIMEOUT")
        }
        timeout = parseSubscriptionTimeout(timeoutHeader)
        timestamp = Date()
        isSubscribed = true
    }

    /// Unsubscribe. Calling this before subscription, more than once, or after
    /// timeout is intentionally a no-op.
    @discardableResult
    public func unsubscribe(strict: Bool = true) throws -> Subscription {
        do { try unsubscribeImpl() }
        catch {
            lastError = error
            cancelSubscription()
            if strict { throw error }
        }
        return self
    }

    private func unsubscribeImpl() throws {
        lock.lock(); defer { lock.unlock() }
        guard !hasBeenUnsubscribed, isSubscribed, timeLeft != 0 else { return }
        guard let sid else { cancelSubscription(); return }
        defer { cancelSubscription() }

        do {
            let response = try eventRequest(method: "UNSUBSCRIBE", headers: ["SID": sid])
            // A rebooted speaker has already discarded the subscription and may
            // reply 412. That is exactly the state unsubscribe is trying to
            // achieve, so it is deliberately ignored.
            if response.statusCode == 412 { return }
        } catch {
            // Python ignores transport timeouts/errors during UNSUBSCRIBE because
            // the local subscription is going away regardless. Preserve that
            // behavior for transport failures, but still let caller-visible HTTP
            // errors from a real response propagate via eventRequest.
            if error is URLError || error as? SoCoError == .timeout { return }
            throw error
        }
    }

    /// Send an event to `callback`, if set, otherwise to the event queue.
    public func sendEvent(_ event: Event) {
        if let callback { callback(event) } else { events.put(event) }
    }

    /// Seconds remaining until expiry. Unsubscribed subscriptions return zero;
    /// an explicitly infinite UPnP subscription returns `.infinity`.
    public var timeLeft: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard isSubscribed, let timestamp else { return 0 }
        guard let timeout else { return .infinity }
        return max(0, timeout - Date().timeIntervalSince(timestamp))
    }

    private func eventRequest(method: String, headers: [String: String]) throws -> HTTPResponse {
        let url = URL(string: "http://\(service.ipAddress):1400\(service.eventSubscriptionURL)")!
        let response = try service.httpClient.request(
            method: method,
            url: url,
            headers: headers,
            body: nil,
            timeout: 3
        )
        if method == "UNSUBSCRIBE", response.statusCode == 412 { return response }
        guard (200..<300).contains(response.statusCode) else {
            throw SoCoError.http(status: response.statusCode, body: response.text)
        }
        return response
    }

    private func cancelSubscription() {
        lock.lock(); defer { lock.unlock() }
        map.unregister(self)
        if map.count == 0 { listener.stop() }
        guard !hasBeenUnsubscribed else { return }
        isSubscribed = false
        hasBeenUnsubscribed = true
        timestamp = nil
        service.soco?.zoneGroupState.removeSubscription(self)
        autoRenewCancel()
    }

    private func autoRenewStart(interval: TimeInterval) {
        autoRenewCancel()
        guard interval > 0 else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "SoCoKit.events.autorenew"))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            _ = try? self.renew(isAutoRenew: true, strict: false)
        }
        autoRenewTimer = timer
        timer.resume()
    }

    private func autoRenewCancel() {
        autoRenewTimer?.setEventHandler {}
        autoRenewTimer?.cancel()
        autoRenewTimer = nil
    }
}

// MARK: - Service convenience

public extension Service {
    /// Subscribe to this service's UPnP events.
    @discardableResult
    func subscribe(
        requestedTimeout: TimeInterval? = nil,
        autoRenew: Bool = false,
        eventQueue: EventQueue? = nil,
        strict: Bool = true
    ) throws -> Subscription {
        let subscription = Subscription(service: self, eventQueue: eventQueue)
        return try subscription.subscribe(
            requestedTimeout: requestedTimeout,
            autoRenew: autoRenew,
            strict: strict
        )
    }

    /// Opportunity for a service to update caches before an event reaches user
    /// code. The base implementation intentionally does nothing, matching SoCo.
    func updateCacheOnEvent(_ event: Event) {}
}

// MARK: - Listener network helpers

/// Find the local IP address which can route to the specified Sonos player.
public func getListenIP(_ ipAddress: String) -> String? {
    if let configured = SoCoConfig.eventListenerIP { return configured }
    guard parseIPv4(ipAddress) != nil else { return nil }

    let fd = socket(AF_INET, eventDatagramSocketType, 0)
    guard fd >= 0 else { return nil }
    defer { eventClose(fd) }

    var target = sockaddr_in()
    target.sin_family = sa_family_t(AF_INET)
    target.sin_port = SoCoConfig.eventListenerPort.bigEndian
    guard ipAddress.withCString({ inet_pton(AF_INET, $0, &target.sin_addr) }) == 1 else { return nil }
    let result = withUnsafePointer(to: &target) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else { return nil }

    var local = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let got = withUnsafeMutablePointer(to: &local) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(fd, $0, &length)
        }
    }
    guard got == 0 else { return nil }
    return formatIPv4(UInt32(bigEndian: local.sin_addr.s_addr))
}

private struct ParsedHTTPRequest {
    let method: String
    let headers: [String: String]
    let body: String
}

private func readHTTPRequest(_ fd: Int32) -> ParsedHTTPRequest? {
    var data = Data()
    let headerLimit = 64 * 1024
    let totalLimit = 2 * 1024 * 1024
    var headerRange: Range<Data.Index>?
    var delimiterLength = 4

    while data.count < headerLimit {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(fd, &buffer, buffer.count, 0)
        guard count > 0 else { return nil }
        data.append(contentsOf: buffer.prefix(Int(count)))
        if let range = data.range(of: Data("\r\n\r\n".utf8)) {
            headerRange = range; delimiterLength = 4; break
        }
        if let range = data.range(of: Data("\n\n".utf8)) {
            headerRange = range; delimiterLength = 2; break
        }
    }
    guard let headerRange,
          let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8)
    else { return nil }

    let normalizedHeaderText = headerText.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalizedHeaderText.split(separator: "\n", omittingEmptySubsequences: false)
    guard let requestLine = lines.first else { return nil }
    let requestParts = requestLine.split(separator: " ")
    guard let method = requestParts.first.map(String.init) else { return nil }

    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
        guard let colon = line.firstIndex(of: ":") else { continue }
        let name = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        headers[name] = value
    }

    let contentLength = Int(headers["content-length"] ?? "0") ?? 0
    let bodyStart = headerRange.lowerBound + delimiterLength
    let targetSize = bodyStart + contentLength
    while data.count < targetSize && data.count < totalLimit {
        var buffer = [UInt8](repeating: 0, count: min(4096, targetSize - data.count))
        let count = recv(fd, &buffer, buffer.count, 0)
        guard count > 0 else { break }
        data.append(contentsOf: buffer.prefix(Int(count)))
    }
    guard data.count >= targetSize else { return nil }
    let body = String(data: data[bodyStart..<targetSize], encoding: .utf8) ?? ""
    return ParsedHTTPRequest(method: method, headers: headers, body: body)
}

private func sendHTTPResponse(_ fd: Int32, status: Int, reason: String) {
    let response = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
    let bytes = Array(response.utf8)
    _ = bytes.withUnsafeBytes { buffer in
        #if os(Linux)
        return send(fd, buffer.baseAddress, buffer.count, Int32(MSG_NOSIGNAL))
        #else
        return send(fd, buffer.baseAddress, buffer.count, 0)
        #endif
    }
}

private func setReceiveTimeout(_ fd: Int32, seconds: Int) {
    var timeout = timeval(tv_sec: seconds, tv_usec: 0)
    _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
}

private func header(_ headers: [AnyHashable: Any], named name: String) -> String? {
    let target = name.lowercased()
    for (key, value) in headers where String(describing: key).lowercased() == target {
        return String(describing: value)
    }
    return nil
}

private func parseSubscriptionTimeout(_ header: String) -> TimeInterval? {
    if header.lowercased() == "infinite" { return nil }
    let lower = header.lowercased()
    guard lower.hasPrefix("second-") else { return nil }
    return TimeInterval(lower.dropFirst("second-".count))
}

private func timeoutHeaderNumber(_ timeout: TimeInterval) -> String {
    timeout.rounded() == timeout ? String(Int(timeout)) : String(timeout)
}

private var eventStreamSocketType: Int32 {
    #if os(Linux)
    Int32(SOCK_STREAM.rawValue)
    #else
    SOCK_STREAM
    #endif
}

private var eventDatagramSocketType: Int32 {
    #if os(Linux)
    Int32(SOCK_DGRAM.rawValue)
    #else
    SOCK_DGRAM
    #endif
}

private func eventClose(_ fd: Int32) {
    #if os(Linux)
    _ = Glibc.close(fd)
    #else
    _ = Darwin.close(fd)
    #endif
}

private func DarwinOrGlibcListen(_ fd: Int32, backlog: Int32) -> Int32 {
    #if os(Linux)
    return Glibc.listen(fd, backlog)
    #else
    return Darwin.listen(fd, backlog)
    #endif
}
