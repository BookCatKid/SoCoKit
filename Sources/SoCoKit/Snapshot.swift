import Foundation

/// The subset of speaker behavior used by `Snapshot`.
///
/// `SoCo` conforms directly. Keeping this surface protocol-based also allows the
/// snapshot algorithm to be tested without network hardware and lets advanced
/// callers provide a compatible adapter if needed.
public protocol SnapshotDevice: AnyObject {
    func snapshotIsCoordinator() throws -> Bool
    func snapshotMediaInfo() throws -> [String: String]

    func snapshotVolume() throws -> Int
    func snapshotSetVolume(_ value: Int) throws
    func snapshotMute() throws -> Bool
    func snapshotSetMute(_ value: Bool) throws
    func snapshotBass() throws -> Int
    func snapshotSetBass(_ value: Int) throws
    func snapshotTreble() throws -> Int
    func snapshotSetTreble(_ value: Int) throws
    func snapshotLoudness() throws -> Bool
    func snapshotSetLoudness(_ value: Bool) throws
    func snapshotFixedVolume() throws -> Bool
    func snapshotRampToVolume(_ value: Int) throws

    func snapshotPlayMode() throws -> String
    func snapshotSetPlayMode(_ value: String) throws
    func snapshotCrossFade() throws -> Bool
    func snapshotSetCrossFade(_ value: Bool) throws
    func snapshotTrackInfo() throws -> [String: String]
    func snapshotTransportInfo() throws -> [String: String]

    func snapshotPlayFromQueue(index: Int, start: Bool) throws
    func snapshotSeek(_ position: String) throws
    func snapshotPlayURI(_ uri: String, metadata: String, start: Bool) throws
    func snapshotPlay() throws
    func snapshotPause() throws
    func snapshotStop() throws

    func snapshotGetQueue(start: Int, maxItems: Int) throws -> [DidlObject]
    func snapshotClearQueue() throws
    func snapshotAddURIToQueue(_ uri: String) throws
}

extension SoCo: SnapshotDevice {
    public func snapshotIsCoordinator() throws -> Bool { try isCoordinator() }

    public func snapshotMediaInfo() throws -> [String: String] {
        try avTransport.sendCommand("GetMediaInfo", arguments: [("InstanceID", "0")])
    }

    public func snapshotVolume() throws -> Int { try volume() }
    public func snapshotSetVolume(_ value: Int) throws { try setVolume(value) }
    public func snapshotMute() throws -> Bool { try muted() }
    public func snapshotSetMute(_ value: Bool) throws { try setMuted(value) }
    public func snapshotBass() throws -> Int { try bass() }
    public func snapshotSetBass(_ value: Int) throws { try setBass(value) }
    public func snapshotTreble() throws -> Int { try treble() }
    public func snapshotSetTreble(_ value: Int) throws { try setTreble(value) }
    public func snapshotLoudness() throws -> Bool { try loudness() }
    public func snapshotSetLoudness(_ value: Bool) throws { try setLoudness(value) }
    public func snapshotFixedVolume() throws -> Bool { try fixedVolume() }
    public func snapshotRampToVolume(_ value: Int) throws { _ = try rampToVolume(value) }

    public func snapshotPlayMode() throws -> String { try playMode() }
    public func snapshotSetPlayMode(_ value: String) throws { try setPlayMode(value) }
    public func snapshotCrossFade() throws -> Bool { try crossFade() }
    public func snapshotSetCrossFade(_ value: Bool) throws { try setCrossFade(value) }
    public func snapshotTrackInfo() throws -> [String: String] { try currentTrackInfo() }
    public func snapshotTransportInfo() throws -> [String: String] { try currentTransportInfo() }

    public func snapshotPlayFromQueue(index: Int, start: Bool) throws {
        try playFromQueue(index: index, start: start)
    }
    public func snapshotSeek(_ position: String) throws { try seek(position: position) }
    public func snapshotPlayURI(_ uri: String, metadata: String, start: Bool) throws {
        _ = try playURI(uri, metadata: metadata, start: start)
    }
    public func snapshotPlay() throws { try play() }
    public func snapshotPause() throws { try pause() }
    public func snapshotStop() throws { try stop() }

    public func snapshotGetQueue(start: Int, maxItems: Int) throws -> [DidlObject] {
        try getQueue(start: start, maxItems: maxItems).items
    }
    public func snapshotClearQueue() throws { try clearQueue() }
    public func snapshotAddURIToQueue(_ uri: String) throws { _ = try addURIToQueue(uri) }
}

