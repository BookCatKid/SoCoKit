import Foundation

public struct Favorite: Sendable, Equatable {
    public var title: String
    public var uri: String
    public var metadata: String?
    public init(title: String, uri: String, metadata: String? = nil) {
        self.title = title; self.uri = uri; self.metadata = metadata
    }
}

public struct FavoriteResult: Sendable {
    public var total: Int
    public var returned: Int { favorites.count }
    public var favorites: [Favorite]
}

public struct PlaylistReorderResult: Sendable, Equatable {
    public var change: Int
    public var updateID: Int
    public var length: Int
}

extension SoCo {
    public func getQueue(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false) throws -> SoCoQueue {
        let response = try contentDirectory.sendCommand("Browse", arguments: [
            ("ObjectID", "Q:0"), ("BrowseFlag", "BrowseDirectChildren"), ("Filter", "*"),
            ("StartingIndex", String(start)), ("RequestedCount", String(maxItems)), ("SortCriteria", "")
        ])
        let items = try fromDIDLString(response["Result"] ?? "")
        if fullAlbumArtURI {
            for item in items where item.albumArtURI != nil { item.albumArtURI = musicLibrary.buildAlbumArtFullURI(item.albumArtURI!) }
        }
        return SoCoQueue(items: items, numberReturned: response["NumberReturned"] ?? "0", totalMatches: response["TotalMatches"] ?? "0", updateID: response["UpdateID"] ?? "0")
    }

    public var queueSize: Int? {
        get throws {
            let response = try contentDirectory.sendCommand("Browse", arguments: [
                ("ObjectID", "Q:0"), ("BrowseFlag", "BrowseMetadata"), ("Filter", "*"),
                ("StartingIndex", "0"), ("RequestedCount", "1"), ("SortCriteria", "")
            ])
            guard let xml = response["Result"], !xml.isEmpty else { return nil }
            let tree = try XMLTree(xml)
            let container = tree.root?.descendants(named: "container").first
            return container?.attribute("childCount").flatMap(Int.init)
        }
    }

    public func getSonosPlaylists(start: Int = 0, maxItems: Int = 100, fullAlbumArtURI: Bool = false) throws -> SearchResult {
        try musicLibrary.getSonosPlaylists(start: start, maxItems: maxItems, fullAlbumArtURI: fullAlbumArtURI)
    }

    @discardableResult
    public func addURIToQueue(_ uri: String, position: Int = 0, asNext: Bool = false) throws -> Int {
        let item = try DidlObject(title: "", parentID: "", itemID: "", resources: [DidlResource(uri: uri, protocolInfo: "x-rincon-playlist:*:*:*")])
        return try addToQueue(item, position: position, asNext: asNext)
    }

    @discardableResult
    public func addToQueue(_ item: DidlObject, position: Int = 0, asNext: Bool = false) throws -> Int {
        try requireCoordinator()
        guard let uri = item.resources.first?.uri else { throw SoCoError.invalidArgument("Queueable item has no resources") }
        let metadata = try toDIDLString([item])
        let response = try avTransport.sendCommand("AddURIToQueue", arguments: [
            ("InstanceID", "0"), ("EnqueuedURI", uri), ("EnqueuedURIMetaData", metadata),
            ("DesiredFirstTrackNumberEnqueued", String(position)), ("EnqueueAsNext", asNext ? "1" : "0")
        ])
        return Int(response["FirstTrackNumberEnqueued"] ?? "0") ?? 0
    }

    /// Add a modern SMAPI music-service item directly to the Sonos queue.
    ///
    /// Python SoCo's `add_to_queue` is intentionally duck-typed and accepts both
    /// `DidlObject` and `music_services.data_structures.MusicServiceItem`. Swift
    /// needs an explicit overload to preserve that public behavior.
    @discardableResult
    public func addToQueue(_ item: SMAPI.MusicServiceItem, position: Int = 0, asNext: Bool = false) throws -> Int {
        try requireCoordinator()
        guard let uri = item.resources.first?.uri else {
            throw SoCoError.invalidArgument("Queueable item has no resources")
        }
        let response = try avTransport.sendCommand("AddURIToQueue", arguments: [
            ("InstanceID", "0"), ("EnqueuedURI", uri), ("EnqueuedURIMetaData", try toDIDLString(item)),
            ("DesiredFirstTrackNumberEnqueued", String(position)), ("EnqueueAsNext", asNext ? "1" : "0")
        ])
        return Int(response["FirstTrackNumberEnqueued"] ?? "0") ?? 0
    }

