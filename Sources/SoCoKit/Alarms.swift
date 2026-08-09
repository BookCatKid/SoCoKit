import Foundation

public let recurrenceKeywordEquivalent: [String: String] = [
    "DAILY": "ON_0123456", "ONCE": "ON_", "WEEKDAYS": "ON_12345", "WEEKENDS": "ON_06"
]

public func isValidRecurrence(_ text: String) -> Bool {
    if recurrenceKeywordEquivalent.keys.contains(text) { return true }
    return text.range(of: #"^ON_[0-6]{1,7}$"#, options: .regularExpression) != nil
}

public struct AlarmTime: Equatable, Sendable, CustomStringConvertible {
    public var hour: Int
    public var minute: Int
    public var second: Int
    public init(hour: Int, minute: Int, second: Int = 0) throws {
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { throw SoCoError.invalidArgument("Invalid alarm time") }
        self.hour = hour; self.minute = minute; self.second = second
    }
    public init(_ value: String) throws {
        let p = value.split(separator: ":").compactMap { Int($0) }
        guard p.count == 3 else { throw SoCoError.invalidArgument("Invalid alarm time: \(value)") }
        try self.init(hour: p[0], minute: p[1], second: p[2])
    }
    public var secondsSinceMidnight: Int { hour * 3600 + minute * 60 + second }
    public var description: String { String(format: "%02d:%02d:%02d", hour, minute, second) }
}

public final class Alarm: Hashable, CustomStringConvertible {
    public var zone: SoCo?
    public var startTime: AlarmTime
    public var duration: AlarmTime?
    public var enabled: Bool
    public var programURI: String?
    public var programMetadata: String
    public var includeLinkedZones: Bool
    public var roomUUID: String?
    public private(set) var alarmID: String?
    private var _playMode: String
    private var _volume: Int
    private var _recurrence: String

    public var playMode: String {
        get { _playMode }
        set { try? setPlayMode(newValue) }
    }
    public var volume: Int { get { _volume } set { _volume = max(0, min(newValue, 100)) } }
    public var recurrence: String { get { _recurrence } set { try? setRecurrence(newValue) } }

    /// Set the play mode, throwing for the same invalid values for which Python
    /// SoCo's `play_mode` property setter raises `KeyError`. Swift property
    /// setters cannot throw, so `playMode = ...` preserves the previous value on
    /// invalid input while this method exposes the original failure semantics.
    public func setPlayMode(_ playMode: String) throws {
        let normalized = playMode.uppercased()
        guard SoCo.playModes[normalized] != nil else {
            throw SoCoError.invalidArgument("'\(normalized)' is not a valid play mode")
        }
        _playMode = normalized
    }

    /// Set the recurrence, throwing for the same invalid values for which Python
    /// SoCo's `recurrence` property setter raises `KeyError`.
    public func setRecurrence(_ recurrence: String) throws {
        guard isValidRecurrence(recurrence) else {
            throw SoCoError.invalidArgument("'\(recurrence)' is not a valid recurrence value")
        }
        _recurrence = recurrence
    }

    public init(zone: SoCo?, startTime: AlarmTime? = nil, duration: AlarmTime? = nil, recurrence: String = "DAILY", enabled: Bool = true, programURI: String? = nil, programMetadata: String = "", playMode: String = "NORMAL", volume: Int = 20, includeLinkedZones: Bool = false, roomUUID: String? = nil, alarmID: String? = nil) throws {
        guard isValidRecurrence(recurrence) else { throw SoCoError.invalidArgument("'\(recurrence)' is not a valid recurrence value") }
        guard SoCo.playModes[playMode.uppercased()] != nil else { throw SoCoError.invalidArgument("'\(playMode)' is not a valid play mode") }
        let now = Calendar.current.dateComponents([.hour,.minute,.second], from: Date())
        self.zone = zone
        self.startTime = try startTime ?? AlarmTime(hour: now.hour ?? 0, minute: now.minute ?? 0, second: now.second ?? 0)
        self.duration = duration; self._recurrence = recurrence; self.enabled = enabled; self.programURI = programURI
        self.programMetadata = programMetadata; self._playMode = playMode.uppercased(); self._volume = max(0,min(volume,100))
        self.includeLinkedZones = includeLinkedZones; self.roomUUID = roomUUID; self.alarmID = alarmID
    }

    /// Update an existing Alarm instance using Python SoCo's `update(**kwargs)` names.
    ///
    /// Swift has no `**kwargs`, so the compatibility surface accepts a dictionary.
    /// The supported keys are exactly the writable attributes accepted by the Python
    /// object: `zone`, `start_time`, `duration`, `recurrence`, `enabled`,
    /// `program_uri`, `program_metadata`, `play_mode`, `volume`,
    /// `include_linked_zones`, and `room_uuid`. Use `NSNull()` for a Python `None`.
    public func update(_ values: [String: Any]) throws {
        for (attribute, value) in values {
            switch attribute {
            case "zone":
                if value is NSNull { zone = nil }
                else if let value = value as? SoCo { zone = value }
                else { throw SoCoError.invalidArgument("zone must be a SoCo instance or nil") }
            case "start_time":
                guard let value = value as? AlarmTime else {
                    throw SoCoError.invalidArgument("start_time must be an AlarmTime")
                }
                startTime = value
            case "duration":
                if value is NSNull { duration = nil }
                else if let value = value as? AlarmTime { duration = value }
                else { throw SoCoError.invalidArgument("duration must be an AlarmTime or nil") }
            case "recurrence":
                guard let value = value as? String else {
                    throw SoCoError.invalidArgument("recurrence must be a String")
                }
                try setRecurrence(value)
            case "enabled":
                guard let value = value as? Bool else {
                    throw SoCoError.invalidArgument("enabled must be a Bool")
                }
                enabled = value
            case "program_uri":
                if value is NSNull { programURI = nil }
                else if let value = value as? String { programURI = value }
                else { throw SoCoError.invalidArgument("program_uri must be a String or nil") }
            case "program_metadata":
                guard let value = value as? String else {
                    throw SoCoError.invalidArgument("program_metadata must be a String")
                }
                programMetadata = value
            case "play_mode":
                guard let value = value as? String else {
                    throw SoCoError.invalidArgument("play_mode must be a String")
                }
                try setPlayMode(value)
            case "volume":
                let parsed: Int?
                if let value = value as? Int { parsed = value }
                else if let value = value as? NSNumber { parsed = value.intValue }
                else if let value = value as? String { parsed = Int(value) }
                else { parsed = nil }
                guard let parsed else {
                    throw SoCoError.invalidArgument("volume must be convertible to Int")
                }
                volume = parsed
            case "include_linked_zones":
                guard let value = value as? Bool else {
                    throw SoCoError.invalidArgument("include_linked_zones must be a Bool")
                }
                includeLinkedZones = value
            case "room_uuid":
                if value is NSNull { roomUUID = nil }
                else if let value = value as? String { roomUUID = value }
                else { throw SoCoError.invalidArgument("room_uuid must be a String or nil") }
            default:
                throw SoCoError.invalidArgument("Alarm does not have writable attribute \(attribute)")
            }
        }
    }

    /// Update an existing Alarm instance using the same values as construction.
    ///
    /// Python SoCo deliberately updates alarm objects in place so callers holding a
    /// reference do not suddenly point at stale state after `Alarms.update()`.
    fileprivate func update(from other: Alarm) {
        zone = other.zone
        startTime = other.startTime
        duration = other.duration
        enabled = other.enabled
        programURI = other.programURI
        programMetadata = other.programMetadata
        includeLinkedZones = other.includeLinkedZones
        roomUUID = other.roomUUID
        _playMode = other._playMode
        _volume = other._volume
        _recurrence = other._recurrence
    }

    public static func == (lhs: Alarm, rhs: Alarm) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    public var description: String { "<Alarm id:\(alarmID ?? "nil")@\(startTime)>" }

    @discardableResult
    public func save() throws -> String? {
        guard let zone else { throw SoCoError.invalidArgument("Cannot save alarm: zone is not set") }
        let room = try zone.uid()
        var args: [(String,String)] = [
            ("StartLocalTime", startTime.description), ("Duration", duration?.description ?? ""), ("Recurrence", recurrence),
            ("Enabled", enabled ? "1":"0"), ("RoomUUID", room), ("ProgramURI", programURI ?? "x-rincon-buzzer:0"),
            ("ProgramMetaData", programMetadata), ("PlayMode", playMode), ("Volume", String(volume)), ("IncludeLinkedZones", includeLinkedZones ? "1":"0")
        ]
        if let alarmID { args.insert(("ID", alarmID), at: 0); _ = try zone.alarmClock.sendCommand("UpdateAlarm", arguments: args) }
        else {
            let response = try zone.alarmClock.sendCommand("CreateAlarm", arguments: args)
            alarmID = response["AssignedID"]
            if let alarmID {
                let alarms = Alarms.shared
                // Upstream advances its cached alarm-list version when Sonos assigns
                // exactly the next ID, avoiding an unnecessary refresh immediately
                // after creating an alarm.
                if alarms.lastID == (Int(alarmID) ?? -1) - 1, let uid = alarms.lastUID {
                    try? alarms.setVersion("\(uid):\(alarmID)")
                }
                alarms.store(self, id: alarmID)
            }
        }
        return alarmID
    }

    @discardableResult
    public func remove() throws -> Bool {
        guard let zone, let alarmID else { return false }
        _ = try zone.alarmClock.sendCommand("DestroyAlarm", arguments: [("ID", alarmID)])
        Alarms.shared.removeCached(id: alarmID)
        self.alarmID = nil
        return true
    }

    public func nextAlarmDate(from date: Date = Date(), includeDisabled: Bool = false, calendar: Calendar = .current) -> Date? {
        if !enabled && !includeDisabled { return nil }
        var rec = recurrenceKeywordEquivalent[recurrence] ?? recurrence
        if rec == recurrenceKeywordEquivalent["ONCE"] { rec = recurrenceKeywordEquivalent["DAILY"]! }
        let digits = Set(rec.dropFirst(3).compactMap { Int(String($0)) })
        guard !digits.isEmpty else { return nil }
        let current = calendar.dateComponents([.hour,.minute,.second], from: date)
        let currentSeconds = (current.hour ?? 0) * 3600 + (current.minute ?? 0) * 60 + (current.second ?? 0)
        let startOffset = startTime.secondsSinceMidnight <= currentSeconds ? 1 : 0
        for offset in startOffset..<(startOffset + 8) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: day) - 1 // Sonos: Sunday=0
            if digits.contains(weekday) {
                var comps = calendar.dateComponents([.year,.month,.day,.timeZone], from: day)
                comps.hour = startTime.hour; comps.minute = startTime.minute; comps.second = startTime.second
                return calendar.date(from: comps)
            }
        }
        return nil
    }

    fileprivate func replaceID(_ id: String?) { alarmID = id }
}