/// Functionality to support saving and restoring the current Sonos state.
///
/// This is useful for scenarios such as when you want to switch to radio or an
/// announcement and then back again to what was playing previously.
///
/// - Warning: Sonos introduced control via Amazon Alexa, which creates a cloud
///   queue. At present there appears to be no way to restart that queue from a
///   snapshot. If a cloud queue was playing it will currently not restart.
/// - Warning: This class is designed to be created, used and destroyed. It is
///   not designed to be reused or long lived. Initialization sets up defaults
///   for one use.
public final class Snapshot {
    /// The device that will be snapshotted.
    public let device: any SnapshotDevice

    // The values that will be stored.
    // For all zones:
    public var mediaURI: String?
    public var isCoordinator = false
    public var isPlayingQueue = false
    public var isPlayingCloudQueue = false

    public var volume: Int?
    public var mute: Bool?
    public var bass: Int?
    public var treble: Int?
    public var loudness: Bool?

    // For coordinator zone playing from Queue:
    public var playMode: String?
    public var crossFade: Bool?
    public var playlistPosition = 0
    public var trackPosition: String?

    // For coordinator zone playing a Stream:
    public var mediaMetadata: String?

    // For all coordinator zones:
    public var transportState: String?

    /// Queue batches, or nil when the caller chose not to snapshot the queue.
    public var queue: [[DidlObject]]?

    /// Create a snapshot helper for a device.
    ///
    /// - Parameter snapshotQueue: Whether the queue should be snapshotted.
    ///   Defaults to false.
    /// - Warning: It is strongly advised that you do not snapshot the queue
    ///   unless you really need to. Large queues take a long time to restore
    ///   because they are restored one track at a time, matching SoCo.
    public init(device: any SnapshotDevice, snapshotQueue: Bool = false) {
        self.device = device
        // Only set the queue as a list if we are going to save it.
        queue = snapshotQueue ? [] : nil
    }

    /// Record and store the current state of a device.
    ///
    /// - Returns: `true` if the device is a coordinator, `false` otherwise.
    ///   This is useful for determining whether playing an alert on a device
    ///   will ungroup it.
    @discardableResult
    public func snapshot() throws -> Bool {
        // Get if device coordinator (or slave) True (or False).
        isCoordinator = try device.snapshotIsCoordinator()

        // Get information about the currently playing media.
        let mediaInfo = try device.snapshotMediaInfo()
        mediaURI = mediaInfo["CurrentURI"] ?? ""

        // Extract source from media uri - below some media URI value examples:
        // 'x-rincon-queue:RINCON_000E5859E49601400#0'
        //      - playing a local queue always #0 for local queue
        // 'x-rincon-queue:RINCON_000E5859E49601400#6'
        //      - playing a cloud queue where #x changes with each queue
        // 'x-rincon:RINCON_000E5859E49601400'
        //      - a slave player pointing to coordinator player
        if let uri = mediaURI, uri.split(separator: ":", maxSplits: 1).first == "x-rincon-queue" {
            if uri.split(separator: "#", maxSplits: 1).dropFirst().first == "0" {
                // Playing local queue.
                isPlayingQueue = true
            } else {
                // Playing cloud queue - started from Alexa.
                isPlayingCloudQueue = true
            }
        }

        // Save the volume, mute and other sound settings.
        volume = try device.snapshotVolume()
        mute = try device.snapshotMute()
        bass = try device.snapshotBass()
        treble = try device.snapshotTreble()
        loudness = try device.snapshotLoudness()

        // Get details required for what's playing.
        if isPlayingQueue {
            // Playing from queue - save repeat, random, cross fade, track, etc.
            playMode = try device.snapshotPlayMode()
            crossFade = try device.snapshotCrossFade()

            // Get information about the currently playing track.
            let trackInfo = try device.snapshotTrackInfo()
            let position = trackInfo["playlist_position"] ?? ""
            if !position.isEmpty, let value = Int(position) {
                // Save as integer.
                playlistPosition = value
            }
            trackPosition = trackInfo["position"]
        } else {
            // Playing from a stream - save media metadata.
            mediaMetadata = mediaInfo["CurrentURIMetaData"] ?? ""
        }

        // Work out what the playing state is - if a coordinator.
        if isCoordinator {
            let transportInfo = try device.snapshotTransportInfo()
            transportState = transportInfo["current_transport_state"]
        }

        // Save the current queue if we need to.
        try saveQueue()

        // Return if device is a coordinator (helps usage).
        return isCoordinator
    }