    public func addMultipleToQueue(_ items: [DidlObject], container: DidlObject? = nil) throws {
        let containerURI = container?.resources.first?.uri ?? ""
        let containerMetadata = try container.map { try toDIDLString([$0]) } ?? ""
        for start in stride(from: 0, to: items.count, by: 16) {
            let chunk = Array(items[start..<min(start + 16, items.count)])
            let uris = try chunk.map { item -> String in
                guard let uri = item.resources.first?.uri else { throw SoCoError.invalidArgument("Queueable item has no resources") }
                return uri
            }.joined(separator: " ")
            let metadata = try chunk.map { try toDIDLString([$0]) }.joined(separator: " ")
            _ = try avTransport.sendCommand("AddMultipleURIsToQueue", arguments: [
                ("InstanceID", "0"), ("UpdateID", "0"), ("NumberOfURIs", String(chunk.count)),
                ("EnqueuedURIs", uris), ("EnqueuedURIsMetaData", metadata), ("ContainerURI", containerURI),
                ("ContainerMetaData", containerMetadata), ("DesiredFirstTrackNumberEnqueued", "0"), ("EnqueueAsNext", "0")
            ])
        }
    }


    /// Add multiple modern SMAPI items to the queue in the same 16-item chunks
    /// used for DIDL objects.
    ///
    /// Python SoCo's `add_multiple_to_queue` is duck-typed: despite documenting
    /// the optional container as a `DidlObject`, any queueable object exposing
    /// `resources` and supported by `to_didl_string` works. This overload keeps
    /// that behavior available for modern music-service browse/search results.
    public func addMultipleToQueue(
        _ items: [SMAPI.MusicServiceItem],
        container: SMAPI.MusicServiceItem? = nil
    ) throws {
        let containerURI = container?.resources.first?.uri ?? ""
        let containerMetadata = try container.map { try toDIDLString($0) } ?? ""
        for start in stride(from: 0, to: items.count, by: 16) {
            let chunk = Array(items[start..<min(start + 16, items.count)])
            let uris = try chunk.map { item -> String in
                guard let uri = item.resources.first?.uri else {
                    throw SoCoError.invalidArgument("Queueable item has no resources")
                }
                return uri
            }.joined(separator: " ")
            let metadata = try chunk.map { try toDIDLString($0) }.joined(separator: " ")
            _ = try avTransport.sendCommand("AddMultipleURIsToQueue", arguments: [
                ("InstanceID", "0"), ("UpdateID", "0"), ("NumberOfURIs", String(chunk.count)),
                ("EnqueuedURIs", uris), ("EnqueuedURIsMetaData", metadata), ("ContainerURI", containerURI),
                ("ContainerMetaData", containerMetadata), ("DesiredFirstTrackNumberEnqueued", "0"), ("EnqueueAsNext", "0")
            ])
        }
    }

    public func removeFromQueue(index: Int) throws {
        try requireCoordinator()
        _ = try avTransport.sendCommand("RemoveTrackFromQueue", arguments: [("InstanceID", "0"), ("ObjectID", "Q:0/\(index + 1)"), ("UpdateID", "0")])
    }

    public func clearQueue() throws {
        try requireCoordinator()
        _ = try avTransport.sendCommand("RemoveAllTracksFromQueue", arguments: [("InstanceID", "0")])
    }

    private func legacyFavorites(objectID: String, start: Int, maxItems: Int) throws -> FavoriteResult {
        let response = try contentDirectory.sendCommand("Browse", arguments: [
            ("ObjectID", objectID), ("BrowseFlag", "BrowseDirectChildren"), ("Filter", "*"),
            ("StartingIndex", String(start)), ("RequestedCount", String(maxItems)), ("SortCriteria", "")
        ])
        let objects = try fromDIDLString(response["Result"] ?? "")
        let favorites = objects.compactMap { object -> Favorite? in
            guard let uri = object.resources.first?.uri else { return nil }
            return Favorite(title: object.title, uri: uri, metadata: object.resourceMetadata)
        }
        return FavoriteResult(total: Int(response["TotalMatches"] ?? "0") ?? 0, favorites: favorites)
    }

