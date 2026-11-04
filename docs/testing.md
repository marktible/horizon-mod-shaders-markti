# Isolated testing

Use an installed **official Horizon** executable and its matching prepared resources.
Every test launch gets fresh temporary game, launcher and XDG homes; never point it
at a real player save. `--game-dir` and `--control-socket` are required explicitly.

The preview helper documents its arguments:

```bash
python3 tools/preview.py --help
```

Pass the official client, resource directory and an optional closed-world copy.
It copies the world into a fresh private home, installs both test ZIPs and writes
a session environment file. Never copy a live save; keep all copies in ignored
scratch storage, out of release ZIPs.

```bash
python3 tools/preview.py \
  --client /absolute/path/to/official/horizon-client \
  --resources /absolute/path/to/prepared/26.3 \
  --world-copy /absolute/path/to/a/closed-world-copy
source .local-test/markti/env.sh
python3 tools/control.py state
python3 tools/control.py capture .local-test/markti/preview.png
```

Native releases are selected by default. Use `--format glsl` for compatibility.
Add `--source` to link the editable GLSL source as `Markti Dev`, or
`--source-path packs/markti-native` for editable native source. Without either,
the helper copies the release artifacts. Use `--settings-from` with a closed preview's shaderpacks
folder to test saved sidecars in a fresh session. Finish with:

```bash
python3 tools/control.py quit
```

Source edits require a pack reload. ZIP edits require reinstallation in that
private home and a reload. Use `tools/control.py` only with the session's explicit
`HORIZON_CONTROL` socket. `python3 tools/reload_preview.py` toggles the selected pack
and returns to play.

Keep output scale at 100%, frame generation off and a modest frame cap for ordinary visual
checks. Confirm the actual renderer size. Check both packs in all three dimensions,
water/reflection materials, grass and shadows. Change an option through the real
Shader Options UI, leave the page, restart in a new private environment with a copy
of that sidecar, and verify it is restored. Do not treat capped FPS as a benchmark.

For shadow changes, freeze time with `command gamerule advance_time false` in the
private session and use a pillar on a flat, pale receiver. Check yaw, pitch and
translation while watching the same world locations, then walk with view bob on.
Use an angled sun and moon: overhead light alone can hide a broken transform.
The Rust regressions must use the loader revision pinned in `tools/bootstrap.sh`;
an older expression evaluator can accept matrix indices that are wrong at runtime.

For native changes, validate both `.hshader` files through the root Rust checker:
it runs the official shader checker and registry page/release-file checks. Test
colored placed lights while looking away from their sources, the color-off
option, actual LabPBR maps in a private resource pack, held light with the official
Dynamic Lights option enabled, water at shallow/grazing/downward views, optional
mirror behavior, metals, tinted glass shadows and both non-Overworld dimensions.
Use a non-falling material for a floating fixture's pool bed.
`--scale 75` may be used for a separate native post-resolution mapping check;
it affects only the private preview, not player settings or the default scale.

For native-mod packaging changes, run `tools/check_native_mods.py` and
`tools/check_mod_api.py`. The first compares GitHub source with `.hnmod` archives
and their embedded `.hshader` payloads, compiles/runs both installers in temporary
homes, and checks settings preservation and write failure behavior. The second
type-checks both trait API crates against the real official client library in a
temporary Cargo workspace, with the upstream compiler patches and lock versions.
It disables optional audio/gamepad features only for this library check; it does
not launch or install a client, use resources or touch a save. These commands may
run while a player game is open; runtime/world tests still follow the closed-save
workflow above. Test GitHub imports in private launcher/game homes too.

## Native FSR and flight benchmarks

Use the launcher-built Markti executable with matching official resources for
FSR tests. If its exact-version compiled libraries are already available,
`tools/build_mod_preview.py --help` describes a private link that reads those
libraries without changing the launcher cache. Compile before measuring.

```bash
python3 tools/benchmark_flight.py \
  --client /absolute/path/to/native/horizon-client \
  --resources /absolute/path/to/prepared/26.3 \
  --output .local-test/flight-fsr --scale 67 --fsr1
```

This creates a fresh seed-0 world, settles spawn, and measures an eight-second
stationary view and two 24-second forest flights at 20 blocks/s, pitch 30°.
Window size is 1920×1080; render/simulation distances are 12. VSync, TAA/FXAA and
generation are off, with a 260 FPS ceiling. Default worker/upload limits match
Horizon auto. Use `--artifacts` for an older release with the same executable;
`--workers`, `--chunk-updates` and `--upload-budget-kib` isolate streaming tuning.
The return route crosses generated terrain but still reloads/remeshes unloaded
sections; it is not a fully resident scene. Measure cold flight separately.

Read frame p50/p95/p99/max and CPU/GPU timings together with pending uploads.
Reject low upload budgets that improve FPS by delaying thousands of sections.
Keep raw frame arrays/logs private. Publish machine/settings, route and aggregate
results with the limitation that short runs are sensitive to generation,
temperature and scheduling. No compilation or concurrent game should run during
measurement; extra GPU pass-timing instrumentation must be off.

For FSR correctness, use the real Mods UI, verify toggles/sharpness survive a
fresh private restart, and test selected-preset ownership with both mods installed.
Check FSR off, both presets, other/no shader, 67% and 100%, water/materials, three
dimensions, and window resize. Watch for shader rejection/fallback and GPU errors;
a successful library check alone does not exercise either GPU stage.

### November 4 forest measurements

Ultra Performance, i3-1215U / ADL GT2 integrated / 8 GiB RAM, Mesa 26.2.6.
All rows use the same official Performance-profile client library; “before”
uses the 1.1.1 shader. These are short configuration comparisons, sensitive to
scheduling and generation, without a sustained 60 FPS result.

| Configuration | Cold flight average FPS | Cold p99 / worst frame | Return average FPS |
| --- | --- | --- | --- |
| Before, 100%, auto streaming | 25.81 | 118.05 / 160.71 ms | 28.33 |
| FSR 1, 67%, auto streaming | 37.60 | 54.57 / 70.96 ms | 45.72 |
| 100%, bounded streaming | 30.00 | 56.92 / 62.83 ms | 35.67 |
| FSR 1, 67%, bounded streaming | 38.53 | 44.18 / 51.71 ms | 45.37 |

Bounded streaming uses **2 workers, 64 section updates/frame and 16 MiB upload
budget/frame (16384 KiB)**, through official Graphics controls. Native 100%
endpoint upload queues were empty; FSR's cold endpoint had 484 pending sections
and its return endpoint was empty. An 8-section / 4 MiB experiment was rejected:
it left thousands waiting despite better FPS. Do not apply that tight budget.
The settings above are measured for this machine, not universal pack defaults.
At 100%, stationary rendering remains GPU-bound; reducing streaming spikes does
not guarantee higher stationary FPS.

See [aggregate evidence](../reports/validation-1.2.0.json) for all percentiles,
CPU/GPU times and limits. Raw frames and worlds stay private.
