#!/usr/bin/env python3
"""Audit upstream SoCo public declarations against the Swift port.

This is intentionally a *completeness* audit, not a promise that Python and
Swift can expose byte-for-byte identical APIs. Python runtime metaclasses,
decorators and its three event-loop backends have explicit reviewed mappings.
Every other public module function, public class, and direct public method must
either normalize to a Swift declaration or appear in EXPLICIT_MAPPINGS below.
"""
from __future__ import annotations

import ast
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PY_ROOT = ROOT / "Reference" / "SoCo-Python" / "soco"
SWIFT_ROOT = ROOT / "Sources" / "SoCoKit"


def normalize(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


@dataclass(frozen=True)
class PythonAPI:
    module: str
    owner: str | None
    name: str
    kind: str

    @property
    def key(self) -> str:
        owner = f"{self.owner}." if self.owner else ""
        return f"{self.module}:{owner}{self.name}"


@dataclass
class CompiledSwiftAPI:
    names: dict[str, set[str]]
    types: set[str]
    top_level: set[str]
    members: set[tuple[str, str]]


def public_python_api() -> list[PythonAPI]:
    result: list[PythonAPI] = []
    for path in sorted(PY_ROOT.rglob("*.py")):
        module = path.relative_to(PY_ROOT).as_posix()
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and not node.name.startswith("_"):
                result.append(PythonAPI(module, None, node.name, "function"))
            elif isinstance(node, ast.ClassDef) and not node.name.startswith("_"):
                result.append(PythonAPI(module, None, node.name, "class"))
                for child in node.body:
                    if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and not child.name.startswith("_"):
                        result.append(PythonAPI(module, node.name, child.name, "method"))
    return result


def swift_build_bin_path() -> Path | None:
    try:
        result = subprocess.run(
            ["swift", "build", "--show-bin-path"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    path = Path(result.stdout.strip())
    return path if path.is_dir() else None


def symbolgraph_tool() -> str | None:
    tool = shutil.which("swift-symbolgraph-extract")
    if tool:
        return tool
    try:
        result = subprocess.run(
            ["xcrun", "--find", "swift-symbolgraph-extract"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    path = result.stdout.strip()
    return path if path else None


def swift_module_location() -> tuple[Path, str]:
    bin_path = swift_build_bin_path()
    if bin_path:
        product_module = bin_path / "SoCoKit.swiftmodule"
        if product_module.is_dir():
            module_files = sorted(product_module.glob("*.swiftmodule"))
            if module_files:
                # `-I` must point to the directory containing the module
                # directory, not to the module directory itself. On Darwin,
                # symbolgraph extraction also needs a deployment-qualified
                # target even though SwiftPM names the artifact without it.
                module_target = module_files[0].stem
                if module_target.endswith("-apple-macos"):
                    module_target += "x13.0"
                return bin_path, module_target

    # Linux SwiftPM's older layout places the public module under a target-triple
    # Modules directory. Keep this fallback for CI/toolchains using that layout.
    module_dirs = sorted((ROOT / ".build").glob("*-unknown-linux-gnu/debug/Modules"))
    if module_dirs:
        return module_dirs[0], module_dirs[0].parents[1].name
    raise RuntimeError("Debug module not found; run `swift build` or `swift test` first")


def swift_declarations() -> CompiledSwiftAPI:
    """Read declarations from Swift's compiled symbol graph, never source text."""
    modules, target = swift_module_location()
    tool = symbolgraph_tool()
    if tool is None:
        raise RuntimeError(
            "swift-symbolgraph-extract not found; install a Swift/Xcode toolchain"
        )
    names: dict[str, set[str]] = {}
    types: set[str] = set()
    top_level: set[str] = set()
    members: set[tuple[str, str]] = set()
    type_kinds = {"swift.class", "swift.struct", "swift.enum", "swift.protocol", "swift.typealias"}

    with tempfile.TemporaryDirectory(prefix="socokit-symbols-") as output:
        command = [
            tool,
            "-module-name", "SoCoKit",
            "-I", str(modules),
            "-target", target,
        ]
        if "apple" in target:
            try:
                sdk = subprocess.run(
                    ["xcrun", "--show-sdk-path"],
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout.strip()
            except (OSError, subprocess.CalledProcessError) as error:
                raise RuntimeError(
                    "Apple SDK path unavailable; run this audit with Xcode or a Swift toolchain"
                ) from error
            command.extend(["-sdk", sdk])
        command.extend(["-output-dir", output])
        subprocess.run(
            command,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        for path in Path(output).glob("SoCoKit*.symbols.json"):
            graph = json.loads(path.read_text(encoding="utf-8"))
            for symbol in graph.get("symbols", []):
                title = symbol.get("names", {}).get("title", "")
                base = title.split("(", 1)[0]
                if "." in base:
                    base = base.rsplit(".", 1)[-1]
                if not base:
                    continue
                path_components = symbol.get("pathComponents", [])
                location = ".".join(path_components) or title
                normalized = normalize(base)
                names.setdefault(normalized, set()).add(location)
                kind = symbol.get("kind", {}).get("identifier")
                if kind in type_kinds:
                    types.add(normalized)
                elif len(path_components) <= 1:
                    top_level.add(normalized)
                else:
                    owner = path_components[-2].split("(", 1)[0]
                    members.add((normalize(owner), normalized))

    return CompiledSwiftAPI(names=names, types=types, top_level=top_level, members=members)


# Python classes whose implementation owner differs from the public Python name.
OWNER_MAPPINGS: dict[str, str] = {
    "data_structures.py:ListOfMusicInfoItems": "MusicInfoList",
    "events.py:EventServerThread": "EventListener",
    "events_asyncio.py:SubscriptionsMapAio": "SubscriptionsMap",
    "events_base.py:EventNotifyHandlerBase": "EventNotifyHandler",
    "events_base.py:EventListenerBase": "EventListener",
    "events_base.py:SubscriptionBase": "Subscription",
    "events_twisted.py:SubscriptionsMapTwisted": "SubscriptionsMap",
    "ms_data_structures.py:MusicServiceItem": "LegacyMusicServiceItem",
    "music_services/accounts.py:Account": "MusicServiceAccount",
    "music_services/token_store.py:TokenStoreBase": "MusicServiceTokenStore",
    "music_services/token_store.py:JsonFileTokenStore": "JSONFileTokenStore",
    "services.py:Queue": "QueueService",
}


# Entries here are only needed when the idiomatic/native Swift API necessarily has
# a different spelling or shape. `target` is checked against the compiled symbols.
EXPLICIT_MAPPINGS: dict[str, tuple[str | None, str]] = {
    "ms_data_structures.py:MusicServiceItem.from_xml": ("fromXML", "idiomatic Swift acronym capitalization"),
    "ms_data_structures.py:MusicServiceItem.to_dict": ("dictionary", "Swift computed dictionary property"),
    "ms_data_structures.py:MusicServiceItem.didl_metadata": ("didlMetadataXML", "throwing Swift method for DIDL XML"),
    "core.py:only_on_master": (None, "Python decorator becomes an internal Swift coordinator guard"),
    "core.py:only_on_soundbars": (None, "Python decorator becomes an internal Swift soundbar guard"),
    "core.py:SoCo.repeat": ("repeatMode", "Swift enum preserves off/all/one rather than Python bool-or-one property"),
    "core.py:SoCo.music_source_from_uri": ("musicSource", "Swift overload musicSource(fromURI:)"),
    "core.py:SoCo.get_current_track_info": ("currentTrackInfo", "Swift getter-style method"),
    "core.py:SoCo.get_current_media_info": ("currentMediaInfo", "Swift getter-style method"),
    "core.py:SoCo.get_current_transport_info": ("currentTransportInfo", "Swift getter-style method"),
    "core.py:SoCo.get_sonos_playlist_by_attr": ("getSonosPlaylistByAttribute", "typed Swift attribute selector"),
    **{f"exceptions.py:{name}": ("SoCoError", "Python exception class represented by a typed SoCoError case") for name in [
        "SoCoException", "UnknownSoCoException", "SoCoUPnPException", "CannotCreateDIDLMetadata",
        "DIDLMetadataError", "MusicServiceException", "MusicServiceAuthException", "UnknownXMLStructure",
        "SoCoSlaveException", "SoCoNotVisibleException", "NotSupportedException", "EventParseException",
    ]},
    "zonegroupstate.py:ZoneGroupState.update_zgs_by_event": ("updateByEvent", "native event backend"),
    "zonegroupstate.py:ZoneGroupState.update_zgs_by_event_default": ("updateByEvent", "native event backend"),
    "zonegroupstate.py:ZoneGroupState.update_zgs_by_event_asyncio": ("updateByEvent", "native event backend"),
    "events_asyncio.py:EventNotifyHandler.notify": ("handleNotification", "native callback handler"),
    "events_asyncio.py:EventListener.async_start": ("start", "native listener start"),
    "events_asyncio.py:EventListener.async_listen": ("start", "native listener start"),
    "events_asyncio.py:EventListener.async_stop": ("stop", "native listener stop"),
    "events_asyncio.py:EventListener.stop_listening": ("stop", "native listener stop"),
    "events_asyncio.py:SubscriptionsMapAio.subscribing": ("register", "single thread-safe native subscriptions map"),
    "events_asyncio.py:SubscriptionsMapAio.finished_subscribing": ("register", "single thread-safe native subscriptions map"),
    "events_asyncio.py:nullcontext": (None, "Python async context-manager implementation detail"),
    "events_asyncio.py:SubscriptionsMapAio": ("SubscriptionsMap", "unified native subscriptions map"),
    "events.py:EventServer": ("EventListener", "socket HTTP server is encapsulated by EventListener"),
    "events.py:EventNotifyHandler.do_NOTIFY": ("handleNotification", "HTTP NOTIFY dispatch"),
    "events.py:EventServerThread": ("EventListener", "Swift listener owns its native worker"),
    "events.py:EventServerThread.run": ("start", "listener worker implementation is encapsulated"),
    "events.py:EventListener.stop_listening": ("stop", "native listener stop"),
    "events_twisted.py:EventNotifyHandler.render_NOTIFY": ("handleNotification", "HTTP NOTIFY dispatch"),
    "events_twisted.py:EventListener.stop_listening": ("stop", "native listener stop"),
    "events_twisted.py:SubscriptionsMapTwisted": ("SubscriptionsMap", "unified native subscriptions map"),
    "events_twisted.py:SubscriptionsMapTwisted.subscribing": ("register", "single native subscriptions map"),
    "events_twisted.py:SubscriptionsMapTwisted.finished_subscribing": ("register", "single native subscriptions map"),
    "events_base.py:EventNotifyHandlerBase": ("EventNotifyHandler", "Swift has one concrete portable handler"),
    "events_base.py:EventListenerBase": ("EventListener", "Swift has one native listener"),
    "events_base.py:EventListenerBase.stop_listening": ("stop", "native listener stop"),
    "events_base.py:SubscriptionBase": ("Subscription", "Swift has one native subscription type"),
    "events_base.py:SubscriptionsMap.get_subscription": ("subscription", "subscription(for:) lookup"),
    "data_structures.py:form_name": ("formDIDLName", "Swift DIDL naming helper"),
    "data_structures.py:DidlResource.to_dict": ("dictionary", "Swift dictionary(removeNils:)"),
    "data_structures.py:DidlObject.to_dict": ("dictionary", "Swift dictionary(removeNils:)"),
    "data_structures.py:DidlMetaClass": (None, "Python runtime metaclass replaced by static Swift DIDL hierarchy"),
    "services.py:Queue": ("QueueService", "UPnP Queue service type; DIDL Queue retains the short name"),
    "services.py:Service.compose_args": ("composeArguments", "idiomatic Swift name"),
    "services.py:Service.event_vars": ("eventVariables", "idiomatic Swift name"),
    "services.py:Service.iter_event_vars": ("iterEventVariables", "idiomatic Swift name"),
    "utils.py:deprecated": (None, "Swift uses @available for deprecated/unavailable declarations"),
    "alarms.py:Alarms.get_next_alarm_datetime": ("nextAlarmDate", "Date-valued Swift API"),
    "alarms.py:Alarm.get_next_alarm_datetime": ("nextAlarmDate", "Date-valued Swift API"),
    "music_services/music_service.py:MusicServiceSoapClient.get_soap_header": ("soapHeader", "idiomatic Swift name"),
    "music_services/music_service.py:MusicService.get_all_music_services_names": ("allMusicServiceNames", "idiomatic Swift name"),
    "music_services/music_service.py:MusicService.get_data_for_name": ("dataForName", "idiomatic Swift name"),
    "music_services/data_structures.py:get_class": ("itemClass", "stable Swift metatype factory"),
    "music_services/data_structures.py:MusicServiceItem.from_music_service": ("fromMusicService", "idiomatic Swift name"),
    "music_services/data_structures.py:bool_str": ("smapiBool", "namespaced Swift helper"),
    "music_services/accounts.py:Account.get_accounts": ("accounts", "Swift static account loader"),
    "music_services/accounts.py:Account.get_accounts_for_service": ("accounts", "accounts(forServiceType:device:) overload"),
}


def main() -> int:
    python_api = public_python_api()
    swift = swift_declarations()
    auto = 0
    explicit = 0
    unclassified: list[PythonAPI] = []
    bad_targets: list[tuple[PythonAPI, str]] = []

    for item in python_api:
        mapping = EXPLICIT_MAPPINGS.get(item.key)
        if mapping is not None:
            explicit += 1
            target, _reason = mapping
            if target is not None and normalize(target) not in swift.names:
                bad_targets.append((item, target))
            continue

        normalized = normalize(item.name)
        if item.kind == "class":
            expected = OWNER_MAPPINGS.get(f"{item.module}:{item.name}", item.name)
            matched = normalize(expected) in swift.types
        elif item.owner is None:
            matched = normalized in swift.top_level
        else:
            expected_owner = OWNER_MAPPINGS.get(f"{item.module}:{item.owner}", item.owner)
            matched = (normalize(expected_owner), normalized) in swift.members

        if matched:
            auto += 1
        else:
            unclassified.append(item)

    stale = sorted(set(EXPLICIT_MAPPINGS) - {item.key for item in python_api})

    print(f"Upstream public declarations: {len(python_api)}")
    print(f"Direct normalized Swift matches: {auto}")
    print(f"Reviewed explicit mappings/adaptations: {explicit}")
    print(f"Unclassified declarations: {len(unclassified)}")
    print(f"Mappings with missing Swift targets: {len(bad_targets)}")
    print(f"Stale mapping entries: {len(stale)}")

    if unclassified:
        print("\nUNCLASSIFIED:")
        for item in unclassified:
            print(f"  {item.key} ({item.kind})")
    if bad_targets:
        print("\nMISSING SWIFT TARGETS:")
        for item, target in bad_targets:
            print(f"  {item.key} -> {target}")
    if stale:
        print("\nSTALE MAPPINGS:")
        for key in stale:
            print(f"  {key}")

    if unclassified or bad_targets or stale:
        return 1
    print("OK: every upstream public declaration is matched or explicitly adapted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
