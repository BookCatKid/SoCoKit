import Foundation

// MARK: - DIDL-Lite

/// Classes for handling DIDL-Lite metadata.
///
/// DIDL is the Digital Item Declaration Language, an XML schema which is part of
/// MPEG-21. DIDL-Lite is a cut-down version used by the UPnP ContentDirectory
/// specification. Sonos uses it for metadata representing tracks, playlists,
/// composers, albums, radio stations, favorites, and many other items.
///
/// This hierarchy follows the UPnP DIDL-Lite class hierarchy wherever possible.
/// Sonos also exposes several vendor-specific classes and, in a few places, emits
/// XML tags that do not strictly match the base specification. Those exceptions are
/// preserved here because they are observable protocol behavior.

// MARK: Resource quirks

/// Apply resource-level DIDL quirks observed in real music services.
///
/// At least Spotify Direct and Amazon/Alexa have been observed omitting mandatory
/// `protocolInfo`. Python SoCo deliberately repairs those payloads instead of rejecting
/// them, and the Swift port does the same.
private func protocolInfoApplyingResourceQuirk(_ element: SoCoXMLElement) -> String {
    if let protocolInfo = element.attribute("protocolInfo") {
        return protocolInfo
    }
    if element.text.hasPrefix("x-sonos-spotify") {
        return "sonos.com-spotify:*:audio/x-spotify.*"
    }
    return "DUMMY_ADDED_BY_QUIRK"
}

/// Identifies a resource, typically a binary asset such as a song.
///
/// It is represented in XML by a `<res>` element whose text contains the URI.
/// Not all parameters are used by Sonos. In practice `uri`, `protocolInfo`, and
/// `duration` are the fields most commonly seen in the wild.
public struct DidlResource: Equatable, Sendable {
    /// Percent-encoded URI identifying the resource.
    public var uri: String
    /// UPnP protocol info in the `a:b:c:d` form described by ConnectionManager.
    public var protocolInfo: String
    public var importURI: String?
    public var size: Int?
    /// Playback duration, usually `H*:MM:SS`.
    public var duration: String?
    public var bitrate: Int?
    public var sampleFrequency: Int?
    public var bitsPerSample: Int?
    public var nrAudioChannels: Int?
    public var resolution: String?
    public var colorDepth: Int?
    public var protection: String?

    public init(
        uri: String,
        protocolInfo: String,
        importURI: String? = nil,
        size: Int? = nil,
        duration: String? = nil,
        bitrate: Int? = nil,
        sampleFrequency: Int? = nil,
        bitsPerSample: Int? = nil,
        nrAudioChannels: Int? = nil,
        resolution: String? = nil,
        colorDepth: Int? = nil,
        protection: String? = nil
    ) {
        self.uri = uri
        self.protocolInfo = protocolInfo
        self.importURI = importURI
        self.size = size
        self.duration = duration
        self.bitrate = bitrate
        self.sampleFrequency = sampleFrequency
        self.bitsPerSample = bitsPerSample
        self.nrAudioChannels = nrAudioChannels
        self.resolution = resolution
        self.colorDepth = colorDepth
        self.protection = protection
    }

    /// Create a resource from a `<res>` element.
    public init(element: SoCoXMLElement) throws {
        func integerAttribute(_ name: String) throws -> Int? {
            guard let raw = element.attribute(name) else { return nil }
            guard let value = Int(raw) else {
                throw SoCoError.didlMetadata("Could not convert \(name) to an integer")
            }
            return value
        }

        self.init(
            uri: element.text,
            protocolInfo: protocolInfoApplyingResourceQuirk(element),
            importURI: element.attribute("importUri"),
            size: try integerAttribute("size"),
            duration: element.attribute("duration"),
            bitrate: try integerAttribute("bitrate"),
            sampleFrequency: try integerAttribute("sampleFrequency"),
            bitsPerSample: try integerAttribute("bitsPerSample"),
            nrAudioChannels: try integerAttribute("nrAudioChannels"),
            resolution: element.attribute("resolution"),
            colorDepth: try integerAttribute("colorDepth"),
            protection: element.attribute("protection")
        )
    }

    /// Alternate constructor corresponding to Python SoCo's `from_element`.
    public static func fromElement(_ element: SoCoXMLElement) throws -> DidlResource {
        try DidlResource(element: element)
    }

    /// Return an `SoCoXMLElement` corresponding to Python SoCo's `to_element`.
    public func toElement() throws -> SoCoXMLElement {
        guard !protocolInfo.isEmpty else {
            throw SoCoError.didlMetadata(
                "Could not create Element for this resource: protocolInfo not set (required)."
            )
        }
        let root = SoCoXMLElement(name: "res")
        func attribute(_ name: String, _ value: String?) {
            guard let value else { return }
            root.addAttribute(SoCoXMLNode.attribute(withName: name, stringValue: value))
        }
        attribute("protocolInfo", protocolInfo)
        attribute("importUri", importURI)
        attribute("size", size.map(String.init))
        attribute("duration", duration)
        attribute("bitrate", bitrate.map(String.init))
        attribute("sampleFrequency", sampleFrequency.map(String.init))
        attribute("bitsPerSample", bitsPerSample.map(String.init))
        attribute("nrAudioChannels", nrAudioChannels.map(String.init))
        attribute("resolution", resolution)
        attribute("colorDepth", colorDepth.map(String.init))
        attribute("protection", protection)
        root.stringValue = uri
        return root
    }

