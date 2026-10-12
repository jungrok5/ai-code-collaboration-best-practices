#!/usr/bin/env python3
"""Check diagram labels and JavaScript copy with the pinned ai-design checker."""
import ast
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET


def visible_copy():
    script = Path("docs/site/drawio.js").read_text(encoding="utf-8")
    paragraphs = []
    for line in script.splitlines():
        if re.match(r"\s*\[(?:'|\")\d+(?:'|\"),", line):
            step = ast.literal_eval(line.strip().removesuffix(","))
            if len(step) != 6 or not all(isinstance(value, str) for value in step):
                raise ValueError("Expected a six-string diagram step")
            # Commands and source paths are code, not prose.
            paragraphs.extend(step[1:4])
    if not paragraphs:
        raise ValueError("No diagram steps found; update the copy extractor")
    literal = r"('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")"
    for pattern in (r"title:\s*" + literal, r"textContent\s*=\s*" + literal):
        paragraphs.extend(ast.literal_eval(value) for value in re.findall(pattern, script))
    for path in sorted(Path("docs/site/data").glob("*.drawio")):
        root = ET.parse(path).getroot()
        paragraphs.extend(page.get("name", "") for page in root.iter("diagram"))
        paragraphs.extend(cell.get("value", "") for cell in root.iter("mxCell"))
    return "\n\n".join(paragraphs) + "\n"


if __name__ == "__main__":
    result = subprocess.run(
        ["scripts/ai-design.sh", "style", "-", "--stdin-name", "docs/site/visual-copy.md"],
        input=visible_copy(), text=True, check=False,
    )
    raise SystemExit(result.returncode)
