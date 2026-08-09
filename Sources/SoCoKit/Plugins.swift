import Foundation

// MARK: - Plugin base

/// Base class for SoCo plugins.
open class SoCoPlugin {
    public let soco: SoCo
    public required init(_ soco: SoCo) { self.soco = soco }
    open var name: String { "SoCo Plugin" }

    public typealias Factory = (SoCo) throws -> SoCoPlugin
    private static let registryLock = NSLock()
    private static var registry: [String: Factory] = [:]

    /// Swift cannot import a class from an arbitrary dotted Python module name at
    /// runtime. The equivalent extensibility point is an explicit factory registry.
    public static func register(_ fullName: String, factory: @escaping Factory) {
        registryLock.lock(); registry[fullName] = factory; registryLock.unlock()
    }

    public static func fromName(_ fullName: String, soco: SoCo) throws -> SoCoPlugin {
        registryLock.lock(); let factory = registry[fullName]; registryLock.unlock()
        if let factory { return try factory(soco) }
        switch fullName {
        case "soco.plugins.sharelink.ShareLinkPlugin", "ShareLinkPlugin": return ShareLinkPlugin(soco)
        case "soco.plugins.plex.PlexPlugin", "PlexPlugin": return PlexPlugin(soco)
        default: throw SoCoError.unsupported("No Swift plugin factory registered for \(fullName)")
        }
    }
}

// MARK: - Share-link plugin

/// Base class for music-service share-link adapters.
open class ShareClass {
    open func canonicalURI(_ uri: String) -> String? { nil }
    open var serviceNumber: Int { 0 }
    open func extract(_ uri: String) -> (shareType: String, encodedURI: String)? { nil }

    /// Magic prefix/key/class values used by Sonos's DIDL representation of share links.
    public static let magic: [String: (prefix: String, key: String, itemClass: String)] = [
        "album": ("x-rincon-cpcontainer:1004206c", "00040000", "object.container.album.musicAlbum"),
        "episode": ("", "00032020", "object.item.audioItem.musicTrack"),
        "track": ("", "00032020", "object.item.audioItem.musicTrack"),
        "show": ("x-rincon-cpcontainer:1006206c", "1006206c", "object.container.playlistContainer"),
        "song": ("", "10032020", "object.item.audioItem.musicTrack"),
        "playlist": ("x-rincon-cpcontainer:1006206c", "1006206c", "object.container.playlistContainer"),
    ]