    /// Alternate constructor corresponding to Python SoCo's `from_dict`.
    public static func fromDict(_ dictionary: [String: Any]) throws -> DidlResource {
        try DidlResource(dictionary: dictionary)
    }

    /// Dictionary representation equivalent to Python SoCo's `to_dict`.
    public func dictionary(removeNils: Bool = false) -> [String: Any] {
        var result: [String: Any] = [
            "uri": uri,
            "protocol_info": protocolInfo,
        ]
        let optional: [(String, Any?)] = [
            ("import_uri", importURI), ("size", size), ("duration", duration),
            ("bitrate", bitrate), ("sample_frequency", sampleFrequency),
            ("bits_per_sample", bitsPerSample), ("nr_audio_channels", nrAudioChannels),
            ("resolution", resolution), ("color_depth", colorDepth), ("protection", protection),
        ]
        for (key, value) in optional {
            if let value { result[key] = value }
            else if !removeNils { result[key] = NSNull() }
        }
        return result
    }

    /// Create a resource from the dictionary representation used by Python SoCo.
    public init(dictionary: [String: Any]) throws {
        guard let uri = dictionary["uri"] as? String else {
            throw SoCoError.didlMetadata("Resource dictionary has no uri")
        }
        guard let protocolInfo = dictionary["protocol_info"] as? String else {
            throw SoCoError.didlMetadata("Resource dictionary has no protocol_info")
        }
        self.init(
            uri: uri,
            protocolInfo: protocolInfo,
            importURI: dictionary["import_uri"] as? String,
            size: dictionary["size"] as? Int,
            duration: dictionary["duration"] as? String,
            bitrate: dictionary["bitrate"] as? Int,
            sampleFrequency: dictionary["sample_frequency"] as? Int,
            bitsPerSample: dictionary["bits_per_sample"] as? Int,
            nrAudioChannels: dictionary["nr_audio_channels"] as? Int,
            resolution: dictionary["resolution"] as? String,
            colorDepth: dictionary["color_depth"] as? Int,
            protection: dictionary["protection"] as? String
        )
    }

    /// XML representation of the `<res>` element.
    public func xml() throws -> String {
        guard !protocolInfo.isEmpty else {
            throw SoCoError.didlMetadata(
                "Could not create Element for this resource: protocolInfo not set (required)."
            )
        }
        var attributes = ["protocolInfo=\"\(xmlEscape(protocolInfo))\""]
        func append(_ name: String, _ value: String?) {
            if let value { attributes.append("\(name)=\"\(xmlEscape(value))\"") }
        }
        append("importUri", importURI)
        append("size", size.map(String.init))
        append("duration", duration)
        append("bitrate", bitrate.map(String.init))
        append("sampleFrequency", sampleFrequency.map(String.init))
        append("bitsPerSample", bitsPerSample.map(String.init))
        append("nrAudioChannels", nrAudioChannels.map(String.init))
        append("resolution", resolution)
        append("colorDepth", colorDepth.map(String.init))
        append("protection", protection)
        return "<res \(attributes.joined(separator: " "))>\(xmlEscape(uri))</res>"
    }
}

public typealias DIDLTranslation = [String: (namespace: String, tag: String)]

private func merging(_ base: DIDLTranslation, _ additional: DIDLTranslation) -> DIDLTranslation {
    var result = base
    additional.forEach { result[$0] = $1 }
    return result
}

/// Base class for all DIDL-Lite objects.
open class DidlObject: CustomStringConvertible, Equatable {
    open class var itemClass: String { "object" }
    open class var xmlTag: String { "item" }
    open class var translation: DIDLTranslation {
        [
            "creator": ("dc", "creator"),
            "write_status": ("upnp", "writeStatus"),
        ]
    }

    public var title: String
    public var parentID: String
    public var itemID: String
    public var restricted: Bool
    public var resources: [DidlResource]
    public var desc: String?
    public var metadata: [String: String]

    /// The precise class string read from XML. This differs from `Self.itemClass` only
    /// for unknown vendor extensions. Python SoCo creates a dynamic subclass at runtime;
    /// Swift cannot synthesize nominal types at runtime, so the nearest known class is
    /// instantiated while this property preserves the exact vendor class losslessly.
    public internal(set) var originalItemClass: String?

    public var didlClass: String { originalItemClass ?? Self.itemClass }
    public var runtimeClassName: String { (try? formDIDLName(didlClass)) ?? String(describing: type(of: self)) }

    public required init(
        title: String,
        parentID: String,
        itemID: String,
        restricted: Bool = true,
        resources: [DidlResource] = [],
        desc: String? = "RINCON_AssociatedZPUDN",
        metadata: [String: String] = [:]
    ) throws {
        let allowed = Set(Self.translation.keys)
        if let bad = metadata.keys.first(where: { !allowed.contains($0) }) {
            throw SoCoError.invalidArgument("The key '\(bad)' is not allowed as an argument")
        }
        self.title = title
        self.parentID = parentID
        self.itemID = itemID
        self.restricted = restricted
        self.resources = resources
        self.desc = desc
        self.metadata = metadata
    }

