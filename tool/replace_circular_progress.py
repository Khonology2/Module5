#!/usr/bin/env python3
"""Replace CircularProgressIndicator(...) with CustomLogoLoader (one-off maintenance)."""

from __future__ import annotations

from pathlib import Path


def _balanced_close(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    while i < len(text):
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced parens")


def _replacement_for_inner(inner: str) -> str:
    if "strokeWidth" in inner:
        return "CustomLogoLoader.inline()"
    return "CustomLogoLoader()"


def _strip_leading_const_before(pos: int, text: str) -> tuple[int, bool]:
    """If `const` sits immediately before whitespace + identifier at pos, return start index."""
    j = pos - 1
    while j >= 0 and text[j] in " \t":
        j -= 1
    if j < 4:
        return pos, False
    if text[j - 4 : j + 1] != "const":
        return pos, False
    # ensure word boundary before const
    k = j - 5
    if k >= 0 and (text[k].isalnum() or text[k] == "_"):
        return pos, False
    start = j - 4
    while start > 0 and text[start - 1] in " \t":
        start -= 1
    return start, True


def transform(text: str) -> str:
    key = "CircularProgressIndicator"
    i = 0
    out: list[str] = []
    while True:
        pos = text.find(key, i)
        if pos == -1:
            out.append(text[i:])
            break

        lp = text.find("(", pos + len(key))
        if lp == -1:
            out.append(text[i : pos + len(key)])
            i = pos + len(key)
            continue

        expr_start, had_const = _strip_leading_const_before(pos, text)
        close_end = _balanced_close(text, lp)
        inner = text[lp + 1 : close_end - 1]
        repl = _replacement_for_inner(inner)
        if had_const and repl == "CustomLogoLoader()":
            repl = "const CustomLogoLoader()"

        out.append(text[i:expr_start])
        out.append(repl)
        i = close_end

    return "".join(out)


def ensure_import(text: str) -> str:
    needle = "custom_logo_loader.dart"
    if needle in text:
        return text
    lines = text.splitlines(keepends=True)
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = idx + 1
    lines.insert(
        insert_at,
        "import 'package:pdh/widgets/custom_logo_loader.dart';\n",
    )
    return "".join(lines)


def main() -> None:
    root = Path("lib")
    for path in sorted(root.rglob("*.dart")):
        if "backup" in path.name.lower():
            continue
        if path.name == "custom_logo_loader.dart":
            continue
        raw = path.read_text(encoding="utf-8")
        if "CircularProgressIndicator" not in raw:
            continue
        new_raw = ensure_import(transform(raw))
        if new_raw != raw:
            path.write_text(new_raw, encoding="utf-8")
            print("updated", path)


if __name__ == "__main__":
    main()
