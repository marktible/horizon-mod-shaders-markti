# Markti GLSL compatibility shaders

Original MIT-licensed shaders for official Horizon. Source defaults match
**Markti Shader**, based on Performance. The packager also builds
**Markti Shaders Ultra Performance** with lower default budgets.

Use Horizon's Shader Options menu to adjust lighting, shadows, water, materials
and color. Two profiles are provided. Balance, Quality, Raytraced and the native
Radiance client extension are retired. No private native-client samplers are used.

Features include sun/moon shadows, procedural sky, rippled water, screen-space
reflections, held-item lighting and dimension atmosphere. Placed lights use the
normal scalar block-light map. Shader settings persist in Horizon's per-pack
sidecar file; stable ZIP names preserve that association across updates.

The separate native `.hshader` packages provide the native color-grid and LabPBR
features. Renaming one of these GLSL ZIPs does not convert its renderer.
