import Foundation

public final class ZoneGroup: Hashable, CustomStringConvertible {
    public let uid: String
    public let coordinator: SoCo
    public var members: Set<SoCo>
    public init(uid:String, coordinator:SoCo, members:Set<SoCo> = []) { self.uid=uid; self.coordinator=coordinator; self.members=members }
    public static func ==(lhs:ZoneGroup,rhs:ZoneGroup)->Bool { lhs.uid == rhs.uid }
    public func hash(into h:inout Hasher){h.combine(uid)}
    public var description:String { "ZoneGroup(uid='\(uid)', coordinator=\(coordinator), members=\(members))" }
    public var label: String { members.compactMap { try? $0.playerName() }.sorted().joined(separator:", ") }
    public var shortLabel: String { let n=members.compactMap{try? $0.playerName()}.sorted(); guard let first=n.first else{return ""}; return n.count>1 ? "\(first) + \(n.count-1)" : first }
    public func volume() throws -> Int {
        _ = try coordinator.groupRenderingControl.sendCommand("SnapshotGroupVolume", arguments:[("InstanceID","0")])
        return Int(try coordinator.groupRenderingControl.sendCommand("GetGroupVolume",arguments:[("InstanceID","0")])["CurrentVolume"] ?? "") ?? 0
    }
    public func setVolume(_ value:Int) throws {
        let v=max(0,min(100,value)); _=try coordinator.groupRenderingControl.sendCommand("SnapshotGroupVolume",arguments:[("InstanceID","0")]); _=try coordinator.groupRenderingControl.sendCommand("SetGroupVolume",arguments:[("InstanceID","0"),("DesiredVolume",String(v))])
    }
    /// Compatibility spelling for Python SoCo's `ZoneGroup.mute` property getter.
    public func mute() throws -> Bool { try muted() }
    /// Compatibility spelling for Python SoCo's `ZoneGroup.mute` property setter.
    public func setMute(_ value: Bool) throws { try setMuted(value) }
    public func muted() throws -> Bool { (Int(try coordinator.groupRenderingControl.sendCommand("GetGroupMute",arguments:[("InstanceID","0")])["CurrentMute"] ?? "0") ?? 0) != 0 }
    public func setMuted(_ value:Bool) throws { _=try coordinator.groupRenderingControl.sendCommand("SetGroupMute",arguments:[("InstanceID","0"),("DesiredMute",value ? "1":"0")]) }
    @discardableResult public func setRelativeVolume(_ adjustment:Int) throws -> Int { _=try coordinator.groupRenderingControl.sendCommand("SnapshotGroupVolume",arguments:[("InstanceID","0")]); let r=try coordinator.groupRenderingControl.sendCommand("SetRelativeGroupVolume",arguments:[("InstanceID","0"),("Adjustment",String(adjustment))]); return Int(r["NewVolume"] ?? "") ?? 0 }
}

public final class ZoneGroupState {
    /// All groups in the most recently processed ZoneGroupState.
    public private(set) var groups: Set<ZoneGroup> = []
    /// All zones, including invisible bridges and satellites.
    public private(set) var allZones: Set<SoCo> = []
    /// Zones which are not marked `Invisible="1"`.
    public private(set) var visibleZones: Set<SoCo> = []

    /// Number of poll/event payload requests observed, including requests which
    /// could use an active subscription or the five-second polling cache.
    public private(set) var totalRequests = 0
    /// Number of payloads whose normalized content actually changed.
    public private(set) var processedCount = 0

    internal var cacheUntil = Date.distantPast
    private var lastNormalizedPayload: String?

    // ZoneGroupState XML payloads are received from both
    // ZoneGroupTopology.GetZoneGroupState and subscription callbacks. They are
    // identical between speakers in a household, but Sonos may generate groups
    // and members in different orders. Python SoCo normalizes with an XSLT
    // before comparing payloads; SoCoKit intentionally has no XSLT dependency across SwiftPM
    // platform, so this port builds a deterministic canonical representation.

    // ZoneGroupState payloads received through an active ZoneGroupTopology
    // subscription are fresher than polling. Track subscriptions weakly so the
    // state cache never owns their lifecycle.
    private final class WeakSubscription {
        weak var value: Subscription?
        init(_ value: Subscription) { self.value = value }
    }
    private let subscriptionLock = NSLock()
    private var subscriptions: [ObjectIdentifier: WeakSubscription] = [:]

    public init() {}

    /// Clear the cache timestamp, forcing the next accessor to poll again.
    public func clearCache() { cacheUntil = .distantPast }

    /// Clear all known group sets.
    public func clearZoneGroups() {
        groups.removeAll()
        allZones.removeAll()
        visibleZones.removeAll()
    }

    /// Start tracking a ZoneGroupTopology subscription.
    public func addSubscription(_ subscription: Subscription) {
        guard subscription.service.serviceType == "ZoneGroupTopology" else { return }
        subscriptionLock.lock()
        subscriptions[ObjectIdentifier(subscription)] = WeakSubscription(subscription)
        pruneSubscriptionsLocked()
        subscriptionLock.unlock()
    }

