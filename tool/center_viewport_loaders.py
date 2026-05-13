#!/usr/bin/env python3
"""Replace Center(child: CustomLogoLoader()) with CustomLogoLoader(centerInViewport: true)."""

from __future__ import annotations

import re
from pathlib import Path


def transform(text: str) -> str:
    # Multiline: const Center( \n child: CustomLogoLoader(), \n )
    text = re.sub(
        r"const\s+Center\(\s*\n\s*child:\s*CustomLogoLoader\(\),\s*\n\s*\)",
        "const CustomLogoLoader(centerInViewport: true),",
        text,
    )
    text = re.sub(
        r"Center\(\s*\n\s*child:\s*CustomLogoLoader\(\),\s*\n\s*\)",
        "CustomLogoLoader(centerInViewport: true),",
        text,
    )
    # Single-line patterns
    text = text.replace(
        "const Center(child: CustomLogoLoader())",
        "const CustomLogoLoader(centerInViewport: true)",
    )
    text = text.replace(
        "Center(child: CustomLogoLoader())",
        "CustomLogoLoader(centerInViewport: true)",
    )
    return text


def main() -> None:
    root = Path("lib")
    for path in sorted(root.rglob("*.dart")):
        raw = path.read_text(encoding="utf-8")
        if "Center(child: CustomLogoLoader()" not in raw and "child: CustomLogoLoader()," not in raw:
            continue
        if "CustomLogoLoader()" not in raw:
            continue
        new_raw = transform(raw)
        if new_raw != raw:
            path.write_text(new_raw, encoding="utf-8")
            print("updated", path)


if __name__ == "__main__":
    main()
