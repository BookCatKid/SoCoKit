import Foundation

// MARK: - Legacy music-service plugin data structures

/// This file ports `soco.ms_data_structures`, the older data model used by the legacy
/// plugin API. It intentionally remains separate from the newer `SMAPI.*` classes.
/// Upstream SoCo itself notes that these structures should eventually be integrated;
/// preserving both today avoids silently breaking plugins which still use them.
public protocol LegacyMusicServiceProviding: AnyObject {
    var musicServiceDescription: String { get }
    var legacyServiceID: Int { get }
    func idToExtendedID(_ itemID: String, itemClass: LegacyMusicServiceItem.Type) -> String?
    func formURI(_ itemContent: [String: Any], itemClass: LegacyMusicServiceItem.Type) -> String?
}

/// Return all XML leaf elements which contain text, recursively.
public func tagsWithText(_ xml: SoCoXMLElement) throws -> [SoCoXMLElement] {
    var tags: [SoCoXMLElement] = []
    func visit(_ element: SoCoXMLElement) throws {
        for child in (element.children ?? []).compactMap({ $0 as? SoCoXMLElement }) {
            let grandchildren = (child.children ?? []).compactMap { $0 as? SoCoXMLElement }
            if child.stringValue != nil && grandchildren.isEmpty {
                tags.append(child)
            } else if !grandchildren.isEmpty {
                try visit(child)
            } else {
                throw SoCoError.musicService("Unknown XML structure: \(child.xmlString)")
            }
        }
    }
    try visit(xml)
    return tags
}

/// Base class representing an item returned by the legacy music-service plugin API.
open class LegacyMusicServiceItem: CustomStringConvertible {
    open class var itemClass: String? { nil }
    open class var validFields: Set<String> { [] }
    open class var requiredFields: [String] { [] }

    public private(set) var content: [String: Any]

    public required init(content: [String: Any]) throws {
        for key in Self.requiredFields where content[key] == nil {
            throw SoCoError.musicService("A field corresponding to '\(key)' is required for \(Self.self)")
        }
        self.content = content
    }

    /// Build an item from the XML returned by a legacy music-service plugin.
    public class func fromXML(
        _ xml: SoCoXMLElement,
        service: LegacyMusicServiceProviding,
        parentID: String
    ) throws -> Self {
        var content: [String: Any] = [
            "description": service.musicServiceDescription,
            "service_id": service.legacyServiceID,
            "parent_id": parentID,
        ]
        for element in try tagsWithText(xml) {
            let key = camelToUnderscore(element.localNameSafe)
            guard Self.validFields.contains(key) else {
                throw SoCoError.musicService("The info tag '\(key)' is not allowed for this item")
            }
            var value: Any = element.text
            if key == "duration" {
                guard let int = Int(element.text) else { throw SoCoError.musicService("Invalid duration: \(element.text)") }
                value = int
            } else if ["can_play", "can_skip", "can_add_to_favorites", "can_enumerate"].contains(key) {
                value = element.text == "true"
            }
            content[key] = value
        }
        guard let rawID = content.removeValue(forKey: "id") as? String else {
            throw SoCoError.musicService("Music-service XML has no id")
        }
        content["item_id"] = rawID
        content["extended_id"] = service.idToExtendedID(rawID, itemClass: Self.self) ?? NSNull()
        if let uri = service.formURI(content, itemClass: Self.self) { content["uri"] = uri }
        return try Self.init(content: content)
    }

    /// Compatibility spelling for Python SoCo's `from_dict`.
    public class func fromDict(_ dictionary: [String: Any]) throws -> Self {
        try fromDictionary(dictionary)
    }

    public class func fromDictionary(_ dictionary: [String: Any]) throws -> Self {
        try Self.init(content: dictionary)
    }

    public var dictionary: [String: Any] { content }

    public static func contentEqual(_ lhs: LegacyMusicServiceItem, _ rhs: LegacyMusicServiceItem) -> Bool {
        legacyDictionaryEqual(lhs.content, rhs.content)
    }

    public var description: String {
        let middle: String
        if let title = content["title"] as? String { middle = String(title.prefix(40)) }
        else { middle = String(String(describing: content).prefix(40)) }
        return "<\(String(describing: type(of: self))) '\(middle)'>"
    }

    public var itemID: String { content["item_id"] as? String ?? "" }
    public var extendedID: String? { content["extended_id"] as? String }
    public var title: String { content["title"] as? String ?? "" }
    public var serviceID: Int { content["service_id"] as? Int ?? Int(content["service_id"] as? String ?? "") ?? 0 }
    public var canPlay: Bool { content["can_play"] as? Bool ?? false }
    public var parentID: String? { content["parent_id"] as? String }
    public var albumArtURI: String? { content["album_art_uri"] as? String }

