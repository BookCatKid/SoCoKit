#!/usr/bin/env python3
"""Verify that OriginalSoCoCommentary.swift retains every upstream comment/docstring."""
from __future__ import annotations

import ast
import io
from pathlib import Path
import re
import sys
import tokenize

ROOT = Path(__file__).resolve().parents[1]
PY_ROOT = ROOT / "Reference" / "SoCo-Python" / "soco"
COMMENTARY = ROOT / "Sources" / "SoCoKit" / "OriginalSoCoCommentary.swift"


def swift_comment_lines(text: str) -> list[str]:
    return [line[3:] if line.startswith("// ") else line[2:] for line in text.splitlines() if line.startswith("//")]


def main() -> int:
    output = COMMENTARY.read_text(encoding="utf-8")
    output_lines = swift_comment_lines(output)
    missing: list[str] = []
    inline_count = 0
    doc_count = 0

    for path in sorted(PY_ROOT.rglob("*.py")):
        relative = path.relative_to(PY_ROOT).as_posix()
        source = path.read_text(encoding="utf-8")

        for token in tokenize.generate_tokens(io.StringIO(source).readline):
            if token.type != tokenize.COMMENT:
                continue
            inline_count += 1
            text = token.string[1:].lstrip()
            marker = f"[{relative}:{token.start[0]}] {text}"
            if marker not in output_lines:
                missing.append(marker)

        tree = ast.parse(source, filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            docstring = ast.get_docstring(node, clean=False)
            if docstring is None:
                continue
            doc_count += 1
            line = 1 if isinstance(node, ast.Module) else node.lineno
            header_re = re.compile(
                rf"^// \[{re.escape(relative)}:{line}\] .*docstring:\n",
                re.MULTILINE,
            )
            match = header_re.search(output)
            if match is None:
                missing.append(f"// [{relative}:{line}] <docstring marker>")
                continue

            actual_lines: list[str] = []
            tail = output[match.end():]
            for rendered in tail.splitlines():
                if rendered.startswith("// [") or rendered.startswith("// MARK:"):
                    break
                if rendered.startswith("// "):
                    actual_lines.append(rendered[3:])
                elif rendered == "//":
                    actual_lines.append("")
                elif rendered.strip() == "":
                    continue
                else:
                    break

            expected_lines = docstring.splitlines()
            while expected_lines and expected_lines[-1] == "":
                expected_lines.pop()
            while actual_lines and actual_lines[-1] == "":
                actual_lines.pop()
            if actual_lines != expected_lines:
                missing.append(
                    f"{relative}:{line} docstring content mismatch: "
                    f"expected {expected_lines!r}, got {actual_lines!r}"
                )

    marker_count = len(re.findall(r"^// \[[^]]+\.py:\d+\] ", output, re.MULTILINE))
    doc_marker_count = len(re.findall(r"^// \[[^]]+\.py:\d+\] .*docstring:", output, re.MULTILINE))

    print(f"upstream inline comments: {inline_count}")
    print(f"upstream docstrings:      {doc_count}")
    print(f"commentary markers:       {marker_count}")
    print(f"docstring markers:        {doc_marker_count}")

    if missing:
        print(f"ERROR: {len(missing)} commentary entries/lines are missing", file=sys.stderr)
        for item in missing[:50]:
            print(f"  {item}", file=sys.stderr)
        return 1
    if doc_marker_count != doc_count:
        print("ERROR: docstring marker count does not match upstream", file=sys.stderr)
        return 1
    if marker_count != inline_count + doc_count:
        print("ERROR: total marker count does not match comments + docstrings", file=sys.stderr)
        return 1

    print("OK: every upstream inline comment and docstring is preserved.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
