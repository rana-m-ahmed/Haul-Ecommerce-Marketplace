from __future__ import annotations

import re


TOKEN_RE = re.compile(r"[a-z0-9]+")


def search_tokens(*parts: str | list[str]) -> list[str]:
    flattened: list[str] = []
    for part in parts:
        if isinstance(part, list):
            flattened.extend(part)
        else:
            flattened.append(part)
    raw = " ".join(flattened).lower()
    return sorted(set(TOKEN_RE.findall(raw)))
