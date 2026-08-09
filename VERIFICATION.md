# Verification record

## Environment

- Swift: 6.x toolchain
- Hosts used for verification: macOS arm64 and Linux SwiftPM environments
- Package language mode: Swift 5
- Declared Apple deployment targets: macOS 13+, iOS 16+
- Xcode/iOS simulator: not exercised in this package-only verification
- Physical Sonos household: Study was exercised separately with read-only live probes; see the hardware boundary below

## Checks performed

The complete deterministic gate can be run with:

```sh
python3 Scripts/verify_all.py
```

That runs the full Swift tests, release build, package-manifest validation, compiled-symbol public-API audit, SOAP-action audit, and comment/docstring preservation audit. The public-API audit locates SwiftPM products on both Linux and macOS and uses the platform's Swift symbol-graph tool.

The source is also scanned for accidental `fatalError`/`preconditionFailure`/new TODO placeholders. The one remaining `FIXME` in `SOAP.swift` is intentionally preserved from the original SoCo source commentary rather than being a newly introduced unfinished item.

## Final local result

- **233 Swift tests passed**: 211 XCTest-discovered tests plus 22 Swift Testing tests.
- **0 failures**.
- Release (`-c release`) build completed successfully.
- `swift package dump-package` completed successfully with only macOS 13 and iOS 16 declared.
- Compiled-symbol API audit: **547 / 547** upstream public declarations accounted for (477 direct compiled Swift matches + 70 explicitly reviewed language/backend adaptations; 0 unclassified).
- SOAP action audit: **66 / 66** upstream actions matched with 0 argument-signature and 0 literal mismatches.
- Commentary audit: **1,623 / 1,623** inline comments and **670 / 670** docstrings preserved.

## Test scope

The deterministic Swift suite covers:

- cache enable/disable/expiry
- XML sanitization/namespaces
- SOAP headers/bodies/calls/faults
- UPnP SCPD parsing, dispatch, caching and fault handling
- DIDL hierarchy, fixtures, vendor extensions, resources, references and quirks
- SSDP/network-scan helpers and a real localhost TCP socket connection test
- event parsing, subscription/renew/unsubscribe headers, SID routing and queue behavior
- alarms and skipped-zone identity reuse
- core playback, queue, transport, coordinator guards, EQ/soundbar controls and speaker info
- bulk Sonos playlist reorder/removal wire semantics
- topology normalization/caching/satellites/group volume
- music library searches/shares/update behavior
- modern SMAPI metadata/factory/URI behavior
- music-service descriptors/accounts/auth/token stores
- configured-account decryption and read-only music-service browsing, including default-on in-memory refresh, DeviceLink sessions, content HTTP 401 refresh/retry, malformed provider XML tolerance, and content-to-SMAPI handoff
- legacy music-service objects and WiMP behavior
- ShareLink and Plex queue metadata
- snapshot/restore and queue batching

## Original Python test baseline

The untouched upstream Python tests are retained under `Reference/SoCo-Python/tests`. An extra attempt to execute the non-integration pytest suite in this conversion container stopped during collection because the environment does not contain upstream's `xmltodict` dependency, and the package mirror available in this environment could not supply it. This does **not** affect the Swift test results above; the ported Swift suite is self-contained and has no Python runtime dependency.

## Hardware-only boundary

Upstream `tests/test_integration.py` is a real-speaker test suite and requires an explicit Sonos IP, a playing queue and careful state restoration. The source is retained unchanged in `Reference/SoCo-Python/tests/test_integration.py`. Its protocol contracts are represented in mock-based Swift tests.

A separate read-only live run against the Study household exercised Swift's public music-service APIs: encrypted configured-account discovery twice, 14 accounts across 12 services, legacy SMAPI browsing, manifest/content browsing, child browsing, searches where advertised, metadata probes, and default in-memory credential refresh. Household identity remained stable and no playback, queue, volume, grouping, alarm, account-linking, or account-mutation operation was used. Pandora was an account/provider-specific failure in that household and is not treated as a universal SoCoKit limitation; search remains provider-dependent.

Live hardware validation does not prove every current firmware/provider combination. Compiling on Linux or macOS does not validate:

- Apple's local-network privacy prompt
- the required iOS multicast entitlement in a signed physical-device build
- App Transport Security/local-HTTP behavior in a signed Apple app
- inbound event callback reachability under an app sandbox
- current Sonos firmware quirks not represented by the supplied SoCo tests/fixtures
- live third-party SMAPI service credentials/endpoints

Those are the remaining integration-verification steps for an app/device environment, not hidden source TODOs.
