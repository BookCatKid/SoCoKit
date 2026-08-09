import Foundation

public extension SoCo {
    /// Compatibility spelling for Python SoCo's `mute` property getter.
    func mute() throws -> Bool { try muted() }

    /// Compatibility spelling for Python SoCo's `mute` property setter.
    func setMute(_ value: Bool) throws { try setMuted(value) }

    func muted()throws->Bool { (Int(try renderingControl.sendCommand("GetMute",arguments:[("InstanceID","0"),("Channel","Master")])["CurrentMute"] ?? "0") ?? 0) != 0 }
    func setMuted(_ value:Bool)throws { _=try renderingControl.sendCommand("SetMute",arguments:[("InstanceID","0"),("Channel","Master"),("DesiredMute",value ? "1":"0")]) }
    func volume()throws->Int { Int(try renderingControl.sendCommand("GetVolume",arguments:[("InstanceID","0"),("Channel","Master")])["CurrentVolume"] ?? "0") ?? 0 }
    func setVolume(_ value:Int)throws { let v=max(0,min(100,value)); _=try renderingControl.sendCommand("SetVolume",arguments:[("InstanceID","0"),("Channel","Master"),("DesiredVolume",String(v))]) }
    func bass()throws->Int { Int(try renderingControl.sendCommand("GetBass",arguments:[("InstanceID","0"),("Channel","Master")])["CurrentBass"] ?? "0") ?? 0 }
    func setBass(_ value:Int)throws { let v=max(-10,min(10,value)); _=try renderingControl.sendCommand("SetBass",arguments:[("InstanceID","0"),("DesiredBass",String(v))]) }
    func treble()throws->Int { Int(try renderingControl.sendCommand("GetTreble",arguments:[("InstanceID","0"),("Channel","Master")])["CurrentTreble"] ?? "0") ?? 0 }
    func setTreble(_ value:Int)throws { let v=max(-10,min(10,value)); _=try renderingControl.sendCommand("SetTreble",arguments:[("InstanceID","0"),("DesiredTreble",String(v))]) }
    func loudness()throws->Bool { (Int(try renderingControl.sendCommand("GetLoudness",arguments:[("InstanceID","0"),("Channel","Master")])["CurrentLoudness"] ?? "0") ?? 0) != 0 }
    func setLoudness(_ value:Bool)throws { _=try renderingControl.sendCommand("SetLoudness",arguments:[("InstanceID","0"),("Channel","Master"),("DesiredLoudness",value ? "1":"0")]) }

