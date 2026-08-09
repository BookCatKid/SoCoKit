import Foundation

public extension SoCo {
    func bootSequenceNumber() throws -> Int { try zoneGroupState.poll(self); return _bootSeqnum ?? 0 }
    /// Python-compatible spelling of `boot_seqnum`.
    func bootSeqnum() throws -> Int { try bootSequenceNumber() }
    func playerName() throws -> String { try zoneGroupState.poll(self); return _playerName ?? "" }
    func setPlayerName(_ value:String) throws { _=try deviceProperties.sendCommand("SetZoneAttributes",arguments:[("DesiredZoneName",value),("DesiredIcon",""),("DesiredConfiguration","")]) }
    func uid() throws -> String { if let _uid{return _uid}; try zoneGroupState.poll(self); guard let _uid else{throw SoCoError.unknown("UID unavailable")}; return _uid }
    func householdID() throws -> String { if let _householdID{return _householdID}; let r=try deviceProperties.sendCommand("GetHouseholdID"); _householdID=r["CurrentHouseholdID"]; return _householdID ?? "" }
    func isVisible() throws -> Bool { try zoneGroupState.poll(self); return zoneGroupState.visibleZones.contains(self) }
    func isBridge() throws -> Bool { if let _isBridge{return _isBridge}; try zoneGroupState.poll(self); return _isBridge ?? false }
    func isCoordinator() throws -> Bool { try zoneGroupState.poll(self); return _isCoordinator ?? false }
    func isSatellite() throws -> Bool { try zoneGroupState.poll(self); return _isSatellite }
    func hasSatellites() throws -> Bool { try zoneGroupState.poll(self); return _hasSatellites }
    func channel() throws -> String? { try zoneGroupState.poll(self); guard let c=_channel else{return nil}; let u=Set(c.split(separator:",").map(String.init)); return u.count==1 ? u.first : c }
    func isSubwoofer() throws -> Bool { try channel()=="SW" }
    func hasSubwoofer() throws -> Bool {
        if speakerInfo.isEmpty { _=try getSpeakerInfo() }
        if speakerInfo["model_name"]?.lowercased().hasSuffix("sonos amp") == true { return true }
        try zoneGroupState.poll(self); return (_channelMap ?? _htSatChanMap)?.contains(":SW") == true
    }
    func isSoundbar() throws -> Bool {
        if let _isSoundbar{return _isSoundbar}; if speakerInfo.isEmpty{_=try getSpeakerInfo()}
        let model=speakerInfo["model_name"]?.lowercased() ?? ""; let names=["arc","arc sl","arc ultra","beam","playbase","playbar","ray","sonos amp"]
        _isSoundbar=names.contains{model.hasSuffix($0)}; return _isSoundbar ?? false
    }
    func isArcUltraSoundbar() throws -> Bool { if speakerInfo.isEmpty{_=try getSpeakerInfo()}; return speakerInfo["model_name"]?.lowercased().hasSuffix("arc ultra") == true }

    func allGroups() throws -> Set<ZoneGroup> { try zoneGroupState.poll(self); return zoneGroupState.groups }
    func group() throws -> ZoneGroup? { try allGroups().first{$0.members.contains(self)} }
    func allZones() throws -> Set<SoCo> { try zoneGroupState.poll(self); return zoneGroupState.allZones }
    func visibleZones() throws -> Set<SoCo> { try zoneGroupState.poll(self); return zoneGroupState.visibleZones }
    func partyMode() throws { guard let g=try group() else{return}; for z in try visibleZones() where !g.members.contains(z){try z.join(self)} }
    func join(_ master:SoCo, timeout:TimeInterval?=nil) throws { _=try avTransport.sendCommand("SetAVTransportURI",arguments:[("InstanceID","0"),("CurrentURI","x-rincon:\(try master.uid())"),("CurrentURIMetaData","")],timeout:timeout); zoneGroupState.clearCache() }
    func unjoin(timeout:TimeInterval?=nil) throws { _=try avTransport.sendCommand("BecomeCoordinatorOfStandaloneGroup",arguments:[("InstanceID","0")],timeout:timeout); zoneGroupState.clearCache() }
    func createStereoPair(right:SoCo)throws { let p="\(try uid()):LF,LF;\(try right.uid()):RF,RF"; _=try deviceProperties.sendCommand("AddBondedZones",arguments:[("ChannelMapSet",p)]) }
    func separateStereoPair()throws { _=try deviceProperties.sendCommand("RemoveBondedZones",arguments:[("ChannelMapSet",""),("KeepGrouped","0")]) }
    func addSatelliteSpeakers(leftRear:SoCo,rightRear:SoCo)throws { try requireSoundbar("addSatelliteSpeakers"); let map="\(try uid()):LF,RF;\(try rightRear.uid()):RR;\(try leftRear.uid()):LR"; _=try deviceProperties.sendCommand("AddHTSatellite",arguments:[("ChannelMapSet",map)]) }
    func separateSatelliteSpeakers()throws { try requireSoundbar("separateSatelliteSpeakers"); for satellite in try group()?.members.filter({(try? $0.isSatellite())==true}) ?? [] { _=try deviceProperties.sendCommand("RemoveHTSatellite",arguments:[("SatRoomUUID",try satellite.uid())]) } }

    @discardableResult func getSpeakerInfo(refresh:Bool=false,timeout:TimeInterval?=nil)throws->[String:String] {
        if !speakerInfo.isEmpty && !refresh{return speakerInfo}
        let url=URL(string:"http://\(ipAddress):1400/xml/device_description.xml")!
        let r=try httpClient.request(method:"GET",url:url,headers:[:],body:nil,timeout:timeout ?? SoCoConfig.requestTimeout)
        guard (200..<300).contains(r.statusCode) else{throw SoCoError.http(status:r.statusCode,body:r.text)}
        let tree=try XMLTree(r.text); guard let device=tree.root?.descendants(named:"device").first else{return speakerInfo}
        let map=["zone_name":"roomName","player_icon":"url","serial_number":"serialNum","software_version":"softwareVersion","hardware_version":"hardwareVersion","model_number":"modelNumber","model_name":"modelName","display_version":"displayVersion"]
        for (k,tag) in map { if let v=device.descendants(named:tag).first?.text { speakerInfo[k]=v } }
        if _uid==nil, let udn=device.descendants(named:"UDN").first?.text { _uid=udn.replacingOccurrences(of:"uuid:",with:"") }
        speakerInfo["uid"]=_uid ?? ""
        if let serial=speakerInfo["serial_number"] { speakerInfo["mac_address"]=serial.split(separator:":").first.map(String.init) ?? serial }
        return speakerInfo
    }
}
