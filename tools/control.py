#!/usr/bin/env python3
"""Development control for the isolated Horizon session made during shader testing.

HORIZON_CONTROL must explicitly name the test socket. No global game home is used.
"""

import json
import os
from pathlib import Path
import socket
import sys
import time


def call(command, timeout=90):
    address = os.environ["HORIZON_CONTROL"]
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(timeout)
        sock.connect(address)
        sock.sendall((command + "\n").encode())
        with sock.makefile() as reply:
            value = json.loads(reply.readline())
    if "error" in value:
        raise RuntimeError(value)
    return value


def play():
    for _ in range(10):
        if call("state").get("screen") == "playing":
            return
        call("key esc tap")
        time.sleep(0.05)
    raise RuntimeError("Could not leave the menu")


def capture(path):
    path = Path(path).resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    before = path.stat().st_mtime_ns if path.exists() else 0
    reply = call("screenshot " + str(path))
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if path.exists() and path.stat().st_mtime_ns != before:
            # PNG encoding finishes shortly after the file is created.
            data = path.read_bytes()
            if data.endswith(b"\x00\x00\x00\x00IEND\xaeB`\x82"):
                return reply
        time.sleep(0.03)
    raise RuntimeError(f"Screenshot was not written: {path}")


if __name__ == "__main__":
    if sys.argv[1:] == ["play"]:
        play()
    elif len(sys.argv) == 3 and sys.argv[1] == "capture":
        print(json.dumps(capture(sys.argv[2])))
    else:
        print(json.dumps(call(" ".join(sys.argv[1:])), indent=2))
