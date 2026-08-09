import XCTest
@testable import SoCoKit

private final class MockSnapshotDevice: SnapshotDevice {
    var coordinator = true
    var mediaInfo = ["CurrentURI": "", "CurrentURIMetaData": ""]
    var volumeValue = 20
    var muteValue = false
    var bassValue = 0
    var trebleValue = 0
    var loudnessValue = true
    var fixedVolumeValue = false
    var playModeValue = "NORMAL"
    var crossFadeValue = false
    var trackInfo = ["playlist_position": "", "position": ""]
    var transportInfo = ["current_transport_state": "STOPPED"]
    var queueBatches: [[DidlObject]] = []
    var calls: [String] = []
    var addedURIs: [String] = []

    func snapshotIsCoordinator() throws -> Bool { coordinator }
    func snapshotMediaInfo() throws -> [String : String] { mediaInfo }
    func snapshotVolume() throws -> Int { volumeValue }
    func snapshotSetVolume(_ value: Int) throws { calls.append("volume:\(value)"); volumeValue = value }
    func snapshotMute() throws -> Bool { muteValue }
    func snapshotSetMute(_ value: Bool) throws { calls.append("mute:\(value)"); muteValue = value }
    func snapshotBass() throws -> Int { bassValue }
    func snapshotSetBass(_ value: Int) throws { calls.append("bass:\(value)"); bassValue = value }
    func snapshotTreble() throws -> Int { trebleValue }
    func snapshotSetTreble(_ value: Int) throws { calls.append("treble:\(value)"); trebleValue = value }
    func snapshotLoudness() throws -> Bool { loudnessValue }
    func snapshotSetLoudness(_ value: Bool) throws { calls.append("loudness:\(value)"); loudnessValue = value }
    func snapshotFixedVolume() throws -> Bool { calls.append("fixedVolume"); return fixedVolumeValue }
    func snapshotRampToVolume(_ value: Int) throws { calls.append("ramp:\(value)") }
    func snapshotPlayMode() throws -> String { playModeValue }
    func snapshotSetPlayMode(_ value: String) throws { calls.append("playMode:\(value)") }
    func snapshotCrossFade() throws -> Bool { crossFadeValue }
    func snapshotSetCrossFade(_ value: Bool) throws { calls.append("crossFade:\(value)") }
    func snapshotTrackInfo() throws -> [String : String] { trackInfo }
    func snapshotTransportInfo() throws -> [String : String] { transportInfo }
    func snapshotPlayFromQueue(index: Int, start: Bool) throws { calls.append("queue:\(index):\(start)") }
    func snapshotSeek(_ position: String) throws { calls.append("seek:\(position)") }
    func snapshotPlayURI(_ uri: String, metadata: String, start: Bool) throws { calls.append("uri:\(uri):\(metadata):\(start)") }
    func snapshotPlay() throws { calls.append("play") }
    func snapshotPause() throws { calls.append("pause") }
    func snapshotStop() throws { calls.append("stop") }
    func snapshotGetQueue(start: Int, maxItems: Int) throws -> [DidlObject] {
        calls.append("getQueue:\(start):\(maxItems)")
        return queueBatches.isEmpty ? [] : queueBatches.removeFirst()
    }
    func snapshotClearQueue() throws { calls.append("clearQueue") }
    func snapshotAddURIToQueue(_ uri: String) throws { addedURIs.append(uri); calls.append("add:\(uri)") }
}

final class SnapshotTests: XCTestCase {
    private func makeTrack(_ uri: String, protocolInfo: String = "http-get:*:audio/mpeg:*") throws -> DidlMusicTrack {
        try DidlMusicTrack(
            title: "Test Track",
            parentID: "Q:0",
            itemID: "Q:0/1",
            resources: [DidlResource(uri: uri, protocolInfo: protocolInfo)]
        )
    }

    func testRestoreQueueCallsAddURIToQueue() throws {
        let device = MockSnapshotDevice()
        let track1 = try makeTrack("x-file-cifs://nas/music/a.mp3")
        let track2 = try makeTrack("http://192.168.1.50/music/b.mp3")
        let snapshot = Snapshot(device: device, snapshotQueue: true)
        snapshot.queue = [[track1, track2]]

        try snapshot.restoreQueue()

        XCTAssertEqual(device.addedURIs, [
            "x-file-cifs://nas/music/a.mp3",
            "http://192.168.1.50/music/b.mp3",
        ])
        XCTAssertEqual(device.calls.first, "clearQueue")
    }

    func testRestoreQueueHTTPURIUsesDIDLResource() throws {
        let device = MockSnapshotDevice()
        let httpTrack = try makeTrack("http://192.168.1.50/share/song.mp3")
        XCTAssertEqual(try httpTrack.getURI(), "http://192.168.1.50/share/song.mp3")

        let snapshot = Snapshot(device: device, snapshotQueue: true)
        snapshot.queue = [[httpTrack]]
        try snapshot.restoreQueue()

        XCTAssertEqual(device.addedURIs, ["http://192.168.1.50/share/song.mp3"])
    }

