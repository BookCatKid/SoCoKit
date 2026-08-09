import Foundation

// MARK: - Sonos Music API (SMAPI) data structures

/// Data structures for music service items.
///
/// The basis for this implementation is the Sonos Music API documentation. The
/// Sonos API uses lower camel-case field names; the Swift API exposes those values
/// through a metadata dictionary using Swift-style lowerCamelCase keys while also
/// providing typed accessors for the fields which are most useful to applications.
///
/// The Python implementation dynamically creates classes such as `MSTrack` from a
/// `MediaMetadataTrack` class key. Swift nominal types cannot be created at runtime,
/// and the original SoCo package also contains an older, deprecated top-level
/// `MSTrack` type. To preserve both APIs without a name collision, the newer SMAPI
/// data structures live under the `SMAPI` namespace (for example `SMAPI.MSTrack`).
public enum SMAPI {}

/// Minimal surface needed by SMAPI data items to derive Sonos playback URIs and DIDL
/// descriptors. `MusicService` conforms to this protocol; the abstraction also keeps
/// response parsing directly testable without a live Sonos system.
public protocol MusicServiceProviding: AnyObject {
    var serviceName: String { get }
    var serviceID: Int { get }
    var serviceType: Int { get }
    var desc: String { get }
    func sonosURIFromID(_ itemID: String) -> String
}

/// Percent-encode bytes like Python's `urllib.parse.quote(..., safe="/")`.
///
/// This deliberately works on UTF-8 bytes, not Unicode scalars. Among other things,
/// that preserves SoCo's behavior for control characters and non-ASCII service IDs.
internal func smapiQuote(_ value: String) -> String {
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/".utf8)
    return value.utf8.map { byte -> String in
        allowed.contains(byte) ? String(UnicodeScalar(byte)) : String(format: "%%%02X", byte)
    }.joined()
}

/// Convert the only boolean string spellings accepted by the Sonos service schema.
/// Music services occasionally return malformed data, but silently treating arbitrary
/// strings as booleans would make those protocol errors much harder to diagnose.
public func smapiBool(_ string: String) throws -> Bool {
    switch string {
    case "true": return true
    case "false": return false
    default: throw SoCoError.musicService("Invalid boolean string: \"\(string)\"")
    }
}

/// Form and return a music service item URI.
public func smapiFormURI(itemID: String, service: MusicServiceProviding, isTrack: Bool) -> String {
    if isTrack { return service.sonosURIFromID(itemID) }
    return "x-rincon-cpcontainer:\(itemID)"
}

/// Top-level compatibility wrapper for Python SoCo's `form_uri`.
public func formURI(itemID: String, service: MusicServiceProviding, isTrack: Bool) -> String {
    smapiFormURI(itemID: itemID, service: service, isTrack: isTrack)
}

extension SMAPI {
    /// The value types accepted in music-service metadata dictionaries.
    public enum MetadataValue: Equatable, CustomStringConvertible {
        case string(String)
        case int(Int)
        case bool(Bool)
        case dictionary([String: MetadataValue])
        case array([MetadataValue])
        case null

        public var stringValue: String? {
            if case .string(let value) = self { return value }
            return nil
        }
        public var intValue: Int? {
            if case .int(let value) = self { return value }
            return nil
        }
        public var boolValue: Bool? {
            if case .bool(let value) = self { return value }
            return nil
        }
        public var dictionaryValue: [String: MetadataValue]? {
            if case .dictionary(let value) = self { return value }
            return nil
        }
        public var description: String {
            switch self {
            case .string(let value): return value
            case .int(let value): return String(value)
            case .bool(let value): return String(value)
            case .dictionary(let value): return String(describing: value)
            case .array(let value): return String(describing: value)
            case .null: return "nil"
            }
        }

        internal static func from(any value: Any) -> MetadataValue {
            switch value {
            case let value as MetadataValue: return value
            case let value as String: return .string(value)
            case let value as Int: return .int(value)
            case let value as Bool: return .bool(value)
            case let value as [String: Any]:
                return .dictionary(value.mapValues { MetadataValue.from(any: $0) })
            case let value as [Any]:
                return .array(value.map { MetadataValue.from(any: $0) })
            case _ as NSNull: return .null
            default: return .string(String(describing: value))
            }
        }
    }

