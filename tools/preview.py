#!/usr/bin/env python3
"""Launch a Markti preview using an official client and fresh private data homes."""

import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--client",
        type=Path,
        required=True,
        help="Installed official Horizon executable",
    )
    parser.add_argument(
        "--resources",
        type=Path,
        required=True,
        help="Matching prepared resource directory",
    )
    parser.add_argument(
        "--world-copy", type=Path, help="Closed save copied into private storage"
    )
    parser.add_argument(
        "--settings-from",
        type=Path,
        help="Closed preview shaderpacks folder supplying Markti option sidecars",
    )
    parser.add_argument("--output", type=Path, default=ROOT / ".local-test/markti")
    parser.add_argument("--pack", choices=["base", "ultra"], default="base")
    parser.add_argument(
        "--source",
        action="store_true",
        help="Link editable Markti source as Markti Dev",
    )
    parser.add_argument("--visible", action="store_true")
    args = parser.parse_args()
    client = args.client.resolve()
    resources = args.resources.resolve()
    out = args.output.resolve()
    if not client.is_file() or not (resources / "horizon-resources.json").is_file():
        raise RuntimeError("Choose an official client and matching prepared resources")
    if (client.parent / "radiance-client.json").exists():
        raise RuntimeError(
            "Use an unmodified official Horizon client for Markti validation"
        )
    if args.world_copy:
        if not (args.world_copy / "level.dat").is_file():
            raise RuntimeError("World copy has no level.dat")
        for p in Path("/proc").iterdir():
            if not p.name.isdigit():
                continue
            try:
                if Path(os.readlink(p / "exe")).name == "horizon-client":
                    raise RuntimeError("Close Horizon before copying a save")
            except (FileNotFoundError, PermissionError, ProcessLookupError):
                pass
    session = Path(tempfile.mkdtemp(prefix="horizon-markti-"))
    out.mkdir(parents=True, exist_ok=True)
    for name in ["game", "launcher", "data", "config", "trash", "clipboard", "desktop"]:
        (session / name).mkdir()
    home = session / "game"
    (home / "saves").mkdir()
    (home / "shaderpacks").mkdir()
    if args.world_copy:
        shutil.copytree(
            args.world_copy.resolve(),
            home / "saves/MarktiPreview",
            ignore=shutil.ignore_patterns("session.lock"),
        )
    manifest = json.loads((ROOT / "dist/manifest.json").read_text())
    for pack in manifest["packs"]:
        shutil.copy2(ROOT / "dist" / pack["file"], home / "shaderpacks" / pack["file"])
    selected = next(
        p["file"]
        for p in manifest["packs"]
        if p["preset"] == ("Performance" if args.pack == "base" else "UltraPerformance")
    )
    if args.source:
        selected = "Markti Dev"
        (home / "shaderpacks" / selected).symlink_to(
            ROOT / "packs/markti", target_is_directory=True
        )
    if args.settings_from:
        for pack in manifest["packs"]:
            sidecar = pack["file"] + ".txt"
            p = args.settings_from.resolve() / sidecar
            if p.is_file():
                shutil.copy2(p, home / "shaderpacks" / sidecar)
    (home / "horizon-graphics.txt").write_text(
        "preset:custom\nresolutionScale:100\ngraphicsApi:vulkan\npickedShaderPack:"
        + selected
        + "\nfxaa:false\ntaa:false\nlod:0\nworkers:2\nupscaling:native\nframeGeneration:off\n"
    )
    (home / "options.txt").write_text(
        "renderDistance:12\nsimulationDistance:8\nmaxFps:12\nenableVsync:false\ninactivityFpsLimit:minimized\nbobView:false\nguiScale:1\n"
    )
    private = {
        "HORIZON_HOME": str(home),
        "HORIZON_LAUNCHER_HOME": str(session / "launcher"),
        "XDG_DATA_HOME": str(session / "data"),
        "XDG_CONFIG_HOME": str(session / "config"),
        "HORIZON_LAUNCHER_TRASH": str(session / "trash"),
        "HORIZON_LAUNCHER_CLIPBOARD": str(session / "clipboard"),
        "HORIZON_LAUNCHER_DESKTOP": str(session / "desktop"),
        "HORIZON_CONTROL": str(session / "control.sock"),
        "HORIZON_NO_AUDIO": "1",
        "HORIZON_LAUNCHER_NO_SELF_UPDATE": "1",
        "WINIT_UNIX_BACKEND": "x11",
    }
    env = os.environ.copy()
    env.update(private)
    for key in ["WAYLAND_DISPLAY", "HORIZON_SHADER_PACK", "HORIZON_FRAMEGEN_DEBUG"]:
        env.pop(key, None)
    (out / "env.sh").write_text(
        "".join("export " + k + "=" + shlex.quote(v) + "\n" for k, v in private.items())
        + "unset WAYLAND_DISPLAY HORIZON_SHADER_PACK HORIZON_FRAMEGEN_DEBUG\n"
    )
    command = [
        str(client),
        "--resources",
        str(resources),
        "--game-dir",
        str(home),
        "--control-socket",
        private["HORIZON_CONTROL"],
        "--world",
        "MarktiPreview",
        "--creative",
        "--width",
        "1280",
        "--height",
        "720",
    ]
    if not args.visible:
        command.append("--offscreen")
    with (out / "client.log").open("w") as log:
        process = subprocess.Popen(
            command,
            cwd=home,
            env=env,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    record = {
        "session": str(session),
        "client": str(client),
        "resources": str(resources),
        "pid": process.pid,
        "world_copy": str(args.world_copy.resolve()) if args.world_copy else None,
        "command": command,
    }
    (out / "session.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, indent=2))
    print("Environment:", out / "env.sh")


if __name__ == "__main__":
    main()
