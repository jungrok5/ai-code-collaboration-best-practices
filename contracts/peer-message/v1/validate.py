"""Validate peer-message v1 examples (and any task JSON files given) against task.schema.json.

Usage: python3 contracts/peer-message/v1/validate.py [file.json ...]
Needs the `jsonschema` package (pip install jsonschema).
"""
import json
import pathlib
import sys

from jsonschema import Draft202012Validator, FormatChecker

HERE = pathlib.Path(__file__).resolve().parent
schema = json.loads((HERE / "task.schema.json").read_text(encoding="utf-8"))
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())
files = [pathlib.Path(p) for p in sys.argv[1:]] or sorted((HERE / "examples").glob("*.json"))
failed = 0
for f in files:
    errors = sorted(validator.iter_errors(json.loads(f.read_text(encoding="utf-8"))), key=lambda e: list(e.path))
    for e in errors:
        print(f"{f}: {'/'.join(map(str, e.path)) or '<root>'}: {e.message}")
    failed += bool(errors)
    if not errors:
        print(f"ok {f}")
sys.exit(1 if failed else 0)