    /// Class used to parse metadata from keyword/dictionary values.
    ///
    /// The Python code deliberately *does not* reject unknown fields. Although the
    /// schema has a documented set of valid fields, real music services have already
    /// been observed returning extras. The Swift port keeps the same forward-compatible
    /// behavior: known fields receive typed conversion; unknown fields remain available.
    open class MetadataDictBase: CustomStringConvertible {
        open class var validFields: Set<String> { [] }
        open class var integerFields: Set<String> { [] }
        open class var booleanFields: Set<String> { [] }
        open class var nestedTrackMetadataFields: Set<String> { [] }
        open class var nestedStreamMetadataFields: Set<String> { [] }

        public private(set) var metadata: [String: MetadataValue] = [:]

        public required init(metadataDictionary: [String: Any]) throws {
            for (key, rawValue) in metadataDictionary {
                let value: MetadataValue
                if Self.integerFields.contains(key), let text = rawValue as? String {
                    guard let integer = Int(text) else {
                        throw SoCoError.musicService("Invalid integer string for \(key): \(text)")
                    }
                    value = .int(integer)
                } else if Self.integerFields.contains(key), let integer = rawValue as? Int {
                    value = .int(integer)
                } else if Self.booleanFields.contains(key), let text = rawValue as? String {
                    value = .bool(try smapiBool(text))
                } else if Self.booleanFields.contains(key), let boolean = rawValue as? Bool {
                    value = .bool(boolean)
                } else if Self.nestedTrackMetadataFields.contains(key), let dict = rawValue as? [String: Any] {
                    value = .dictionary(try TrackMetadata(metadataDictionary: dict).metadata)
                } else if Self.nestedStreamMetadataFields.contains(key), let dict = rawValue as? [String: Any] {
                    value = .dictionary(try StreamMetadata(metadataDictionary: dict).metadata)
                } else {
                    value = MetadataValue.from(any: rawValue)
                }
                metadata[camelToUnderscore(key)] = value
            }
        }

        /// Dynamic-field equivalent to Python's `__getattr__`.
        public subscript(_ key: String) -> MetadataValue? { metadata[key] }
        public var description: String { String(describing: metadata) }
    }

    /// A base class for all modern music service items.
    open class MusicServiceItem: MetadataDictBase {
        open class var isTrack: Bool { false }

        public let itemID: String
        public let descValue: String
        public let resources: [DidlResource]
        public let uri: String
        public weak var musicService: MusicServiceProviding?

        /// This is the DIDL-compatible ID (including SoCo's historical hex prefix),
        /// not the music service's raw item ID.
        public required init(
            itemID: String,
            desc: String,
            resources: [DidlResource],
            uri: String,
            metadataDictionary: [String: Any],
            musicService: MusicServiceProviding? = nil
        ) throws {
            self.itemID = itemID
            self.descValue = desc
            self.resources = resources
            self.uri = uri
            self.musicService = musicService
            try super.init(metadataDictionary: metadataDictionary)
        }

        public required convenience init(metadataDictionary: [String: Any]) throws {
            try self.init(itemID: "", desc: "", resources: [], uri: "", metadataDictionary: metadataDictionary)
        }

        /// Instantiate from the information returned directly by a music service.
        public class func fromMusicService(
            _ musicService: MusicServiceProviding,
            contentDictionary: [String: Any]
        ) throws -> Self {
            guard let rawID = contentDictionary["id"] as? String else {
                throw SoCoError.musicService("Music service item is missing id")
            }
            let quotedID = smapiQuote(rawID)
            // The hex prefix remains a mystery in upstream SoCo too; it is retained
            // because Sonos expects the resulting identifier in DIDL metadata.
            let itemID = "0fffffff\(quotedID)"
            let uri = smapiFormURI(itemID: itemID, service: musicService, isTrack: Self.isTrack)
            let resources = [DidlResource(uri: uri, protocolInfo: "DUMMY")]
            return try Self.init(
                itemID: itemID,
                desc: musicService.desc,
                resources: resources,
                uri: uri,
                metadataDictionary: contentDictionary,
                musicService: musicService
            )
        }

        public var rawID: String? { metadata["id"]?.stringValue }
        public var title: String? { metadata["title"]?.stringValue }
        public var itemType: String? { metadata["item_type"]?.stringValue }