    // Properties represented by the `_translation` maps in the Python implementation.
    public var creator: String? { get { metadata["creator"] } set { metadata["creator"] = newValue } }
    public var writeStatus: String? { get { metadata["write_status"] } set { metadata["write_status"] = newValue } }
    public var streamContent: String? { get { metadata["stream_content"] } set { metadata["stream_content"] = newValue } }
    public var radioShow: String? { get { metadata["radio_show"] } set { metadata["radio_show"] = newValue } }
    public var albumArtURI: String? { get { metadata["album_art_uri"] } set { metadata["album_art_uri"] = newValue } }
    public var genre: String? { get { metadata["genre"] } set { metadata["genre"] = newValue } }
    public var itemDescription: String? { get { metadata["description"] } set { metadata["description"] = newValue } }
    public var longDescription: String? { get { metadata["long_description"] } set { metadata["long_description"] = newValue } }
    public var publisher: String? { get { metadata["publisher"] } set { metadata["publisher"] = newValue } }
    public var language: String? { get { metadata["language"] } set { metadata["language"] = newValue } }
    public var relation: String? { get { metadata["relation"] } set { metadata["relation"] = newValue } }
    public var rights: String? { get { metadata["rights"] } set { metadata["rights"] = newValue } }
    public var artist: String? { get { metadata["artist"] } set { metadata["artist"] = newValue } }
    public var album: String? { get { metadata["album"] } set { metadata["album"] = newValue } }
    public var originalTrackNumber: Int? {
        get { metadata["original_track_number"].flatMap(Int.init) }
        set { metadata["original_track_number"] = newValue.map(String.init) }
    }
    public var playlist: String? { get { metadata["playlist"] } set { metadata["playlist"] = newValue } }
    public var contributor: String? { get { metadata["contributor"] } set { metadata["contributor"] = newValue } }
    public var date: String? { get { metadata["date"] } set { metadata["date"] = newValue } }
    public var storageMedium: String? { get { metadata["storage_medium"] } set { metadata["storage_medium"] = newValue } }
    public var producer: String? { get { metadata["producer"] } set { metadata["producer"] = newValue } }
    public var region: String? { get { metadata["region"] } set { metadata["region"] = newValue } }
    public var radioCallSign: String? { get { metadata["radio_call_sign"] } set { metadata["radio_call_sign"] = newValue } }
    public var radioStationID: String? { get { metadata["radio_station_id"] } set { metadata["radio_station_id"] = newValue } }
    public var channelNumber: String? { get { metadata["channel_nr"] } set { metadata["channel_nr"] = newValue } }
    public var toc: String? { get { metadata["toc"] } set { metadata["toc"] = newValue } }
    public var artistDiscographyURI: String? { get { metadata["artist_discography_uri"] } set { metadata["artist_discography_uri"] = newValue } }
    public var favoriteType: String? { get { metadata["type"] } set { metadata["type"] = newValue } }
    public var favoriteNumber: String? { get { metadata["favorite_nr"] } set { metadata["favorite_nr"] = newValue } }
    public var resourceMetadata: String? { get { metadata["resource_meta_data"] } set { metadata["resource_meta_data"] = newValue } }

    /// Create an instance of this specific DIDL class from an `<item>` or
    /// `<container>` element, matching Python SoCo's `DidlObject.from_element`.
    ///
    /// This method intentionally validates that the incoming `upnp:class` is the
    /// class represented by `Self`. Generic vendor-extension dispatch belongs to
    /// `fromDIDLString`, just as Python performs dynamic class lookup before calling
    /// the class-specific `from_element` constructor.
    public class func fromElement(_ element: SoCoXMLElement) throws -> Self {
        guard element.localNameSafe == "item" || element.localNameSafe == "container" else {
            throw SoCoError.didlMetadata(
                "Wrong element. Expected <item> or <container>, got <\(element.localNameSafe)> for class \(Self.itemClass)"
            )
        }
        guard let classNode = element.children?.compactMap({ $0 as? SoCoXMLElement }).first(where: { $0.localNameSafe == "class" }),
              !classNode.text.isEmpty else {
            throw SoCoError.didlMetadata("Missing upnp:class")
        }
        let incomingClass = classWithoutUnofficialSubclass(classNode.text)
        guard incomingClass == Self.itemClass else {
            throw SoCoError.didlMetadata(
                "UPnP class is incorrect. Expected '\(Self.itemClass)', got '\(incomingClass)'"
            )
        }
        guard let itemID = element.attribute("id") else {
            throw SoCoError.didlMetadata("Missing id attribute")
        }
        guard let parentID = element.attribute("parentID") else {
            throw SoCoError.didlMetadata("Missing parentID attribute")
        }

        // This reproduces the upstream implementation exactly: a missing
        // `restricted` attribute is treated as true, as are values other than the
        // literal strings "false" and "False". (ElementTree returns attributes as
        // strings, so the integer 0 in the Python comparison is effectively inert.)
        let restrictedRaw = element.attribute("restricted")
        let restricted = restrictedRaw != "false" && restrictedRaw != "False"
        let title = element.children?.compactMap({ $0 as? SoCoXMLElement })
            .first(where: { $0.localNameSafe == "title" })?.text ?? ""

        var resources: [DidlResource] = []
        for resourceElement in element.children?.compactMap({ $0 as? SoCoXMLElement })
            .filter({ $0.localNameSafe == "res" }) ?? [] {
            if Self.itemClass == DidlFavorite.itemClass && (resourceElement.attributes?.isEmpty ?? true) {
                continue
            }
            resources.append(try DidlResource(element: resourceElement))
        }

