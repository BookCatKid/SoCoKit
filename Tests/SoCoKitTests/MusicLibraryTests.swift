import Foundation
import Testing
@testable import SoCoKit

private func contentDirectoryResponse(action: String, fields: [(String, String)]) -> String {
    let body = fields.map { "<\($0.0)>\(xmlEscape($0.1))</\($0.0)>" }.joined()
    return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:\(action)Response xmlns:u=\"urn:schemas-upnp-org:service:ContentDirectory:1\">\(body)</u:\(action)Response></s:Body></s:Envelope>"
}

private let emptyDIDL = "<DIDL-Lite xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\"></DIDL-Lite>"

private func browseResponse(_ didl: String, count: Int) -> String {
    contentDirectoryResponse(action: "Browse", fields: [
        ("Result", didl), ("NumberReturned", String(count)), ("TotalMatches", String(count)), ("UpdateID", "0")
    ])
}

private let noSuchObject701 = """
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>701</errorCode></UPnPError></detail></s:Fault></s:Body></s:Envelope>
"""

private func requestBody(_ http: MockHTTPClient, _ index: Int = 0) -> String {
    String(data: http.requests[index].body ?? Data(), encoding: .utf8) ?? ""
}

@Suite(.serialized) struct MusicLibraryTests {
    @Test func searchTrackUsesAlbumArtistHierarchyAndCompleteSearch() throws {
        let http = MockHTTPClient()
        http.enqueue(text: browseResponse(emptyDIDL, count: 0))
        let soco = try SoCo("10.0.0.61", httpClient: http)
        let result = try soco.musicLibrary.searchTrack(artist: "artist", album: "album", track: "track")
        #expect(result.items.isEmpty)
        #expect(result.searchType == "search_track")
        let body = requestBody(http)
        #expect(body.contains("<ObjectID>A:ALBUMARTIST/artist/album:track</ObjectID>"))
        #expect(body.contains("<RequestedCount>100000</RequestedCount>"))
    }

    @Test func searchTrackArtistOnlyKeepsTrailingSlash() throws {
        let http = MockHTTPClient()
        http.enqueue(text: browseResponse(emptyDIDL, count: 0))
        let soco = try SoCo("10.0.0.62", httpClient: http)
        _ = try soco.musicLibrary.searchTrack(artist: "The Artist")
        #expect(requestBody(http).contains("<ObjectID>A:ALBUMARTIST/The%20Artist/</ObjectID>"))
    }

    @Test func noSuchObjectBecomesEmptySearchResult() throws {
        let http = MockHTTPClient()
        http.enqueue(statusCode: 500, text: noSuchObject701)
        let soco = try SoCo("10.0.0.63", httpClient: http)
        let result = try soco.musicLibrary.searchTrack(artist: "missing")
        #expect(result.items.isEmpty)
        #expect(result.totalMatches == "0")
    }

    @Test func parsesAlbumsTracksAndQualifiesArtwork() throws {
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><container id="A:ALBUMARTIST/The%20Artist/First%20Album" parentID="A:ALBUMARTIST/The%20Artist" restricted="true"><dc:title>First Album</dc:title><upnp:class>object.container.album.musicAlbum</upnp:class><upnp:albumArtURI>/getaa?x=1</upnp:albumArtURI></container></DIDL-Lite>
        """
        let http = MockHTTPClient()
        http.enqueue(text: browseResponse(didl, count: 1))
        let soco = try SoCo("10.0.0.64", httpClient: http)
        let result = try soco.musicLibrary.searchTrack(artist: "The Artist", fullAlbumArtURI: true)
        #expect(result.items.count == 1)
        #expect(result.items[0].title == "First Album")
        #expect(result.items[0].albumArtURI == "http://10.0.0.64:1400/getaa?x=1")
    }

    @Test func getAlbumsForArtistIncludesAlbumSubclassesOnly() throws {
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><container id="A:1" parentID="A:" restricted="true"><dc:title>Album</dc:title><upnp:class>object.container.album.musicAlbum</upnp:class></container><container id="A:2" parentID="A:" restricted="true"><dc:title>Compilation</dc:title><upnp:class>object.container.album.musicAlbum.compilation</upnp:class></container><item id="Q:0/1" parentID="Q:0" restricted="true"><dc:title>Track</dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class></item></DIDL-Lite>
        """
        let http = MockHTTPClient()
        http.enqueue(text: browseResponse(didl, count: 3))
        let soco = try SoCo("10.0.0.65", httpClient: http)
        let result = try soco.musicLibrary.getAlbumsForArtist("Some Artist")
        #expect(result.items.count == 2)
        #expect(result.items[0] is DidlMusicAlbum)
        #expect(result.items[1] is DidlMusicAlbumCompilation)
        #expect(result.searchType == "albums_for_artist")
        #expect(result.numberReturned == "2")
    }

    @Test func libraryUpdatingAndRefresh() throws {
        let http = MockHTTPClient()
        http.enqueue(text: contentDirectoryResponse(action: "GetShareIndexInProgress", fields: [("IsIndexing", "0")]))
        http.enqueue(text: contentDirectoryResponse(action: "GetShareIndexInProgress", fields: [("IsIndexing", "1")]))
        http.enqueue(text: contentDirectoryResponse(action: "RefreshShareIndex", fields: []))
        let soco = try SoCo("10.0.0.66", httpClient: http)
        #expect(try soco.musicLibrary.libraryUpdating == false)
        #expect(try soco.musicLibrary.libraryUpdating == true)
        _ = try soco.musicLibrary.startLibraryUpdate()
        #expect(requestBody(http, 2).contains("<AlbumArtistDisplayOption></AlbumArtistDisplayOption>"))
    }

    @Test func listAndDeleteLibraryShares() throws {
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><container id="S://host/share" parentID="S:" restricted="true"><dc:title>//host/share</dc:title><upnp:class>object.container</upnp:class></container><container id="S://host/two" parentID="S:" restricted="true"><dc:title>//host/two</dc:title><upnp:class>object.container</upnp:class></container></DIDL-Lite>
        """
        let http = MockHTTPClient()
        http.enqueue(text: browseResponse(didl, count: 2))
        http.enqueue(text: contentDirectoryResponse(action: "DestroyObject", fields: []))
        let soco = try SoCo("10.0.0.67", httpClient: http)
        #expect(try soco.musicLibrary.listLibraryShares() == ["//host/share", "//host/two"])
        #expect(requestBody(http).contains("<RequestedCount>100</RequestedCount>"))
        _ = try soco.musicLibrary.deleteLibraryShare("//host/share")
        #expect(requestBody(http, 1).contains("<ObjectID>S://host/share</ObjectID>"))
    }

    @Test func browseByIDStringDoesNotPrefixImportedPlaylist() throws {
        let http = MockHTTPClient()
        http.enqueue(text: browseResponse(emptyDIDL, count: 0))
        let soco = try SoCo("10.0.0.68", httpClient: http)
        _ = try soco.musicLibrary.browseByIDString(searchType: "playlists", idString: "A:PLAYLISTS/foo")
        #expect(requestBody(http).contains("<ObjectID>A:PLAYLISTS/foo</ObjectID>"))
    }
}
