# SoCo → SoCoKit porting audit

This file records how the Python source tree maps to the Swift implementation. `Reference/SoCo-Python` is the immutable reference copy.

## Module map

| Python module | Swift implementation | Status / adaptation |
|---|---|---|
| `soco/__init__.py` | `SoCo.swift`, `Discovery.swift` | `SoCo`, `discover`, reset and public entry points present. |
| `alarms.py` | `Alarms.swift` | Ported. Swift adds throwing `setPlayMode` / `setRecurrence` because property setters cannot throw. |
| `cache.py` | `Cache.swift` | Ported (`NullCache`, timed cache behavior and global enable flag). |
| `config.py` | `Config.swift` | Ported relevant runtime configuration. Events backend selection is unnecessary because Swift has one native backend. |
| `core.py` | `SoCo.swift`, `CoreIdentity.swift`, `CorePlayback.swift`, `CoreAudio.swift`, `CoreQueue.swift` | All 136 public methods/properties have Swift counterparts. Python properties become getter/setter methods where throwing/network behavior is involved. |
| `data_structure_quirks.py` | `DIDL.swift` | `applyResourceQuirks` ported. |
| `data_structures.py` | `DIDL.swift` | Full static DIDL hierarchy, resource/object dictionary/XML conversion, favorites/references, search/queue containers and vendor subclasses. Runtime metaclass is replaced by static type dispatch. |
| `data_structures_entry.py` | `DIDL.swift` | DIDL parser (`fromDIDLString`) ported. |
| `discovery.py` | `Discovery.swift` | SSDP + subnet scan ported with native sockets. Both namespaced and free-function APIs are provided. |
| `events_base.py` | `Events.swift` | Event model/parser/subscription base semantics ported. |
| `events.py` | `Events.swift` | Native callback HTTP listener and subscription lifecycle ported. |
| `events_asyncio.py` | `Events.swift` | Unified into native listener; `AsyncStream<Event>` replaces Python asyncio queue consumption. Backend-specific task/socket race tests are not meaningful one-for-one. |
| `events_twisted.py` | `Events.swift` | Unified native implementation; no Twisted dependency is needed in Swift. |
| `exceptions.py` | `Errors.swift` | Distinct Python exception classes become typed `SoCoError` cases plus `SoapFault`. |
| `groups.py` | `ZoneGroups.swift` | Ported group identity, label, volume, mute and relative-volume behavior. |
| `ms_data_structures.py` | `LegacyMusicServiceData.swift` | Ported; global `MusicServiceItem` aliases the legacy base. |
| `music_library.py` | `MusicLibrary.swift` | All public search/browse/update/share methods ported. |
| `music_services/accounts.py` | `MusicServiceAccounts.swift` | Ported including deleted accounts, object reuse and synthetic TuneIn behavior. |
| `music_services/data_structures.py` | `SMAPI.swift` | Ported under `SMAPI` namespace to avoid collision with legacy `MS*` classes. |
| `music_services/music_service.py` | `MusicService.swift` | Descriptor parsing, SOAP client, auth, search/category maps, URI/descriptor behavior ported. |
| `music_services/token_store.py` | `MusicServiceTokenStore.swift` | Ported as a Swift protocol + memory/JSON implementations; `JsonFileTokenStore` and `TokenStoreBase` aliases provided. |
| Additive configured-service browser | `MusicServiceBrowser.swift`, `MusicServiceBrowseCrypto.swift` | Read-only browser ported from the separately validated Python browser: encrypted `ThirdPartyMediaServersX` account discovery, legacy SMAPI, manifest/content roots, in-memory credential refresh and content-to-SMAPI handoff. Existing `MusicService` behavior is unchanged; no account write/onboarding APIs are included. |
| `plugins/__init__.py` | `Plugins.swift` | Plugin base/registry ported with Swift factories rather than dynamic import by arbitrary constructor args. |
| `plugins/example.py` | `Plugins.swift` | Ported. |
| `plugins/plex.py` | `PlexPlugin.swift` | Ported through `PlexMediaProviding` so the Swift library does not depend on Python `plexapi`. |
| `plugins/sharelink.py` | `Plugins.swift` | Spotify/TIDAL/Deezer/Apple Music share parsing and queue metadata ported. |
| `plugins/spotify.py` | `DeprecatedSpotifyPlugin.swift` | Intentionally unavailable, matching upstream's immediate runtime failure after API shutdown. |
| `plugins/wimp.py` | `WimpPlugin.swift` | Legacy plugin SOAP/search/browse/retry/fault behavior ported. |
| `services.py` | `Services.swift` | SCPD parsing, action dispatch, service URLs, errors and all service classes ported. `MS_ConnectionManager` / `MR_ConnectionManager` aliases retained. Python service `Queue` is `QueueService` because DIDL `Queue` occupies the module-level name. |
| `snapshot.py` | `Snapshot.swift` | Snapshot/restore, queue batching, cloud queue handling and volume/EQ restore behavior ported. |
| `soap.py` | `SOAP.swift` | SOAP preparation/call/fault behavior ported. |
| `utils.py` | `Utilities.swift` | Unicode, casing, XML display, escaping and time helpers ported. Python's runtime `deprecated` decorator maps to normal Swift `@available(..., deprecated/unavailable)` declarations where relevant. |
| `xml.py` | `XML.swift` | Namespace tagging and XML helpers ported. The Swift DOM is implemented on portable `XMLParser` rather than macOS-only `XMLDocument`/`XMLElement`, so the production XML layer is available on iOS as well. |
| `zonegroupstate.py` | `ZoneGroups.swift` | Household topology parsing/cache, satellites, event fallback and normalized duplicate suppression ported. Public normalization helper provided. |

