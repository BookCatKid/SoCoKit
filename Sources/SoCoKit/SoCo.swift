import Foundation

public final class SoCo: Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    public let ipAddress: String
    public let httpClient: HTTPClient
    public lazy var avTransport = AVTransport(self)
    public lazy var contentDirectory = ContentDirectory(self)
    public lazy var deviceProperties = DeviceProperties(self)
    public lazy var renderingControl = RenderingControl(self)
    public lazy var groupRenderingControl = GroupRenderingControl(self)
    public lazy var zoneGroupTopology = ZoneGroupTopology(self)
    public lazy var alarmClock = AlarmClock(self)
    public lazy var systemProperties = SystemProperties(self)
    public lazy var musicServices = MusicServices(self)
    public lazy var audioIn = AudioIn(self)
    public lazy var queueService = QueueService(self)
    public lazy var groupManagement = GroupManagement(self)
    public lazy var musicLibrary = MusicLibrary(self)
    public lazy var zoneGroupState = ZoneGroupState()

    internal var _bootSeqnum:Int?
    internal var _channelMap:String?
    internal var _htSatChanMap:String?
    internal var _isBridge:Bool?
    internal var _isCoordinator:Bool?
    internal var _isSatellite=false
    internal var _hasSatellites=false
    internal weak var _satelliteParent:SoCo?
    internal var _channel:String?
    internal var _isSoundbar:Bool?
    internal var _voiceConfigState:String?
    internal var _micEnabled:String?
    internal var _playerName:String?
    internal var _uid:String?
    internal var _householdID:String?
    internal var speakerInfo:[String:String]=[:]

    public init(_ ipAddress: String, httpClient: HTTPClient = URLSessionHTTPClient.shared) throws {
        let parts = ipAddress.split(separator: ".")
        guard parts.count == 4 && parts.allSatisfy({ Int($0).map { (0...255).contains($0) } == true }) else { throw SoCoError.invalidArgument("Not a valid IP address string") }
        self.ipAddress = ipAddress; self.httpClient = httpClient
        SoCoRegistry.shared.register(self)
    }
    public var description: String { "<SoCo object at ip \(ipAddress)>" }
    /// Swift counterpart of Python SoCo's `__repr__`.
    public var debugDescription: String { "SoCo(\"\(ipAddress)\")" }
    public static func ==(lhs:SoCo,rhs:SoCo)->Bool { lhs.ipAddress == rhs.ipAddress }
    public func hash(into hasher: inout Hasher) { hasher.combine(ipAddress) }

    internal func requireCoordinator(_ operation:String = #function) throws {
        if try !isCoordinator() { throw SoCoError.slaveOperation("The method or property \"\(operation)\" can only be called/used on the coordinator in a group") }
    }
    internal func requireSoundbar(_ operation:String = #function) throws {
        if try !isSoundbar() { throw SoCoError.unsupported("The method or property \"\(operation)\" is only supported on soundbars") }
    }
}


/// Clear SoCoKit's weak registry of previously-created speaker objects.
///
/// Python SoCo uses an argument-keyed singleton metaclass and exposes
/// `soco_reset()` to clear it. Swift initializers cannot return an existing class
/// instance, so SoCoKit does not pretend to provide identity-singleton semantics;
/// it keeps a weak registry instead so discovery's `anySoco` can still reuse a
/// known device without keeping speakers alive.
public func socoReset() {
    SoCoRegistry.shared.clear()
}

private final class WeakSoCoBox {
    weak var value: SoCo?
    init(_ value: SoCo) { self.value = value }
}

internal final class SoCoRegistry {
    static let shared = SoCoRegistry()
    private let lock = NSLock()

    // Python SoCo's argument-keyed singleton means there can only be one live
    // wrapper for an IP. Swift initializers cannot return an existing object,
    // but the registry can still make internal discovery/topology code
    // deterministic: the most recently constructed wrapper for an IP wins.
    private var devicesByIP: [String: WeakSoCoBox] = [:]

    func register(_ device: SoCo) {
        lock.lock()
        defer { lock.unlock() }
        devicesByIP[device.ipAddress] = WeakSoCoBox(device)
        removeDeadLocked()
    }

    func existing() -> [SoCo] {
        lock.lock()
        defer { lock.unlock() }
        removeDeadLocked()
        return devicesByIP.values.compactMap(\.value)
    }

    /// Return the current live wrapper for an IP address when one exists.
    ///
    /// Python SoCo's argument-keyed singleton metaclass guarantees this identity
    /// automatically. Swift initializers cannot return a previously-created
    /// class instance, so parser/discovery code explicitly consults this weak
    /// registry before constructing a new wrapper.
    func existing(ipAddress: String) -> SoCo? {
        lock.lock()
        defer { lock.unlock() }
        removeDeadLocked()
        return devicesByIP[ipAddress]?.value
    }

    func clear() {
        lock.lock()
        devicesByIP.removeAll()
        lock.unlock()
    }

    private func removeDeadLocked() {
        devicesByIP = devicesByIP.filter { $0.value.value != nil }
    }
}
