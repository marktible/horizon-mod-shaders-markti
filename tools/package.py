#!/usr/bin/env python3
"""Build the two standalone Markti shader packs; no native client is built."""

from pathlib import Path
import hashlib
import json
import re
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "packs/markti"
NATIVE_SOURCE = ROOT / "packs/markti-native"
VERSION = "1.1.0"
TESTED_HORIZON = "nightly-2026-11-03-f42ef42"
PRESETS = {
    "UltraPerformance": {
        "name": "Markti Shaders Ultra Performance",
        "file": "Markti Shaders Ultra Performance.zip",
        "settings": {
            "WATER_REFRACTION": "1",
            "WATER_CLARITY": "1.0",
            "WATER_CAUSTICS": "0",
            "COMPACT_WATER_BUFFER": "1",
            "WATER_RIPPLE_STRENGTH": "0.5",
            "SURFACE_REFLECTIONS": "0",
            "SHADOW_RESOLUTION": "1024",
            "SHADOW_DISTANCE": "48.0",
            "SHADOW_FILTER": "0",
            "BLOOM_STRENGTH": "0.08",
            "SSR_STEPS": "12",
            "AO_SAMPLES": "4",
            "AO_STRENGTH": "0.0",
            "SHADOW_TEMPORAL": "0",
            "HELD_LIGHTS": "1",
            "COLORED_LIGHTS": "0",
        },
    },
    "Performance": {
        "name": "Markti Shader",
        "file": "Markti Shader.zip",
        "settings": {
            "WATER_REFRACTION": "1",
            "WATER_CLARITY": "1.0",
            "WATER_CAUSTICS": "1",
            "COMPACT_WATER_BUFFER": "1",
            "WATER_RIPPLE_STRENGTH": "0.85",
            "SURFACE_REFLECTIONS": "1",
            "SHADOW_RESOLUTION": "2048",
            "SHADOW_DISTANCE": "56.0",
            "SHADOW_FILTER": "2",
            "BLOOM_STRENGTH": "0.16",
            "SSR_STEPS": "20",
            "AO_SAMPLES": "6",
            "AO_STRENGTH": "0.60",
            "SHADOW_TEMPORAL": "1",
            "HELD_LIGHTS": "1",
            "COLORED_LIGHTS": "1",
        },
    },
}


def native_files(preset, record):
    files = {
        p.name: p.read_bytes() for p in sorted(NATIVE_SOURCE.iterdir()) if p.is_file()
    }
    source = files["horizon-shaders.toml"].decode()
    source = re.sub(
        r"(?m)^name = .*$", "name = " + json.dumps(record["name"]), source, count=1
    )
    source = re.sub(
        r"(?m)^version = .*$", "version = " + json.dumps(VERSION), source, count=1
    )
    values = {}
    if preset == "UltraPerformance":
        source = source.replace(
            'id = "markti_shaders"', 'id = "markti_shaders_ultra"', 1
        )
        source = source.replace("resolution = 2048", "resolution = 1024", 1).replace(
            "distance = 56.0", "distance = 48.0", 1
        )
        values = {
            "reflection_steps": 12,
            "water_ripples": 0.5,
            "surface_reflections": False,
            "ao_strength": 0.0,
            "pbr_materials": False,
            "water_caustics": False,
        }

    def option(match):
        text = match[0]
        key = re.search(r'(?m)^id = "([^"]+)"', text)[1]
        if key in values:
            text = re.sub(
                r"(?m)^default = .*$",
                "default = " + json.dumps(values[key]),
                text,
                count=1,
            )
        return text

    source = re.sub(r"(?ms)^\[\[options\]\]\n.*?(?=^\[|\Z)", option, source)
    files["horizon-shaders.toml"] = source.encode()
    options = {o["id"]: o["default"] for o in tomllib.loads(source)["options"]}
    return files, options


def write_archive(output, files):
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            info.create_system = 3
            archive.writestr(info, data, compresslevel=9)


def build():
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    results = []
    for preset, record in PRESETS.items():
        output = dist / record["file"]
        with zipfile.ZipFile(
            output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
        ) as archive:
            for path in sorted(p for p in SOURCE.rglob("*") if p.is_file()):
                name = path.relative_to(SOURCE).as_posix()
                data = path.read_bytes()
                if name == "shaders/lib/settings.glsl":
                    source = data.decode()
                    for key, value in record["settings"].items():
                        source, count = re.subn(
                            r"(?m)^(#define " + key + r" )\S+",
                            lambda match: match[1] + value,
                            source,
                        )
                        if count != 1:
                            raise ValueError(
                                f"Expected exactly one definition of {key}"
                            )
                    data = source.encode()
                info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                info.create_system = 3
                archive.writestr(info, data, compresslevel=9)
        results.append(
            {
                "file": output.name,
                "name": record["name"],
                "preset": preset,
                "format": "glsl",
                "bytes": output.stat().st_size,
                "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
                "settings": record["settings"],
            }
        )
        print(output.relative_to(ROOT))
        native_id = (
            "markti_shaders_ultra" if preset == "UltraPerformance" else "markti_shaders"
        )
        native_output = dist / (native_id + ".hshader")
        files, values = native_files(preset, record)
        write_archive(native_output, files)
        results.append(
            {
                "file": native_output.name,
                "name": record["name"],
                "preset": preset,
                "format": "native",
                "bytes": native_output.stat().st_size,
                "sha256": hashlib.sha256(native_output.read_bytes()).hexdigest(),
                "settings": values,
            }
        )
        print(native_output.relative_to(ROOT))
    manifest = {
        "name": "Markti Shaders",
        "version": VERSION,
        "format": "Horizon native shader mod (.hshader), with GLSL compatibility packs",
        "recommended_format": "native",
        "requires_custom_client": False,
        "tested_horizon": TESTED_HORIZON,
        "settings": "Horizon Shader Options; stable ZIP filenames retain sidecars across updates",
        "packs": results,
    }
    (dist / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (dist / "SHA256SUMS").write_text(
        "".join(f"{r['sha256']}  {r['file']}\n" for r in results)
    )


if __name__ == "__main__":
    build()