        /// XML element representation used when a service item is queued.
        ///
        /// As in Python SoCo, this piggy-backs on the regular `DidlItem`
        /// implementation. The title and parent ID are dummies because Sonos derives
        /// the displayed title from the service item ID.
        /// Return an XML element representing this music-service item.
        ///
        /// This is the Swift equivalent of upstream SoCo's public `to_element`
        /// method. It deliberately piggy-backs on `DidlItem`, including the two
        /// dummy title/parent values that Sonos ignores for SMAPI queue entries.
        public func toElement(includeNamespaces: Bool = false) throws -> SoCoXMLElement {
            let item = try DidlItem(
                title: "DUMMY",
                parentID: "DUMMY",
                itemID: itemID,
                resources: resources,
                desc: descValue
            )
            return try item.toElement(includeNamespaces: includeNamespaces)
        }

        /// XML representation used when a service item is queued.
        ///
        /// As in Python SoCo, this piggy-backs on the regular `DidlItem`
        /// implementation. The title and parent ID are dummies because Sonos derives
        /// the displayed title from the service item ID.
        public func didlXML(includeNamespaces: Bool = false) throws -> String {
            let item = try DidlItem(
                title: "DUMMY",
                parentID: "DUMMY",
                itemID: itemID,
                resources: resources,
                desc: descValue
            )
            return try item.xml(includeNamespaces: includeNamespaces)
        }

        public override var description: String {
            "<\(String(describing: type(of: self))) title=\"\(title ?? "nil")\">"
        }
    }

    /// Track metadata class.
    public final class TrackMetadata: MetadataDictBase {
        public override class var validFields: Set<String> {
            ["artistId", "artist", "composerId", "composer", "albumId", "album", "albumArtURI",
             "albumArtistId", "albumArtist", "genreId", "genre", "duration", "canPlay", "canSkip",
             "canAddToFavorites", "rating", "trackNumber", "isFavorite"]
        }
        public override class var integerFields: Set<String> { ["duration", "rating", "trackNumber"] }
        public override class var booleanFields: Set<String> { ["canPlay", "canSkip", "canAddToFavorites", "isFavorite"] }
    }

    /// Stream metadata class.
    public final class StreamMetadata: MetadataDictBase {
        public override class var validFields: Set<String> {
            ["currentHost", "currentShowId", "currentShow", "secondsRemaining", "secondsToNextShow", "bitrate",
             "logo", "hasOutOfBandMetadata", "description", "isEphemeral"]
        }
        public override class var integerFields: Set<String> { ["secondsRemaining", "secondsToNextShow", "bitrate"] }
        public override class var booleanFields: Set<String> { ["hasOutOfBandMetadata", "isEphemeral"] }
    }

    /// Base class for all `mediaMetadata` items.
    open class MediaMetadata: MusicServiceItem {
        public override class var validFields: Set<String> {
            ["id", "title", "mimeType", "itemType", "displayType", "summary", "trackMetadata", "streamMetadata", "dynamic"]
        }
        public override class var nestedTrackMetadataFields: Set<String> { ["trackMetadata"] }
        public override class var nestedStreamMetadataFields: Set<String> { ["streamMetadata"] }
    }

    /// Base class for all `mediaCollection` items.
    open class MediaCollection: MusicServiceItem {
        public override class var validFields: Set<String> {
            ["id", "title", "itemType", "displayType", "summary", "artistId", "artist", "albumArtURI", "canPlay",
             "canEnumerate", "canAddToFavorites", "containsFavorite", "canScroll", "canSkip", "isFavorite"]
        }
        public override class var booleanFields: Set<String> {
            ["canPlay", "canEnumerate", "canAddToFavorites", "containsFavorite", "canScroll", "canSkip", "isFavorite"]
        }
    }

    // The concrete types generated dynamically by Python SoCo. Keeping them as real
    // Swift classes gives callers a stable type surface while retaining the same names
    // under `SMAPI`.
    public final class MSTrack: MediaMetadata { public override class var isTrack: Bool { true } }
    public final class MSStream: MediaMetadata {}
    public final class MSShow: MediaMetadata {}
    public final class MSMediaOther: MediaMetadata {}

    public final class MSArtist: MediaCollection {}
    public final class MSAlbum: MediaCollection {}
    public final class MSGenre: MediaCollection {}
    public final class MSPlaylist: MediaCollection {}
    public final class MSSearch: MediaCollection {}
    public final class MSProgram: MediaCollection {}
    public final class MSFavorites: MediaCollection {}
    public final class MSFavorite: MediaCollection {}
    public final class MSCollection: MediaCollection {}
    public final class MSContainer: MediaCollection {}
    public final class MSAlbumList: MediaCollection {}
    public final class MSTrackList: MediaCollection {}
    public final class MSStreamList: MediaCollection {}
    public final class MSArtistTrackList: MediaCollection {}
    public final class MSCollectionOther: MediaCollection {}

