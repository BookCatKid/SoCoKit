#!/usr/bin/env python3
"""Run SoCoKit's complete deterministic verification gate."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args: str, stdout=None) -> None:
    print("+", " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, check=True, stdout=stdout)


def main() -> int:
    run("swift", "test", "--parallel")
    run("swift", "build", "-c", "release")
    with open(ROOT / ".build" / "package-dump.json", "w", encoding="utf-8") as handle:
        run("swift", "package", "dump-package", stdout=handle)
    run(sys.executable, "Scripts/verify_public_api.py")
    run(sys.executable, "Scripts/verify_service_actions.py")
    run(sys.executable, "Scripts/verify_commentary.py")
    print("All deterministic SoCoKit verification gates passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
