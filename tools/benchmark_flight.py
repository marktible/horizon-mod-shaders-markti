#!/usr/bin/env python3
"""Benchmark a repeatable forest flight in a fresh private seed-0 world.

Raw frames and session details stay in the chosen output folder, never a player
save. Use --artifacts to compare older releases with the same native executable.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

from control import call, capture, play

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", required=True, type=Path)
    parser.add_argument("--resources", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--artifacts", type=Path, default=ROOT / "dist")
    parser.add_argument("--scale", type=int, default=100)
    parser.add_argument("--fsr1", action="store_true")
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--chunk-updates", type=int, default=0)
    parser.add_argument("--upload-budget-kib", type=int, default=0)
    args = parser.parse_args()
    for proc in Path("/proc").iterdir():
        if proc.name.isdigit():
            try:
                if Path(os.readlink(proc / "exe")).name == "horizon-client":
                    raise RuntimeError("Close other game sessions before measuring frame times")
            except OSError:
                pass
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    command = ["python3", str(ROOT / "tools/preview.py"), "--client", str(args.client.resolve()),
        "--resources", str(args.resources.resolve()), "--output", str(output),
        "--pack", "ultra", "--width", "1920", "--height", "1080", "--fps", "260", "--native-mods",
        "--scale", str(args.scale), "--workers", str(args.workers), "--chunk-updates", str(args.chunk_updates),
        "--upload-budget-kib", str(args.upload_budget_kib), "--artifacts", str(args.artifacts.resolve())]
    if args.fsr1:
        command.append("--fsr1")
    env = os.environ.copy()
    env.pop("HORIZON_SHADER_PACK_TIMING", None)
    subprocess.run(command, cwd=ROOT, env=env, check=True, stdout=subprocess.DEVNULL)
    session = json.loads((output / "session.json").read_text())
    os.environ["HORIZON_CONTROL"] = str(Path(session["session"]) / "control.sock")
    records = {"settings": {"scale": args.scale, "fsr1": args.fsr1, "workers": args.workers,
        "chunk_updates": args.chunk_updates, "upload_budget_kib": args.upload_budget_kib,
        "render_distance": 12, "window": [1920,1080], "vsync": False, "frame_cap": 260}, "cases": []}
    try:
        deadline = time.monotonic() + 120
        while True:
            try:
                state = call("state", timeout=5)
                if state.get("screen") == "playing": break
            except (OSError, RuntimeError): pass
            if time.monotonic() > deadline: raise RuntimeError("Private game did not become ready")
            time.sleep(0.5)
        for cmd in ("command gamemode spectator", "command gamerule advance_time false", "time 3000", "tp -24.5 100 2.5", "look 0 30"):
            call(cmd)
        # Wait for spawn's terrain to finish, without pregenerating the flight route.
        quiet = None
        while time.monotonic() < deadline:
            status = call("status")
            stable = status.get("chunks",0) >= 600 and status.get("pending_uploads",0) == 0 and not any(status.get("streaming",{}).values())
            quiet = (quiet or time.monotonic()) if stable else None
            if quiet and time.monotonic() - quiet > 3: break
            time.sleep(0.5)
        else: raise RuntimeError("Spawn terrain did not settle before benchmark")
        log = (output / "client.log").read_text()
        if "refused:" in log or "panicked" in log: raise RuntimeError("Shader/runtime failed; invalid benchmark")
        for name, cmd in [("stationary", "bench 8"),
            ("cold-flight", "fly -24.5 100 2.5 -24.5 100 482.5 24 30 raw"),
            ("warm-return", "fly -24.5 100 482.5 -24.5 100 2.5 24 30 raw")]:
            before = call("status")
            stats = call(cmd, timeout=60)
            after = call("status")
            records["cases"].append({"name": name, "stats": stats,
                "stream_before": {k:before.get(k) for k in ("generated_chunks","pending_uploads","streaming")},
                "stream_after": {k:after.get(k) for k in ("generated_chunks","pending_uploads","streaming")}})
            (output / "results.json").write_text(json.dumps(records,indent=2)+"\n")
            print(name, json.dumps({k:stats[k] for k in ("avg_fps","p50_ms","p95_ms","p99_ms","max_ms")}), flush=True)
        capture(output / "forest.png")
    finally:
        try: call("quit", timeout=20)
        except (OSError,RuntimeError): pass


if __name__ == "__main__":
    main()
