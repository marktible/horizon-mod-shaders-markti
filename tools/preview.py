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
    parser.add_argument("--format", choices=["glsl", "native"], default="native")
    parser.add_argument(
        "--scale",
        type=int,
        default=100,
        help="Private test render scale, 50..200 percent; default 100",
    )
    parser.add_argument(
        "--source",
        action="store_true",
        help="Link editable Markti source as Markti Dev",
    )
    parser.add_argument(
        "--source-path",
        type=Path,
        help="Preview another editable GLSL or native shader folder as Markti Dev",
    )
    parser.add_argument("--visible", action="store_true")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument(
        "--fps", type=int, default=12, help="Private frame cap; 260 for benchmarking"
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=2,
        help="Chunk workers; 0 follows Horizon's automatic choice",
    )
    parser.add_argument("--native-mods", action="store_true", help="Install source bundles for a native API preview")
    parser.add_argument("--mod-settings-from", type=Path, help="Closed private preview's horizon-mods/.horizon-mod-data folder")
    parser.add_argument("--fsr1", action="store_true", help="Enable FSR 1 in this private native-mod preview")
    parser.add_argument("--chunk-updates", type=int, default=0)
    parser.add_argument("--upload-budget-kib", type=int, default=0)
    parser.add_argument("--artifacts", type=Path, default=ROOT / "dist", help="Release directory for private before/after comparisons")
    args = parser.parse_args()
    if not 50 <= args.scale <= 200:
        parser.error("--scale must be between 50 and 200")
    if min(args.width, args.height, args.fps) <= 0:
        parser.error("--width, --height and --fps must be positive")
    if min(args.workers, args.chunk_updates, args.upload_budget_kib) < 0:
        parser.error("worker and upload limits cannot be negative")
    if args.fsr1 and (not args.native_mods or args.format != "native"):
        parser.error("--fsr1 needs --native-mods and --format native")
    if args.mod_settings_from and not args.native_mods:
        parser.error("--mod-settings-from needs --native-mods")
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
    manifest = json.loads((args.artifacts / "manifest.json").read_text())
    for pack in manifest["packs"]:
        shutil.copy2(args.artifacts / pack["file"], home / "shaderpacks" / pack["file"])
    if args.native_mods:
        (home / "horizon-native-mods").mkdir()
        for mod in manifest["mods"]:
            shutil.copy2(args.artifacts / mod["file"], home / "horizon-native-mods" / mod["file"])
            settings = home / "horizon-mods/.horizon-mod-data" / mod["id"]
            if args.mod_settings_from:
                for name in ("fsr1", "fsr1_sharpness"):
                    source = args.mod_settings_from / mod["id"] / name
                    if source.is_file():
                        settings.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(source, settings / name)
            if args.fsr1:
                settings.mkdir(parents=True, exist_ok=True)
                (settings / "fsr1").write_text("1")
    selected = next(
        p["file"]
        for p in manifest["packs"]
        if p["preset"] == ("Performance" if args.pack == "base" else "UltraPerformance")
        and p.get("format", "glsl") == args.format
    )
    if args.source or args.source_path:
        source = (
            args.source_path.resolve() if args.source_path else ROOT / "packs/markti"
        )
        if (
            not (source / "shaders").is_dir()
            and not (source / "horizon-shaders.toml").is_file()
        ):
            raise RuntimeError(
                "Source folder has no GLSL shaders or native shader manifest"
            )
        selected = "Markti Dev"
        (home / "shaderpacks" / selected).symlink_to(source, target_is_directory=True)
    if args.settings_from:
        for pack in manifest["packs"]:
            sidecar = pack["file"] + ".txt"
            p = args.settings_from.resolve() / sidecar
            if p.is_file():
                shutil.copy2(p, home / "shaderpacks" / sidecar)
    (home / "horizon-graphics.txt").write_text(
        f"preset:custom\nresolutionScale:{args.scale}\ngraphicsApi:vulkan\npickedShaderPack:"
        + selected
        + f"\nfxaa:false\ntaa:false\nlod:0\nworkers:{args.workers}\nchunkUpdates:{args.chunk_updates}\nuploadBudgetKiB:{args.upload_budget_kib}\nupscaling:native\nframeGeneration:off\n"
    )
    (home / "options.txt").write_text(
        f"renderDistance:12\nsimulationDistance:12\nmaxFps:{args.fps}\nenableVsync:false\ninactivityFpsLimit:minimized\nbobView:false\nguiScale:1\n"
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
        str(args.width),
        "--height",
        str(args.height),
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
