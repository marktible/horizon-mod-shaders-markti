# Release and installation

Requires Python 3.11+ and a stable Rust toolchain compatible with the pinned Horizon.
From the project root:

```bash
./tools/bootstrap.sh
python3 tools/package.py
cargo run --locked --release -- packs/markti packs/markti-native dist/*.zip dist/*.hshader
```

The packager writes the two `.hshader` files, two GLSL compatibility ZIPs,
`dist/manifest.json` and `dist/SHA256SUMS`. They are two named presets in two
formats. Stable filenames retain per-file settings. Native asset names use only
registry-safe characters. Only source, metadata and license text are packaged.

Validate on the tested official binary in an isolated environment. Shader/API and
registry checks alone cannot prove GPU correctness or visual quality. Do not
build a custom client or test on a live player save.

With the game closed, install all files and select native base:

```bash
python3 tools/install_profile.py --game-dir /absolute/path/to/horizon --pack base --format native
```

Use `--pack ultra` for Ultra Performance or `--format glsl` for compatibility.
`--keep-selected` installs the files while preserving the existing shader choice.
Vanilla options, resolution, Extras and shader sidecars are preserved. Native
held/dropped lighting requires the client's Dynamic Lights setting to be on.

The installer checks hashes, backs up settings/replaced files and retires old
Radiance files. Installation reports and backups stay local. An optional
`--launcher-dir /absolute/path/to/horizon-launcher` selects the tested official
version only while the launcher is closed. It does not race launcher settings.

Commit source, docs, current artifacts and sanitized reports. CI rebuilds the
packages and rejects `dist` differences, runs the real native/GLSL/registry
checks, Rust/Python checks and documentation checks. GPU checks stay manual.

The manual **Prepare native release** workflow creates a draft GitHub release
with the native assets after validation. Publish the reviewed draft, then follow
[the catalog instructions](../registry/README.md) for the initial submission.
Registry review is separate from creating a release; do not claim a listing early.