    public func getFavoriteRadioShows(start: Int = 0, maxItems: Int = 100) throws -> FavoriteResult { try legacyFavorites(objectID: "R:0/1", start: start, maxItems: maxItems) }
    public func getFavoriteRadioStations(start: Int = 0, maxItems: Int = 100) throws -> FavoriteResult { try legacyFavorites(objectID: "R:0/0", start: start, maxItems: maxItems) }
    public func getSonosFavorites(start: Int = 0, maxItems: Int = 100) throws -> FavoriteResult { try legacyFavorites(objectID: "FV:2", start: start, maxItems: maxItems) }

    public func createSonosPlaylist(title: String) throws -> DidlPlaylistContainer {
        let response = try avTransport.sendCommand("CreateSavedQueue", arguments: [("InstanceID", "0"), ("Title", title), ("EnqueuedURI", ""), ("EnqueuedURIMetaData", "")])
        return try playlistFromResponse(response, title: title)
    }

    public func createSonosPlaylistFromQueue(title: String) throws -> DidlPlaylistContainer {
        try requireCoordinator()
        let response = try avTransport.sendCommand("SaveQueue", arguments: [("InstanceID", "0"), ("Title", title), ("ObjectID", "")])
        return try playlistFromResponse(response, title: title)
    }

    private func playlistFromResponse(_ response: [String: String], title: String) throws -> DidlPlaylistContainer {
        guard let itemID = response["AssignedObjectID"] else { throw SoCoError.unknown("Sonos did not return AssignedObjectID") }
        let objectNumber = itemID.split(separator: ":").dropFirst().first.map(String.init) ?? itemID
        return try DidlPlaylistContainer(title: title, parentID: "SQ:", itemID: itemID, resources: [DidlResource(uri: "file:///jffs/settings/savedqueues.rsq#\(objectNumber)", protocolInfo: "x-rincon-playlist:*:*:*")])
    }

    public func removeSonosPlaylist(_ playlist: DidlPlaylistContainer) throws { _ = try contentDirectory.sendCommand("DestroyObject", arguments: [("ObjectID", playlist.itemID)]) }
    public func removeSonosPlaylist(itemID: String) throws { _ = try contentDirectory.sendCommand("DestroyObject", arguments: [("ObjectID", itemID)]) }

    public func addItemToSonosPlaylist(_ item: DidlObject, playlist: DidlPlaylistContainer) throws {
        let updateID = try musicLibrary.musicLibSearch(search: playlist.itemID, start: 0, maxItems: 1).response["UpdateID"] ?? "0"
        guard let uri = item.resources.first?.uri else { throw SoCoError.invalidArgument("Queueable item has no resources") }
        _ = try avTransport.sendCommand("AddURIToSavedQueue", arguments: [
            ("InstanceID", "0"), ("UpdateID", updateID), ("ObjectID", playlist.itemID), ("EnqueuedURI", uri),
            ("EnqueuedURIMetaData", try toDIDLString([item])), ("AddAtIndex", "4294967295")
        ])
    }

    public func setSleepTimer(seconds: Int?) throws {
        try requireCoordinator()
        guard seconds == nil || (0...86_399).contains(seconds!) else { throw SoCoError.invalidArgument("sleep timer must be 0...86399 seconds or nil") }
        let duration = seconds.map { formatTimeInterval(TimeInterval($0)) } ?? ""
        _ = try avTransport.sendCommand("ConfigureSleepTimer", arguments: [("InstanceID", "0"), ("NewSleepTimerDuration", duration)])
    }

    public func getSleepTimer() throws -> Int? {
        try requireCoordinator()
        let value = try avTransport.sendCommand("GetRemainingSleepTimerDuration", arguments: [("InstanceID", "0")])["RemainingSleepTimerDuration"] ?? ""
        return value.isEmpty ? nil : parseTimeInterval(value).map(Int.init)
    }