        let desc = element.children?.compactMap({ $0 as? SoCoXMLElement })
            .first(where: { $0.localNameSafe == "desc" })?.text
        var metadata: [String: String] = [:]
        for (key, mapping) in Self.translation {
            guard key != "title" else { continue }
            if let value = element.children?.compactMap({ $0 as? SoCoXMLElement })
                .first(where: { $0.localNameSafe == mapping.tag })?.text {
                metadata[key] = value
            }
        }
        return try Self.init(
            title: title,
            parentID: parentID,
            itemID: itemID,
            restricted: restricted,
            resources: resources,
            desc: desc,
            metadata: metadata
        )
    }

    /// Create an instance from the dictionary representation returned by
    /// `dictionary(removeNils:)`, corresponding to Python SoCo's `from_dict`.
    /// Compatibility spelling for Python SoCo's `from_dict`.
    public class func fromDict(_ content: [String: Any]) throws -> Self {
        try fromDictionary(content)
    }

    public class func fromDictionary(_ content: [String: Any]) throws -> Self {
        let reserved: Set<String> = ["title", "parent_id", "item_id", "restricted", "resources", "desc"]
        let allowed = reserved.union(Self.translation.keys)
        if let unknown = content.keys.first(where: { !allowed.contains($0) }) {
            throw SoCoError.invalidArgument("The key '\(unknown)' is not allowed as an argument")
        }
        guard let title = content["title"] as? String else {
            throw SoCoError.didlMetadata("DIDL dictionary has no title")
        }
        guard let parentID = content["parent_id"] as? String else {
            throw SoCoError.didlMetadata("DIDL dictionary has no parent_id")
        }
        guard let itemID = content["item_id"] as? String else {
            throw SoCoError.didlMetadata("DIDL dictionary has no item_id")
        }
        let restricted = content["restricted"] as? Bool ?? true

        var resources: [DidlResource] = []
        if let rawResources = content["resources"] {
            if let typed = rawResources as? [DidlResource] {
                resources = typed
            } else if let dictionaries = rawResources as? [[String: Any]] {
                resources = try dictionaries.map(DidlResource.init(dictionary:))
            } else if !(rawResources is NSNull) {
                throw SoCoError.didlMetadata("DIDL resources must be resources or dictionaries")
            }
        }

        let desc: String?
        if content.keys.contains("desc") {
            desc = content["desc"] as? String
        } else {
            desc = "RINCON_AssociatedZPUDN"
        }

        var metadata: [String: String] = [:]
        for key in Self.translation.keys where key != "title" {
            guard let value = content[key], !(value is NSNull) else { continue }
            switch value {
            case let value as String: metadata[key] = value
            case let value as Int: metadata[key] = String(value)
            case let value as Bool: metadata[key] = value ? "true" : "false"
            default: metadata[key] = String(describing: value)
            }
        }
        return try Self.init(
            title: title,
            parentID: parentID,
            itemID: itemID,
            restricted: restricted,
            resources: resources,
            desc: desc,
            metadata: metadata
        )
    }

    /// Return an XML element representing this object, corresponding to Python
    /// SoCo's `to_element` API.
    public func toElement(includeNamespaces: Bool = false) throws -> SoCoXMLElement {
        let root = SoCoXMLElement(name: Self.xmlTag)
        func attribute(_ name: String, _ value: String) {
            root.addAttribute(SoCoXMLNode.attribute(withName: name, stringValue: value))
        }
        if includeNamespaces {
            attribute("xmlns", "urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/")
            attribute("xmlns:dc", "http://purl.org/dc/elements/1.1/")
            attribute("xmlns:upnp", "urn:schemas-upnp-org:metadata-1-0/upnp/")
        }
        attribute("parentID", parentID)
        attribute("restricted", restricted ? "true" : "false")
        attribute("id", itemID)
        root.addChild(SoCoXMLElement(name: "dc:title", stringValue: title))
        for resource in resources { root.addChild(try resource.toElement()) }
        for (key, mapping) in Self.translation where key != "title" {
            guard let value = metadata[key] else { continue }
            let name = mapping.namespace.isEmpty ? mapping.tag : "\(mapping.namespace):\(mapping.tag)"
            root.addChild(SoCoXMLElement(name: name, stringValue: value))
        }
        root.addChild(SoCoXMLElement(name: "upnp:class", stringValue: didlClass))
        if let desc {
            let node = SoCoXMLElement(name: "desc", stringValue: desc)
            node.addAttribute(SoCoXMLNode.attribute(withName: "id", stringValue: "cdudn"))
            node.addAttribute(SoCoXMLNode.attribute(withName: "nameSpace", stringValue: "urn:schemas-rinconnetworks-com:metadata-1-0/"))
            root.addChild(node)
        }
        return root
    }

    public func getURI(resourceNumber: Int = 0) throws -> String {
        guard resources.indices.contains(resourceNumber) else {
            throw SoCoError.didlMetadata("Resource index out of range")
        }
        return resources[resourceNumber].uri
    }

    public func setURI(_ uri: String, resourceNumber: Int = 0, protocolInfo: String? = nil) {
        if resources.indices.contains(resourceNumber) {
            resources[resourceNumber].uri = uri
            if let protocolInfo { resources[resourceNumber].protocolInfo = protocolInfo }
        } else {
            let scheme = uri.split(separator: ":", maxSplits: 1).first.map(String.init) ?? "http"
            resources.append(DidlResource(uri: uri, protocolInfo: protocolInfo ?? "\(scheme):*:*:*"))
        }
    }

