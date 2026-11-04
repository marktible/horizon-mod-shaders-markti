# Settings

Select the native `.hshader` or compatibility ZIP in Shader Packs and open
**Shader Options**. Settings belong to that file's `.txt` sidecar. Native and GLSL
choices are independent; installing another format does not translate them.

## Native packages

| Page | Controls |
| --- | --- |
| Lighting | Colored block/dynamic light, block light brightness, soft shadow filter, shadow softness |
| Water | Ripple strength, environment/screen reflection, optional terrain mirror, clarity, shallow caustics, ray steps |
| Materials | LabPBR resource-pack inputs, solid reflections, contact shading |
| Color | Exposure, saturation |

Colored placed lights are on in both native presets. Held/dropped lights also
require **Dynamic Lights** in Horizon's Extras settings. LabPBR needs a resource
pack supplying `_n`/`_s` maps. The optional mirror adds another terrain draw and
stays off in both presets. Ultra disables solid reflections, contact shading,
caustics and LabPBR reads by default; its shadow map is 1024 instead of 2048, the wider soft filter is off, and
its water reflection rays use 12 instead of 24 steps. Base solid reflections use
64 steps to reduce holes around thin entity silhouettes; Ultra keeps that pass off.

Native shadow-map resolution/range come from the packaged preset's manifest.
They are not live WGSL options in this API. Shader Options can change softness.

## GLSL compatibility packages

The existing five pages remain: Lighting, Shadows, Water, Materials and Color.
They retain per-pack resolution/range, filter and shadow-history options, held
lighting controls, water, solid reflections, AO, bloom, exposure and saturation.
Their two profiles are Ultra Performance and Performance. GLSL placed block light
uses the ordinary scalar lightmap; colored held-item lighting remains optional.

## FSR 1 in the native mod

FSR 1 is available in both launcher-built `.hnmod` presets from 1.2.0.
Select the corresponding installed shader, then open **Options → Mods →
Markti preset → Settings**. Enable **FSR 1 (EASU + RCAS)** and adjust
**FSR 1 sharpness** (0–1, default 0.2). Values persist separately for each mod.
Only the selected preset processes the image, even if both mods are installed.

Use Horizon's Graphics settings for render resolution; set its own upscaler to
**Native**. Approximate FSR ratios are:

| Render resolution | FSR ratio | 1920×1080 world resolution, approximately |
| --- | --- | --- |
| 77% | Ultra Quality | 1478×832 |
| 67% | Quality | 1286×724 |
| 59% | Balanced | 1133×637 |
| 50% | Performance | 960×540 |

The window and HUD stay at output resolution. FSR defaults **off** and never
changes resolution automatically. At 100%, it adds sharpening/filtering cost;
reduce render resolution to obtain an upscaling speed benefit. It is a spatial
upscaler: fine foliage can still shimmer. It does not generate frames.

Standalone `.hshader` and GLSL ZIP installations do not provide the complete
FSR pipeline; they use the client's presentation. Existing TAA/FXAA/frame-generation
features remain client settings. Disable them when comparing FSR on/off so the
measurement isolates one change.

For measured flight settings and their limits, see [testing](testing.md).