    /// Stop tracking a ZoneGroupTopology subscription.
    public func removeSubscription(_ subscription: Subscription) {
        subscriptionLock.lock()
        subscriptions.removeValue(forKey: ObjectIdentifier(subscription))
        pruneSubscriptionsLocked()
        subscriptionLock.unlock()
    }

    /// True while active subscriptions are updating this ZoneGroupState.
    public var hasSubscriptions: Bool {
        subscriptionLock.lock()
        defer { subscriptionLock.unlock() }
        pruneSubscriptionsLocked()
        subscriptions = subscriptions.filter { ($0.value.value?.timeLeft ?? 0) > 0 }
        return !subscriptions.isEmpty
    }

    private func pruneSubscriptionsLocked() {
        subscriptions = subscriptions.filter { $0.value.value != nil }
    }

    /// Poll using the provided SoCo instance and process the payload.
    ///
    /// Satellites can return outdated information when directly polled, so the
    /// request is forwarded to the satellite's parent exactly as in SoCo.
    ///
    /// On large (roughly 20+ player) systems, GetZoneGroupState can return a
    /// UPnP/HTTP failure. SoCo falls back to a short-lived ZGT event subscription
    /// because the event contains the same ZoneGroupState payload.
    public func poll(_ originalSoCo: SoCo) throws {
        totalRequests += 1
        if hasSubscriptions { return }
        if Date() < cacheUntil { return }

        let soco: SoCo
        if originalSoCo._isSatellite, let parent = originalSoCo._satelliteParent {
            soco = parent
        } else {
            soco = originalSoCo
        }

        do {
            let result = try soco.zoneGroupTopology.sendCommand("GetZoneGroupState")
            guard let payload = result["ZoneGroupState"] else {
                throw SoCoError.xml("GetZoneGroupState response missing ZoneGroupState")
            }
            try processPayload(payload, sourceSoCo: soco, countRequest: false)
            cacheUntil = Date().addingTimeInterval(5)
        } catch let error as SoCoError {
            switch error {
            case .upnp, .http:
                guard SoCoConfig.zoneGroupTopologyEventFallback else {
                    throw SoCoError.unsupported("'GetZoneGroupState()' call fails on large Sonos systems and event fallback is disabled")
                }
                try updateByEvent(soco)
            default:
                throw error
            }
        }
    }

    /// Fall back to updating the ZGS using one ZoneGroupTopology event.
    public func updateByEvent(_ speaker: SoCo) throws {
        let subscription = try speaker.zoneGroupTopology.subscribe()
        defer { _ = try? subscription.unsubscribe() }
        let event = try subscription.events.get(timeout: 1.0)
        guard case .string(let value)? = event.variables["zone_group_state"], let payload = value else {
            throw SoCoError.eventParse("ZoneGroupTopology event did not contain zone_group_state")
        }
        try processPayload(payload, sourceSoCo: speaker)
    }

    /// Update using the provided XML payload.
    public func processPayload(_ payload: String, sourceSoCo: SoCo) throws {
        try processPayload(payload, sourceSoCo: sourceSoCo, countRequest: true)
    }

    private func processPayload(_ payload: String, sourceSoCo: SoCo, countRequest: Bool) throws {
        if countRequest { totalRequests += 1 }
        let tree = try XMLTree(payload)
        guard let root = tree.root else { return }
        let normalized = canonicalZoneGroupElement(root)
        if normalized == lastNormalizedPayload { return }

        processedCount += 1
        updateSoCoInstances(root: root, sourceSoCo: sourceSoCo)
        lastNormalizedPayload = normalized
    }

    /// Parse the tree and update every live SoCo wrapper it describes.
    public func updateSoCoInstances(root: SoCoXMLElement, sourceSoCo: SoCo) {
        clearZoneGroups()

        // Compatibility fallback for pre-10.1 firmwares where a ZoneGroups
        // wrapper element is not used. `descendants(named:)` naturally handles
        // both layouts.
        for groupElement in root.descendants(named: "ZoneGroup") {
            guard
                let coordinatorUID = groupElement.attribute("Coordinator"),
                let groupUID = groupElement.attribute("ID")
            else { continue }

            var groupCoordinator: SoCo?
            var members: Set<SoCo> = []
            let memberElements = groupElement.children?.compactMap { $0 as? SoCoXMLElement }.filter {
                $0.localNameSafe == "ZoneGroupMember"
            } ?? []

            for memberElement in memberElements {
                guard let zone = try? parseZoneGroupMember(memberElement, httpClient: sourceSoCo.httpClient) else { continue }
                zone._isSatellite = false
                zone._satelliteParent = nil
                if zone._uid == coordinatorUID {
                    groupCoordinator = zone
                    zone._isCoordinator = true
                } else {
                    zone._isCoordinator = false
                }

                // is_bridge does not normally change, but resetting it here is
                // harmless and ensures newly-seen zones are initialized.
                zone._isBridge = memberElement.attribute("IsZoneBridge") == "1"
                members.insert(zone)

                let satellites = memberElement.children?.compactMap { $0 as? SoCoXMLElement }.filter {
                    $0.localNameSafe == "Satellite"
                } ?? []
                zone._hasSatellites = !satellites.isEmpty
                for satelliteElement in satellites {
                    guard let satellite = try? parseZoneGroupMember(satelliteElement, httpClient: sourceSoCo.httpClient) else { continue }
                    satellite._isSatellite = true
                    satellite._satelliteParent = zone
                    satellite._isCoordinator = false
                    satellite._isBridge = false
                    members.insert(satellite)
                }
            }

            if let groupCoordinator {
                groups.insert(ZoneGroup(uid: groupUID, coordinator: groupCoordinator, members: members))
            }
        }
    }

