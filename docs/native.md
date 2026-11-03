# Native Horizon shader mods

Markti uses Horizon's `.hshader` format for the shader catalog. The native
WGSL source lives in `packs/markti-native`; the compatible GLSL source remains
in `packs/markti`. They are two implementations of the same two named presets.

A `.hnmod` carries Rust source compiled into a launcher-built game. Since 1.1.1,
the repository also supplies these bundles for **Add from GitHub**. They install
the corresponding `.hshader` contents into a mod-owned folder once on the first
frame. Rendering and Shader Options are identical in both installation routes;
the mod wrapper adds installation and Mods toggle integration. See
[installation](mod-install.md) and [shared installer source](../native-mod/README.md).

## What the native format adds

| Feature | Implementation |
| --- | --- |
| Colored placed light | `[[lights]]` maps source blocks to RGB; `material.wgsl` colors ordinary block light through `block_light_color` |
| Colored held and dropped items | `MaterialInput.colored_light`, with Horizon's dynamic-light setting enabled |
| Resource-pack materials | LabPBR normal/ambient-occlusion and specular/smoothness inputs, enabled by the Materials option |
| Tinted glass shadows | Opaque and translucent depth maps plus `shadow_color`, filtered together |
| Water | World-anchored filtered ripples, depth absorption, guarded refraction, screen-space reflection and an optional native terrain mirror |
| Solid reflections | Native surface metadata and a screen-space ray with near-plane clipping and depth/receiving-plane rejection |
| Options | Typed WGSL overrides, four menu pages and per-file saved choices |

The original Shader and Ultra Performance names and budgets remain distinct.
Ultra defaults to no solid reflections, no screen AO and no LabPBR texture reads;
both native presets enable colored lights. Color can be switched off in Lighting.
The native defaults differ from the GLSL compatibility presets.

## Limits

Placed RGB lighting tints Horizon's existing propagated light. It is not a diffuse
bounce or path tracer. Dynamic lights use Horizon's own limits. The native material
stage affects terrain; entities keep the official client's material lighting.

Screen-space reflections need visible color/depth. The optional terrain mirror
contains the native client's terrain and sky gradient, not reflected entities or
the pack's procedural clouds. It stays off by default; a plane-height guard rejects
it for water at another elevation. These two reflection sources have different
visibility limits.

The material stage compresses its linear lighting into the official client's
shared display-range world target. This is not the old GLSL HDR pass chain.
LabPBR normals, AO and smoothness are read; the initial solid reflection model uses
smoothness to control reflection strength, rather than a full roughness-dependent
reflection cone or path-traced BRDF.

The official native shadow renderer determines caster visibility and map updates.
Its documented offscreen-entity shadow limit still applies. Filtered edges and
low-resolution shadow maps can retain sampling variation. Native API 0.1 is
experimental: test new Horizon builds rather than assuming unlimited compatibility.

The GLSL ZIPs remain available for the existing appearance and GLSL-only controls
such as per-pack shadow resolution and temporal shadow history. Sidecars are not
silently translated between the formats. There is no BC250 or 60 FPS claim for the
new native implementation until a relevant benchmark is run.

References: [official shader guide](https://github.com/horizon-rust/horizon/blob/f42ef42ef6ceccb3c6a20bea2481d87949a51c81/docs/shaders.md),
[API reference](https://github.com/horizon-rust/horizon/blob/f42ef42ef6ceccb3c6a20bea2481d87949a51c81/docs/api/shaders-reference.md),
[native mod guide](https://github.com/horizon-rust/horizon/blob/f42ef42ef6ceccb3c6a20bea2481d87949a51c81/docs/native-mods.md).
