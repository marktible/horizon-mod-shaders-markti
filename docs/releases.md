# Release and installation

Requires Python 3.11+ and a stable Rust toolchain compatible with the pinned Horizon.
From the project root:

```bash
./tools/bootstrap.sh
python3 tools/package.py
python3 tools/check_native_mods.py
python3 tools/check_mod_api.py --jobs 1
cargo run --locked --release -- packs/markti packs/markti-native dist/*.zip dist/*.hshader dist/*.hnmod
```

The packager writes two `.hshader` files, two source-only `.hnmod` bundles, two GLSL compatibility ZIPs,
`dist/manifest.json` and `dist/SHA256SUMS`. They are two named presets in two
shader formats, plus native-mod installation for both. Stable filenames retain per-file settings. Native asset names use only
registry-safe characters. Only source, metadata and license text are packaged.

Validate on the tested official binary in an isolated environment. Shader/API and
registry checks alone cannot prove GPU correctness or visual quality. Do not
restore the retired client fork or test on a live player save. Native mods use
the launcher's supported build flow; see [mod installation](mod-install.md).

With the game closed, install the four standalone shader files and select native base:

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
packages and rejects `dist` or generated bundle differences, compiles/tests both
native installers, runs the real native/GLSL/registry
checks, Rust/Python checks and documentation checks. GPU checks stay manual.

The manual **Prepare native release** workflow creates a draft GitHub release
with the native shader assets after validation. GitHub installs scan that tag's
source archive for both mod bundles. This launcher picks the first `.hnmod` asset
when present, so the workflow deliberately leaves them in the source archive and
`dist/` rather than attaching two competing release assets. The GitHub installer
also works from committed unpacked bundles without a release. Publish the reviewed draft, then follow
[the catalog instructions](../registry/README.md) for the initial submission.
Registry review is separate from creating a release; do not claim a listing early.