    /// Swift replacement for Python's runtime `get_class` factory.
    ///
    /// The returned metatype is stable for every supported key, matching the Python
    /// cache's externally observable behavior without runtime type generation.
    public static func itemClass(for classKey: String) throws -> MusicServiceItem.Type {
        switch classKey {
        case "MediaMetadataTrack": return MSTrack.self
        case "MediaMetadataStream": return MSStream.self
        case "MediaMetadataShow": return MSShow.self
        case "MediaMetadataOther": return MSMediaOther.self
        case "MediaCollectionArtist": return MSArtist.self
        case "MediaCollectionAlbum": return MSAlbum.self
        case "MediaCollectionGenre": return MSGenre.self
        case "MediaCollectionPlaylist": return MSPlaylist.self
        case "MediaCollectionSearch": return MSSearch.self
        case "MediaCollectionProgram": return MSProgram.self
        case "MediaCollectionFavorites": return MSFavorites.self
        case "MediaCollectionFavorite": return MSFavorite.self
        case "MediaCollectionCollection": return MSCollection.self
        case "MediaCollectionContainer": return MSContainer.self
        case "MediaCollectionAlbumlist", "MediaCollectionAlbumList": return MSAlbumList.self
        case "MediaCollectionTracklist", "MediaCollectionTrackList": return MSTrackList.self
        case "MediaCollectionStreamlist", "MediaCollectionStreamList": return MSStreamList.self
        case "MediaCollectionArtisttracklist", "MediaCollectionArtistTrackList": return MSArtistTrackList.self
        case "MediaCollectionOther": return MSCollectionOther.self
        default:
            throw SoCoError.musicService("Unknown music service class key: \(classKey)")
        }
    }

    /// Search/browse result from a third-party music service.
    public struct SearchResult {
        public var items: [MusicServiceItem]
        public var searchType: String
        public var numberReturned: Int
        public var totalMatches: Int?
        public var updateID: Int?

        public init(items: [MusicServiceItem], searchType: String, numberReturned: Int, totalMatches: Int? = nil, updateID: Int? = nil) {
            self.items = items
            self.searchType = searchType
            self.numberReturned = numberReturned
            self.totalMatches = totalMatches
            self.updateID = updateID
        }
    }

    /// Parse the response to a music service query and return a search result.
    public static func parseResponse(
        service: MusicServiceProviding,
        response: [String: Any],
        searchType: String
    ) throws -> SearchResult {
        let wrapped: Any
        if let value = response["searchResult"] { wrapped = value }
        else if let value = response["getMetadataResult"] { wrapped = value }
        else {
            throw SoCoError.musicService("response should contain either searchResult or getMetadataResult")
        }
        guard let result = wrapped as? [String: Any] else {
            throw SoCoError.musicService("Music service result is not a dictionary")
        }

        let count: Int
        if let value = result["count"] as? Int { count = value }
        else if let text = result["count"] as? String, let value = Int(text) { count = value }
        else { count = 0 }

        var items: [MusicServiceItem] = []
        for (resultType, proper) in [("mediaCollection", "MediaCollection"), ("mediaMetadata", "MediaMetadata")] {
            guard let raw = result[resultType] else { continue }
            let dictionaries: [[String: Any]]
            if let single = raw as? [String: Any] { dictionaries = [single] }
            else if let many = raw as? [[String: Any]] { dictionaries = many }
            else if let many = raw as? [Any] { dictionaries = many.compactMap { $0 as? [String: Any] } }
            else { continue }

            for dictionary in dictionaries {
                guard let itemType = dictionary["itemType"] as? String else {
                    throw SoCoError.musicService("Music service item is missing itemType")
                }
                let classKey = proper + itemType.prefix(1).uppercased() + String(itemType.dropFirst())
                let cls = try itemClass(for: classKey)
                items.append(try cls.fromMusicService(service, contentDictionary: dictionary))
            }
        }
        return SearchResult(items: items, searchType: searchType, numberReturned: count)
    }
}

/// Top-level compatibility wrapper for Python SoCo's `parse_response`.
public func parseResponse(
    service: MusicServiceProviding,
    response: [String: Any],
    searchType: String
) throws -> SMAPI.SearchResult {
    try SMAPI.parseResponse(service: service, response: response, searchType: searchType)
}