    /// Dictionary representation equivalent to Python SoCo's `to_dict`.
    public func dictionary(removeNils: Bool = false) -> [String: Any] {
        var result: [String: Any] = [
            "parent_id": parentID,
            "item_id": itemID,
            "restricted": restricted,
            "title": title,
        ]
        // Python only places translated attributes in the dictionary when that
        // attribute was actually present on the object. Do not manufacture null
        // entries for every key supported by the class.
        for (key, value) in metadata {
            guard Self.translation[key] != nil else { continue }
            result[key] = key == "original_track_number" ? (Int(value) ?? 0) : value
        }
        if !resources.isEmpty {
            // `remove_nones` is forwarded to resource dictionaries. At the object
            // level upstream still includes `desc=None`, so `removeNils` must not
            // remove the descriptor itself.
            result["resources"] = resources.map { $0.dictionary(removeNils: removeNils) }
        }
        result["desc"] = desc ?? NSNull()
        return result
    }

    /// Serialize this object as an `<item>` or `<container>` element.
    public func xml(includeNamespaces: Bool = false) throws -> String {
        var attributes =
            "id=\"\(xmlEscape(itemID))\" parentID=\"\(xmlEscape(parentID))\" restricted=\"\(restricted ? "true" : "false")\""
        if includeNamespaces {
            attributes +=
                " xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\"" +
                " xmlns:dc=\"http://purl.org/dc/elements/1.1/\"" +
                " xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\"" +
                " xmlns:r=\"urn:schemas-rinconnetworks-com:metadata-1-0/\""
        }

        var body = "<dc:title>\(xmlEscape(title))</dc:title>"
        for resource in resources { body += try resource.xml() }

        // Dictionary order is not protocol-significant. XML equality tests compare nodes,
        // not raw attribute/child ordering, just like the original SoCo test suite.
        for key in Self.translation.keys.sorted() {
            guard key != "title", let value = metadata[key], let mapping = Self.translation[key] else { continue }
            let tag = mapping.namespace.isEmpty ? mapping.tag : "\(mapping.namespace):\(mapping.tag)"
            body += "<\(tag)>\(xmlEscape(value))</\(tag)>"
        }
        body += "<upnp:class>\(xmlEscape(didlClass))</upnp:class>"
        if let desc {
            body +=
                "<desc id=\"cdudn\" nameSpace=\"urn:schemas-rinconnetworks-com:metadata-1-0/\">" +
                "\(xmlEscape(desc))</desc>"
        }
        return "<\(Self.xmlTag) \(attributes)>\(body)</\(Self.xmlTag)>"
    }

    public var description: String {
        "<\(runtimeClassName) '\(String(title.prefix(40)))'>"
    }

    public static func == (lhs: DidlObject, rhs: DidlObject) -> Bool {
        lhs.didlClass == rhs.didlClass &&
            lhs.title == rhs.title && lhs.parentID == rhs.parentID && lhs.itemID == rhs.itemID &&
            lhs.restricted == rhs.restricted && lhs.resources == rhs.resources && lhs.desc == rhs.desc &&
            lhs.metadata == rhs.metadata
    }
}

// MARK: DIDL hierarchy

open class DidlItem: DidlObject {
    override open class var itemClass: String { "object.item" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "stream_content": ("r", "streamContent"),
            "radio_show": ("r", "radioShowMd"),
            "album_art_uri": ("upnp", "albumArtURI"),
        ])
    }
}

open class DidlAudioItem: DidlItem {
    override open class var itemClass: String { "object.item.audioItem" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "genre": ("upnp", "genre"),
            "description": ("dc", "description"),
            "long_description": ("upnp", "longDescription"),
            "publisher": ("dc", "publisher"),
            "language": ("dc", "language"),
            "relation": ("dc", "relation"),
            "rights": ("dc", "rights"),
        ])
    }
}

open class DidlMusicTrack: DidlAudioItem {
    override open class var itemClass: String { "object.item.audioItem.musicTrack" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "artist": ("upnp", "artist"),
            "album": ("upnp", "album"),
            "original_track_number": ("upnp", "originalTrackNumber"),
            "playlist": ("upnp", "playlist"),
            "contributor": ("dc", "contributor"),
            "date": ("dc", "date"),
        ])
    }
}

open class DidlAudioBook: DidlAudioItem {
    override open class var itemClass: String { "object.item.audioItem.audioBook" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "storage_medium": ("upnp", "storageMedium"),
            "producer": ("upnp", "producer"),
            "contributor": ("dc", "contributor"),
            "date": ("dc", "date"),
        ])
    }
}

open class DidlAudioBroadcast: DidlAudioItem {
    override open class var itemClass: String { "object.item.audioItem.audioBroadcast" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "region": ("upnp", "region"),
            "radio_call_sign": ("upnp", "radioCallSign"),
            "radio_station_id": ("upnp", "radioStationID"),
            "channel_nr": ("upnp", "channelNr"),
        ])
    }
}

open class DidlAudioLineIn: DidlAudioItem {
    override open class var itemClass: String { "object.item.audioItem.linein" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, ["title": ("upnp", "title")])
    }
}

open class DidlRecentShow: DidlMusicTrack {
    override open class var itemClass: String { "object.item.audioItem.musicTrack.recentShow" }
}

open class DidlAudioBroadcastFavorite: DidlAudioBroadcast {
    override open class var itemClass: String { "object.item.audioItem.audioBroadcast.sonos-favorite" }
}