## Public API naming

Swift uses lower-camel-case names while retaining the original meaning. Examples:

- `get_current_track_info` → `currentTrackInfo()`
- `play_uri` → `playURI(...)`
- `get_sonos_playlist_by_attr` → `getSonosPlaylistByAttribute(_:matching:)`
- `scan_network_by_household_id` → `scanNetworkByHouseholdID(...)`
- `parse_event_xml` → `parseEventXML(...)`
- `to_didl_string` → `toDIDLString(...)`

Where Python accepts dynamically typed values, Swift generally offers typed overloads. The raw comma-list Sonos playlist reorder path is preserved because it has behavior that cannot safely be reconstructed from sequential integer operations.

## Deliberate runtime/language differences

### SoCo singleton identity

Python's metaclass can return the same object from a constructor call for the same IP. Swift initializers cannot return an earlier object. `SoCoRegistry` therefore holds a weak **latest-live-wrapper-per-IP** mapping, and all internal topology/discovery code reuses it. `socoReset()` clears the mapping. Equality/hash are IP-based.

### Dynamic service methods

Python manufactures methods with `__getattr__` after reading an SCPD. Swift exposes the parsed `ServiceAction` metadata and `sendCommand`/dispatcher path instead of trying to synthesize methods at runtime. High-level SoCo calls still use the same SCPD/SOAP action definitions and wire payloads.

### DIDL runtime metaclass

Python can dynamically manufacture DIDL subclasses for unknown vendor extensions. Swift uses a known static hierarchy and retains exact class strings/metadata for supported vendor-extension forms. No unsafe runtime class creation is attempted.

### Event backends

Python carries synchronous, asyncio and Twisted implementations because those are separate Python I/O ecosystems. Swift has one socket listener, a blocking `EventQueue`, callbacks, and `AsyncStream<Event>`. asyncio/Twisted task-management internals therefore have no direct public Swift equivalent.

### Exception hierarchy

Swift's `SoCoError` enum retains semantic distinctions (`upnp`, `http`, `musicServiceAuth`, `slaveOperation`, etc.) but is not a class-for-class mirror of Python's exception inheritance tree.

### Request timeout `None`

Python permits global `REQUEST_TIMEOUT = None` to mean potentially infinite waits. SoCoKit's global request timeout is a concrete `TimeInterval`; individual APIs that explicitly support infinite Sonos subscription timeout model that separately. This avoids passing an undefined timeout into Foundation/URLSession behavior.

## Comment/documentation preservation

The original source contains 1,623 inline comments and 670 docstrings. They are all retained verbatim in `OriginalSoCoCommentary.swift` with file/line markers, and the untouched Python source remains under `Reference/`. Protocol-critical notes are additionally colocated with the Swift implementation.

## Mechanical completeness gates

The repository includes executable audits in `Scripts/` which verify that:

- all 547 public upstream Python declarations are either present as compiled Swift API or explicitly reviewed as a language/backend adaptation;
- all 66 upstream SOAP actions match Swift argument names and literal values; and
- all 1,623 original inline comments plus 670 docstrings are preserved.

These checks inspect the compiled Swift symbol graph where appropriate, so preserved Python commentary cannot create false API matches.

## Verification boundary

The Swift code is compiled and unit/protocol tested in this repository. The conversion environment has no Xcode, iOS simulator or physical Sonos household, so Apple sandbox/entitlement behavior and current-firmware acceptance of live commands are not claimed as hardware-verified. See `VERIFICATION.md`.