    /// Reorder and/or remove tracks in a Sonos playlist.
    ///
    /// The underlying Sonos call is unusual because it can move or delete
    /// tracks depending on `TrackList` and `NewPositionList`. When arrays are
    /// supplied, each pair is a discrete modification and later pairs must
    /// anticipate the playlist state produced by earlier pairs. This mirrors
    /// SoCo's list-input behavior.
    public func reorderSonosPlaylist(itemID: String, tracks: [Int], newPositions: [Int?], updateID initialUpdateID: Int = 0) throws -> PlaylistReorderResult {
        try requireCoordinator()
        guard tracks.count == newPositions.count else { throw SoCoError.invalidArgument("tracks and newPositions must have the same number of entries") }
        var updateID = try sonosPlaylistUpdateID(itemID: itemID, supplied: initialUpdateID)
        var change = 0
        var length = 0
        var madeRequest = false
        for (track, newPosition) in zip(tracks, newPositions) {
            let position = newPosition.map(String.init) ?? ""
            if String(track) == position { continue }
            let response = try reorderSavedQueueCommand(
                itemID: itemID,
                trackList: String(track),
                newPositionList: position,
                updateID: updateID
            )
            madeRequest = true
            change += Int(response["QueueLengthChange"] ?? "0") ?? 0
            updateID = Int(response["NewUpdateID"] ?? String(updateID)) ?? updateID
            length = Int(response["NewQueueLength"] ?? "0") ?? 0
        }
        if !madeRequest {
            // Python's implementation assumes at least one operation and leaves
            // `response` undefined for an all-no-op list. Swift returns a useful,
            // deterministic result instead of reproducing that accidental error.
            length = Int(try musicLibrary.musicLibSearch(search: itemID, start: 0, maxItems: 1).response["TotalMatches"] ?? "0") ?? 0
        }
        return PlaylistReorderResult(change: change, updateID: updateID, length: length)
    }

    /// Raw comma-list form of `ReorderTracksInSavedQueue`.
    ///
    /// SoCo deliberately performs no transformation on string inputs. This is
    /// important for operations such as clearing a playlist: sending
    /// `tracks="0,1,2"` and an empty `newPositions` removes the whole set in one
    /// operation, whereas deleting the same numeric indices sequentially would
    /// make the indices shift underneath later deletions.
    public func reorderSonosPlaylist(itemID: String, tracks: String, newPositions: String, updateID initialUpdateID: Int = 0) throws -> PlaylistReorderResult {
        try requireCoordinator()
        let updateID = try sonosPlaylistUpdateID(itemID: itemID, supplied: initialUpdateID)
        if tracks == newPositions {
            let count = Int(try musicLibrary.musicLibSearch(search: itemID, start: 0, maxItems: 1).response["TotalMatches"] ?? "0") ?? 0
            return PlaylistReorderResult(change: 0, updateID: updateID, length: count)
        }
        let response = try reorderSavedQueueCommand(
            itemID: itemID,
            trackList: tracks,
            newPositionList: newPositions,
            updateID: updateID
        )
        return PlaylistReorderResult(
            change: Int(response["QueueLengthChange"] ?? "0") ?? 0,
            updateID: Int(response["NewUpdateID"] ?? String(updateID)) ?? updateID,
            length: Int(response["NewQueueLength"] ?? "0") ?? 0
        )
    }

    /// Playlist-object overload matching Python SoCo's acceptance of either a
    /// `DidlPlaylistContainer` or its `item_id` string.
    public func reorderSonosPlaylist(_ playlist: DidlPlaylistContainer, tracks: [Int], newPositions: [Int?], updateID: Int = 0) throws -> PlaylistReorderResult {
        try reorderSonosPlaylist(itemID: playlist.itemID, tracks: tracks, newPositions: newPositions, updateID: updateID)
    }

    /// Raw comma-list playlist-object overload.
    public func reorderSonosPlaylist(_ playlist: DidlPlaylistContainer, tracks: String, newPositions: String, updateID: Int = 0) throws -> PlaylistReorderResult {
        try reorderSonosPlaylist(itemID: playlist.itemID, tracks: tracks, newPositions: newPositions, updateID: updateID)
    }

    private func sonosPlaylistUpdateID(itemID: String, supplied: Int) throws -> Int {
        if supplied != 0 { return supplied }
        return try musicLibrary.musicLibSearch(search: itemID, start: 0, maxItems: 1).metadata.updateID
    }

    private func reorderSavedQueueCommand(itemID: String, trackList: String, newPositionList: String, updateID: Int) throws -> [String: String] {
        try avTransport.sendCommand("ReorderTracksInSavedQueue", arguments: [
            ("InstanceID", "0"), ("ObjectID", itemID), ("UpdateID", String(updateID)),
            ("TrackList", trackList), ("NewPositionList", newPositionList)
        ])
    }

