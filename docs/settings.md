# Settings

Select the native `.hshader` or compatibility ZIP in Shader Packs and open
**Shader Options**. Settings belong to that file's `.txt` sidecar. Native and GLSL
choices are independent; installing another format does not translate them.

## Native packages

| Page | Controls |
| --- | --- |
| Lighting | Colored block/dynamic light, block light brightness, shadow softness |
| Water | Ripple strength, environment/screen reflection, optional terrain mirror, clarity, shallow caustics, ray steps |
| Materials | LabPBR resource-pack inputs, solid reflections, contact shading |
| Color | Exposure, saturation |

Colored placed lights are on in both native presets. Held/dropped lights also
require **Dynamic Lights** in Horizon's Extras settings. LabPBR needs a resource
pack supplying `_n`/`_s` maps. The optional mirror adds another terrain draw and
stays off in both presets. Ultra disables solid reflections, contact shading,
caustics and LabPBR reads by default; its shadow map is 1024 instead of 2048 and
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

Upscaling and frame generation belong to official Horizon, with its own supported
combinations. Neither format embeds a custom FSR implementation. Output scale
is a client setting and is not changed by the shader settings.
