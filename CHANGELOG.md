# Changelog

## 1.2.0 — 2026-11-04

- Add optional FSR 1 EASU + RCAS through supported native shader/render hooks,
  with persistent per-mod toggles and sharpness. Keep 100% resolution and FSR off
  by default; expose the settings in the actual Mods menu.
- Cache RCAS resources across frames and unroll EASU taps. Add an optional faster
  native shadow filter, enabled by Ultra's budget; base retains its wider filter.
- Test on official November 4 Horizon with repeatable isolated forest flights.
  Add private native-build reuse and flight benchmark tools; keep player saves
  and raw frame reports out of distribution.

## 1.1.1 — 2026-11-04

- Fix Add from GitHub: supply two discoverable unpacked native mod bundles and
  matching source-only `.hnmod` downloads, in addition to the shader packages.
- Install the matching native shader once at the title screen, preserving the
  selected shader, resolution, sidecars and other packs. Integrate its Mods toggle.
- Use named hooks with native API 326 so supported official updates can build
  without rebasing a client fork. Shader programs and preset budgets are unchanged.
- Validate embedded payloads, installer updates/failures and real native bundles;
  document the separate shader-pack and native-mod installation routes.

## 1.1.0 — 2026-11-03

- Add native Horizon shader mods (`.hshader`) for the existing two presets,
  without a Rust native-mod build or custom client.
- Add colored placed and dynamic lighting through Horizon's official API, LabPBR
  material inputs, filtered translucent shadow colors and optional terrain mirrors.
- Port water ripples/refraction and perspective-correct screen-space reflections,
  plus material metadata, terrain lighting, sky and post processing, to WGSL.
- Add native Shader Options pages and keep the GLSL compatibility packs available.
- Add catalog metadata, candidate entries and a manual draft-release workflow.

## 1.0.1 — 2026-11-03

- Fix shadows and sunlight rotating with camera yaw and pitch on official Horizon.
- Match custom-expression matrix indices to the tested November 3 client.
- Validate against that exact loader revision; cover 315 camera orientations.
- Publish the standalone project with reproducible ZIPs, development instructions
  and automated checks. Preserve saved options through stable ZIP filenames.

## 1.0.0 — 2026-11-03

- Introduce **Markti Shader**, based on Performance, and **Markti Shaders Ultra
  Performance**, with Horizon's Shader Options and two profiles.
- Target official Horizon without a custom client fork.
- Retire Balance, Quality and Raytraced. The retired fork's voxel lighting and
  custom FSR integration are not included in the standalone packs.
