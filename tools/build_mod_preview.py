#!/usr/bin/env python3
"""Link a private trait-mod preview using existing official native-build libraries.

The dependency directory is read-only. Only this project's two API crates and
entry point are compiled; no upstream source or player launcher cache is changed.
"""

import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiled-deps", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    deps = args.compiled_deps.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    def library(name):
        candidates = list(deps.glob(f"lib{name}-*.rlib"))
        if len(candidates) != 1:
            raise RuntimeError(f"Choose a consistent official build: {name} has {len(candidates)} candidates")
        return candidates[0]

    common = ["rustc", "--edition=2024", "-C", "opt-level=3", "-C", "codegen-units=16",
              "-L", "dependency=" + str(deps), "-L", "dependency=" + str(output)]
    records = json.loads((ROOT / "dist/manifest.json").read_text())["mods"]
    for index, record in enumerate(records):
        source = ROOT / record["source"] / "mixins" / record["id"] / "api/src/lib.rs"
        subprocess.run([*common, "--crate-type=rlib", "--crate-name", f"mod_{index}",
                        "--extern", "horizon_client=" + str(library("horizon_client")),
                        str(source), "-o", str(output / f"libmod_{index}.rlib")], check=True)
    entry = output / "main.rs"
    ids = [r["id"] for r in records]
    hooks = ", ".join(f"mod_{i}::hooks()" for i in range(len(records)))
    entry.write_text(
        '#![forbid(unsafe_code)]\n'
        '#[global_allocator]\nstatic ALLOCATOR: horizon_threads::Allocator = horizon_threads::ALLOCATOR;\n'
        'static MOD_API_LEVEL: [u8; horizon_mods::api_level::MARK.len()] = horizon_mods::api_level::MARK;\n'
        'fn main() {\nstd::hint::black_box(&MOD_API_LEVEL);\n'
        f'horizon_client::mod_api::name_mods(&{json.dumps(ids)});\n'
        f'horizon_client::entry::main_with(vec![{hooks}].into());\n}}\n'
    )
    command = [*common, "--crate-name", "markti_native_preview", str(entry)]
    for name in ("horizon_client", "horizon_threads", "horizon_mods"):
        command += ["--extern", name + "=" + str(library(name))]
    for index in range(len(records)):
        command += ["--extern", f"mod_{index}=" + str(output / f"libmod_{index}.rlib")]
    command += ["-o", str(output / "horizon-client")]
    subprocess.run(command, check=True)
    print(output / "horizon-client")


if __name__ == "__main__":
    main()
