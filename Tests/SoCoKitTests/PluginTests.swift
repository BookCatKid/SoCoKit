import Foundation
import Testing
@testable import SoCoKit

private func avTransportSCPDForQueueAndPlayback() -> String {
    """
    <scpd xmlns="urn:schemas-upnp-org:service-1-0">
      <actionList>
        <action><name>AddURIToQueue</name><argumentList>
          <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
          <argument><name>EnqueuedURI</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_URI</relatedStateVariable></argument>
          <argument><name>EnqueuedURIMetaData</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_MetaData</relatedStateVariable></argument>
          <argument><name>DesiredFirstTrackNumberEnqueued</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_TrackNumber</relatedStateVariable></argument>
          <argument><name>EnqueueAsNext</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Boolean</relatedStateVariable></argument>
          <argument><name>FirstTrackNumberEnqueued</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_TrackNumber</relatedStateVariable></argument>
        </argumentList></action>
      </actionList>
      <serviceStateTable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_InstanceID</name><dataType>ui4</dataType></stateVariable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_URI</name><dataType>string</dataType></stateVariable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_MetaData</name><dataType>string</dataType></stateVariable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_TrackNumber</name><dataType>ui4</dataType></stateVariable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_Boolean</name><dataType>boolean</dataType></stateVariable>
      </serviceStateTable>
    </scpd>
    """
}

private func addQueueResponse(_ position: Int) -> String {
    """
    <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><FirstTrackNumberEnqueued>\(position)</FirstTrackNumberEnqueued></u:AddURIToQueueResponse></s:Body></s:Envelope>
    """
}

@Suite(.serialized) struct ShareLinkPluginTests {
    @Test func canonicalAndExtractionRulesMatchUpstream() throws {
        let spotify = SpotifyShare()
        #expect(spotify.canonicalURI("spotify:track:abc123") == "spotify:track:abc123")
        #expect(spotify.canonicalURI("https://open.spotify.com/album/6wiUBliPe76YAVpNEdidpY") == "spotify:album:6wiUBliPe76YAVpNEdidpY")
        #expect(spotify.extract("spotify:show:xyz")?.1 == "spotify%3ashow%3axyz")
        #expect(TIDALShare().extract("https://tidal.com/browse/album/157273956")?.1 == "album%2f157273956")
        #expect(DeezerShare().extract("https://www.deezer.com/track/123")?.1 == "track-123")
        #expect(AppleMusicShare().canonicalURI("https://music.apple.com/dk/album/black-velvet/217502930?i=217503142") == "song:217503142")
        #expect(AppleMusicShare().canonicalURI("https://music.apple.com/de/playlist/unnamed-playlist/pl.u-rR2PCrLdLJk") == "playlist:pl.u-rR2PCrLdLJk")
        #expect(spotify.canonicalURI("https://example.com/not-music") == nil)
    }

    @Test func shareLinkQueueRequestContainsExactMagicMetadata() throws {
        let http = MockHTTPClient()
        http.enqueue(text: addQueueResponse(7))
        let soco = try SoCo("10.0.0.40", httpClient: http)
        let plugin = ShareLinkPlugin(soco)
        let result = try plugin.addShareLinkToQueue("spotify:album:abc123", position: 4, asNext: true, dcTitle: "A & B")
        #expect(result == 7)
        let body = String(data: http.requests.last!.body!, encoding: .utf8)!
        #expect(body.contains("x-rincon-cpcontainer:1004206cspotify%3aalbum%3aabc123"))
        #expect(body.contains("00040000spotify%3aalbum%3aabc123"))
        #expect(body.contains("A &amp;amp; B")) // metadata is XML escaped once again by SOAP wrapping
        #expect(body.contains("SA_RINCON2311_X_#Svc2311-0-Token"))
        #expect(body.contains("<DesiredFirstTrackNumberEnqueued>4</DesiredFirstTrackNumberEnqueued>"))
        #expect(body.contains("<EnqueueAsNext>1</EnqueueAsNext>"))
    }
}

private struct FakePlexMedia: PlexMediaProviding {
    let plexMachineIdentifier: String
    let plexLibrarySectionID: String?
    let plexType: String
    let plexRatingKey: String
    let plexTitle: String
    let plexIsAudio: Bool
    let plexParentRatingKey: String?
}

@Suite(.serialized) struct PlexPluginTests {
    @Test func queueMetadataAndURIUsePlexDescriptor() throws {
        MusicService.resetDescriptorCache()
        MusicService.descriptorLoader = { _ in
            """
            <Services><Service Id="40" Name="Plex" Uri="https://example.invalid" SecureUri="https://example.invalid" ContainerType="MService" Capabilities="0"><Policy Auth="Anonymous" PollInterval="30"/></Service></Services>
            """
        }
        defer { MusicService.resetDescriptorCache() }
        let http = MockHTTPClient()
        http.enqueue(text: addQueueResponse(12))
        let soco = try SoCo("10.0.0.41", httpClient: http)
        let media = FakePlexMedia(plexMachineIdentifier: "machine", plexLibrarySectionID: "7", plexType: "track", plexRatingKey: "99", plexTitle: "Track & One", plexIsAudio: true, plexParentRatingKey: "55")
        let position = try PlexPlugin(soco).addToQueue(media, position: 3, asNext: true)
        #expect(position == 12)
        let body = String(data: http.requests.last!.body!, encoding: .utf8)!
        #expect(body.contains("sid=40"))
        #expect(body.contains("flags=8300"))
        #expect(body.contains("10036020machine%3A7%3A99%3Atrack"))
        #expect(body.contains("1004206cmachine%3A7%3A55%3Aalbum"))
        #expect(body.contains("SA_RINCON10247_X_#Svc10247-0-Token"))
    }