    func testRestoreQueueSkippedWhenNotSnapshotted() throws {
        let device = MockSnapshotDevice()
        let snapshot = Snapshot(device: device, snapshotQueue: false)
        try snapshot.restoreQueue()
        XCTAssertTrue(device.calls.isEmpty)
    }

    func testSnapshotClassifiesLocalAndCloudQueue() throws {
        let local = MockSnapshotDevice()
        local.mediaInfo = [
            "CurrentURI": "x-rincon-queue:RINCON_000E5859E49601400#0",
            "CurrentURIMetaData": "ignored",
        ]
        local.trackInfo = ["playlist_position": "4", "position": "0:01:23"]
        local.playModeValue = "SHUFFLE"
        local.crossFadeValue = true
        local.transportInfo = ["current_transport_state": "PLAYING"]

        let localSnapshot = Snapshot(device: local)
        XCTAssertTrue(try localSnapshot.snapshot())
        XCTAssertTrue(localSnapshot.isPlayingQueue)
        XCTAssertFalse(localSnapshot.isPlayingCloudQueue)
        XCTAssertEqual(localSnapshot.playlistPosition, 4)
        XCTAssertEqual(localSnapshot.trackPosition, "0:01:23")
        XCTAssertNil(localSnapshot.mediaMetadata)

        let cloud = MockSnapshotDevice()
        cloud.mediaInfo = ["CurrentURI": "x-rincon-queue:RINCON_X#6", "CurrentURIMetaData": "cloud"]
        let cloudSnapshot = Snapshot(device: cloud)
        _ = try cloudSnapshot.snapshot()
        XCTAssertFalse(cloudSnapshot.isPlayingQueue)
        XCTAssertTrue(cloudSnapshot.isPlayingCloudQueue)
        XCTAssertEqual(cloudSnapshot.mediaMetadata, "cloud")
    }

    func testSaveQueueUsesFourHundredItemBatches() throws {
        let device = MockSnapshotDevice()
        let first = try (0..<400).map { try makeTrack("http://host/\($0).mp3") }
        let second = try (0..<2).map { try makeTrack("http://host/second-\($0).mp3") }
        device.queueBatches = [first, second]
        let snapshot = Snapshot(device: device, snapshotQueue: true)

        try snapshot.saveQueue()

        XCTAssertEqual(snapshot.queue?.map(\.count), [400, 2])
        XCTAssertTrue(device.calls.contains("getQueue:0:400"))
        XCTAssertTrue(device.calls.contains("getQueue:400:400"))
    }

    func testRestoreCoordinatorQueueOrderAndTransport() throws {
        let device = MockSnapshotDevice()
        device.transportInfo = ["current_transport_state": "PLAYING"]
        let snapshot = Snapshot(device: device)
        snapshot.isCoordinator = true
        snapshot.isPlayingQueue = true
        snapshot.playlistPosition = 3
        snapshot.trackPosition = "0:00:42"
        snapshot.playMode = "REPEAT_ALL"
        snapshot.crossFade = true
        snapshot.volume = 25
        snapshot.mute = false
        snapshot.bass = 1
        snapshot.treble = -1
        snapshot.loudness = true
        snapshot.transportState = "PLAYING"

        try snapshot.restore()

        XCTAssertEqual(snapshot.playlistPosition, 2)
        XCTAssertEqual(Array(device.calls.prefix(5)), [
            "pause",
            "queue:2:false",
            "seek:0:00:42",
            "playMode:REPEAT_ALL",
            "crossFade:true",
        ])
        XCTAssertEqual(device.calls.last, "play")
    }

    func testRestoreStreamAndFadeVolume() throws {
        let device = MockSnapshotDevice()
        device.transportInfo = ["current_transport_state": "PAUSED_PLAYBACK"]
        let snapshot = Snapshot(device: device)
        snapshot.isCoordinator = true
        snapshot.mediaURI = "x-sonosapi-stream:station"
        snapshot.mediaMetadata = "metadata"
        snapshot.volume = 35
        snapshot.mute = false
        snapshot.bass = 2
        snapshot.treble = 3
        snapshot.loudness = true
        snapshot.transportState = "PAUSED_PLAYBACK"

        try snapshot.restore(fade: true)

        XCTAssertTrue(device.calls.contains("uri:x-sonosapi-stream:station:metadata:false"))
        XCTAssertTrue(device.calls.contains("volume:0"))
        XCTAssertTrue(device.calls.contains("ramp:35"))
        XCTAssertFalse(device.calls.contains("play"))
        XCTAssertFalse(device.calls.contains("stop"))
    }

    func testFixedVolumeSkipsEQAndVolumeChanges() throws {
        let device = MockSnapshotDevice()
        device.fixedVolumeValue = true
        let snapshot = Snapshot(device: device)
        snapshot.volume = 100
        snapshot.mute = true
        snapshot.bass = 4
        snapshot.treble = 5
        snapshot.loudness = false

        try snapshot.restoreVolume(fade: false)

        XCTAssertEqual(device.calls, ["mute:true", "fixedVolume"])
    }
}