open class DidlFavorite: DidlItem {
    // Yes, this string looks malformed. It is the exact class emitted/expected by Sonos
    // and by Python SoCo, so changing it would break wire compatibility.
    override open class var itemClass: String { "object.itemobject.item.sonos-favorite" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "type": ("r", "type"),
            "description": ("r", "description"),
            "favorite_nr": ("r", "ordinal"),
            "resource_meta_data": ("r", "resMD"),
        ])
    }

    /// The DIDL object referenced by this favorite's `r:resMD` payload.
    public var reference: DidlObject {
        get throws {
            guard let resourceMetadata else {
                throw SoCoError.didlMetadata("Favorite '\(title)' has no resource_meta_data (resMD) element")
            }
            guard let referenced = try fromDIDLString(resourceMetadata).first else {
                throw SoCoError.didlMetadata("Favorite '\(title)' has resource_meta_data containing no DIDL item")
            }
            // Favorites often put the playable resource on the outer favorite while the
            // referenced resMD object has no <res>. Copy it across, matching Python SoCo.
            referenced.resources = resources
            return referenced
        }
    }

    public func setReference(_ value: DidlObject) throws {
        resourceMetadata = try toDIDLString([value])
        resources = value.resources
    }
}

open class DidlContainer: DidlObject {
    override open class var itemClass: String { "object.container" }
    override open class var xmlTag: String { "container" }
}

open class DidlAlbum: DidlContainer {
    override open class var itemClass: String { "object.container.album" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "description": ("dc", "description"),
            "long_description": ("upnp", "longDescription"),
            "publisher": ("dc", "publisher"),
            "contributor": ("dc", "contributor"),
            "date": ("dc", "date"),
            "relation": ("dc", "relation"),
            "rights": ("dc", "rights"),
        ])
    }
}

open class DidlMusicAlbum: DidlAlbum {
    override open class var itemClass: String { "object.container.album.musicAlbum" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "artist": ("upnp", "artist"),
            "genre": ("upnp", "genre"),
            "producer": ("upnp", "producer"),
            "toc": ("upnp", "toc"),
            "album_art_uri": ("upnp", "albumArtURI"),
        ])
    }
}

open class DidlMusicAlbumFavorite: DidlMusicAlbum {
    override open class var itemClass: String { "object.container.album.musicAlbum.sonos-favorite" }
    // Despite deriving from object.container, Sonos uses an <item> tag here.
    override open class var xmlTag: String { "item" }
}

open class DidlMusicAlbumCompilation: DidlMusicAlbum {
    override open class var itemClass: String { "object.container.album.musicAlbum.compilation" }
}

open class DidlPerson: DidlContainer {
    override open class var itemClass: String { "object.container.person" }
    override open class var xmlTag: String { "item" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, ["language": ("dc", "language")])
    }
}

open class DidlComposer: DidlPerson {
    override open class var itemClass: String { "object.container.person.composer" }
}

open class DidlMusicArtist: DidlPerson {
    override open class var itemClass: String { "object.container.person.musicArtist" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "genre": ("upnp", "genre"),
            "artist_discography_uri": ("upnp", "artistDiscographyURI"),
        ])
    }
}

open class DidlAlbumList: DidlContainer {
    override open class var itemClass: String { "object.container.albumlist" }
}

open class DidlPlaylistContainer: DidlContainer {
    override open class var itemClass: String { "object.container.playlistContainer" }
    // Sonos really does often use <item> here, despite the container base class.
    override open class var xmlTag: String { "item" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "artist": ("upnp", "artist"),
            "genre": ("upnp", "genre"),
            "long_description": ("upnp", "longDescription"),
            "producer": ("dc", "producer"),
            "contributor": ("dc", "contributor"),
            "description": ("dc", "description"),
            "date": ("dc", "date"),
            "language": ("dc", "language"),
            "rights": ("dc", "rights"),
        ])
    }
}

open class DidlSameArtist: DidlPlaylistContainer {
    override open class var itemClass: String { "object.container.playlistContainer.sameArtist" }
}
open class DidlPlaylistContainerFavorite: DidlPlaylistContainer {
    override open class var itemClass: String { "object.container.playlistContainer.sonos-favorite" }
}
open class DidlPlaylistContainerTracklist: DidlPlaylistContainer {
    override open class var itemClass: String { "object.container.playlistContainer.tracklist" }
}

open class DidlGenre: DidlContainer {
    override open class var itemClass: String { "object.container.genre" }
    override open class var translation: DIDLTranslation {
        merging(super.translation, [
            "genre": ("upnp", "genre"),
            "long_description": ("upnp", "longDescription"),
            "description": ("dc", "description"),
        ])
    }
}

open class DidlMusicGenre: DidlGenre {
    override open class var itemClass: String { "object.container.genre.musicGenre" }
    override open class var xmlTag: String { "item" }
}

open class DidlRadioShow: DidlContainer {
    override open class var itemClass: String { "object.container.radioShow" }
}

// MARK: DIDL class lookup