    /// Parse a ZoneGroupMember or Satellite element and update its SoCo object.
    ///
    /// Python SoCo obtains the concrete SoCo class from global configuration.
    /// Swift uses an injectable HTTP client instead; the default matches a normal
    /// `SoCo` initializer while tests/apps can supply their own transport.
    public func parseZoneGroupMember(
        _ element: SoCoXMLElement,
        httpClient: HTTPClient = URLSessionHTTPClient.shared
    ) throws -> SoCo {
        guard
            let location = element.attribute("Location"),
            let host = URL(string: location)?.host
        else { throw SoCoError.xml("ZoneGroupMember missing Location") }

        // Python's SoCo objects are argument-singletons. Reuse an already-live
        // wrapper here to preserve the same object identity where Swift can.
        let zone: SoCo
        if let existing = SoCoRegistry.shared.existing(ipAddress: host) {
            zone = existing
        } else {
            zone = try SoCo(host, httpClient: httpClient)
        }
        // Every member in a household observes the same ZoneGroupState payload.
        // Share this state object with the wrappers discovered in the payload,
        // reproducing Python SoCo's household-level cache after the first ZGS
        // has been observed.
        zone.zoneGroupState = self
        zone._bootSeqnum = Int(element.attribute("BootSeq") ?? "")
        zone._channelMap = element.attribute("ChannelMapSet")
        zone._htSatChanMap = element.attribute("HTSatChanMapSet")
        zone._micEnabled = element.attribute("MicEnabled")
        zone._uid = element.attribute("UUID")
        zone._voiceConfigState = element.attribute("VoiceConfigState")
        zone._playerName = element.attribute("ZoneName")

        // Example ChannelMapSet (stereo pair):
        // RINCON_001XXX1400:LF,LF;RINCON_002XXX1400:RF,RF
        // Example HTSatChanMapSet (home theater):
        // RINCON_001XXX1400:LF,RF;RINCON_002XXX1400:LR;RINCON_003XXX1400:RR
        for channelMap in [zone._channelMap, zone._htSatChanMap].compactMap({ $0 }) {
            for channel in channelMap.split(separator: ";").map(String.init)
            where zone._uid.map({ channel.hasPrefix($0) }) == true {
                zone._channel = channel.split(separator: ":").last.map(String.init)
            }
        }

        allZones.insert(zone)
        if element.attribute("Invisible") != "1" { visibleZones.insert(zone) }
        return zone
    }

}

/// Normalize a ZoneGroupState payload for stable equality comparisons.
///
/// Python SoCo exposes `normalize_zgs_xml`, implemented with an XSLT that sorts
/// ZoneGroup and ZoneGroupMember children by Coordinator/UUID. the portable XML tree
/// does not expose XSLT on every SwiftPM platform, so this function returns a
/// deterministic canonical XML-like string with equivalent ordering semantics.
public func normalizeZoneGroupStateXML(_ xml: String) throws -> String {
    let tree = try XMLTree(xml)
    guard let root = tree.root else { throw SoCoError.xml("ZoneGroupState XML has no root element") }
    return canonicalZoneGroupElement(root)
}

/// Python-compatible shorthand for `normalize_zgs_xml`.
public func normalizeZGSXML(_ xml: String) throws -> String {
    try normalizeZoneGroupStateXML(xml)
}

/// Produce the deterministic representation used for ZoneGroupState duplicate
/// checks. Children are sorted by Coordinator/UUID as SoCo's XSLT does;
/// attributes are also sorted to avoid serializer ordering differences.
private func canonicalZoneGroupElement(_ element: SoCoXMLElement) -> String {
    let name = element.localNameSafe
    let attributes = (element.attributes ?? []).compactMap { node -> (String, String)? in
        guard let name = node.name else { return nil }
        return (name, node.stringValue ?? "")
    }.sorted { $0.0 < $1.0 }
    let attrs = attributes.map { "\($0.0)=\($0.1)" }.joined(separator: "|")
    var children = element.children?.compactMap { $0 as? SoCoXMLElement } ?? []
    children.sort {
        let lk = $0.attribute("Coordinator") ?? $0.attribute("UUID") ?? $0.localNameSafe
        let rk = $1.attribute("Coordinator") ?? $1.attribute("UUID") ?? $1.localNameSafe
        if lk == rk { return $0.localNameSafe < $1.localNameSafe }
        return lk < rk
    }
    let childText = children.map(canonicalZoneGroupElement).joined()
    let text = children.isEmpty ? element.text.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    return "<\(name)|\(attrs)>\(text)\(childText)</\(name)>"
}
