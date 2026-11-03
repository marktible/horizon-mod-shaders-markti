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
