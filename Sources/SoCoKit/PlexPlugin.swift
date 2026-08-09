import Foundation

/// Minimal Swift-facing abstraction over the Plex metadata consumed by SoCo's Plex
/// plugin. Python SoCo accepts `plexapi` objects directly; Swift has no corresponding
/// Python runtime object model, so Plex clients/adapters conform to this protocol.
public protocol PlexMediaProviding {
    var plexMachineIdentifier: String { get }
    var plexLibrarySectionID: String? { get }
    var plexType: String { get }          // album, artist, playlist, track
    var plexRatingKey: String { get }
    var plexTitle: String { get }
    var plexIsAudio: Bool { get }
    /// Album rating key for a track, artist rating key for an album; otherwise nil.
    var plexParentRatingKey: String? { get }
}

/// SoCo plugin for playing media from a linked Plex music service.
///
/// Preconditions are the same as upstream: Plex must be linked in Sonos and the Plex
/// server URI represented by the media must be reachable from the speakers.
public final class PlexPlugin: SoCoPlugin {
    private static let prefixLookup: [String: String] = [
        "album": "1004206c", "artist": "1005004c", "playlist": "1006206c", "track": "10036020",
        "albums:directory": "100d2066", "artists:directory": "10fe2066", "playlists:directory": "10fe2064"
    ]
    private static let parentType: [String: String] = [
        "album": "artist", "artist": "artists:directory", "playlist": "playlists:directory", "track": "album"
    ]

    private var cachedServiceInfo: MusicService.Descriptor?
    public required init(_ soco: SoCo) { super.init(soco) }
    public override var name: String { "Plex Plugin" }
    public var serviceName: String { "Plex" }
    public var serviceInfo: MusicService.Descriptor {
        get throws {
            if let cachedServiceInfo { return cachedServiceInfo }
            let info = try MusicService.dataForName(serviceName)
            cachedServiceInfo = info
            return info
        }
    }
    public var serviceID: String { get throws { try serviceInfo["ServiceID"] ?? "" } }
    public var serviceType: String { get throws { try serviceInfo["ServiceType"] ?? "" } }

    public func playNow(_ media: PlexMediaProviding) throws {
        let position = try addToQueue(media)
        try soco.playFromQueue(index: position - 1)
    }

    /// Add one Plex item to the queue.
    @discardableResult
    public func addToQueue(_ media: PlexMediaProviding, position: Int = 0, asNext: Bool = false) throws -> Int {
        let baseID = media.plexMachineIdentifier + ":" + (media.plexLibrarySectionID ?? "")
        let itemType = media.plexType
        guard let parentType = Self.parentType[itemType],
              let itemPrefix = Self.prefixLookup[itemType],
              let parentPrefix = Self.prefixLookup[parentType] else {
            throw SoCoError.unsupported("Unsupported Plex media type: \(itemType)")
        }

        let itemURI = "\(baseID):\(media.plexRatingKey):\(itemType)"
        let parentURI: String
        switch itemType {
        case "track", "album":
            guard let parent = media.plexParentRatingKey else {
                throw SoCoError.invalidArgument("Plex \(itemType) is missing its parent rating key")
            }
            parentURI = "\(baseID):\(parent):\(parentType)"
        case "artist":
            parentURI = "00020000artist:\(media.plexTitle.split(separator: " ").first.map(String.init) ?? media.plexTitle)"
        case "playlist":
            guard media.plexIsAudio else { throw SoCoError.unsupported("Non-audio playlists are not supported") }
            parentURI = "\(baseID):\(parentType)"
        default:
            throw SoCoError.unsupported("Unsupported Plex media type: \(itemType)")
        }

        let descriptor = "SA_RINCON\(try serviceType)_X_#Svc\(try serviceType)-0-Token"
        let parentID = parentPrefix + smapiQuote(parentURI)
        let itemID = itemPrefix + smapiQuote(itemURI)
        let item: DidlObject
        switch itemType {
        case "track": item = try DidlMusicTrack(title: media.plexTitle, parentID: parentID, itemID: itemID, desc: descriptor)
        case "album": item = try DidlMusicAlbum(title: media.plexTitle, parentID: parentID, itemID: itemID, desc: descriptor)
        case "artist": item = try DidlMusicArtist(title: media.plexTitle, parentID: parentID, itemID: itemID, desc: descriptor)
        case "playlist": item = try DidlPlaylistContainer(title: media.plexTitle, parentID: parentID, itemID: itemID, desc: descriptor)
        default: throw SoCoError.unsupported("Unsupported Plex media type: \(itemType)")
        }

        let metadata = try toDIDLString(item)
        let enqueuedURI = "x-rincon-cpcontainer:\(item.itemID)?sid=\(try serviceID)&flags=8300&sn=9"
        let response = try soco.avTransport.sendCommand("AddURIToQueue", arguments: [
            ("InstanceID", "0"), ("EnqueuedURI", enqueuedURI), ("EnqueuedURIMetaData", metadata),
            ("DesiredFirstTrackNumberEnqueued", String(position)), ("EnqueueAsNext", asNext ? "1" : "0")
        ])
        return Int(response["FirstTrackNumberEnqueued"] ?? "0") ?? 0
    }

    /// Add multiple items while preserving Python SoCo's insertion semantics: when a
    /// specific position or `asNext` is requested, media are inserted in reverse so the
    /// caller's original order is retained in the queue.
    @discardableResult
    public func addToQueue(_ media: [PlexMediaProviding], position: Int = 0, asNext: Bool = false) throws -> Int {
        guard !media.isEmpty else { return 0 }
        var firstAdded: Int?
        var lastPosition: Int = 0
        let items = (asNext || position != 0) ? Array(media.reversed()) : media
        for item in items {
            if asNext || position != 0 {
                lastPosition = try addToQueue(item, position: firstAdded ?? position, asNext: asNext)
            } else {
                lastPosition = try addToQueue(item)
            }
            if firstAdded == nil { firstAdded = lastPosition }
        }
        return asNext ? lastPosition : (firstAdded ?? lastPosition)
    }
}
