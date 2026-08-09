import Foundation

public final class MusicLibrary {
    public static let searchTranslation: [String: String] = [
        "artists": "A:ARTIST",
        "album_artists": "A:ALBUMARTIST",
        "albums": "A:ALBUM",
        "genres": "A:GENRE",
        "composers": "A:COMPOSER",
        "tracks": "A:TRACKS",
        "playlists": "A:PLAYLISTS",
        "share": "S:",
        "sonos_playlists": "SQ:",
        "categories": "A:",
        "sonos_favorites": "FV:2",
        "radio_stations": "R:0/0",
        "radio_shows": "R:0/1",
    ]

    public let soco: SoCo
    public var contentDirectory: ContentDirectory { soco.contentDirectory }

    public init(_ soco: SoCo) {
        self.soco = soco
    }

    public func buildAlbumArtFullURI(_ uri: String) -> String {
        guard !uri.hasPrefix("http:"), !uri.hasPrefix("https:") else { return uri }
        return "http://\(soco.ipAddress):1400\(uri)"
    }

    private func qualifyAlbumArt(_ item: DidlObject) {
        if let uri = item.albumArtURI, !uri.isEmpty {
            item.albumArtURI = buildAlbumArtFullURI(uri)
        }
    }

    public func getArtists(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "artists", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getAlbumArtists(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "album_artists", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getAlbums(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "albums", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getGenres(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "genres", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getComposers(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "composers", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getTracks(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "tracks", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getPlaylists(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "playlists", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getSonosPlaylists(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false, searchTerm: String? = nil, subcategories: [String]? = nil, completeResult: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "sonos_playlists", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI, searchTerm: searchTerm, subcategories: subcategories, completeResult: completeResult)
    }
    public func getSonosFavorites(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "sonos_favorites", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI)
    }
    public func getFavoriteRadioStations(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "radio_stations", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI)
    }
    public func getFavoriteRadioShows(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        try getMusicLibraryInformation(searchType: "radio_shows", start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI)
    }

    public func getMusicLibraryInformation(
        searchType: String,
        start: Int = 0,
        maxItems: Int = 100,
        fullAlbumArtURI: Bool = false,
        searchTerm: String? = nil,
        subcategories: [String]? = nil,
        completeResult: Bool = false
    ) throws -> SearchResult {
        guard var search = Self.searchTranslation[searchType] else {
            throw SoCoError.invalidArgument("Unknown music library search type: \(searchType)")
        }
        if searchType != "share" {
            for category in subcategories ?? [] { search += "/" + urlEscapePath(category) }
        }
        if let searchTerm {
            if searchType == "share" {
                search += searchTerm.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? searchTerm
            } else {
                search += ":" + urlEscapePath(searchTerm)
            }
        }

        var items: [DidlObject] = []
        var metadata = SearchMetadata(numberReturned: 0, totalMatches: Int.max, updateID: 0)
        repeat {
            let batchStart = completeResult ? items.count : start
            let batchMax = completeResult ? 100_000 : maxItems
            do {
                let result = try musicLibSearch(search: search, start: batchStart, maxItems: batchMax)
                metadata = result.metadata
                let parsed = try fromDIDLString(result.response["Result"] ?? "")
                if fullAlbumArtURI { parsed.forEach(qualifyAlbumArt) }
                items.append(contentsOf: parsed)
            } catch SoCoError.upnp(let code, _, _) where code == "701" {
                return SearchResult(items: [], searchType: searchType, numberReturned: "0", totalMatches: "0", updateID: "0")
            }
            if !completeResult { break }
        } while items.count < metadata.totalMatches

        return SearchResult(
            items: items,
            searchType: searchType,
            numberReturned: String(completeResult ? items.count : metadata.numberReturned),
            totalMatches: String(metadata.totalMatches),
            updateID: String(metadata.updateID)
        )
    }

    public func browse(
        item: DidlObject? = nil,
        start: Int = 0,
        maxItems: Int = 100,
        fullAlbumArtURI: Bool = false,
        searchTerm: String? = nil,
        subcategories: [String]? = nil
    ) throws -> SearchResult {
        var search = item?.itemID ?? "A:"
        for category in subcategories ?? [] { search += "/" + urlEscapePath(category) }
        if let searchTerm { search += ":" + urlEscapePath(searchTerm) }
        do {
            let result = try musicLibSearch(search: search, start: start, maxItems: maxItems)
            let parsed = try fromDIDLString(result.response["Result"] ?? "")
            if fullAlbumArtURI { parsed.forEach(qualifyAlbumArt) }
            return SearchResult(items: parsed, searchType: "browse", numberReturned: String(result.metadata.numberReturned), totalMatches: String(result.metadata.totalMatches), updateID: String(result.metadata.updateID))
        } catch SoCoError.upnp(let code, _, _) where code == "701" {
            return SearchResult(items: [], searchType: "browse", numberReturned: "0", totalMatches: "0", updateID: "0")
        }
    }

    public func browseByIDString(searchType: String, idString: String, start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        guard let prefix = Self.searchTranslation[searchType] else { throw SoCoError.invalidArgument("Unknown music library search type: \(searchType)") }
        let prepend = idString.hasPrefix(prefix) || searchType == "playlists" ? "" : prefix
        let objectID = prepend + idString
        let item = try DidlObject(title: "", parentID: "", itemID: objectID, resources: [DidlResource(uri: "#\(objectID)", protocolInfo: "x-rincon-playlist:*:*:*")])
        return try browse(item: item, start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI)
    }

    public struct SearchMetadata: Sendable, Equatable {
        public var numberReturned: Int
        public var totalMatches: Int
        public var updateID: Int
    }

    public func musicLibSearch(search: String, start: Int, maxItems: Int) throws -> (response: [String: String], metadata: SearchMetadata) {
        let response = try contentDirectory.sendCommand("Browse", arguments: [
            ("ObjectID", search),
            ("BrowseFlag", "BrowseDirectChildren"),
            ("Filter", "*"),
            ("StartingIndex", String(start)),
            ("RequestedCount", String(maxItems)),
            ("SortCriteria", ""),
        ])
        let metadata = SearchMetadata(
            numberReturned: Int(response["NumberReturned"] ?? "0") ?? 0,
            totalMatches: Int(response["TotalMatches"] ?? "0") ?? 0,
            updateID: Int(response["UpdateID"] ?? "0") ?? 0
        )
        return (response, metadata)
    }

    public var libraryUpdating: Bool {
        get throws {
            let result = try contentDirectory.sendCommand("GetShareIndexInProgress")
            return result["IsIndexing"] != "0"
        }
    }

    @discardableResult
    public func startLibraryUpdate(albumArtistDisplayOption: String = "") throws -> [String: String] {
        try contentDirectory.sendCommand("RefreshShareIndex", arguments: [("AlbumArtistDisplayOption", albumArtistDisplayOption)])
    }

    public func searchTrack(artist: String, album: String? = nil, track: String? = nil, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        // SoCo intentionally searches the ALBUMARTIST hierarchy here rather than the
        // plain ARTIST hierarchy. The empty album component is significant: asking for
        // just an artist produces `A:ALBUMARTIST/<artist>/` with a trailing slash.
        let subcategories = [artist, album ?? ""]
        var result = try getMusicLibraryInformation(
            searchType: "album_artists",
            fullAlbumArtURI: fullAlbumArtURI,
            searchTerm: track,
            subcategories: subcategories,
            completeResult: true
        )
        result.searchType = "search_track"
        return result
    }

    public func getAlbumsForArtist(_ artist: String, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        var result = try getMusicLibraryInformation(
            searchType: "album_artists",
            fullAlbumArtURI: fullAlbumArtURI,
            subcategories: [artist],
            completeResult: true
        )
        // Use type membership rather than exact-type equality. This preserves album
        // subclasses such as DidlMusicAlbumCompilation (upstream regression test).
        result.items = result.items.filter { $0 is DidlMusicAlbum }
        result.searchType = "albums_for_artist"
        result.numberReturned = String(result.items.count)
        result.totalMatches = String(result.items.count)
        return result
    }

    public func getTracksForAlbum(artist: String, album: String, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        var result = try getMusicLibraryInformation(
            searchType: "album_artists",
            fullAlbumArtURI: fullAlbumArtURI,
            subcategories: [artist, album],
            completeResult: true
        )
        result.searchType = "tracks_for_album"
        return result
    }

    public var albumArtistDisplayOption: String {
        get throws { try contentDirectory.sendCommand("GetAlbumArtistDisplayOption")["AlbumArtistDisplayOption"] ?? "" }
    }

    public func listLibraryShares() throws -> [String] {
        // This upstream method intentionally performs one simple Browse for at most 100
        // shares rather than routing through the general complete-result machinery.
        let response = try contentDirectory.sendCommand("Browse", arguments: [
            ("ObjectID", "S:"), ("BrowseFlag", "BrowseDirectChildren"), ("Filter", "*"),
            ("StartingIndex", "0"), ("RequestedCount", "100"), ("SortCriteria", "")
        ])
        guard response["TotalMatches"] != "0" else { return [] }
        return try fromDIDLString(response["Result"] ?? "").map(\.title)
    }

    @discardableResult
    public func deleteLibraryShare(_ shareName: String) throws -> [String: String] {
        try contentDirectory.sendCommand("DestroyObject", arguments: [("ObjectID", "S:\(shareName)")])
    }
}