    public func clearSonosPlaylist(_ playlist: DidlPlaylistContainer, updateID: Int = 0) throws -> PlaylistReorderResult {
        let count = Int(try musicLibrary.browse(item: playlist).totalMatches) ?? 0
        guard count > 0 else { return PlaylistReorderResult(change: 0, updateID: updateID, length: 0) }
        let tracks = (0..<count).map(String.init).joined(separator: ",")
        return try reorderSonosPlaylist(playlist, tracks: tracks, newPositions: "", updateID: updateID)
    }

    /// Clear a playlist addressed by item ID, resolving it to a playlist first
    /// as Python SoCo does.
    public func clearSonosPlaylist(itemID: String, updateID: Int = 0) throws -> PlaylistReorderResult {
        let playlist = try getSonosPlaylistByAttribute("item_id", matching: itemID)
        return try clearSonosPlaylist(playlist, updateID: updateID)
    }

    public func moveInSonosPlaylist(_ playlist: DidlPlaylistContainer, track: Int, newPosition: Int, updateID: Int = 0) throws -> PlaylistReorderResult {
        try reorderSonosPlaylist(itemID: playlist.itemID, tracks: [track], newPositions: [newPosition], updateID: updateID)
    }

    public func moveInSonosPlaylist(itemID: String, track: Int, newPosition: Int, updateID: Int = 0) throws -> PlaylistReorderResult {
        try reorderSonosPlaylist(itemID: itemID, tracks: [track], newPositions: [newPosition], updateID: updateID)
    }

    public func removeFromSonosPlaylist(_ playlist: DidlPlaylistContainer, track: Int, updateID: Int = 0) throws -> PlaylistReorderResult {
        try reorderSonosPlaylist(itemID: playlist.itemID, tracks: [track], newPositions: [nil], updateID: updateID)
    }

    public func removeFromSonosPlaylist(itemID: String, track: Int, updateID: Int = 0) throws -> PlaylistReorderResult {
        try reorderSonosPlaylist(itemID: itemID, tracks: [track], newPositions: [nil], updateID: updateID)
    }

    public func getSonosPlaylist(title: String) throws -> DidlPlaylistContainer? {
        try getSonosPlaylists(start: 0, maxItems: 1000).items.compactMap { $0 as? DidlPlaylistContainer }.first { $0.title == title }
    }

    public func getSonosPlaylist(itemID: String) throws -> DidlPlaylistContainer? {
        try getSonosPlaylists(start: 0, maxItems: 1000).items.compactMap { $0 as? DidlPlaylistContainer }.first { $0.itemID == itemID }
    }

    /// Return the first Sonos playlist matching the indicated attribute.
    ///
    /// Python's `get_sonos_playlist_by_attr` uses `getattr` and can therefore
    /// accept an arbitrary attribute name. Swift's model is statically typed;
    /// the two useful attributes documented by SoCo (`title` and `item_id`) are
    /// accepted explicitly, and unknown names fail instead of being silently
    /// ignored.
    public func getSonosPlaylistByAttribute(_ attribute: String, matching value: String) throws -> DidlPlaylistContainer {
        try requireCoordinator("getSonosPlaylistByAttribute")
        let playlists = try getSonosPlaylists(start: 0, maxItems: 1000).items.compactMap { $0 as? DidlPlaylistContainer }
        let match: DidlPlaylistContainer?
        switch attribute {
        case "title": match = playlists.first { $0.title == value }
        case "item_id", "itemID": match = playlists.first { $0.itemID == value }
        default: throw SoCoError.invalidArgument("DidlPlaylistContainer has no supported attribute '\(attribute)'")
        }
        guard let match else { throw SoCoError.invalidArgument("No match on \"\(attribute)\" for value \"\(value)\"") }
        return match
    }

    public func getBatteryInfo(timeout: TimeInterval = 3) throws -> [String: String] {
        let url = URL(string: "http://\(ipAddress):1400/status/batterystatus")!
        let response = try httpClient.request(method: "GET", url: url, headers: [:], body: nil, timeout: timeout)
        guard (200..<300).contains(response.statusCode) else { throw SoCoError.http(status: response.statusCode, body: response.text) }
        let tree = try XMLTree(response.text)
        let dataNodes = tree.root?.descendants(named: "Data") ?? []
        guard !dataNodes.isEmpty else { throw SoCoError.unsupported("This speaker does not report battery information") }
        var info: [String: String] = [:]
        for node in dataNodes { if let name = node.attribute("name") { info[name] = node.text } }
        return info
    }
}
