# GitHub-installable native mods

The launcher scans GitHub archives for `horizon-mixin.toml` or an unpacked
`.hnmod` with `horizon-native.json`. `.hshader` files alone are not native mods.
This directory supplies the missing installation format for the two presets.

`installer.rs` is the shared authoritative installer. `runtime.rs` owns the
supported mod/settings/shader/render hooks; `fsr.rs` caches the RCAS GPU objects,
and `fsr1_rcas.wgsl` is the sharpening stage. `tools/package.py` generates
`bundles/<id>/horizon-native.json`, `mixins/<id>/horizon-mixin.toml`, a trait-mod
API crate and its embedded shader data. Edit
the shared source or `packs/markti-native`, then regenerate; do not hand-edit
copies under `bundles`. Each source tree matches its `dist/<id>.hnmod` archive.

The IDs are `markti_shaders_mod` and `markti_shaders_ultra_mod`. On the first frame,
including the title screen, each enabled mod creates/updates only its pack in
`shaderpacks/native-<id>/`. Equal files are not rewritten; shader selection,
resolution and option sidecars are preserved. The manifest is written last.
An I/O failure is logged once instead of panicking or retrying every frame.
The shader programs are identical to the standalone `.hshader` preset.

The native bundle requires hooks API 326 for the instance-directory helper, and
uses the official `Hooks` and `RenderHooks` traits. No source injections or mixin
transformation are used. FSR 1 settings default off, persist per mod and only
affect its selected preset. EASU lives in the embedded shader; RCAS runs in the
world-drawn hook before hand/HUD. See [controls](../docs/settings.md).
The recorded Horizon/mixins commits are the
tested baseline; the unpacked JSON keeps the hook-version compatibility contract
when installed from GitHub. The launcher may build newer official source with
those hooks. WGSL API compatibility still needs testing as Horizon changes.

Validate with:

```bash
python3 tools/package.py
python3 tools/check_native_mods.py
python3 tools/check_mod_api.py --jobs 1
cargo run --locked --release -- dist/*.hnmod
```

The only API-crate dependency is official `horizon-client`; the shared installer
and payload use only Rust's standard library. No engine renderer patch or retired
tracing code is included. The launcher builds these native extensions; the standalone shader
installation remains available without a game build. See [player installation](../docs/mod-install.md).
Uninstalling the mod leaves its installed shader folder and saved options in
place; remove that folder manually if it is no longer wanted.
