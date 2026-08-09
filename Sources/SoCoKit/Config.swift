import Foundation

public enum SoCoConfig {
    /// The factory to use whenever discovery creates a `SoCo` instance.
    ///
    /// This is the Swift equivalent of Python SoCo's `config.SOCO_CLASS`. A
    /// factory is used instead of a class object because `SoCo` is a concrete
    /// Swift type and callers commonly need to inject a custom HTTP transport.
    public static var socoFactory: (String) throws -> SoCo = { try SoCo($0) }
    public static var requestTimeout: TimeInterval = 20
    public static var cacheEnabled = true
    /// The IP advertised to Sonos in event subscription callback URLs.
    /// `nil` means to use the listener's automatically-detected address.
    public static var eventAdvertiseIP: String? = nil
    /// The local IP on which the event listener should bind. `nil` selects the
    /// interface which can route to the target Sonos player.
    public static var eventListenerIP: String? = nil
    /// Preferred event-listener port. If occupied, SoCoKit tries the following
    /// 99 ports, matching Python SoCo.
    public static var eventListenerPort: UInt16 = 1400
    /// Whether ZoneGroupState polling may fall back to an event subscription on
    /// large Sonos systems where GetZoneGroupState returns an error.
    public static var zoneGroupTopologyEventFallback = true
    public static var discoveryTimeout: TimeInterval = 5
    public static var discoveryPort: UInt16 = 1900
    public static var sonosPort: UInt16 = 1400
    public static var discoveryAddress = "239.255.255.250"
    public static var includeInvisible = false
}

/// Package metadata copied from SoCo's public module attributes.
public enum SoCoKitMetadata {
    public static let author = "The SoCo-Team <python-soco@googlegroups.com>"
    public static let version = "0.32.0-dev"
    public static let website = "https://github.com/SoCo/SoCo"
    public static let license = "MIT License"
}

public enum SoCoConstants {
    /// Public constants corresponding to `RADIO_STATIONS`, `RADIO_SHOWS`, and
    /// `SONOS_FAVORITES` in `soco.core`.
    public static let radioStations = 0
    public static let radioShows = 1
    public static let sonosFavorites = 2

    /// Public copy of SoCo's `AUDIO_INPUT_FORMATS` mapping.
    public static let audioInputFormats: [Int: String] = [
        0: "No input connected",
        2: "Stereo",
        7: "Dolby 2.0",
        18: "Dolby 5.1",
        21: "No input",
        22: "No audio",
        59: "Dolby Atmos (DD+)",
        61: "Dolby Atmos (TrueHD)",
        63: "Dolby Atmos (MAT 2.0)",
        33554434: "PCM 2.0",
        33554454: "PCM 2.0 no audio",
        33554488: "Dolby 2.0",
        33554490: "Dolby Digital Plus 2.0",
        33554492: "Dolby TrueHD 2.0",
        33554494: "Dolby Multichannel PCM 2.0",
        84934658: "Multichannel PCM 5.1",
        84934713: "Dolby 5.1",
        84934714: "Dolby Digital Plus 5.1",
        84934716: "Dolby TrueHD 5.1",
        84934718: "Dolby Multichannel PCM 5.1",
        84934721: "DTS 5.1",
        118489090: "Multichannel PCM 7.1",
        118489146: "Dolby Digital Plus 7.1",
        118489148: "Dolby TrueHD 7.1",
    ]

    /// SoCo compares lowercased model names with this suffix.
    public static let arcUltraProductName = "arc ultra"
    public static let queueURI = "x-rincon-queue:"
    public static let tvURI = "x-sonos-htastream:"
    public static let lineInURI = "x-rincon-stream:"
    public static let radioURIPrefixes = ["x-sonosapi-stream:", "x-sonosapi-radio:", "x-rincon-mp3radio:"]
}
