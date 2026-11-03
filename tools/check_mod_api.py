#!/usr/bin/env python3
"""Type-check both trait mods against official Horizon in a private build workspace."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def downloaded(lock):
    return {
        (p["name"], p["version"], p["source"])
        for p in tomllib.loads(lock)["package"]
        if "source" in p
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=1)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    upstream = ROOT / ".upstream/horizon"
    manifest = json.loads((ROOT / "dist/manifest.json").read_text())
    scratch = ROOT / ".local-test"
    scratch.mkdir(exist_ok=True)
    original_lock = (upstream / "Cargo.lock").read_text()
    with tempfile.TemporaryDirectory(prefix="mod-api-", dir=scratch) as temporary:
        workspace = Path(temporary)
        members = []
        for mod in manifest["mods"]:
            identity = mod["id"]
            source = ROOT / mod["source"] / "mixins" / identity / "api"
            crate = workspace / identity
            shutil.copytree(source, crate)
            metadata = crate / "Cargo.toml"
            text, count = re.subn(
                r"(?m)^horizon-client = .*$",
                "horizon-client = { path = "
                + json.dumps(str(upstream / "crates/horizon-client"))
                + ", default-features = false }",
                metadata.read_text(),
            )
            assert count == 1
            metadata.write_text(text)
            members.append(identity)
        patches = tomllib.loads((upstream / "Cargo.toml").read_text())["patch"][
            "crates-io"
        ]
        text = (
            '[workspace]\nresolver = "2"\nmembers = '
            + json.dumps(members)
            + "\n\n[patch.crates-io]\n"
        )
        for name, patch in patches.items():
            text += (
                name
                + " = { path = "
                + json.dumps(str(upstream / patch["path"]))
                + " }\n"
            )
        text += "\n[profile.dev]\ndebug = 0\n"
        (workspace / "Cargo.toml").write_text(text)
        (workspace / "Cargo.lock").write_text(original_lock)
        env = dict(os.environ, CARGO_TARGET_DIR=str(ROOT / "target/native-api"))
        subprocess.run(
            ["cargo", "check", "--workspace", "--jobs", str(args.jobs)],
            cwd=workspace,
            env=env,
            check=True,
        )
        additional = downloaded((workspace / "Cargo.lock").read_text()) - downloaded(
            original_lock
        )
        assert not additional, (
            f"Native check resolved dependencies outside Horizon's lock: {additional}"
        )
    print(
        "Both native trait mods compile against official Horizon; no new registry dependencies"
    )


if __name__ == "__main__":
    main()