    internal func match(_ pattern: String, in input: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = input as NSString
        guard let result = regex.firstMatch(in: input, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<result.numberOfRanges).map { index in
            let range = result.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }
}

public final class SpotifyShare: ShareClass {
    public override func canonicalURI(_ uri: String) -> String? {
        guard let m = match(#"spotify.*[:/](album|episode|playlist|show|track)[:/](\w+)"#, in: uri), m.count >= 3 else { return nil }
        return "spotify:\(m[1]):\(m[2])"
    }
    public override var serviceNumber: Int { 2311 }
    public override func extract(_ uri: String) -> (String, String)? {
        guard let canonical = canonicalURI(uri) else { return nil }
        let parts = canonical.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        return (String(parts[1]), canonical.replacingOccurrences(of: ":", with: "%3a"))
    }
}

public final class SpotifyUSShare: ShareClass {
    private let base = SpotifyShare()
    public override func canonicalURI(_ uri: String) -> String? { base.canonicalURI(uri) }
    public override var serviceNumber: Int { 3079 }
    public override func extract(_ uri: String) -> (String, String)? { base.extract(uri) }
}

public final class TIDALShare: ShareClass {
    public override func canonicalURI(_ uri: String) -> String? {
        guard let m = match(#"https://tidal.*[:/](album|track|playlist)[:/]([\w-]+)"#, in: uri), m.count >= 3 else { return nil }
        return "tidal:\(m[1]):\(m[2])"
    }
    public override var serviceNumber: Int { 44551 }
    public override func extract(_ uri: String) -> (String, String)? {
        guard let canonical = canonicalURI(uri) else { return nil }
        let parts = canonical.split(separator: ":")
        let encoded = canonical.replacingOccurrences(of: "tidal:", with: "").replacingOccurrences(of: ":", with: "%2f")
        return parts.count > 1 ? (String(parts[1]), encoded) : nil
    }
}

public final class DeezerShare: ShareClass {
    public override func canonicalURI(_ uri: String) -> String? {
        guard let m = match(#"https://www\.deezer.*[:/](album|track|playlist)[:/]([\w-]+)"#, in: uri), m.count >= 3 else { return nil }
        return "deezer:\(m[1]):\(m[2])"
    }
    public override var serviceNumber: Int { 519 }
    public override func extract(_ uri: String) -> (String, String)? {
        guard let canonical = canonicalURI(uri) else { return nil }
        let parts = canonical.split(separator: ":")
        let encoded = canonical.replacingOccurrences(of: "deezer:", with: "").replacingOccurrences(of: ":", with: "-")
        return parts.count > 1 ? (String(parts[1]), encoded) : nil
    }
}

public final class AppleMusicShare: ShareClass {
    public override func canonicalURI(_ uri: String) -> String? {
        if let m = match(#"https://music\.apple\.com/\w+/album/[^/]+/\d+\?i=(\d+)"#, in: uri), m.count >= 2 { return "song:\(m[1])" }
        if let m = match(#"https://music\.apple\.com/\w+/album/[^/]+/(\d+)"#, in: uri), m.count >= 2 { return "album:\(m[1])" }
        if let m = match(#"https://music\.apple\.com/\w+/playlist/[^/]+/(pl\.[-a-zA-Z0-9]+)"#, in: uri), m.count >= 2 { return "playlist:\(m[1])" }
        return nil
    }
    public override var serviceNumber: Int { 52231 }
    public override func extract(_ uri: String) -> (String, String)? {
        guard let canonical = canonicalURI(uri) else { return nil }
        let shareType = canonical.split(separator: ":").first.map(String.init) ?? ""
        return (shareType, canonical.replacingOccurrences(of: ":", with: "%3a"))
    }
}

/// Plugin for adding Spotify/TIDAL/Deezer/Apple Music share links to a Sonos queue.
public final class ShareLinkPlugin: SoCoPlugin {
    public let services: [ShareClass]
    public required init(_ soco: SoCo) {
        services = [SpotifyShare(), SpotifyUSShare(), TIDALShare(), DeezerShare(), AppleMusicShare()]
        super.init(soco)
    }
    public override var name: String { "ShareLink Plugin" }

    public func isShareLink(_ uri: String) -> Bool { services.contains { $0.canonicalURI(uri) != nil } }

    /// Add a supported share link to the queue, preserving the exact magic IDs and
    /// descriptor format used by the Python plugin.
    @discardableResult
    public func addShareLinkToQueue(_ uri: String, position: Int = 0, asNext: Bool = false, dcTitle: String = "") throws -> Int {
        var lastError: Error = SoCoError.unsupported("Unsupported URI: \(uri)")
        for service in services {
            guard let extracted = service.extract(uri), let magic = ShareClass.magic[extracted.shareType] else { continue }
            let enqueueURI = magic.prefix + extracted.encodedURI
            let metadata =
                "<DIDL-Lite xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:r=\"urn:schemas-rinconnetworks-com:metadata-1-0/\" xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\">" +
                "<item id=\"\(xmlEscape(magic.key + extracted.encodedURI))\" parentID=\"-1\" restricted=\"true\"><dc:title>\(xmlEscape(dcTitle))</dc:title>" +
                "<upnp:class>\(magic.itemClass)</upnp:class><desc id=\"cdudn\" nameSpace=\"urn:schemas-rinconnetworks-com:metadata-1-0/\">" +
                "SA_RINCON\(service.serviceNumber)_X_#Svc\(service.serviceNumber)-0-Token</desc></item></DIDL-Lite>"
            do {
                let response = try soco.avTransport.sendCommand("AddURIToQueue", arguments: [
                    ("InstanceID", "0"), ("EnqueuedURI", enqueueURI), ("EnqueuedURIMetaData", metadata),
                    ("DesiredFirstTrackNumberEnqueued", String(position)), ("EnqueueAsNext", asNext ? "1" : "0")
                ])
                return Int(response["FirstTrackNumberEnqueued"] ?? "0") ?? 0
            } catch {
                // Some URIs can match more than one service variant (notably Spotify
                // US/global). Upstream keeps trying and raises the last service error.
                lastError = error
            }
        }
        throw lastError
    }
}

// MARK: - Example plugin

public final class ExamplePlugin: SoCoPlugin {
    public var username: String
    public init(_ soco: SoCo, username: String) { self.username = username; super.init(soco) }
    public required convenience init(_ soco: SoCo) { self.init(soco, username: "") }
    public override var name: String { "Example Plugin for \(username)" }
    public func musicPluginPlay() throws { try soco.play() }
    public func musicPluginStop() throws { try soco.stop() }
}