public final class Alarms {
    public static let shared = Alarms()
    private let lock = NSLock()
    public private(set) var alarms: [String: Alarm] = [:]
    public private(set) var skipped: [String: Alarm] = [:]
    public private(set) var lastAlarmListVersion: String?
    public private(set) var lastUID: String?
    public private(set) var lastID: Int = 0
    private weak var lastZoneUsed: SoCo?
    private init() {}

    public subscript(id: String) -> Alarm? { lock.lock(); defer { lock.unlock() }; return alarms[id] }

    /// Return the alarm by ID or nil, matching Python SoCo's `Alarms.get`.
    public func get(_ alarmID: String) -> Alarm? { self[alarmID] }

    public var all: [Alarm] { lock.lock(); defer { lock.unlock() }; return Array(alarms.values) }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return alarms.count }

    fileprivate func store(_ alarm: Alarm, id: String) { lock.lock(); defer { lock.unlock() }; alarms[id] = alarm }
    fileprivate func removeCached(id: String) { lock.lock(); defer { lock.unlock() }; alarms.removeValue(forKey:id) }

    fileprivate func setVersion(_ version: String) throws {
        let p = version.split(separator: ":", maxSplits: 1).map(String.init)
        guard p.count == 2, let id = Int(p[1]) else { throw SoCoError.unknown("Invalid alarm list version: \(version)") }
        lastUID = p[0]; lastID = id; lastAlarmListVersion = version
    }

    /// Clear all cached alarm state. This mirrors resetting Python SoCo's `Alarms`
    /// singleton and is useful when switching households or in deterministic tests.
    public func reset() {
        lock.lock()
        alarms.removeAll()
        skipped.removeAll()
        lastAlarmListVersion = nil
        lastUID = nil
        lastID = 0
        lastZoneUsed = nil
        lock.unlock()
    }

    public func update(zone suppliedZone: SoCo? = nil) throws {
        guard let zone = suppliedZone ?? lastZoneUsed else { throw SoCoError.noDeviceFound }
        lastZoneUsed = zone
        let response = try zone.alarmClock.sendCommand("ListAlarms")
        guard let version = response["CurrentAlarmListVersion"] else { throw SoCoError.unknown("ListAlarms omitted CurrentAlarmListVersion") }
        if let previous = lastAlarmListVersion {
            let p = version.split(separator: ":", maxSplits: 1).map(String.init)
            if p.count == 2, lastUID == p[0], let id = Int(p[1]), id <= lastID { return }
            if p.count == 2, lastUID != p[0] {
                let zones = try zone.allZones()
                if !zones.contains(where: { (try? $0.uid()) == p[0] }) { throw SoCoError.unknown("Alarm list UID \(version) does not match \(previous)") }
            }
        }
        try setVersion(version)
        let zones = try zone.allZones()
        let parsed = try Self.parseAlarmPayload(response, zones: Array(zones))
        lock.lock(); defer { lock.unlock() }
        let oldAlarms = alarms
        let oldSkipped = skipped
        var newAlarms: [String: Alarm] = [:]
        var newSkipped: [String: Alarm] = [:]
        for parsedAlarm in parsed {
            guard let id = parsedAlarm.alarmID else { continue }
            // Reuse existing objects from either dictionary. This is intentional:
            // callers may retain an Alarm while its missing zone later appears.
            let alarm = oldAlarms[id] ?? oldSkipped[id] ?? parsedAlarm
            if alarm !== parsedAlarm { alarm.update(from: parsedAlarm) }
            if alarm.zone == nil { newSkipped[id] = alarm } else { newAlarms[id] = alarm }
        }
        // Anything absent from the new payload is pruned, matching upstream behavior.
        alarms = newAlarms
        skipped = newSkipped
    }

    public func updateSkipped(zone: SoCo) throws {
        let uid = try zone.uid(); lock.lock(); defer { lock.unlock() }
        // Iterate a snapshot because matching entries are removed from `skipped`.
        for (id, alarm) in Array(skipped) where alarm.roomUUID == uid {
            alarm.zone = zone
            alarms[id] = alarm
            skipped.removeValue(forKey: id)
        }
    }

    public func nextAlarmDate(from date: Date = Date(), includeDisabled: Bool = false, zoneUID: String? = nil, calendar: Calendar = .current) -> Date? {
        all.filter { zoneUID == nil || $0.roomUUID == zoneUID }.compactMap { $0.nextAlarmDate(from: date, includeDisabled: includeDisabled, calendar: calendar) }.min()
    }

    public static func parseAlarmPayload(_ payload: [String:String], zones: [SoCo]) throws -> [Alarm] {
        guard let xml = payload["CurrentAlarmList"] else { return [] }
        let tree = try XMLTree(xml)
        var result: [Alarm] = []
        for node in tree.root?.descendants(named: "Alarm") ?? [] {
            guard let id=node.attribute("ID"), let start=node.attribute("StartTime"), let recurrence=node.attribute("Recurrence") else { continue }
            let room=node.attribute("RoomUUID")
            let zone=zones.first { z in guard let room else{return false}; return (try? z.uid()) == room }
            let durationRaw=node.attribute("Duration") ?? ""
            let program=node.attribute("ProgramURI")
            let alarm=try Alarm(zone:zone,startTime:AlarmTime(start),duration:durationRaw.isEmpty ? nil : AlarmTime(durationRaw),recurrence:recurrence,enabled:node.attribute("Enabled") == "1",programURI:program == "x-rincon-buzzer:0" ? nil : program,programMetadata:node.attribute("ProgramMetaData") ?? "",playMode:node.attribute("PlayMode") ?? "NORMAL",volume:Int(node.attribute("Volume") ?? "20") ?? 20,includeLinkedZones:node.attribute("IncludeLinkedZones") == "1",roomUUID:room,alarmID:id)
            result.append(alarm)
        }
        return result
    }
}

public func getAlarms(zone: SoCo) throws -> Set<Alarm> { try Alarms.shared.update(zone: zone); return Set(Alarms.shared.all) }
public func removeAlarmByID(zone: SoCo, alarmID: String) throws -> Bool { try Alarms.shared.update(zone: zone); return try Alarms.shared[alarmID]?.remove() ?? false }

/// Parse a `ListAlarms` response into Alarm objects.
///
/// This top-level compatibility helper mirrors SoCo's public
/// `parse_alarm_payload`; the implementation lives on `Alarms` so the cache can
/// reuse it internally as well.
public func parseAlarmPayload(_ payload: [String: String], zones: [SoCo]) throws -> [Alarm] {
    try Alarms.parseAlarmPayload(payload, zones: zones)
}