    func surroundEnabled()throws->Bool? { guard try isSoundbar() else{return nil}; let r=try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SurroundEnable")]); return (Int(r["CurrentValue"] ?? "0") ?? 0) != 0 }
    func setSurroundEnabled(_ value:Bool)throws { try requireSoundbar("surroundEnabled"); _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SurroundEnable"),("DesiredValue",value ? "1":"0")]) }
    func subCrossover()throws->Int? { if speakerInfo.isEmpty{_=try getSpeakerInfo()}; guard speakerInfo["model_name"]?.lowercased().hasSuffix("sonos amp")==true else{return nil}; return Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SubCrossover")])["CurrentValue"] ?? "") }
    func setSubCrossover(_ frequency:Int)throws { if speakerInfo.isEmpty{_=try getSpeakerInfo()}; guard speakerInfo["model_name"]?.lowercased().hasSuffix("sonos amp")==true else{throw SoCoError.unsupported("Subwoofer crossover not supported on this device.")}; guard (50...110).contains(frequency) else{throw SoCoError.invalidArgument("Invalid value, must be integer between 50 and 110 inclusive")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SubCrossover"),("DesiredValue",String(frequency))]) }
    func subEnabled()throws->Bool? { guard try hasSubwoofer() else{return nil}; return (Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SubEnable")])["CurrentValue"] ?? "0") ?? 0) != 0 }
    func setSubEnabled(_ value:Bool)throws { guard try hasSubwoofer() else{throw SoCoError.unsupported("This group does not have a subwoofer")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SubEnable"),("DesiredValue",value ? "1":"0")]) }
    func subGain()throws->Int? { guard try hasSubwoofer() else{return nil}; return Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SubGain")])["CurrentValue"] ?? "") }
    func setSubGain(_ level:Int)throws { guard try hasSubwoofer() else{throw SoCoError.unsupported("This group does not have a subwoofer")}; guard (-15...15).contains(level) else{throw SoCoError.invalidArgument("Invalid value, must be integer between -15 and 15 inclusive")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SubGain"),("DesiredValue",String(level))]) }

    func balance()throws->(left:Int,right:Int) { let l=try renderingControl.sendCommand("GetVolume",arguments:[("InstanceID","0"),("Channel","LF")]); let r=try renderingControl.sendCommand("GetVolume",arguments:[("InstanceID","0"),("Channel","RF")]); return (Int(l["CurrentVolume"] ?? "0") ?? 0,Int(r["CurrentVolume"] ?? "0") ?? 0) }
    func setBalance(left:Int,right:Int)throws { let l=max(0,min(100,left)),r=max(0,min(100,right)); _=try renderingControl.sendCommand("SetVolume",arguments:[("InstanceID","0"),("Channel","LF"),("DesiredVolume",String(l))]); _=try renderingControl.sendCommand("SetVolume",arguments:[("InstanceID","0"),("Channel","RF"),("DesiredVolume",String(r))]) }
    func audioDelay()throws->Int? { guard try isSoundbar() else{return nil}; return Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","AudioDelay")])["CurrentValue"] ?? "") }
    func setAudioDelay(_ value:Int)throws { guard try isSoundbar() else{throw SoCoError.unsupported("This device does not support audio delay")}; guard (0...5).contains(value) else{throw SoCoError.invalidArgument("invalid value, must be integer between 0 and 5 inclusive")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","AudioDelay"),("DesiredValue",String(value))]) }
    func nightMode()throws->Bool? { guard try isSoundbar() else{return nil}; return (Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","NightMode")])["CurrentValue"] ?? "0") ?? 0) != 0 }
    func setNightMode(_ value:Bool)throws { try requireSoundbar("nightMode"); _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","NightMode"),("DesiredValue",value ? "1":"0")]) }
    func dialogMode()throws->Bool? { guard try isSoundbar() else{return nil}; return (Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","DialogLevel")])["CurrentValue"] ?? "0") ?? 0) != 0 }
    func setDialogMode(_ value:Bool)throws { try requireSoundbar("dialogMode"); _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","DialogLevel"),("DesiredValue",value ? "1":"0")]) }
    func surroundFullVolumeEnabled()throws->Bool? { guard try isSoundbar() else{return nil}; return (Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SurroundMode")])["CurrentValue"] ?? "0") ?? 0) != 0 }
    func setSurroundFullVolumeEnabled(_ value:Bool)throws { try requireSoundbar("surroundFullVolumeEnabled"); _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SurroundMode"),("DesiredValue",value ? "1":"0")]) }
    func surroundVolumeTV()throws->Int? { guard try isSoundbar() else{return nil}; return Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SurroundLevel")])["CurrentValue"] ?? "") }
    func setSurroundVolumeTV(_ value:Int)throws { try requireSoundbar("surroundVolumeTV"); guard (-15...15).contains(value) else{throw SoCoError.invalidArgument("Value must be [-15, 15]")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SurroundLevel"),("DesiredValue",String(value))]) }
    func surroundVolumeMusic()throws->Int? { guard try isSoundbar() else{return nil}; return Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","MusicSurroundLevel")])["CurrentValue"] ?? "") }
    func setSurroundVolumeMusic(_ value:Int)throws { try requireSoundbar("surroundVolumeMusic"); guard (-15...15).contains(value) else{throw SoCoError.invalidArgument("Value must be [-15, 15]")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","MusicSurroundLevel"),("DesiredValue",String(value))]) }
    func speechEnhanceEnabled()throws->Bool? { guard try isArcUltraSoundbar() else{return nil}; return (Int(try renderingControl.sendCommand("GetEQ",arguments:[("InstanceID","0"),("EQType","SpeechEnhanceEnabled")])["CurrentValue"] ?? "0") ?? 0) != 0 }
    func setSpeechEnhanceEnabled(_ value:Bool)throws { guard try isArcUltraSoundbar() else{throw SoCoError.unsupported("The device is not an Arc Ultra and doesn't support speech enhancement.")}; _=try renderingControl.sendCommand("SetEQ",arguments:[("InstanceID","0"),("EQType","SpeechEnhanceEnabled"),("DesiredValue",value ? "1":"0")]) }
    func trueplay()throws->Bool? { let r=try renderingControl.sendCommand("GetRoomCalibrationStatus",arguments:[("InstanceID","0")]); guard r["RoomCalibrationAvailable"] != "0" else{return nil}; return r["RoomCalibrationEnabled"]=="1" }
    func setTrueplay(_ value:Bool)throws { let r=try renderingControl.sendCommand("GetRoomCalibrationStatus",arguments:[("InstanceID","0")]); guard r["RoomCalibrationAvailable"] != "0" else{throw SoCoError.unsupported("Trueplay is not supported or not calibrated")}; guard try isVisible() else{throw SoCoError.notVisible("Trueplay can only be changed on visible devices")}; _=try renderingControl.sendCommand("SetRoomCalibrationStatus",arguments:[("InstanceID","0"),("RoomCalibrationEnabled",value ? "1":"0")]) }

    func soundbarAudioInputFormatCode()throws->Int? { guard try isSoundbar() else{return nil}; return Int(try deviceProperties.sendCommand("GetZoneInfo")["HTAudioIn"] ?? "") }
    func soundbarAudioInputFormat()throws->String? { guard let code=try soundbarAudioInputFormatCode() else{return nil}; return SoCoConstants.audioInputFormats[code] ?? "Unknown audio input format: \(code)" }
    func supportsFixedVolume()throws->Bool { try renderingControl.sendCommand("GetSupportsOutputFixed",arguments:[("InstanceID","0")])["CurrentSupportsFixed"]=="1" }
    func fixedVolume()throws->Bool { try renderingControl.sendCommand("GetOutputFixed",arguments:[("InstanceID","0")])["CurrentFixed"]=="1" }
    func setFixedVolume(_ value:Bool)throws { do{_=try renderingControl.sendCommand("SetOutputFixed",arguments:[("InstanceID","0"),("DesiredFixed",value ? "1":"0")])}catch{throw SoCoError.unsupported("Fixed volume is not supported on this device")}}
    func statusLight()throws->Bool { try deviceProperties.sendCommand("GetLEDState")["CurrentLEDState"]=="On" }
    func setStatusLight(_ value:Bool)throws { _=try deviceProperties.sendCommand("SetLEDState",arguments:[("DesiredLEDState",value ? "On":"Off")]) }
    func buttonsEnabled()throws->Bool { try deviceProperties.sendCommand("GetButtonLockState")["CurrentButtonLockState"]=="Off" }
    func setButtonsEnabled(_ value:Bool)throws { guard try isVisible() else{throw SoCoError.notVisible("Buttons can only be changed on visible devices")}; _=try deviceProperties.sendCommand("SetButtonLockState",arguments:[("DesiredButtonLockState",value ? "Off":"On")]) }
    func voiceServiceConfigured()throws->Bool? { try zoneGroupState.poll(self); guard let s=_voiceConfigState else{return nil}; return (Int(s) ?? 0) != 0 }
    func micEnabled()throws->Bool? { try zoneGroupState.poll(self); guard try voiceServiceConfigured()==true, let s=_micEnabled else{return nil}; return (Int(s) ?? 0) != 0 }
}

public extension SoCo {
    /// Convenience `surroundFullVolumeEnabled` getter to match the raw Sonos API.
    ///
    /// This is the Swift spelling of SoCo's `surround_mode` compatibility
    /// property. Full-volume mode applies to surround *music* playback; TV
    /// playback uses the separate surround-level setting.
    func surroundMode() throws -> Bool? { try surroundFullVolumeEnabled() }

    /// Convenience `surroundFullVolumeEnabled` setter to match the raw Sonos API.
    func setSurroundMode(_ value: Bool) throws { try setSurroundFullVolumeEnabled(value) }

    /// Convenience getter for `surroundVolumeTV` to match the raw Sonos API.
    func surroundLevel() throws -> Int? { try surroundVolumeTV() }

    /// Convenience setter for `surroundVolumeTV` to match the raw Sonos API.
    func setSurroundLevel(_ value: Int) throws { try setSurroundVolumeTV(value) }

    /// Convenience getter for `surroundVolumeMusic` to match the raw Sonos API.
    func musicSurroundLevel() throws -> Int? { try surroundVolumeMusic() }

    /// Convenience setter for `surroundVolumeMusic` to match the raw Sonos API.
    func setMusicSurroundLevel(_ value: Int) throws { try setSurroundVolumeMusic(value) }

    /// Convenience wrapper for the dialog-mode getter to match the raw Sonos API.
    func dialogLevel() throws -> Bool? { try dialogMode() }

    /// Convenience wrapper for the dialog-mode setter to match the raw Sonos API.
    func setDialogLevel(_ value: Bool) throws { try setDialogMode(value) }
}
