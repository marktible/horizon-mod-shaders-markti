#!/usr/bin/env python3
"""Install both Markti packs in a closed Horizon profile, with backups."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def active_program(name):
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if Path(os.readlink(proc / "exe")).name == name:
                return True
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            pass
    return False


def stage(target, data):
    with tempfile.NamedTemporaryFile(
        prefix=".markti-", dir=target.parent, delete=False
    ) as out:
        out.write(data)
        path = Path(out.name)
    path.chmod(target.stat().st_mode & 0o777 if target.exists() else 0o644)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-dir", required=True, type=Path)
    parser.add_argument("--pack", choices=["base", "ultra"], default="base")
    parser.add_argument("--format", choices=["glsl", "native"], default="native")
    parser.add_argument(
        "--keep-selected",
        action="store_true",
        help="Install artifacts without changing the selected pack",
    )
    parser.add_argument(
        "--launcher-dir",
        type=Path,
        help="Select the tested official version when the launcher is closed",
    )
    args = parser.parse_args()
    home = args.game_dir.resolve()
    if active_program("horizon-client"):
        raise RuntimeError("Close Horizon before installing its shader packs")
    graphics = home / "horizon-graphics.txt"
    options = home / "options.txt"
    if not graphics.is_file() or not options.is_file():
        raise RuntimeError("Choose an existing Horizon profile")
    manifest = json.loads((ROOT / "dist/manifest.json").read_text())
    selected = next(
        p
        for p in manifest["packs"]
        if p["preset"] == ("Performance" if args.pack == "base" else "UltraPerformance")
        and p.get("format", "glsl") == args.format
    )
    original = {graphics: graphics.read_bytes(), options: options.read_bytes()}
    backup = (
        ROOT
        / ".local-test/install-backups"
        / datetime.datetime.now().strftime("markti-%Y%m%d-%H%M%S-%f")
    )
    backup.mkdir(parents=True)
    for file in original:
        shutil.copy2(file, backup / file.name)
    folder = home / "shaderpacks"
    folder.mkdir(exist_ok=True)
    pending = []
    for pack in manifest["packs"]:
        source = ROOT / "dist" / pack["file"]
        data = source.read_bytes()
        if hashlib.sha256(data).hexdigest() != pack["sha256"]:
            raise RuntimeError("Pack checksum mismatch")
        target = folder / pack["file"]
        if target.exists():
            shutil.copy2(target, backup / target.name)
        pending.append((target, stage(target, data)))
    lines = original[graphics].decode().splitlines(keepends=True)
    seen = False
    new = []
    for line in lines:
        if line.startswith("pickedShaderPack:"):
            if seen:
                raise RuntimeError("Duplicate shader selection")
            if args.keep_selected:
                selected = {"file": line.partition(":")[2].strip()}
                new.append(line)
                seen = True
                continue
            seen = True
            line = (
                "pickedShaderPack:"
                + selected["file"]
                + ("\r\n" if line.endswith("\r\n") else "\n")
            )
        new.append(line)
    if not seen and args.keep_selected:
        selected = {"file": ""}
    elif not seen:
        if new and not new[-1].endswith("\n"):
            new[-1] += "\n"
        new.append("pickedShaderPack:" + selected["file"] + "\n")
    pending.append((graphics, stage(graphics, "".join(new).encode())))
    if any(file.read_bytes() != data for file, data in original.items()):
        raise RuntimeError("Player settings changed during installation")
    for target, temporary in pending:
        os.replace(temporary, target)
    retired = []
    for legacy in sorted(folder.glob("Radiance-*")):
        if legacy.is_file() and (legacy.suffix in [".zip", ".txt"]):
            shutil.move(legacy, backup / legacy.name)
            retired.append(legacy.name)
    launcher_selection = None
    if args.launcher_dir:
        launcher = args.launcher_dir.resolve()
        settings = launcher / "settings.json"
        version = manifest["tested_horizon"]
        if active_program("horizon-launcher"):
            launcher_selection = {
                "pending": version,
                "reason": "Launcher is open; select this official version in its UI.",
            }
        elif (
            settings.is_file()
            and (launcher / "versions" / version / ".installed").is_file()
        ):
            data = settings.read_bytes()
            config = json.loads(data)
            if config.get("instance"):
                raise RuntimeError(
                    "Select the official version for the active instance in the launcher"
                )
            shutil.copy2(settings, backup / "launcher-settings.json")
            previous = config.get("selected")
            config["selected"] = version
            os.replace(
                stage(settings, (json.dumps(config, indent=2) + "\n").encode()),
                settings,
            )
            launcher_selection = {"previous": previous, "selected": version}
    report = {
        "name": manifest["name"],
        "version": manifest["version"],
        "installed": [p["file"] for p in manifest["packs"]],
        "selected": selected["file"],
        "game_dir": str(home),
        "backup": str(backup),
        "retired": retired,
        "launcher": launcher_selection,
        "options_unchanged": options.read_bytes() == original[options],
    }
    (ROOT / "reports" / f"installation-markti-{manifest['version']}.json").write_text(
        json.dumps(report, indent=2) + "\n"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
