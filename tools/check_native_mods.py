#!/usr/bin/env python3
"""Verify the GitHub-discoverable sources and test both embedded native installers."""

import json
from pathlib import Path
import subprocess
import tempfile
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    manifest = json.loads((ROOT / "dist/manifest.json").read_text())
    for mod in manifest["mods"]:
        source = ROOT / mod["source"]
        with zipfile.ZipFile(ROOT / "dist" / mod["file"]) as archive:
            packed = {name: archive.read(name) for name in archive.namelist()}
        unpacked = {
            p.relative_to(source).as_posix(): p.read_bytes()
            for p in source.rglob("*")
            if p.is_file()
        }
        assert packed == unpacked, f"{mod['id']}: GitHub source differs from .hnmod"
        identity = json.loads(packed["horizon-native.json"])
        assert identity["id"] == mod["id"] and identity["hooks"] == 326
        prefix = f"mixins/{mod['id']}/"
        mixin = tomllib.loads(packed[prefix + "horizon-mixin.toml"].decode())
        assert mixin["mod"]["version"] == manifest["version"]
        crate = source / prefix / "api"
        assert (crate / "src/installer.rs").read_bytes() == (
            ROOT / "native-mod/installer.rs"
        ).read_bytes()
        for shared in ("fsr.rs", "runtime.rs"):
            assert (crate / "src" / shared).read_bytes() == (
                ROOT / "native-mod" / shared
            ).read_bytes(), f"Stale shared native runtime: {shared}"
        assert (crate / "data/fsr1_rcas.wgsl").read_bytes() == (
            ROOT / "native-mod/fsr1_rcas.wgsl"
        ).read_bytes()
        assert (crate / "data/FSR1-LICENSE.txt").read_bytes() == (
            ROOT / "packs/markti-native/LICENSE.txt"
        ).read_bytes()
        shader = next(
            p
            for p in manifest["packs"]
            if p["format"] == "native" and p["preset"] == mod["preset"]
        )
        with zipfile.ZipFile(ROOT / "dist" / shader["file"]) as archive:
            shader_files = {n: archive.read(n) for n in archive.namelist()}
        embedded = {
            p.relative_to(crate / "data/pack").as_posix(): p.read_bytes()
            for p in (crate / "data/pack").rglob("*")
            if p.is_file()
        }
        assert embedded == shader_files, "Mod and standalone shader payloads differ"
        # The installer has only std dependencies, so no full game build is needed here.
        with tempfile.TemporaryDirectory(prefix="markti-mod-check-") as scratch:
            test = Path(scratch) / "installer-test"
            subprocess.run(
                [
                    "rustc",
                    "--edition=2024",
                    "--test",
                    str(crate / "src/payload.rs"),
                    "-o",
                    str(test),
                ],
                check=True,
            )
            subprocess.run([str(test)], check=True)
            # Exercise the real embedded payload in a private home with player settings.
            runner = Path(scratch) / "install.rs"
            runner.write_text(
                f"#[path = {json.dumps(str(crate / 'src/payload.rs'))}] mod bundled;\n"
                "fn main() { bundled::install(std::path::Path::new(&std::env::args().nth(1).unwrap())).unwrap(); }\n"
            )
            executable = Path(scratch) / "install"
            subprocess.run(
                ["rustc", "--edition=2024", str(runner), "-o", str(executable)],
                check=True,
            )
            home = Path(scratch) / "game"
            home.mkdir()
            options = home / "horizon-graphics.txt"
            options.write_bytes(
                b"pickedShaderPack:other.hshader\nresolutionScale:100\n"
            )
            subprocess.run([str(executable), str(home)], check=True)
            installed = home / "shaderpacks" / mod["shader_folder"]
            assert {p.name: p.read_bytes() for p in installed.iterdir()} == shader_files
            assert (
                options.read_bytes()
                == b"pickedShaderPack:other.hshader\nresolutionScale:100\n"
            )
        print(
            f"{mod['id']}: discoverable source, archive identity, shader payload and installer passed"
        )


if __name__ == "__main__":
    main()
