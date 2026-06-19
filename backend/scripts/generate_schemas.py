from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "progress" / "01_API_CONTRACT.yaml"
OUTPUT_PATH = ROOT / "backend" / "app" / "schemas" / "generated.py"


def load_contract() -> dict[str, Any]:
    with CONTRACT_PATH.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def ref_name(ref: str) -> str:
    return ref.rsplit("/", 1)[-1]


def literal(values: list[Any]) -> str:
    rendered = ", ".join(repr(value) for value in values)
    return f"Literal[{rendered}]"


def annotation(schema: dict[str, Any]) -> str:
    nullable = schema.get("nullable", False)
    if "allOf" in schema and len(schema["allOf"]) == 1:
        inner = annotation(schema["allOf"][0])
        return f"{inner} | None" if nullable else inner
    if "$ref" in schema:
        inner = ref_name(schema["$ref"])
        return f"{inner} | None" if nullable else inner
    if "enum" in schema:
        inner = literal(schema["enum"])
        return f"{inner} | None" if nullable else inner

    schema_type = schema.get("type", "object")
    schema_format = schema.get("format")
    if schema_type == "array":
        inner = annotation(schema.get("items", {"type": "object"}))
        result = f"list[{inner}]"
    elif schema_type == "integer":
        result = "int"
    elif schema_type == "number":
        result = "float"
    elif schema_type == "boolean":
        result = "bool"
    elif schema_type == "string" and schema_format == "date-time":
        result = "datetime"
    elif schema_type == "string":
        result = "str"
    elif schema_type == "object":
        result = "dict[str, Any]"
    else:
        result = "Any"
    return f"{result} | None" if nullable else result


def model_base(schema: dict[str, Any]) -> str:
    all_of = schema.get("allOf")
    if all_of and len(all_of) == 1 and "$ref" in all_of[0]:
        return ref_name(all_of[0]["$ref"])
    return "BaseModel"


def field_line(name: str, schema: dict[str, Any], required: set[str]) -> str:
    type_hint = annotation(schema)
    if name in required and not schema.get("nullable", False):
        return f"    {name}: {type_hint}"
    return f"    {name}: {type_hint} = None"


def generate_model(name: str, schema: dict[str, Any]) -> str:
    base = model_base(schema)
    properties = schema.get("properties", {})
    required = set(schema.get("required", []))
    lines = [f"class {name}({base}):"]
    if not properties:
        lines.append("    pass")
    else:
        for field_name, field_schema in properties.items():
            lines.append(field_line(field_name, field_schema, required))
    return "\n".join(lines)


def main() -> None:
    contract = load_contract()
    schemas = contract["components"]["schemas"]
    lines = [
        '"""Generated from progress/01_API_CONTRACT.yaml. Do not edit by hand."""',
        "from __future__ import annotations",
        "",
        "from datetime import datetime",
        "from typing import Any, Literal",
        "",
        "from pydantic import BaseModel, ConfigDict",
        "",
        "",
        "class ContractModel(BaseModel):",
        "    model_config = ConfigDict(extra='forbid')",
        "",
    ]

    for name, schema in schemas.items():
        if schema.get("type") == "string" and "enum" in schema:
            lines.append(f"{name} = {literal(schema['enum'])}")
            lines.append("")
            continue
        model_text = generate_model(name, schema).replace("(BaseModel)", "(ContractModel)")
        lines.append(model_text)
        lines.append("")

    OUTPUT_PATH.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
