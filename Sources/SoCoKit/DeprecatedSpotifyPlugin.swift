import Foundation

/// The old Spotify plugin is intentionally unavailable.
///
/// SoCo deprecated it immediately in August 2016 because the Spotify Metadata
/// API on which it depended was shut down. The original Python module raises a
/// `RuntimeError` as soon as it is imported (except while building docs). In
/// Swift, marking the compatibility symbol unavailable provides the same clear
/// failure at compile time rather than allowing an object which can never work.
/// Use `MusicService` / SMAPI or `ShareLinkPlugin` instead.
@available(*, unavailable, message: "The legacy Spotify Metadata API was shut down; use MusicService/SMAPI or ShareLinkPlugin instead.")
public enum SpotifyPlugin {}