    /// DIDL metadata for a playable legacy music-service item.
    public func didlMetadataXML() throws -> String {
        guard canPlay else {
            throw SoCoError.didlMetadata("This item is not meant to be played and therefore also not to create its own didl_metadata")
        }
        guard let extendedID, let itemClass = type(of: self).itemClass else {
            throw SoCoError.didlMetadata("This item was not meant to create didl_metadata")
        }
        guard let description = content["description"] as? String else {
            throw SoCoError.didlMetadata("The item for 'description' is not present in self.content")
        }
        let parent = parentID ?? ""
        return """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="\(xmlEscape(extendedID))" parentID="\(xmlEscape(parent))" restricted="true"><dc:title>\(xmlEscape(title))</dc:title><upnp:class>\(xmlEscape(itemClass))</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">\(xmlEscape(description))</desc></item></DIDL-Lite>
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public final class MSTrack: LegacyMusicServiceItem {
    public override class var itemClass: String? { "object.item.audioItem.musicTrack" }
    public override class var validFields: Set<String> {
        ["album", "can_add_to_favorites", "artist", "album_artist_id", "title", "album_id", "album_art_uri", "album_artist",
         "composer_id", "item_type", "composer", "duration", "can_skip", "artist_id", "can_play", "id", "mime_type", "description"]
    }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "uri", "description", "service_id"] }
    public var album: String? { content["album"] as? String }
    public var artist: String? { content["artist"] as? String }
    public var duration: Int? { content["duration"] as? Int }
    public var uri: String { content["uri"] as? String ?? "" }
}

public final class MSAlbum: LegacyMusicServiceItem {
    public override class var itemClass: String? { "object.container.album.musicAlbum" }
    public override class var validFields: Set<String> {
        ["username", "can_add_to_favorites", "artist", "title", "album_art_uri", "can_play", "item_type", "service_id", "id", "description", "can_cache", "artist_id", "can_skip"]
    }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "uri", "description", "service_id"] }
    public var artist: String? { content["artist"] as? String }
    public var uri: String { content["uri"] as? String ?? "" }
}

public final class MSAlbumList: LegacyMusicServiceItem {
    public override class var itemClass: String? { "object.container.albumlist" }
    public override class var validFields: Set<String> {
        ["id", "title", "item_type", "artist", "artist_id", "can_play", "can_enumerate", "can_add_to_favorites", "album_art_uri", "can_cache"]
    }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "uri", "description", "service_id"] }
    public var uri: String { content["uri"] as? String ?? "" }
}

public final class MSPlaylist: LegacyMusicServiceItem {
    public override class var itemClass: String? { "object.container.albumlist" }
    public override class var validFields: Set<String> {
        ["id", "item_type", "title", "can_play", "can_cache", "album_art_uri", "artist", "can_enumerate", "can_add_to_favorites", "artist_id"]
    }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "uri", "description", "service_id"] }
    public var uri: String { content["uri"] as? String ?? "" }
}

public final class MSArtistTracklist: LegacyMusicServiceItem {
    public override class var itemClass: String? { "object.container.playlistContainer.sameArtist" }
    public override class var validFields: Set<String> { ["id", "title", "item_type", "can_play", "album_art_uri"] }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "uri", "description", "service_id"] }
    public var uri: String { "x-rincon-cpcontainer:100f006c\(itemID)" }
}

public final class MSArtist: LegacyMusicServiceItem {
    public override class var validFields: Set<String> {
        ["username", "can_add_to_favorites", "artist", "title", "album_art_uri", "item_type", "id", "service_id", "description", "can_cache"]
    }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "service_id"] }
}

public final class MSFavorites: LegacyMusicServiceItem {
    public override class var validFields: Set<String> { ["id", "item_type", "title", "can_play", "can_cache", "album_art_uri"] }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "service_id"] }
}

public final class MSCollection: LegacyMusicServiceItem {
    public override class var validFields: Set<String> { ["id", "item_type", "title", "can_play", "can_cache", "album_art_uri"] }
    public override class var requiredFields: [String] { ["title", "item_id", "extended_id", "service_id"] }
}

/// Return the legacy music-service item corresponding to an XML item's `itemType`.
public func getMSItem(_ xml: SoCoXMLElement, service: LegacyMusicServiceProviding, parentID: String) throws -> LegacyMusicServiceItem {
    guard let itemType = xml.descendants(named: "itemType").first?.text ?? xml.firstChild(named: "itemType")?.text else {
        throw SoCoError.musicService("Music service item has no itemType")
    }
    let type: LegacyMusicServiceItem.Type
    switch itemType {
    case "artist": type = MSArtist.self
    case "album": type = MSAlbum.self
    case "track": type = MSTrack.self
    case "albumList": type = MSAlbumList.self
    case "favorites": type = MSFavorites.self
    case "collection": type = MSCollection.self
    case "playlist": type = MSPlaylist.self
    case "artistTrackList": type = MSArtistTracklist.self
    default: throw SoCoError.musicService("Unknown music-service item type: \(itemType)")
    }
    return try type.fromXML(xml, service: service, parentID: parentID)
}

private func legacyDictionaryEqual(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
    guard lhs.count == rhs.count, Set(lhs.keys) == Set(rhs.keys) else { return false }
    return lhs.allSatisfy { key, value in guard let other = rhs[key] else { return false }; return legacyAnyEqual(value, other) }
}

private func legacyAnyEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    switch (lhs, rhs) {
    case let (a as String, b as String): return a == b
    case let (a as Int, b as Int): return a == b
    case let (a as Bool, b as Bool): return a == b
    case (_ as NSNull, _ as NSNull): return true
    case let (a as [String: Any], b as [String: Any]): return legacyDictionaryEqual(a, b)
    case let (a as [Any], b as [Any]): return a.count == b.count && zip(a, b).allSatisfy(legacyAnyEqual)
    default: return String(describing: lhs) == String(describing: rhs) && String(reflecting: type(of: lhs)) == String(reflecting: type(of: rhs))
    }
}

/// Source-compatibility name for the base item in SoCo's legacy
/// `ms_data_structures` module. The newer SMAPI model remains available as
/// `SMAPI.MusicServiceItem`, avoiding the name collision Python solves with
/// separate modules.
public typealias MusicServiceItem = LegacyMusicServiceItem