    @Test func videoPlaylistIsRejected() throws {
        MusicService.resetDescriptorCache()
        MusicService.descriptorLoader = { _ in "<Services><Service Id=\"40\" Name=\"Plex\" Uri=\"x\" SecureUri=\"x\" ContainerType=\"MService\" Capabilities=\"0\"><Policy Auth=\"Anonymous\" PollInterval=\"30\"/></Service></Services>" }
        defer { MusicService.resetDescriptorCache() }
        let soco = try SoCo("10.0.0.42", httpClient: MockHTTPClient())
        let media = FakePlexMedia(plexMachineIdentifier: "m", plexLibrarySectionID: nil, plexType: "playlist", plexRatingKey: "1", plexTitle: "Video", plexIsAudio: false, plexParentRatingKey: nil)
        #expect(throws: SoCoError.self) { try PlexPlugin(soco).addToQueue(media) }
    }
}

@Suite(.serialized) struct WimpPluginTests {
    @Test func staticIDAndURIConversionsMatchLegacyPlugin() throws {
        let soco = try SoCo("10.0.0.43", httpClient: MockHTTPClient())
        let wimp = Wimp(soco, username: "user", serialNumber: "serial", sessionID: "session")
        #expect(wimp.name == "Wimp Plugin for user")
        #expect(wimp.descriptionText == "SA_RINCON5127_user")
        #expect(wimp.idToExtendedID("42", itemClass: MSTrack.self) == "0003002042")
        #expect(wimp.idToExtendedID("42", itemClass: MSFavorites.self) == nil)
        #expect(wimp.formURI(["item_id":"trackid", "service_id":20, "mime_type":"audio/aac"], itemClass: MSTrack.self) == "x-sonos-http:trackid.mp4?sid=20&flags=32")
    }

    @Test func soapBodiesContainCredentialsAndEscapedSearch() throws {
        let soco = try SoCo("10.0.0.44", httpClient: MockHTTPClient())
        let wimp = Wimp(soco, username: "u", serialNumber: "SER&1", sessionID: "S<2")
        let body = wimp.searchBody(searchType: "tracksearch", searchTerm: "A & B", start: 2, maxItems: 3)
        #expect(body.contains("<sessionId>S&lt;2</sessionId>"))
        #expect(body.contains("<deviceId>SER&amp;1</deviceId>"))
        #expect(body.contains("<term>A &amp; B</term>"))
        #expect(body.contains("<index>2</index><count>3</count>"))
    }

    @Test func searchAndBrowseParseLegacyItems() throws {
        let http = MockHTTPClient()
        http.enqueue(text: """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><searchResponse xmlns="http://www.sonos.com/Services/1.1"><searchResult><index>0</index><count>1</count><total>1</total><mediaMetadata><id>abc</id><itemType>track</itemType><title>Hello</title><mimeType>audio/aac</mimeType><canPlay>true</canPlay></mediaMetadata></searchResult></searchResponse></s:Body></s:Envelope>
        """)
        http.enqueue(text: """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><getMetadataResponse xmlns="http://www.sonos.com/Services/1.1"><getMetadataResult><index>0</index><count>1</count><total>1</total><mediaCollection><id>al</id><itemType>album</itemType><title>Album</title><artist>A</artist><canPlay>true</canPlay></mediaCollection></getMetadataResult></getMetadataResponse></s:Body></s:Envelope>
        """)
        let soco = try SoCo("10.0.0.45", httpClient: http)
        let wimp = Wimp(soco, username: "u", serialNumber: "serial", sessionID: "session", httpClient: http)
        let tracks = try wimp.getTracks("Hello")
        #expect(tracks.items.count == 1)
        #expect((tracks.items.first as? MSTrack)?.uri == "x-sonos-http:abc.mp4?sid=20&flags=32")
        let browse = try wimp.browse()
        #expect(browse.items.count == 1)
        #expect(browse.items.first is MSAlbum)
        #expect(http.requests[0].headers["SOAPACTION"] == "\"http://www.sonos.com/Services/1.1#search\"")
    }

    @Test func retriesTimeoutsAndMapsFault() throws {
        let http = MockHTTPClient()
        http.enqueue(error: SoCoError.timeout)
        http.enqueue(text: """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><searchResponse xmlns="http://www.sonos.com/Services/1.1"><searchResult><index>0</index><count>0</count><total>0</total></searchResult></searchResponse></s:Body></s:Envelope>
        """)
        http.enqueue(statusCode: 500, text: """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>ItemNotFound</faultstring></s:Fault></s:Body></s:Envelope>
        """)
        let soco = try SoCo("10.0.0.46", httpClient: http)
        let wimp = Wimp(soco, username: "u", serialNumber: "s", sessionID: "x", retries: 2, httpClient: http)
        #expect((try wimp.getTracks("x")).items.isEmpty)
        #expect(http.requests.count == 2)
        do {
            _ = try wimp.getTracks("x")
            Issue.record("Expected UPnP fault")
        } catch let SoCoError.upnp(code, description, _) {
            #expect(code == "20001")
            #expect(description == "ItemNotFound")
        }
    }
}
