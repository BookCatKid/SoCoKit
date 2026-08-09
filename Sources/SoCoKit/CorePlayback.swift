import Foundation

public enum SoCoRepeatMode: String, Sendable { case off, all, one }
public enum SoCoMusicSource: String, Sendable { case none="NONE", library="LIBRARY", radio="RADIO", webFile="WEB_FILE", lineIn="LINE_IN", tv="TV", airPlay="AIRPLAY", spotifyConnect="SPOTIFY_CONNECT", unknown="UNKNOWN" }

public extension SoCo {
    static let playModes:[String:(shuffle:Bool,repeatMode:SoCoRepeatMode)] = [
        "NORMAL":(false,.off),"SHUFFLE_NOREPEAT":(true,.off),"SHUFFLE":(true,.all),"REPEAT_ALL":(false,.all),"SHUFFLE_REPEAT_ONE":(true,.one),"REPEAT_ONE":(false,.one)
    ]

    func playMode() throws -> String { try avTransport.sendCommand("GetTransportSettings",arguments:[("InstanceID","0")])["PlayMode"] ?? "NORMAL" }
    func setPlayMode(_ value:String)throws { try requireCoordinator("playMode"); let mode=value.uppercased(); guard Self.playModes[mode] != nil else{throw SoCoError.invalidArgument("'\(mode)' is not a valid play mode")}; _=try avTransport.sendCommand("SetPlayMode",arguments:[("InstanceID","0"),("NewPlayMode",mode)]) }
    func shuffle()throws->Bool { Self.playModes[try playMode()]?.shuffle ?? false }
    func setShuffle(_ value:Bool)throws { let r=try repeatMode(); let target=Self.playModes.first{$0.value.shuffle==value && $0.value.repeatMode==r}?.key ?? "NORMAL"; try setPlayMode(target) }
    func repeatMode()throws->SoCoRepeatMode { Self.playModes[try playMode()]?.repeatMode ?? .off }
    func setRepeatMode(_ value:SoCoRepeatMode)throws { let s=try shuffle(); let target=Self.playModes.first{$0.value.shuffle==s && $0.value.repeatMode==value}?.key ?? "NORMAL"; try setPlayMode(target) }
    func crossFade()throws->Bool { try requireCoordinator("crossFade"); return (Int(try avTransport.sendCommand("GetCrossfadeMode",arguments:[("InstanceID","0")])["CrossfadeMode"] ?? "0") ?? 0) != 0 }
    func setCrossFade(_ value:Bool)throws { try requireCoordinator("crossFade"); _=try avTransport.sendCommand("SetCrossfadeMode",arguments:[("InstanceID","0"),("CrossfadeMode",value ? "1":"0")]) }
    @discardableResult func rampToVolume(_ volume:Int,rampType:String="SLEEP_TIMER_RAMP_TYPE")throws->Int { let r=try renderingControl.sendCommand("RampToVolume",arguments:[("InstanceID","0"),("Channel","Master"),("RampType",rampType),("DesiredVolume",String(volume)),("ResetVolumeAfter","False"),("ProgramURI","")]); return Int(r["RampTime"] ?? "") ?? 0 }
    @discardableResult func setRelativeVolume(_ adjustment:Int)throws->Int { let r=try renderingControl.sendCommand("SetRelativeVolume",arguments:[("InstanceID","0"),("Channel","Master"),("Adjustment",String(adjustment))]); return Int(r["NewVolume"] ?? "") ?? 0 }

