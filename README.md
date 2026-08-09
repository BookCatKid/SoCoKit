# SoCoKit

A native Swift port of **SoCo 0.32.0-dev** for controlling Sonos speakers from macOS and iOS.

SoCoKit is a native Swift implementation of the SoCo Sonos/UPnP API. Its upstream license and attribution are preserved in `THIRD_PARTY_NOTICES.md`. The goal of the port is behavioral compatibility with SoCo's Sonos/UPnP implementation while presenting APIs that make sense in Swift.

## Platform support

- macOS 13+
- iOS 16+
- Swift 6 toolchain; the package currently uses Swift 5 language mode for broad source compatibility.

The implementation uses Foundation plus a small portable XML DOM built on `XMLParser`, and POSIX/Darwin sockets for SSDP/events. `FoundationXML` is imported only on Linux, where `XMLParser` lives in that module. It does not depend on Python at runtime.

## What is included

The port covers the original project's major subsystems:

- Sonos discovery by SSDP multicast, with TCP/1400 subnet-scan fallback
- Core speaker identity, topology, grouping, playback, transport and audio/EQ controls
- Queue and Sonos-playlist management
- Music library browsing/searching and library-share management
- SOAP/UPnP service description parsing and dynamic action dispatch
- DIDL-Lite data structures, vendor subclasses, serialization and SoCo quirks
- Event subscriptions, NOTIFY parsing, callback HTTP listener, blocking queues and `AsyncStream`
- Alarms
- Snapshots and restoration
- Modern SMAPI music services, accounts, authentication/token storage and metadata types
- Additive read-only browsing of already-configured music-service accounts, including legacy SMAPI and manifest/content home pages
- Legacy music-service data structures and WiMP plugin
- Share-link and Plex queue plugins
- Caching, XML and utility helpers

See `PORTING_AUDIT.md` for a module-by-module map and the deliberate Swift adaptations.

## Basic use

```swift
import SoCoKit

let zones = try discover()
if let speaker = zones?.first {
    print(try speaker.playerName())
    try speaker.play()
}
```

You can also use the namespaced discovery API:

```swift
let zones = try Discovery.discover(timeout: 5)
```

Queue example:

```swift
if let speaker = try anySoCo() {
    let queue = try speaker.getQueue(start: 0, maxItems: 100)
    print("Queue contains \(queue.totalMatches) items")
}
```

Event example:

```swift
let subscription = try speaker.avTransport.subscribe()
let event = try subscription.events.get(timeout: 10)
print(event.variables)
try subscription.unsubscribe()
```

`EventQueue.stream()` also exposes an `AsyncStream<Event>` for Swift-concurrency consumers.

## Configured music-service browsing

`MusicServiceBrowser` is an additive, read-only companion to the existing
`MusicService` API. It discovers accounts already configured in the Sonos
household from `ThirdPartyMediaServersX`, then browses through either legacy
SMAPI or a service's manifest/content endpoint as required. Existing
`MusicService` behavior and token-store APIs are unchanged.

```swift
let accounts = try MusicServiceBrowser.getAccounts(device: speaker)
let apple = accounts.first { $0.serviceID == 204 }

if let apple {
    let browser = try MusicServiceBrowser(
        serviceName: "Apple Music",
        account: apple,
        device: speaker
    )

    let root = try browser.getMetadata()
    if let library = root.items.first { $0.canBrowse } {
        let page = try browser.getMetadata(item: library)
        print(page.items.map(\.title))
    }
}
```

Credential refresh is enabled by default because current providers commonly
return stale seed credentials and require `refreshAuthToken` before browsing.
Refreshes update only the browser's in-memory `ConfiguredMusicServiceAccount`;
they are not written to the Sonos household or to SoCoKit's existing token
store. Pass `allowCredentialRefresh: false` to opt out. The browser exposes no
account-creation, removal, authorization, nickname, or other account-mutation
operations.

For services with multiple configured accounts, call
`MusicServiceBrowser.getAccounts(device:)` and pass the desired account
explicitly. Modern content pages preserve their transport provenance so a
child handed back to SMAPI uses the account-scoped identity required by services
such as Apple Music.

## iOS/macOS local-network requirements

The host application, not a Swift package, owns privacy strings and code-signing entitlements. For a Sonos controller using SoCoKit:

- Add `NSLocalNetworkUsageDescription` to the app's Info.plist. Apple requires a purpose string for apps which connect directly to local hosts.
- On **iOS**, SSDP discovery sends UDP multicast to `239.255.255.250:1900`, so the signed app needs Apple's `com.apple.developer.networking.multicast` entitlement. Apple currently treats this as a restricted entitlement which must be requested for physical-device distribution/testing. It is not required on macOS.
- SoCo talks to Sonos players over plain local HTTP (`http://<speaker>:1400`). On current Apple OS releases, set `NSAppTransportSecurity` → `NSAllowsLocalNetworking` to `YES` so URLSession can load local IP resources without broadly disabling ATS.
- If the **macOS** host app uses App Sandbox, enable both Outgoing Connections (Client) and Incoming Connections (Server). Discovery/control initiate network traffic, while event subscriptions open a callback listener that Sonos connects back to.

The user must grant local-network access. The package cannot add these app-level settings itself. Test discovery and event callbacks in the actual signed iOS/macOS application because a Linux SwiftPM build cannot validate Apple's sandbox, permission prompt, code signing, or multicast entitlement.

For event subscriptions, the phone/Mac must be reachable by the Sonos player at the callback IP/port. `SoCoConfig.eventAdvertiseIP`, `eventListenerIP` and `eventListenerPort` are available for networks where automatic selection is unsuitable. iOS may suspend a backgrounded app, so long-lived event subscriptions should be treated as foreground connectivity unless the host app has an independently valid background-execution reason.

## Testing

Run the complete deterministic verification gate:

```fish
python3 Scripts/verify_all.py
```

Or run the Swift test suite by itself:

```fish
swift test --parallel
```

## Important Swift adaptations

Python features that do not have a direct Swift equivalent are represented explicitly rather than emulated unsafely:

- Python's argument-keyed `SoCo` singleton metaclass becomes a weak per-IP registry used by discovery/topology. Swift initializers cannot return a pre-existing class instance.
- Python's runtime DIDL metaclass/type generation becomes a static Swift class hierarchy and type factory.
- `events.py`, `events_asyncio.py` and `events_twisted.py` become one native event implementation with blocking and Swift-concurrency consumption APIs.
- Python exception subclasses become typed `SoCoError` enum cases.
- Python module namespace collisions are made explicit: DIDL `Queue` is available as `Queue`/`SoCoQueue`, while the UPnP service is `QueueService`; modern music-service items live under `SMAPI.*`, while legacy `MusicServiceItem` remains available globally.
- The deprecated Spotify plugin is deliberately unavailable because the upstream plugin itself raises at import time after Spotify's legacy metadata API shutdown.

## Reference and audit files

- `PORTING_AUDIT.md` — module/API mapping and language adaptations
- `UPSTREAM_TEST_MAPPING.md` — Swift test coverage map
- `THIRD_PARTY_NOTICES.md` — upstream SoCo attribution and license

## License and attribution

SoCoKit is licensed under the MIT License. It is derived from the Python [SoCo](https://github.com/SoCo/SoCo) project, originally created by Rahim Sonawalla with contributions from the SoCo community. See `THIRD_PARTY_NOTICES.md` for the upstream notice and license.
