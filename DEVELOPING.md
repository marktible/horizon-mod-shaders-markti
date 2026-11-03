# Developing Markti Shaders

Read [AGENTS.md](AGENTS.md) before edits. **Every development change must update
this document** with its purpose, source locations and actual validation results.
Never claim an unrun check or test against a player's live save.

## Current direction

Markti is a standalone GLSL shader pack for **official Horizon**. There are exactly
two distributions: **Markti Shaders Ultra Performance** and **Markti Shader** (the
former Performance preset). Balance, Quality and Raytraced are retired. The native
Radiance client fork and unfinished 3.1.3 tracing work are archived under
`.archive/radiance-legacy-2026-11-03`; they are not build inputs or supported releases.

The initial stock-client target is `nightly-2026-11-03-f42ef42`. Horizon now exposes
GLSL Shader Options, profiles, pages and sliders. Lighting switches and visual
preferences belong there, not in separate ZIP variants. Stable ZIP filenames keep
Horizon's per-pack settings sidecars attached across pack updates.

## Source map

| Path | Purpose |
| --- | --- |
| [packs/markti/shaders](packs/markti/shaders) | Authoritative GLSL and standard block/item mappings |
| [lib/settings.glsl](packs/markti/shaders/lib/settings.glsl) | Option definitions and base defaults |
| [shaders.properties](packs/markti/shaders/shaders.properties) | Shader Options pages, sliders and two profiles |
| [lang/en_us.lang](packs/markti/shaders/lang/en_us.lang) | Player-facing labels and help |
| [tools/package.py](tools/package.py) | Two deterministic ZIPs, version, checksums and compatibility metadata |
| [src/main.rs](src/main.rs) | Official loader validation and buffer/shadow invariants |
| [tools/install_profile.py](tools/install_profile.py) | Backup, install both packs, retire old Radiance ZIPs |
| [tools/control.py](tools/control.py) | Explicit-socket private preview control |
| [tools/check_docs.py](tools/check_docs.py) | Local documentation links and example syntax |
| `reports/` | Sanitized release validation summaries and portable check output |
| `.local-test/` | Ignored private world copies, environments, logs and install backups |

The shader's internal `RADIANCE_DIMENSION` and sun-basis expression names are
historical implementation names, not native-client dependencies.

## Development loop

```bash
./tools/bootstrap.sh
cargo run --release -- packs/markti
python3 tools/package.py
cargo run --release -- packs/markti 'dist/Markti Shader.zip' 'dist/Markti Shaders Ultra Performance.zip'
cargo test
cargo fmt --check
```

Packaging builds only the two named packs. Do not build a custom Horizon client.
Use the installed official binary for [isolated visual checks](docs/testing.md),
then verify options change, save and survive a restart. Test both packs in the
Overworld, Nether and End. Validate water, foliage and reflective material behavior
when changing their shaders; the loader alone cannot prove GPU correctness.

For an official Horizon update, change the tested version in `tools/package.py`,
validate on that unmodified binary, and record results. Update the development
loader pin if its interfaces changed. There is no game-source patch to rebase.

## Initial Markti migration (1.0.0)

The two rendering budgets remain based on Radiance Ultra Performance and
Performance. The source moved to `packs/markti`; runtime ray traversal, tracing
settings, private voxel samplers and the custom material-ID texture were removed.
Standard `mc_Entity` / `block.properties` supply material IDs. The two packs use
ordinary Horizon block light and optionally colored held-item lighting. The old
custom colored placed-light volume and custom FSR integration are not portable
GLSL features and are not included. Upscaling and frame generation are owned by
the official client; do not label its TAA upscaler as FSR 3.1.

`shaders.properties` now groups Lighting, Shadows, Water, Materials and Color.
`lang/en_us.lang` names the controls. Only two profiles and two ZIPs remain; there
are no lighting-variant ZIPs. `BLOCK_LIGHT_STRENGTH` adjusts ordinary block light.
The two user-requested names are used in filenames, metadata and documentation.

Initial validation included nine loader/dimension cases (source and both ZIPs),
the existing shadow world-space regression test, format and Clippy checks, and
13 runtime cases. The older loader used then masked the matrix-convention bug
corrected in 1.0.1 below. Both packs
ran in all three dimensions. Additional captures check iron reflection, colored
held light, sky and horizontal water. The actual Shader Options UI exposes only
the two profiles and the five named pages. `COLORED_LIGHTS=0` was saved to
`Markti Shader.zip.txt` and restored in a fresh official-client session. This is
recorded in the local historical runtime report.

The initial installation installed both Markti ZIPs,
selected the base pack, backed up/retired all five active Radiance ZIPs, and selected
official `nightly-2026-11-03-f42ef42` while the launcher was closed. Vanilla options
and resolution scale were preserved. No custom client was installed or built for
Markti. No performance claim from an older custom client applies automatically.

`AGENTS.md` now records the two supported names and the stock-client target so
future work does not resume the retired variants or native fork implicitly.

