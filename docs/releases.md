# Release and installation

From the project root:

```bash
python3 tools/package.py
cargo run --release -- packs/markti 'dist/Markti Shader.zip' 'dist/Markti Shaders Ultra Performance.zip'
```

Validate on the tested **official** Horizon binary in an isolated environment.
Do not build a custom client. The packager writes exactly two deterministic ZIPs,
`dist/manifest.json` and `dist/SHA256SUMS`. Stable filenames let Horizon retain
settings sidecars; change the version inside the manifest when releasing.

With the game closed, install both and choose the base pack:

```bash
python3 tools/install_profile.py --game-dir /absolute/path/to/horizon --pack base
```

Use `--pack ultra` to select Ultra Performance. The installer checks hashes,
backs up settings and replaced files, and moves old Radiance ZIPs/settings into
its backup. It does not change resolution scale or vanilla options.

An optional `--launcher-dir /absolute/path/to/horizon-launcher` selects the tested
official version only while the launcher is closed. If it is open, select
`nightly-2026-11-03-f42ef42` in its UI; the installer records this pending step.
Do not race an open launcher's settings file.

Commit current source, docs, the two ZIPs, manifest and checksums. Add a sanitized
validation summary under `reports/`; keep installation logs, private paths, raw
player state and old captures in ignored local storage. The GitHub validation
workflow rebuilds the ZIPs and rejects differences from committed `dist` files.
It also checks the official loader, Rust/Python sources and documentation.
