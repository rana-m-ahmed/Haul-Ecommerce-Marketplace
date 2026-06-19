from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml


CONTRACT_PATH = Path(__file__).resolve().parents[3] / "progress" / "01_API_CONTRACT.yaml"


@lru_cache
def contract() -> dict[str, Any]:
    with CONTRACT_PATH.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def response_example(path: str, method: str, example: str = "success") -> dict[str, Any]:
    operation = contract()["paths"][path][method]
    for response in operation["responses"].values():
        examples = response.get("content", {}).get("application/json", {}).get("examples", {})
        if example in examples:
            return examples[example]["value"]
    raise KeyError(f"No {example!r} example for {method.upper()} {path}")


def request_example(path: str, method: str, example: str = "request") -> dict[str, Any]:
    examples = (
        contract()["paths"][path][method]
        .get("requestBody", {})
        .get("content", {})
        .get("application/json", {})
        .get("examples", {})
    )
    if example not in examples:
        raise KeyError(f"No {example!r} request example for {method.upper()} {path}")
    return examples[example]["value"]
