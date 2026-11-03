# Developing Markti Shaders

Read [AGENTS.md](AGENTS.md) before edits. **Every development change must update
this document** with its purpose, source locations and actual validation results.
Never claim an unrun check or test against a player's live save.

## Current direction

Markti provides native `.hshader` shader mods for **official Horizon**, plus GLSL
compatibility ZIPs. There are exactly two named presets in these two formats:
**Markti Shaders Ultra Performance** and **Markti Shader** (the former Performance
preset). This is the official native shader API, not a compiled Rust `.hnmod`.
Balance, Quality and Raytraced are retired. The native
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
| [packs/markti-native](packs/markti-native) | Native WGSL material/water/sky/post source and typed options |
| [horizon-registry.toml](horizon-registry.toml) | Public shader catalog page metadata |
| [registry](registry) | Candidate entries for the two native shader IDs |
| [lib/settings.glsl](packs/markti/shaders/lib/settings.glsl) | Option definitions and base defaults |
| [shaders.properties](packs/markti/shaders/shaders.properties) | Shader Options pages, sliders and two profiles |
| [lang/en_us.lang](packs/markti/shaders/lang/en_us.lang) | Player-facing labels and help |
| [tools/package.py](tools/package.py) | Deterministic native/GLSL packages, version, checksums and format metadata |
| [src/main.rs](src/main.rs) | Official native API/catalog and GLSL loader validation, buffer/shadow invariants |
| [tools/install_profile.py](tools/install_profile.py) | Backup, install either format, preserve selection on request and retire old Radiance ZIPs |
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
cargo run --locked --release -- packs/markti packs/markti-native dist/*.zip dist/*.hshader
cargo test
cargo fmt --check
```

Packaging builds the two named presets in native and GLSL formats. Do not build a custom Horizon client.
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
and isolated; hosted CI is not a substitute for them. The original publication's
GitHub Actions run was later observed successful on commit `fa0c235` (run
`41656319309`); a native-conversion CI result is not yet claimed.

After cleanup, the nine loader cases, both unit regressions, formatting, Clippy
and Python syntax checks passed again. The rebuilt ZIPs retain byte-identical
GPU-tested shader programs; only `LICENSE` changed to preserve both copyright
notices. Documentation checks resolve 29 local links and six shell examples.
A clean export of the staged Git tree reproduced both ZIPs byte for byte,
bootstrapped the official loader from scratch, and passed both unit tests and all
nine loader cases. The publication audit found 97 tracked files (about 226 KiB),
with no private session data, game assets, native binaries or credential material.

## Native shader mods (1.1.0)

The user requested a Horizon mod with more shader features. A Rust `.hnmod`
wrapper alone does not expand the GLSL resource interface and requires a
launcher-built game. The official `.hshader` API already exposes colored placed
light, dynamic RGB light, LabPBR maps, translucent shadow colors and native water
reflection resources. Work starts with a native shader core, usable directly or
as a mod payload, while the existing GLSL release stays intact. No retired
Raytraced/client-fork implementation is being resumed.

The exact official November 3 API source and current upstream documentation were
inspected. The official `horizon-shader` checker was built from the pinned source.
`packs/markti-native` holds native material, water, shared reflection tracing, sky
and post stages. Native light tables distinguish torch, soul, copper and other
source colors. Water preserves the filtered non-periodic ripple field, rejects
foreground refraction, uses depth absorption/caustics, and rejects the optional
terrain mirror at the wrong water height. Solid metadata and depth-refined
screen-space rays support visible geometry; the native backend's own visibility
limits remain. Native material lighting is compressed into the shared display
target; this is not a wholesale copy of the GLSL HDR/history pipeline.

`tools/package.py` emits `markti_shaders.hshader` and
`markti_shaders_ultra.hshader`, plus the existing compatibility ZIPs. Native names
avoid spaces for registry downloads, while their visible names stay unchanged.
Ultra lowers shadow/ray budgets and defaults to no LabPBR reads, solid SSR, screen
AO or caustics. Both native presets enable colored light; held/dropped items also
need Horizon's Dynamic Lights option. Typed overrides have four menu pages.

The Rust validator now checks native source/artifacts with `horizon-shader-api`,
and uses `horizon-mods`' actual `page` / `release_version` validation for the
candidate registry entries, API, IDs and asset names. `Cargo.toml` pins Naga to
the official revision's source patch; `Cargo.lock` records those dependencies.
`tools/preview.py --source-path <folder>` previews either format; `--format`
selects a release format. `tools/install_profile.py --keep-selected` installs
files without changing the chosen shader. Sidecars are not silently migrated.

`horizon-registry.toml`, `registry/*.toml` and `registry/README.md` prepare a
`shader` catalog submission, not a Rust mod. The user made the repository public,
verified through GitHub's API. `.github/workflows/native-release.yml` is a manual
draft-release workflow after validation; no release or external review request
has been created yet. Existing Git history and both license notices remain.

The [native validation summary](reports/validation-1.1.0.json) records the real
source/artifact/registry checks and GPU results. The official client rendered 26
initial private-world cases, ten extra material/light/mirror cases, two final
water views, six final exact-artifact preset/dimension cases, and a separate 75%
configured restart frame. This covers source-offscreen colored lights, color
on/off, water/metal/visible-entity reflections, tinted glass, camera motion,
synthetic private LabPBR maps on/off and actual blue/warm held light with the
official Dynamic Lights switch enabled. The pool bed/walls were made solid after
the first fixture's sand fell; the final water views use that corrected fixture.
Native saturation saved as `1.0999999791383743` and restored as `1.10` in a fresh
client/home. The scaled check's control status reports the 1280×720 window size;
it does not directly expose the native internal target size.

Both unit regressions (315 legacy GLSL camera combinations), format, Clippy with
warnings denied, Python syntax, workflow YAML/shell syntax, deterministic rebuild,
native preset-budget contracts and archive checks passed. Native base uses 24
water ray steps and 64 solid steps to retain thin-silhouette coverage; Ultra
uses 12 water steps and disables the solid pass by default. The nine compatibility
loader cases still pass, with no GLSL program changes. The compatibility README
now distinguishes its format from native features. No benchmark was taken.
Both formats were installed with `--keep-selected`; the existing GLSL selection,
100% player scale, vanilla options, Extras and all sidecars were verified byte for
byte unchanged. Select the `(Horizon)` entry to use the native implementation.
Catalog publication remains a separate release/review step. No Rust native game
build or retired engine code was installed.
Native sidecars store booleans as numeric `0`/`1`, not TOML's `false`/`true`;
use the actual UI or that representation when preparing a private test. Explicit
opaque-color bilinear loads fix the filtering-sampler mismatch found by the GPU
check. Two rotated caustic fields avoid a noise-cell grid. Non-Overworld daylight
is zero. Preview `--scale` supports an isolated 75% metadata-coordinate regression
while normal previews and the player profile remain at 100%.

A clean export of the staged source reproduced all four packages and their
manifest/checksums byte for byte, bootstrapped the pinned official loader, and
passed the native source/artifact/catalog checks and nine GLSL loader cases.
Documentation validation passed 47 local links and seven shell examples. The
publication audit found 117 tracked files (about 317 KiB), with no game assets,
private session data, native game binaries or credential material.

## Limits and maintenance

See [compatibility](docs/compatibility.md), [rendering](docs/rendering.md),
[settings](docs/settings.md), and [release/install steps](docs/releases.md).
Screen-space reflections retain their screen visibility limits. The GLSL API does
not expose the WGSL material API's block-light color grid; maintain that distinction.
No world, account, session or prepared game resource belongs in the shader ZIPs.