## Camera-dependent shadow correction (1.0.1)

Official November 3 Horizon evaluates custom expression matrix components as
`matrix.column.row`. The initial pack used the older loader's `matrix.row.column`
convention when transforming `shadowLightPosition` back to world space. Camera
rotation therefore rotated the light a second time, moving shadows and direct
lighting. `tools/bootstrap.sh` now pins the loader to the exact tested official
client revision, `f42ef42ef6ceccb3c6a20bea2481d87949a51c81`, so the regression in
`src/main.rs` checks the runtime convention. The correction belongs in
`packs/markti/shaders/shaders.properties` and applies to both packs.
The validator accepts the official loader's new optional graphics programs and
additional default game inputs; `Cargo.lock` follows that loader's dependencies.
`tools/package.py` and `Cargo.toml` advance to 1.0.1; stable ZIP filenames and both
preset budgets remain unchanged. `tools/install_profile.py` names its report from
the manifest version rather than overwriting the original migration report.

The existing camera-turn regression failed on the updated official loader before
the matrix correction (`camera turn moved the light`), confirming that the older
validator masked the compatibility bug.

Validation passed on the exact official loader and unmodified client:

- [Nine loader/dimension cases](reports/loader-1.0.1.txt), source plus
  both release ZIPs; [two regression tests](reports/tests-1.0.1.txt), including
  315 yaw/pitch/view-roll combinations with f32 inputs and both light hemispheres;
  Cargo formatting, Clippy with warnings denied, and Python syntax checks.
- [Runtime summary](reports/validation-1.0.1.json): seven yaw, pitch
  and translation poses for each pack, before and after, in a freshly generated
  private world. Time was frozen over a white-concrete receiver and stone pillar.
  Seventeen unobscured floor points were sampled at the same world positions.
  Mean brightness range across viewpoints fell from 67.47/255 to 2.43/255 for base
  and 3.59/255 for Ultra. This measures view-dependent lighting error, not FPS.
  Ordinary edge quantization and screen effects can still vary a few pixels;
  this does not claim perfect temporal antialiasing of low-resolution shadows.
- Both release ZIPs ran in all three dimensions, with additional angled moon
  rotations and walking with view bob enabled. The latter used a private copy of
  the player's shader-options sidecar, including 1024 shadows and the 9-tap filter.
  The player save was never opened. Raw captures remain in local test storage.

The private preview stayed at 1280×720, 100% resolution and a 12 FPS visual cap.
No benchmark or high-end-hardware performance measurement was taken.

Both 1.0.1 ZIPs were installed after the game closed. The base pack remained
selected, and vanilla options, 100% resolution and the saved Shader Options were
preserved. Installation details and backups remain local.

## Repository publication and cleanup

The project is maintained in
[marktible/horizon-mod-shaders-markti](https://github.com/marktible/horizon-mod-shaders-markti).
Its existing `main` history and MIT license are preserved; both root and pack
licenses retain marktible and Horizon contributor notices.

Only the current two-pack source, docs, validation helper, deterministic ZIPs and
sanitized evidence belong in Git. Raw reports and captures were moved into
`.local-test/report-archive-2026-11-03`; retired source remains in `.archive`.
Neither folder is published. `.gitignore` excludes upstream/build caches, game
data and raw reports, and allows only the two named ZIPs in `dist`.
`.gitattributes` keeps source line endings stable and treats ZIPs as binary.

`CHANGELOG.md` records public changes. `tools/check_docs.py` checks the changelog
and report index too, and writes `reports/documentation.json` instead of an old
version-specific filename. [The report index](reports/README.md) explains which
evidence is safe to publish. The standard-library Python helpers were formatted
for readability; they need no new runtime dependencies. `.github/workflows/validate.yml` runs bootstrap,
formatting, unit tests, Clippy, Python syntax checks, deterministic ZIP comparison,
the nine loader cases and documentation checks. GPU/world checks remain manual
and isolated; hosted CI is not a substitute for them. A GitHub Actions run has not
yet been observed.

After cleanup, the nine loader cases, both unit regressions, formatting, Clippy
and Python syntax checks passed again. The rebuilt ZIPs retain byte-identical
GPU-tested shader programs; only `LICENSE` changed to preserve both copyright
notices. Documentation checks resolve 29 local links and six shell examples.
A clean export of the staged Git tree reproduced both ZIPs byte for byte,
bootstrapped the official loader from scratch, and passed both unit tests and all
nine loader cases. The publication audit found 97 tracked files (about 226 KiB),
with no private session data, game assets, native binaries or credential material.

## Limits and maintenance

See [compatibility](docs/compatibility.md), [rendering](docs/rendering.md),
[settings](docs/settings.md), and [release/install steps](docs/releases.md).
Screen-space reflections retain their screen visibility limits. The GLSL API does
not expose the WGSL material API's block-light color grid; maintain that distinction.
No world, account, session or prepared game resource belongs in the shader ZIPs.
