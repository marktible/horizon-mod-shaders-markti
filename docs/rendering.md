# Rendering

Source: `packs/markti/shaders`. `lib/settings.glsl` defines options and
`shaders.properties` defines the two profiles and their menu pages.

The Overworld shadow pass uses the shared transform in `lib/shadow_transform.glsl`.
`shaders.properties` transforms the view-space shadow light into world space before
smoothing it. Horizon custom expressions index matrices as `matrix.column.row`,
matching GLSL; transposing those indices makes the light follow camera rotations.
Terrain/entities receive linear lighting from `lib/lighting.glsl`, standard scalar
block light, and optional held-item light. Normal reconstruction and foliage tint
handling are retained from the Performance source. `block.properties` uses the
standard `mc_Entity` material interface, with no private ID texture.

`deferred.fsh` preserves the opaque color/depth inputs for water and stabilizes
sun/moon shadow history when enabled. `gbuffers_water.fsh` supplies rippled surface
normals, refraction, caustics and screen-space reflections. `composite.fsh` adds
selected solid reflections and screen AO. `final.fsh` performs bloom, exposure,
color saturation and tone mapping.

Intermediate lighting stays linear/HDR; display conversion belongs in the final
pass. Preserve inverse-projection reconstruction and matching caster/receiver
shadow transforms when editing. The dimension wrappers compile out Overworld
sunlight/history in the Nether and End and use their own atmosphere.

Reflection rays use the visible color and depth buffers. Offscreen geometry is
not reconstructed, and there is no voxel or diffuse path tracer. Unknown/private
native samplers must not be reintroduced into standalone Markti releases.