    /// Restore the state of a device to that which was previously saved.
    ///
    /// For coordinator devices restore everything. For slave devices only
    /// restore volume etc.; transport information comes from the slave's
    /// coordinator.
    ///
    /// - Parameter fade: Whether volume should be faded up on restore.
    public func restore(fade: Bool = false) throws {
        var coordinatorError: Error?
        do {
            if isCoordinator {
                try restoreCoordinator()
            }
        } catch {
            coordinatorError = error
        }

        // Python uses `finally` here so volume restoration happens even when
        // coordinator restoration fails. If restoring volume itself fails, that
        // error supersedes the earlier one, which this ordering preserves.
        try restoreVolume(fade: fade)
        if let coordinatorError { throw coordinatorError }

        // Now everything is set, see if we need to be playing, stopped or
        // paused (only for coordinators). A saved PAUSED state requires no call
        // because restoreCoordinator already leaves transport paused.
        if isCoordinator {
            if transportState == "PLAYING" {
                try device.snapshotPlay()
            } else if transportState == "STOPPED" {
                try device.snapshotStop()
            }
        }
    }

    /// Do the coordinator-only part of the restore.
    public func restoreCoordinator() throws {
        // Start by ensuring that the speaker is paused as we don't want things
        // rolling back while changing them, as this could include audio.
        let transportInfo = try device.snapshotTransportInfo()
        if transportInfo["current_transport_state"] == "PLAYING" {
            try device.snapshotPause()
        }

        // Check if the queue should be restored.
        try restoreQueue()

        // Reinstate what was playing.
        if isPlayingQueue && playlistPosition > 0 {
            // The position returned by get_current_track_info starts at 1, but
            // play_from_queue's index starts at 0.
            playlistPosition -= 1
            try device.snapshotPlayFromQueue(index: playlistPosition, start: false)

            if let trackPosition, !trackPosition.isEmpty {
                try device.snapshotSeek(trackPosition)
            }

            // Reinstate track position, play mode and cross fade. A proper track
            // must be selected first.
            if let playMode { try device.snapshotSetPlayMode(playMode) }
            if let crossFade { try device.snapshotSetCrossFade(crossFade) }
        } else if isPlayingCloudQueue {
            // Was playing a cloud queue started by Alexa. There is no known way
            // to restart this yet, so deliberately do nothing rather than throw.
        } else {
            // Was playing a stream (radio station, file, or nothing): reinstate
            // URI and metadata.
            if let mediaURI, !mediaURI.isEmpty {
                try device.snapshotPlayURI(
                    mediaURI,
                    metadata: mediaMetadata ?? "",
                    start: false
                )
            }
        }
    }

    /// Reinstate volume and sound settings.
    public func restoreVolume(fade: Bool) throws {
        if let mute { try device.snapshotSetMute(mute) }

        // Can only change volume on a device with fixed volume set to False,
        // otherwise Sonos returns a UPnP error. Before issuing a network command
        // to check, fixed volume always has volume set to 100, so fixed volume is
        // only queried when the saved volume is 100.
        let fixedVolume: Bool
        if volume == 100 {
            fixedVolume = try device.snapshotFixedVolume()
        } else {
            fixedVolume = false
        }

        // Now set volume if not fixed.
        if !fixedVolume {
            if let bass { try device.snapshotSetBass(bass) }
            if let treble { try device.snapshotSetTreble(treble) }
            if let loudness { try device.snapshotSetLoudness(loudness) }

            if let volume {
                if fade {
                    // If fade requested in restore, set volume to 0 then fade up
                    // to saved volume (non-blocking on Sonos itself).
                    try device.snapshotSetVolume(0)
                    try device.snapshotRampToVolume(volume)
                } else {
                    try device.snapshotSetVolume(volume)
                }
            }
        }
    }

    /// Save the current state of the queue.
    public func saveQueue() throws {
        guard queue != nil else { return }

        // Maximum batch is 486; anything larger will still only return 486.
        let batchSize = 400
        var total = 0
        var numberReturned = batchSize

        // Need to get all tracks in batches, but only get the next batch if all
        // requested items were in the last batch.
        while numberReturned == batchSize {
            let queueItems = try device.snapshotGetQueue(start: total, maxItems: batchSize)
            numberReturned = queueItems.count
            // Make sure the queue is not empty.
            if numberReturned > 0 {
                queue?.append(queueItems)
            }
            total += numberReturned
        }
    }

    /// Restore the previous state of the queue.
    ///
    /// The restore currently adds items back using the URI. For items the Sonos
    /// system already knows about this is OK, but other items may be missing some
    /// metadata because it will not be automatically picked up.
    public func restoreQueue() throws {
        guard let queue else { return }

        // Clear the queue so that it can be reset.
        try device.snapshotClearQueue()
        // Now loop around all queue entries adding them. Importantly, the URI is
        // obtained from the DIDL resource (`getURI`) rather than a nonexistent
        // direct track `.uri` property; this preserves the fix for SoCo #983 and
        // correctly restores HTTP/WebDAV tracks.
        for queueGroup in queue {
            for queueItem in queueGroup {
                try device.snapshotAddURIToQueue(try queueItem.getURI())
            }
        }
    }
}
