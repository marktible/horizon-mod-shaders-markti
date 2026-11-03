#!/usr/bin/env python3
"""Reload the currently selected development pack in the isolated test client."""

from control import call, play

call("options shader-packs")
ui = call("ui")
active = next(w for w in ui["widgets"] if w.get("label", "").endswith(": ON"))
call("click " + active["id"])
call("click " + active["id"])
play()
