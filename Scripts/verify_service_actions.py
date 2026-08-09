#!/usr/bin/env python3
"""Audit SoCoKit's core SOAP action names/argument keys against upstream SoCo.

This intentionally focuses on the four upstream modules whose public behavior is
implemented directly through UPnP service calls in the Swift port. Dynamic
values are ignored; action names, ordered argument-key signatures, and literal
argument values are compared mechanically.
"""
from __future__ import annotations

import ast
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PYTHON_FILES = [
    ROOT / "Reference/SoCo-Python/soco/core.py",
    ROOT / "Reference/SoCo-Python/soco/music_library.py",
    ROOT / "Reference/SoCo-Python/soco/snapshot.py",
    ROOT / "Reference/SoCo-Python/soco/alarms.py",
]
SWIFT_DIR = ROOT / "Sources/SoCoKit"


def python_calls() -> dict[str, list[tuple[tuple[str, ...], tuple[tuple[str, str], ...]]]]:
    out: dict[str, list[tuple[tuple[str, ...], tuple[tuple[str, str], ...]]]] = defaultdict(list)
    for path in PYTHON_FILES:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute):
                continue
            action = node.func.attr
            if not action or not action[0].isupper():
                continue
            # Service calls in these modules conventionally pass one positional
            # list of (argument-name, value) pairs. Calls without that list are
            # valid zero-argument actions.
            keys: list[str] = []
            literals: list[tuple[str, str]] = []
            if node.args and isinstance(node.args[0], (ast.List, ast.Tuple)):
                for item in node.args[0].elts:
                    if not (isinstance(item, ast.Tuple) and len(item.elts) == 2):
                        continue
                    key_node, value_node = item.elts
                    if not (isinstance(key_node, ast.Constant) and isinstance(key_node.value, str)):
                        continue
                    key = key_node.value
                    keys.append(key)
                    if isinstance(value_node, ast.Constant):
                        value = value_node.value
                        # SoCo's SOAP serializer ultimately stringifies primitive
                        # values using Python's str(), including True/False.
                        if value is None:
                            rendered = "None"
                        else:
                            rendered = str(value)
                        literals.append((key, rendered))
            out[action].append((tuple(keys), tuple(literals)))
    return out


def balanced_calls(text: str, marker: str = "sendCommand(") -> list[str]:
    calls: list[str] = []
    pos = 0
    while True:
        start = text.find(marker, pos)
        if start < 0:
            return calls
        i = start + len(marker)
        depth = 1
        quote: str | None = None
        escaped = False
        while i < len(text) and depth:
            ch = text[i]
            if quote is not None:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == quote:
                    quote = None
            else:
                if ch in {'"', "'"}:
                    quote = ch
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
            i += 1
        if depth == 0:
            calls.append(text[start + len(marker): i - 1])
        pos = max(i, start + 1)


def swift_calls() -> dict[str, list[tuple[tuple[str, ...], tuple[tuple[str, str], ...]]]]:
    out: dict[str, list[tuple[tuple[str, ...], tuple[tuple[str, str], ...]]]] = defaultdict(list)
    for path in SWIFT_DIR.glob("*.swift"):
        if path.name == "OriginalSoCoCommentary.swift":
            continue
        text = path.read_text(encoding="utf-8")
        for body in balanced_calls(text):
            match = re.match(r'\s*"([A-Za-z0-9_]+)"', body)
            if not match:
                continue
            action = match.group(1)
            args_match = re.search(r'\barguments\s*:\s*\[', body)
            keys: list[str] = []
            literals: list[tuple[str, str]] = []
            if args_match:
                start = args_match.end()
                depth = 1
                i = start
                quote: str | None = None
                escaped = False
                while i < len(body) and depth:
                    ch = body[i]
                    if quote is not None:
                        if escaped:
                            escaped = False
                        elif ch == "\\":
                            escaped = True
                        elif ch == quote:
                            quote = None
                    else:
                        if ch == '"':
                            quote = ch
                        elif ch == "[":
                            depth += 1
                        elif ch == "]":
                            depth -= 1
                    i += 1
                arg_text = body[start:i - 1]
                # Literal tuple keys are the compatibility surface we audit.
                tuple_re = re.compile(r'\(\s*"([^"\\]+)"\s*,\s*([^\)]*)\)')
                for tm in tuple_re.finditer(arg_text):
                    key, value_expr = tm.group(1), tm.group(2).strip()
                    keys.append(key)
                    vm = re.fullmatch(r'"((?:[^"\\]|\\.)*)"', value_expr, re.S)
                    if vm:
                        value = bytes(vm.group(1), "utf-8").decode("unicode_escape")
                        literals.append((key, value))
            out[action].append((tuple(keys), tuple(literals)))
    return out


def normalize(records):
    return {action: set(entries) for action, entries in records.items()}


def main() -> int:
    py = normalize(python_calls())
    sw = normalize(swift_calls())
    common = sorted(set(py) & set(sw))
    signature_mismatches: list[str] = []
    literal_mismatches: list[str] = []

    for action in common:
        py_sigs = {sig for sig, _ in py[action]}
        sw_sigs = {sig for sig, _ in sw[action]}
        # Swift may contain multiple variants/overloads. Every upstream
        # signature must be represented by a Swift signature. Empty signatures
        # are only meaningful for truly zero-argument upstream actions.
        missing = py_sigs - sw_sigs
        if missing:
            signature_mismatches.append(
                f"{action}: upstream signatures not represented in Swift: {sorted(missing)!r}; Swift={sorted(sw_sigs)!r}"
            )

        # Compare literals only when both sides have an otherwise identical
        # signature. Dynamic expressions are intentionally not compared.
        for sig, py_literals in py[action]:
            candidates = [lits for sw_sig, lits in sw[action] if sw_sig == sig]
            if not candidates:
                continue
            py_literal_map = dict(py_literals)
            for key, expected in py_literal_map.items():
                values = {dict(c).get(key) for c in candidates if key in dict(c)}
                if values and expected not in values:
                    literal_mismatches.append(
                        f"{action}.{key}: upstream literal {expected!r}, Swift literals {sorted(values)!r}"
                    )

    print(f"Upstream SOAP actions found: {len(py)}")
    print(f"Swift SOAP actions found: {len(sw)}")
    print(f"Actions compared in both implementations: {len(common)}")
    print(f"Signature mismatches: {len(signature_mismatches)}")
    for item in signature_mismatches:
        print(f"  - {item}")
    print(f"Literal mismatches: {len(literal_mismatches)}")
    for item in literal_mismatches:
        print(f"  - {item}")

    if signature_mismatches or literal_mismatches:
        return 1
    if len(common) < 60:
        print("ERROR: unexpectedly few overlapping service actions; audit parser may have regressed.")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
