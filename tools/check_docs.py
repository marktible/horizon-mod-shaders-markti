#!/usr/bin/env python3
"""Check current Markti documentation links and code examples, without executing examples."""

import ast
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def without_fences(text):
    return re.sub(r"```.*?```", "", text, flags=re.S)


def slug(text):
    text = (
        re.sub(r"!?\[([^]]+)\]\([^)]*\)", r"\1", text).replace("`", "").strip().lower()
    )
    return "".join(c for c in text if c.isalnum() or c in " _-").replace(" ", "-")


def anchors(path):
    seen = {}
    found = set()
    for line in without_fences(path.read_text()).splitlines():
        match = re.match(r"#{1,6} +(.+?)\s*#*$", line)
        if match:
            key = slug(match[1])
            n = seen.get(key, 0)
            seen[key] = n + 1
            found.add(key if not n else f"{key}-{n}")
    return found


def main():
    paths = [
        ROOT / "AGENTS.md",
        ROOT / "DEVELOPING.md",
        ROOT / "README.md",
        ROOT / "CHANGELOG.md",
        ROOT / "packs/markti/README.md",
        ROOT / "packs/markti-native/README.md",
        ROOT / "registry/README.md",
        ROOT / "reports/README.md",
        *sorted((ROOT / "docs").glob("*.md")),
    ]
    errors = []
    links = 0
    shell = 0
    python = 0
    for path in paths:
        source = path.read_text()
        for dest in re.findall(r"!?\[[^]]*\]\(([^)]+)\)", without_fences(source)):
            url = urlsplit(dest.strip().strip("<>"))
            if url.scheme or dest.startswith("//"):
                continue
            target = (
                (path.parent / unquote(url.path)).resolve()
                if url.path
                else path.resolve()
            )
            links += 1
            if not target.exists():
                errors.append(f"{path.relative_to(ROOT)}: missing {dest}")
            elif (
                url.fragment
                and target.suffix == ".md"
                and unquote(url.fragment) not in anchors(target)
            ):
                errors.append(f"{path.relative_to(ROOT)}: missing anchor {dest}")
        for lang, body in re.findall(r"```([^\n]*)\n(.*?)```", source, flags=re.S):
            if lang == "bash":
                result = subprocess.run(
                    ["bash", "-n"], input=body, text=True, capture_output=True
                )
                shell += 1
                if result.returncode:
                    errors.append(
                        f"{path.relative_to(ROOT)}: shell syntax: {result.stderr}"
                    )
            elif lang == "python":
                try:
                    ast.parse(body)
                    python += 1
                except SyntaxError as e:
                    errors.append(f"{path.relative_to(ROOT)}: Python syntax: {e}")
    report = {
        "documents": [str(p.relative_to(ROOT)) for p in paths],
        "local_links_checked": links,
        "shell_blocks_checked": shell,
        "python_blocks_checked": python,
        "errors": errors,
        "method": "Local link/anchor resolution, bash -n and ast.parse. Code examples were not executed against a player profile.",
    }
    target = ROOT / "reports/documentation.json"
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
