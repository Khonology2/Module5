#!/usr/bin/env python3
"""Inject BACKEND_BASE_URL into build/web/index.html for production SSO."""
import os
import re
import sys
from pathlib import Path


def main() -> int:
    url = (os.environ.get("BACKEND_BASE_URL") or "").strip().rstrip("/")
    if not url:
        print("BACKEND_BASE_URL is empty; skipping meta injection", file=sys.stderr)
        return 0

    path = Path("build/web/index.html")
    if not path.is_file():
        print(f"Missing {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    pattern = r'(<meta\s+name="pdh-backend-base-url"\s+content=")[^"]*(")'
    if not re.search(pattern, text):
        print("pdh-backend-base-url meta tag not found in index.html", file=sys.stderr)
        return 1

    path.write_text(re.sub(pattern, rf"\1{url}\2", text, count=1), encoding="utf-8")
    print(f"Injected BACKEND_BASE_URL into {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