private let didlFactories: [String: DidlObject.Type] = [
    DidlObject.itemClass: DidlObject.self,
    DidlItem.itemClass: DidlItem.self,
    DidlAudioItem.itemClass: DidlAudioItem.self,
    DidlMusicTrack.itemClass: DidlMusicTrack.self,
    DidlAudioBook.itemClass: DidlAudioBook.self,
    DidlAudioBroadcast.itemClass: DidlAudioBroadcast.self,
    DidlAudioLineIn.itemClass: DidlAudioLineIn.self,
    DidlRecentShow.itemClass: DidlRecentShow.self,
    DidlAudioBroadcastFavorite.itemClass: DidlAudioBroadcastFavorite.self,
    DidlFavorite.itemClass: DidlFavorite.self,
    DidlContainer.itemClass: DidlContainer.self,
    DidlAlbum.itemClass: DidlAlbum.self,
    DidlMusicAlbum.itemClass: DidlMusicAlbum.self,
    DidlMusicAlbumFavorite.itemClass: DidlMusicAlbumFavorite.self,
    DidlMusicAlbumCompilation.itemClass: DidlMusicAlbumCompilation.self,
    DidlPerson.itemClass: DidlPerson.self,
    DidlComposer.itemClass: DidlComposer.self,
    DidlMusicArtist.itemClass: DidlMusicArtist.self,
    DidlAlbumList.itemClass: DidlAlbumList.self,
    DidlPlaylistContainer.itemClass: DidlPlaylistContainer.self,
    DidlSameArtist.itemClass: DidlSameArtist.self,
    DidlPlaylistContainerFavorite.itemClass: DidlPlaylistContainerFavorite.self,
    DidlPlaylistContainerTracklist.itemClass: DidlPlaylistContainerTracklist.self,
    DidlGenre.itemClass: DidlGenre.self,
    DidlMusicGenre.itemClass: DidlMusicGenre.self,
    DidlRadioShow.itemClass: DidlRadioShow.self,
]

private let officialDIDLClasses: Set<String> = [
    "object", "object.item", "object.item.audioItem", "object.item.audioItem.musicTrack",
    "object.item.audioItem.audioBroadcast", "object.item.audioItem.audioBook",
    "object.item.audioItem.linein", "object.container", "object.container.person",
    "object.container.person.musicArtist", "object.container.playlistContainer",
    "object.container.album", "object.container.musicAlbum", "object.container.genre",
    "object.container.musicGenre",
]

/// Return the improvised class name Python SoCo uses for vendor-extended classes.
public func formDIDLName(_ didlClass: String) throws -> String {
    guard didlClass.hasPrefix("object.") else {
        throw SoCoError.didlMetadata("Unknown UPnP class: \(didlClass)")
    }
    let parts = didlClass.split(separator: ".").map(String.init)
    if parts.last == "sonos-favorite", parts.count >= 2 {
        return "Didl" + firstCap(parts[parts.count - 2]) + "Favorite"
    }

    var searchParts = parts
    var newParts: [String] = []
    while !searchParts.isEmpty {
        var part = searchParts.removeLast()
        if part.hasSuffix("list") { part = part.replacingOccurrences(of: "list", with: "List") }
        newParts.append(part)
        if officialDIDLClasses.contains(searchParts.joined(separator: ".")) { break }
    }
    return "Didl" + newParts.reversed().map(firstCap).joined()
}

private func classWithoutUnofficialSubclass(_ value: String) -> String {
    // Certain services subclass via a .# or # syntax. SoCo simply ignores that suffix.
    for separator in [".#", "#"] {
        if let range = value.range(of: separator) { return String(value[..<range.lowerBound]) }
    }
    return value
}

/// Return the nearest known Swift class for a DIDL class string.
///
/// For an unknown vendor extension Python SoCo dynamically creates a subclass. Swift
/// uses the nearest known base type and preserves the exact class in `originalItemClass`.
public func didlType(for didlClass: String) -> DidlObject.Type {
    let cleaned = classWithoutUnofficialSubclass(didlClass)
    if let type = didlFactories[cleaned] { return type }
    let parts = cleaned.split(separator: ".")
    if parts.count > 1 { return didlType(for: parts.dropLast().joined(separator: ".")) }
    return DidlObject.self
}

/// Translate a DIDL-Lite class to the corresponding Swift SoCo type.
public func didlClassToSoCoClass(_ didlClass: String?) throws -> DidlObject.Type {
    guard let didlClass else { throw SoCoError.didlMetadata("DIDL class is None") }
    return didlType(for: didlClass)
}

