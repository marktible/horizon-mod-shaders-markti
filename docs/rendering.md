# Rendering

## Native shader API

Source: `packs/markti-native`. The manifest defines stages, typed options, pages,
material IDs, source-light colors and the native shadow/mirror settings.

- `common.wgsl`: color conversion, procedural environment/clouds, reconstruction
  and dimension-aware fog.
- `sky.wgsl`: bounded cloud/environment rendering; the engine keeps sun, moon and
  stars. The post stage supplies End/Nether backgrounds where needed.
- `material.wgsl`: terrain lighting, color-grid/dynamic light, LabPBR inputs,
  RGB translucent-shadow filtering and material metadata for solid reflections.
- `water.wgsl`: world-anchored filtered ripples, opaque-scene refraction with a
  foreground rejection guard, depth absorption, caustics and reflection blending.
- `trace.wgsl`: perspective-correct reflection rays for water and solids, near
  clipping, receiving-plane rejection and a depth-crossing refinement. Opaque
  native color is non-filterable: the hit color uses explicit bilinear loads.
- `post.wgsl`: solid reflections, contact shading, dimension backgrounds and
  grading. Surface metadata is addressed by normalized UV at the internal size,
  so a final pass at window size does not misread it during client upscaling.

The optional native water mirror is used only near the plane the engine rendered;
other heights retain procedural/screen-space fallback. Material writes are in the
official world's display range; see [native limits](native.md). There is no private
GPU interface or custom native game executable.

## GLSL compatibility API

Source: `packs/markti/shaders`. The existing HDR pipeline is retained.
`lib/settings.glsl` and `shaders.properties` define options and two profiles.

The shared caster/receiver transform is `lib/shadow_transform.glsl`.
`shaders.properties` transforms the view-space light into world space before
smoothing. Horizon expressions index matrices as `matrix.column.row`, matching
GLSL; transposing those indices makes light follow camera rotation.

`lib/lighting.glsl` reconstructs normals and preserves foliage tint. The deferred
pass stores the opaque water snapshot and optional shadow history; water handles
ripples/refraction/SSR, composite handles selected solid reflections/AO, and final
handles bloom, exposure and tone mapping. Nether/End wrappers remove Overworld
sunlight/history and supply their own atmosphere. Preserve matching projection,
normal and depth conventions when editing either implementation.