    func playFromQueue(index:Int,start:Bool=true)throws { try requireCoordinator("playFromQueue"); if speakerInfo.isEmpty{_=try getSpeakerInfo()}; let uri="x-rincon-queue:\(try uid())#0"; _=try avTransport.sendCommand("SetAVTransportURI",arguments:[("InstanceID","0"),("CurrentURI",uri),("CurrentURIMetaData","")]); _=try avTransport.sendCommand("Seek",arguments:[("InstanceID","0"),("Unit","TRACK_NR"),("Target",String(index+1))]); if start{try play()} }
    func play(timeout:TimeInterval?=nil)throws { try requireCoordinator("play"); _=try avTransport.sendCommand("Play",arguments:[("InstanceID","0"),("Speed","1")],timeout:timeout) }
    @discardableResult func playURI(_ uri:String="",metadata:String="",title:String="",start:Bool=true,forceRadio:Bool=false,timeout:TimeInterval?=nil)throws->Bool {
        try requireCoordinator("playURI")
        var uri=uri, meta=metadata
        if meta.isEmpty && !title.isEmpty { meta="<DIDL-Lite xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:r=\"urn:schemas-rinconnetworks-com:metadata-1-0/\" xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\"><item id=\"R:0/0/0\" parentID=\"R:0/0\" restricted=\"true\"><dc:title>\(xmlEscape(title))</dc:title><upnp:class>object.item.audioItem.audioBroadcast</upnp:class><desc id=\"cdudn\" nameSpace=\"urn:schemas-rinconnetworks-com:metadata-1-0/\">SA_RINCON65031_</desc></item></DIDL-Lite>" }
        if forceRadio, let idx=uri.firstIndex(of:":") { uri="x-rincon-mp3radio"+uri[idx...] }
        _=try avTransport.sendCommand("SetAVTransportURI",arguments:[("InstanceID","0"),("CurrentURI",uri),("CurrentURIMetaData",meta)],timeout:timeout)
        if start { try play(timeout:timeout); return true }; return false
    }
    func pause()throws { try requireCoordinator("pause"); _=try avTransport.sendCommand("Pause",arguments:[("InstanceID","0"),("Speed","1")]) }
    func stop()throws { try requireCoordinator("stop"); _=try avTransport.sendCommand("Stop",arguments:[("InstanceID","0"),("Speed","1")]) }
    func endDirectControlSession()throws { try requireCoordinator("endDirectControlSession"); _=try avTransport.sendCommand("EndDirectControlSession",arguments:[("InstanceID","0")]) }
    func seek(position:String?=nil,track:Int?=nil)throws {
        try requireCoordinator("seek"); guard position != nil || track != nil else{throw SoCoError.invalidArgument("No position or track information given")}
        if let track{_=try avTransport.sendCommand("Seek",arguments:[("InstanceID","0"),("Unit","TRACK_NR"),("Target",String(track+1))])}
        if let position{let pattern=#"^[0-9][0-9]?:[0-9][0-9]:[0-9][0-9]$"#; guard position.range(of:pattern,options:.regularExpression) != nil else{throw SoCoError.invalidArgument("invalid timestamp, use HH:MM:SS format")}; _=try avTransport.sendCommand("Seek",arguments:[("InstanceID","0"),("Unit","REL_TIME"),("Target",position)])}
    }
    func next()throws { try requireCoordinator("next"); _=try avTransport.sendCommand("Next",arguments:[("InstanceID","0"),("Speed","1")]) }
    func previous()throws { try requireCoordinator("previous"); _=try avTransport.sendCommand("Previous",arguments:[("InstanceID","0"),("Speed","1")]) }

    static func musicSource(fromURI uri:String)->SoCoMusicSource {
        if uri.isEmpty{return .none}; if uri.hasPrefix("x-file-cifs:"){return .library}
        for prefix in ["x-rincon-mp3radio:","x-sonosapi-stream:","x-sonosapi-radio:","x-sonosapi-hls:","x-sonos-http:sonos","aac:","hls-radio:"] where uri.hasPrefix(prefix){return .radio}
        if uri.hasPrefix("http:") || uri.hasPrefix("https:"){return .webFile}; if uri.hasPrefix("x-rincon-stream:"){return .lineIn}; if uri.hasPrefix("x-sonos-htastream:"){return .tv}
        if uri.hasPrefix("x-sonos-vli:") && uri.contains(",airplay:"){return .airPlay}; if uri.hasPrefix("x-sonos-vli:") && uri.contains(",spotify:"){return .spotifyConnect}; return .unknown
    }
    func musicSource()throws->SoCoMusicSource { let r=try avTransport.sendCommand("GetPositionInfo",arguments:[("InstanceID","0"),("Channel","Master")]); return Self.musicSource(fromURI:r["TrackURI"] ?? "") }
    func isPlayingRadio()throws->Bool { try musicSource() == .radio }
    func isPlayingLineIn()throws->Bool { try musicSource() == .lineIn }
    func isPlayingTV()throws->Bool { try musicSource() == .tv }
    func switchToLineIn(source:SoCo?=nil)throws { let u=try (source ?? self).uid(); _=try avTransport.sendCommand("SetAVTransportURI",arguments:[("InstanceID","0"),("CurrentURI","x-rincon-stream:\(u)"),("CurrentURIMetaData","")]) }
    func switchToTV()throws { _=try avTransport.sendCommand("SetAVTransportURI",arguments:[("InstanceID","0"),("CurrentURI","x-sonos-htastream:\(try uid()):spdif"),("CurrentURIMetaData","")]) }

    func currentTrackInfo() throws -> [String:String] {
        let response = try avTransport.sendCommand(
            "GetPositionInfo",
            arguments: [("InstanceID", "0"), ("Channel", "Master")]
        )
        var track = [
            "title": "",
            "artist": "",
            "album": "",
            "album_art": "",
            "position": response["RelTime"] ?? "",
            "playlist_position": response["Track"] ?? "",
            "duration": response["TrackDuration"] ?? "",
            "uri": response["TrackURI"] ?? "",
            // Store the entire Metadata entry in the track, this can then be
            // used if needed by the client to restart a given URI.
            "metadata": response["TrackMetaData"] ?? "",
        ]

        guard let metadata = response["TrackMetaData"],
              !metadata.isEmpty,
              metadata != "NOT_IMPLEMENTED"
        else { return track }

        let tree = try XMLTree(metadata)
        let root = tree.root
        let metadataTitle = root?.descendants(named: "title").first?.text ?? ""

        func titleInURI(_ title: String?) -> Bool {
            guard let title, !title.isEmpty else { return false }
            let uri = track["uri"] ?? ""
            if Self.musicSource(fromURI: uri) == .library { return false }
            return uri.contains(title) || (uri.removingPercentEncoding ?? uri).contains(title)
        }

        // Duration seems to be '0:00:00' when listening to radio.
        if track["duration"] == "0:00:00" {
            let trackInfo = root?.descendants(named: "streamContent").first?.text ?? ""
            if trackInfo.contains("TYPE=SNG|") {
                // Examples from services:
                // Apple Music radio:
                // "TYPE=SNG|TITLE Couleurs|ARTIST M83|ALBUM Saturdays = Youth"
                // SiriusXM:
                // "BR P|TYPE=SNG|TITLE 7.15.17 LA|ARTIST Eagles|ALBUM "
                var tags: [String:String] = [:]
                for part in trackInfo.split(separator: "|", omittingEmptySubsequences: false).map(String.init) {
                    guard let space = part.firstIndex(of: " ") else { continue }
                    tags[String(part[..<space])] = String(part[part.index(after: space)...])
                }
                if let title = tags["TITLE"], !title.isEmpty { track["title"] = title }
                if let artist = tags["ARTIST"], !artist.isEmpty { track["artist"] = artist }
                if let album = tags["ALBUM"], !album.isEmpty { track["album"] = album }
            } else if let range = trackInfo.range(of: " - ") {
                track["artist"] = String(trackInfo[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                track["title"] = String(trackInfo[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                // Might find some kind of title anyway in metadata. Avoid using
                // URIs as the title; in that case the streamContent is better.
                track["title"] = titleInURI(metadataTitle) ? trackInfo : metadataTitle
            }
        }

        // Track may have been processed as radio, but metadata may still be incomplete.
        // This is necessary on Sonos Radio as it encodes metadata as a "regular" track.
        if track["artist"]?.isEmpty != false {
            let validMetadataTitle = titleInURI(metadataTitle) ? "" : metadataTitle
            track["title"] = track["title"]?.isEmpty == false ? track["title"] : validMetadataTitle
            track["artist"] = root?.descendants(named: "creator").first?.text ?? ""
            if track["album"]?.isEmpty != false {
                track["album"] = root?.descendants(named: "album").first?.text ?? ""
            }

            if let albumArt = root?.descendants(named: "albumArtURI").first?.text {
                track["album_art"] = musicLibrary.buildAlbumArtFullURI(albumArt)
            }
        }
        return track
    }
    func currentMediaInfo()throws->[String:String] {
        let r=try avTransport.sendCommand("GetMediaInfo",arguments:[("InstanceID","0")])
        var m=["uri":r["CurrentURI"] ?? "","channel":""]
        if let md=r["CurrentURIMetaData"],!md.isEmpty,let tree=try? XMLTree(md){
            let root=tree.root
            m["channel"]=root?.descendants(named:"title").first?.text ?? ""
            if let art=root?.descendants(named:"albumArtURI").first?.text, !art.isEmpty {
                m["album_art"]=musicLibrary.buildAlbumArtFullURI(art)
            }
        }
        return m
    }
    func currentTransportInfo()throws->[String:String] { let r=try avTransport.sendCommand("GetTransportInfo",arguments:[("InstanceID","0")]); return ["current_transport_state":r["CurrentTransportState"] ?? "","current_transport_status":r["CurrentTransportStatus"] ?? "","current_transport_speed":r["CurrentSpeed"] ?? ""] }
    func availableActions()throws->[String] { let a=try avTransport.sendCommand("GetCurrentTransportActions",arguments:[("InstanceID","0")])["Actions"] ?? ""; return a.components(separatedBy:", ").filter{!$0.isEmpty}.map{$0.components(separatedBy:"_").last ?? $0} }
}