/// Parse a DIDL-Lite XML string into SoCo objects.
public func fromDIDLString(_ xml: String) throws -> [DidlObject] {
    // Upstream deliberately uses lxml's recover parser here, but even that
    // parser rejects an empty document. Do not silently reinterpret an empty
    // response as an empty DIDL result set.
    let tree = try XMLTree(xml, recoverMalformedAttributes: true)
    guard let root = tree.root else { return [] }

    var output: [DidlObject] = []
    for element in root.children?.compactMap({ $0 as? SoCoXMLElement }) ?? [] {
        guard ["item", "container"].contains(element.localNameSafe) else {
            // <desc> is permitted by the DIDL-Lite spec at the document root,
            // but upstream SoCo has never observed Sonos using it there and
            // intentionally treats every non-item/container child as illegal.
            throw SoCoError.didlMetadata("Illegal child of DIDL element: <\(element.name ?? element.localNameSafe)>")
        }
        guard let classNode = element.children?.compactMap({ $0 as? SoCoXMLElement }).first(where: { $0.localNameSafe == "class" }),
              !classNode.text.isEmpty else {
            throw SoCoError.didlMetadata("Missing upnp:class")
        }

        let incomingClass = classWithoutUnofficialSubclass(classNode.text)
        let type = didlType(for: incomingClass)
        guard let itemID = element.attribute("id") else { throw SoCoError.didlMetadata("Missing id attribute") }
        guard let parentID = element.attribute("parentID") else { throw SoCoError.didlMetadata("Missing parentID attribute") }
        let restrictedRaw = element.attribute("restricted")
        // ElementTree exposes XML attributes as strings. The upstream implementation
        // only treats the strings "false" and "False" as false; notably, the string
        // "0" is therefore true. Preserve that slightly surprising behavior exactly.
        let restricted = restrictedRaw != "false" && restrictedRaw != "False"
        let title = element.children?.compactMap({ $0 as? SoCoXMLElement }).first(where: { $0.localNameSafe == "title" })?.text ?? ""

        var resources: [DidlResource] = []
        for resourceElement in element.children?.compactMap({ $0 as? SoCoXMLElement }).filter({ $0.localNameSafe == "res" }) ?? [] {
            // DidlFavorite may contain an empty <res> as a placeholder. The original
            // parser skips that instead of trying to create a resource from it.
            if type == DidlFavorite.self && (resourceElement.attributes?.isEmpty ?? true) { continue }
            resources.append(try DidlResource(element: resourceElement))
        }

        let desc = element.children?.compactMap({ $0 as? SoCoXMLElement }).first(where: { $0.localNameSafe == "desc" })?.text
        var metadata: [String: String] = [:]
        let reverseTranslation = Dictionary(uniqueKeysWithValues: type.translation.map { key, value in (value.tag, key) })
        for child in element.children?.compactMap({ $0 as? SoCoXMLElement }) ?? [] {
            if let key = reverseTranslation[child.localNameSafe], key != "title" {
                metadata[key] = child.text
            }
        }

        let object = try type.init(
            title: title,
            parentID: parentID,
            itemID: itemID,
            restricted: restricted,
            resources: resources,
            desc: desc,
            metadata: metadata
        )
        if incomingClass != type.itemClass {
            object.originalItemClass = incomingClass
        }
        output.append(object)
    }
    return output
}

/// Convert one or more DIDL objects to a DIDL-Lite XML document.
public func toDIDLString(_ objects: [DidlObject]) throws -> String {
    let body = try objects.map { try $0.xml() }.joined()
    return
        "<DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\"" +
        " xmlns:dc=\"http://purl.org/dc/elements/1.1/\"" +
        " xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\"" +
        " xmlns:r=\"urn:schemas-rinconnetworks-com:metadata-1-0/\">" +
        body + "</DIDL-Lite>"
}

/// Variadic convenience matching Python SoCo's `to_didl_string(*args)`.
public func toDIDLString(_ first: DidlObject, _ rest: DidlObject...) throws -> String {
    try toDIDLString([first] + rest)
}

/// Convert a modern SMAPI music-service item to the same DIDL-Lite wrapper used
/// by Python SoCo's polymorphic `to_didl_string` helper.
public func toDIDLString(_ item: SMAPI.MusicServiceItem) throws -> String {
    let inner = try item.didlXML()
    return "<DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:r=\"urn:schemas-rinconnetworks-com:metadata-1-0/\">\(inner)</DIDL-Lite>"
}

// MARK: Search / queue result containers

/// Abstract container for lists returned by library and music-service queries.
/// `totalMatches` and `numberReturned` indicate whether paging is required.
public struct MusicInfoList {
    public var items: [DidlObject]
    public var numberReturned: String
    public var totalMatches: String
    public var updateID: String

    public init(items: [DidlObject], numberReturned: String, totalMatches: String, updateID: String) {
        self.items = items
        self.numberReturned = numberReturned
        self.totalMatches = totalMatches
        self.updateID = updateID
    }
}

/// Container returned from search/browse operations. Browse is a special case of search.
public struct SearchResult {
    public var items: [DidlObject]
    public var searchType: String
    public var numberReturned: String
    public var totalMatches: String
    public var updateID: String

    public init(items: [DidlObject], searchType: String, numberReturned: String, totalMatches: String, updateID: String) {
        self.items = items
        self.searchType = searchType
        self.numberReturned = numberReturned
        self.totalMatches = totalMatches
        self.updateID = updateID
    }
}

/// Container class that represents a Sonos queue.
public typealias SoCoQueue = MusicInfoList
public typealias ListOfMusicInfoItems = MusicInfoList

/// Apply the resource quirks used by SoCo when a third-party service emits a
/// `<res>` element without the mandatory `protocolInfo` attribute.
///
/// The element is mutated in place and returned for convenient chaining, just
/// like `soco.data_structure_quirks.apply_resource_quirks`.
@discardableResult
public func applyResourceQuirks(_ resource: SoCoXMLElement) -> SoCoXMLElement {
    if resource.attribute("protocolInfo") == nil {
        let protocolInfo = resource.text.hasPrefix("x-sonos-spotify")
            ? "sonos.com-spotify:*:audio/x-spotify.*"
            : "DUMMY_ADDED_BY_QUIRK"
        let node = SoCoXMLNode.attribute(withName: "protocolInfo", stringValue: protocolInfo)
        resource.addAttribute(node)
        if resource.stringValue == nil { resource.stringValue = "" }
    }
    return resource
}

/// Source-compatibility name for `soco.data_structures.Queue`.
///
/// Python can also have `soco.services.Queue` because modules provide separate
/// namespaces. Swift has one module namespace, so the UPnP service is named
/// `QueueService` while this public `Queue` alias keeps the DIDL container name.
public typealias Queue = SoCoQueue
