from __future__ import annotations

import re


TOKEN_RE = re.compile(r"[a-z0-9]+")


def search_tokens(name: str, tags: list[str]) -> list[str]:
    raw = " ".join([name, *tags]).lower()
    return sorted(set(TOKEN_RE.findall(raw)))
