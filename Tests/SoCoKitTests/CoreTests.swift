import XCTest
@testable import SoCoKit

final class CoreTests: XCTestCase {
    private func makeSoCo(_ client: MockHTTPClient = MockHTTPClient(), coordinator: Bool = true) throws -> SoCo {
        let soco = try SoCo("192.168.1.101", httpClient: client)
        soco._isCoordinator = coordinator
        // Unit-test stand-in for a fresh ZoneGroupState cache. Production
        // coordinator checks still call `poll`, matching upstream SoCo.
        soco.zoneGroupState.cacheUntil = .distantFuture
        return soco
    }

    private func enqueueOK(_ client: MockHTTPClient, action: String, service: String = "AVTransport", fields: [(String, String)] = []) {
        client.enqueue(text: soapResponse(action: action, serviceType: service, fields: fields))
    }

    func testInvalidIPAddressAndDescription() throws {
        XCTAssertThrowsError(try SoCo("not.an.ip"))
        let soco = try SoCo("192.168.1.101", httpClient: MockHTTPClient())
        XCTAssertEqual(soco.ipAddress, "192.168.1.101")
        XCTAssertEqual(soco.description, "<SoCo object at ip 192.168.1.101>")
    }

    func testPlayModeValidationAndLowercaseSetter() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        for mode in ["NORMAL", "SHUFFLE_NOREPEAT", "SHUFFLE", "REPEAT_ALL", "SHUFFLE_REPEAT_ONE", "REPEAT_ONE"] {
            enqueueOK(client, action: "GetTransportSettings", fields: [("PlayMode", mode)])
            XCTAssertEqual(try soco.playMode(), mode)
        }
        XCTAssertThrowsError(try soco.setPlayMode("BAD_VALUE"))
        enqueueOK(client, action: "SetPlayMode")
        try soco.setPlayMode("normal")
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<NewPlayMode>NORMAL</NewPlayMode>"))
    }

    func testAvailableActionsStripsDLNAPrefix() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "GetCurrentTransportActions", fields: [("Actions", "Set, Stop, Pause, Play, X_DLNA_SeekTime, X_DLNA_SeekTrackNr")])
        XCTAssertEqual(try soco.availableActions(), ["Set", "Stop", "Pause", "Play", "SeekTime", "SeekTrackNr"])
    }

    func testCrossFadeAndCoordinatorProtection() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "GetCrossfadeMode", fields: [("CrossfadeMode", "1")])
        XCTAssertTrue(try soco.crossFade())
        enqueueOK(client, action: "SetCrossfadeMode")
        try soco.setCrossFade(false)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<CrossfadeMode>0</CrossfadeMode>"))

        let slave = try makeSoCo(MockHTTPClient(), coordinator: false)
        XCTAssertThrowsError(try slave.play()) { error in
            guard case SoCoError.slaveOperation = error else { return XCTFail("Expected slaveOperation, got \(error)") }
        }
    }

    func testPlayPauseStopNextPreviousAndDirectControl() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        for (action, call) in [
            ("Play", { try soco.play() }),
            ("Pause", { try soco.pause() }),
            ("Stop", { try soco.stop() }),
            ("EndDirectControlSession", { try soco.endDirectControlSession() }),
            ("Next", { try soco.next() }),
            ("Previous", { try soco.previous() }),
        ] as [(String, () throws -> Void)] {
            enqueueOK(client, action: action)
            try call()
            XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<u:\(action)"))
        }
    }

    func testPlayURIForceRadioTitleStartAndTimeout() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "SetAVTransportURI")
        enqueueOK(client, action: "Play")
        let uri = "https://archive.org/download/example.mp3"
        XCTAssertTrue(try soco.playURI(uri, title: "<Fast & Loose>", forceRadio: true, timeout: 300))
        XCTAssertEqual(client.requests.count, 2)
        let setBody = requestBodyText(client.requests[0])
        XCTAssertTrue(setBody.contains("<CurrentURI>x-rincon-mp3radio://archive.org/download/example.mp3</CurrentURI>"))
        XCTAssertTrue(setBody.contains("&amp;lt;Fast &amp;amp; Loose&amp;gt;"), "SOAP must escape the already XML-escaped DIDL metadata exactly once at the transport layer")
        XCTAssertEqual(client.requests[0].timeout, 300)
        XCTAssertEqual(client.requests[1].timeout, 300)

        let noStart = MockHTTPClient()
        let second = try makeSoCo(noStart)
        enqueueOK(noStart, action: "SetAVTransportURI")
        XCTAssertFalse(try second.playURI("http://example.test/stream", start: false))
        XCTAssertEqual(noStart.requests.count, 1)
    }

    func testSeekValidationTrackAndPosition() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        for invalid in ["NOT_VALID", "12:34:56:78", "99", "12:3:4"] {
            XCTAssertThrowsError(try soco.seek(position: invalid))
        }
        XCTAssertEqual(client.requests.count, 0)

        enqueueOK(client, action: "Seek")
        try soco.seek(position: "12:78:78")
        var body = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(body.contains("<Unit>REL_TIME</Unit>"))
        XCTAssertTrue(body.contains("<Target>12:78:78</Target>"))

        enqueueOK(client, action: "Seek")
        try soco.seek(track: 4)
        body = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(body.contains("<Unit>TRACK_NR</Unit>"))
        XCTAssertTrue(body.contains("<Target>5</Target>"))
    }

    func testTransportInfoAndMusicSourceClassification() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "GetTransportInfo", fields: [("CurrentTransportState", "PLAYING"), ("CurrentTransportStatus", "OK"), ("CurrentSpeed", "1")])
        let info = try soco.currentTransportInfo()
        XCTAssertEqual(info["current_transport_state"], "PLAYING")
        XCTAssertEqual(info["current_transport_status"], "OK")
        XCTAssertEqual(info["current_transport_speed"], "1")

        XCTAssertEqual(SoCo.musicSource(fromURI: ""), .none)
        XCTAssertEqual(SoCo.musicSource(fromURI: "x-file-cifs://server/a.mp3"), .library)
        XCTAssertEqual(SoCo.musicSource(fromURI: "x-rincon-mp3radio://radio"), .radio)
        XCTAssertEqual(SoCo.musicSource(fromURI: "https://example.test/a.mp3"), .webFile)
        XCTAssertEqual(SoCo.musicSource(fromURI: "x-rincon-stream:RINCON_1"), .lineIn)
        XCTAssertEqual(SoCo.musicSource(fromURI: "x-sonos-htastream:RINCON_1:spdif"), .tv)
        XCTAssertEqual(SoCo.musicSource(fromURI: "x-sonos-vli:RINCON_1,airplay:foo"), .airPlay)
        XCTAssertEqual(SoCo.musicSource(fromURI: "x-sonos-vli:RINCON_1,spotify:foo"), .spotifyConnect)
        XCTAssertEqual(SoCo.musicSource(fromURI: "some-new-scheme:test"), .unknown)
    }

    func testSwitchToLineInAndTV() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._uid = "RINCON_MAIN"
        let source = try SoCo("192.168.1.102", httpClient: client)
        source._uid = "RINCON_SOURCE"
        enqueueOK(client, action: "SetAVTransportURI")
        try soco.switchToLineIn(source: source)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("x-rincon-stream:RINCON_SOURCE"))
        enqueueOK(client, action: "SetAVTransportURI")
        try soco.switchToTV()
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("x-sonos-htastream:RINCON_MAIN:spdif"))
    }

    func testMuteVolumeBassTrebleLoudnessAndClamping() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "GetMute", service: "RenderingControl", fields: [("CurrentMute", "1")])
        XCTAssertTrue(try soco.muted())
        enqueueOK(client, action: "SetMute", service: "RenderingControl")
        try soco.setMuted(false)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredMute>0</DesiredMute>"))

        enqueueOK(client, action: "GetVolume", service: "RenderingControl", fields: [("CurrentVolume", "42")])
        XCTAssertEqual(try soco.volume(), 42)
        enqueueOK(client, action: "SetVolume", service: "RenderingControl")
        try soco.setVolume(999)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredVolume>100</DesiredVolume>"))

        enqueueOK(client, action: "SetBass", service: "RenderingControl")
        try soco.setBass(-99)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredBass>-10</DesiredBass>"))
        enqueueOK(client, action: "SetTreble", service: "RenderingControl")
        try soco.setTreble(99)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredTreble>10</DesiredTreble>"))

        enqueueOK(client, action: "GetLoudness", service: "RenderingControl", fields: [("CurrentLoudness", "1")])
        XCTAssertTrue(try soco.loudness())
        enqueueOK(client, action: "SetLoudness", service: "RenderingControl")
        try soco.setLoudness(false)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredLoudness>0</DesiredLoudness>"))
    }

    func testRampRelativeVolumeAndBalance() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "RampToVolume", service: "RenderingControl", fields: [("RampTime", "5")])
        XCTAssertEqual(try soco.rampToVolume(30), 5)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<ResetVolumeAfter>False</ResetVolumeAfter>"))
        enqueueOK(client, action: "SetRelativeVolume", service: "RenderingControl", fields: [("NewVolume", "44")])
        XCTAssertEqual(try soco.setRelativeVolume(-3), 44)

        enqueueOK(client, action: "GetVolume", service: "RenderingControl", fields: [("CurrentVolume", "20")])
        enqueueOK(client, action: "GetVolume", service: "RenderingControl", fields: [("CurrentVolume", "80")])
        let balance = try soco.balance()
        XCTAssertEqual(balance.left, 20)
        XCTAssertEqual(balance.right, 80)
        enqueueOK(client, action: "SetVolume", service: "RenderingControl")
        enqueueOK(client, action: "SetVolume", service: "RenderingControl")
        try soco.setBalance(left: -1, right: 101)
        XCTAssertTrue(requestBodyText(client.requests[client.requests.count - 2]).contains("<DesiredVolume>0</DesiredVolume>"))
        XCTAssertTrue(requestBodyText(client.requests[client.requests.count - 1]).contains("<DesiredVolume>100</DesiredVolume>"))
    }

    func testSoundbarSettingsAliasesAndRanges() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._isSoundbar = true

        for (getterAction, expected, getter) in [
            ("SurroundMode", "1", { try soco.surroundMode().map(String.init(describing:)) }),
            ("SurroundLevel", "-7", { try soco.surroundLevel().map(String.init) }),
            ("MusicSurroundLevel", "8", { try soco.musicSurroundLevel().map(String.init) }),
            ("DialogLevel", "1", { try soco.dialogLevel().map(String.init(describing:)) }),
        ] as [(String, String, () throws -> String?)] {
            enqueueOK(client, action: "GetEQ", service: "RenderingControl", fields: [("CurrentValue", expected)])
            XCTAssertNotNil(try getter())
            XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<EQType>\(getterAction)</EQType>"))
        }

        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setSurroundMode(false)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setSurroundLevel(-15)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setMusicSurroundLevel(15)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setDialogLevel(true)
        XCTAssertThrowsError(try soco.setSurroundLevel(-16))
        XCTAssertThrowsError(try soco.setMusicSurroundLevel(16))
    }

    func testAudioDelayAndSoundbarInputFormat() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._isSoundbar = false
        XCTAssertNil(try soco.audioDelay())
        XCTAssertThrowsError(try soco.setAudioDelay(1))

        soco._isSoundbar = true
        XCTAssertThrowsError(try soco.setAudioDelay(6))
        enqueueOK(client, action: "GetEQ", service: "RenderingControl", fields: [("CurrentValue", "2")])
        XCTAssertEqual(try soco.audioDelay(), 2)
        enqueueOK(client, action: "SetEQ", service: "RenderingControl")
        try soco.setAudioDelay(1)

        enqueueOK(client, action: "GetZoneInfo", service: "DeviceProperties", fields: [("HTAudioIn", "118489148")])
        XCTAssertEqual(try soco.soundbarAudioInputFormatCode(), 118489148)
        enqueueOK(client, action: "GetZoneInfo", service: "DeviceProperties", fields: [("HTAudioIn", "118489148")])
        XCTAssertEqual(try soco.soundbarAudioInputFormat(), "Dolby TrueHD 7.1")
        enqueueOK(client, action: "GetZoneInfo", service: "DeviceProperties", fields: [("HTAudioIn", "12345")])
        XCTAssertEqual(try soco.soundbarAudioInputFormat(), "Unknown audio input format: 12345")
    }

    func testFixedVolumeStatusLightAndButtonsWireBehavior() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        enqueueOK(client, action: "GetSupportsOutputFixed", service: "RenderingControl", fields: [("CurrentSupportsFixed", "1")])
        XCTAssertTrue(try soco.supportsFixedVolume())
        enqueueOK(client, action: "GetOutputFixed", service: "RenderingControl", fields: [("CurrentFixed", "1")])
        XCTAssertTrue(try soco.fixedVolume())
        enqueueOK(client, action: "SetOutputFixed", service: "RenderingControl")
        try soco.setFixedVolume(false)

        enqueueOK(client, action: "GetLEDState", service: "DeviceProperties", fields: [("CurrentLEDState", "On")])
        XCTAssertTrue(try soco.statusLight())
        enqueueOK(client, action: "SetLEDState", service: "DeviceProperties")
        try soco.setStatusLight(false)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<DesiredLEDState>Off</DesiredLEDState>"))

        enqueueOK(client, action: "GetButtonLockState", service: "DeviceProperties", fields: [("CurrentButtonLockState", "Off")])
        XCTAssertTrue(try soco.buttonsEnabled())
    }

    func testPlayerNameStereoAndSatelliteCommands() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        soco._uid = "LEFT"
        enqueueOK(client, action: "SetZoneAttributes", service: "DeviceProperties")
        try soco.setPlayerName("Kitchen")
        XCTAssertNil(soco._playerName, "upstream setter waits for topology to refresh the cached player name")

        let right = try SoCo("192.168.1.102", httpClient: client); right._uid = "RIGHT"
        enqueueOK(client, action: "AddBondedZones", service: "DeviceProperties")
        try soco.createStereoPair(right: right)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("LEFT:LF,LF;RIGHT:RF,RF"))
        enqueueOK(client, action: "RemoveBondedZones", service: "DeviceProperties")
        try soco.separateStereoPair()

        soco._isSoundbar = true
        let leftRear = try SoCo("192.168.1.103", httpClient: client); leftRear._uid = "LR"
        let rightRear = try SoCo("192.168.1.104", httpClient: client); rightRear._uid = "RR"
        enqueueOK(client, action: "AddHTSatellite", service: "DeviceProperties")
        try soco.addSatelliteSpeakers(leftRear: leftRear, rightRear: rightRear)
        let satelliteBody = requestBodyText(try XCTUnwrap(client.requests.last))
        XCTAssertTrue(satelliteBody.contains("<ChannelMapSet>LEFT:LF,RF;RR:RR;LR:LR</ChannelMapSet>"))
        XCTAssertFalse(satelliteBody.contains("HTSatChanMapSet"))
    }

    func testJoinUnjoinTimeoutAndQueueURI() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        let master = try SoCo("192.168.1.102", httpClient: client); master._uid = "MASTER"
        enqueueOK(client, action: "SetAVTransportURI")
        try soco.join(master, timeout: 123)
        XCTAssertEqual(client.requests.last?.timeout, 123)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("x-rincon:MASTER"))
        enqueueOK(client, action: "BecomeCoordinatorOfStandaloneGroup")
        try soco.unjoin(timeout: 234)
        XCTAssertEqual(client.requests.last?.timeout, 234)

        soco._uid = "SELF"
        soco.speakerInfo["model_name"] = "Sonos One"
        soco._isCoordinator = true
        soco.zoneGroupState.cacheUntil = .distantFuture
        enqueueOK(client, action: "SetAVTransportURI")
        enqueueOK(client, action: "Seek")
        try soco.playFromQueue(index: 2, start: false)
        XCTAssertTrue(requestBodyText(client.requests[client.requests.count - 2]).contains("x-rincon-queue:SELF#0"))
        XCTAssertTrue(requestBodyText(client.requests[client.requests.count - 1]).contains("<Target>3</Target>"))
    }

    func testSleepTimer() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        XCTAssertThrowsError(try soco.setSleepTimer(seconds: 86_400))
        enqueueOK(client, action: "ConfigureSleepTimer")
        try soco.setSleepTimer(seconds: 3661)
        XCTAssertTrue(requestBodyText(try XCTUnwrap(client.requests.last)).contains("<NewSleepTimerDuration>01:01:01</NewSleepTimerDuration>"))
        enqueueOK(client, action: "GetRemainingSleepTimerDuration", fields: [("RemainingSleepTimerDuration", "01:01:01")])
        XCTAssertEqual(try soco.getSleepTimer(), 3661)
        enqueueOK(client, action: "GetRemainingSleepTimerDuration", fields: [("RemainingSleepTimerDuration", "")])
        XCTAssertNil(try soco.getSleepTimer())
    }

    func testBatteryInfo() throws {
        let client = MockHTTPClient()
        let soco = try makeSoCo(client)
        client.enqueue(text: """
        <ZPSupportInfo><LocalBatteryStatus><Data name="Level">87</Data><Data name="Temperature">30</Data></LocalBatteryStatus></ZPSupportInfo>
        """)
        let info = try soco.getBatteryInfo(timeout: 9)
        XCTAssertEqual(info["Level"], "87")
        XCTAssertEqual(info["Temperature"], "30")
        XCTAssertEqual(client.requests.last?.url.absoluteString, "http://192.168.1.101:1400/status/batterystatus")
        XCTAssertEqual(client.requests.last?.timeout, 9)
    }
}
