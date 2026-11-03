# Horizon compatibility

Markti targets the unmodified official `nightly-2026-11-03-f42ef42`, commit
`f42ef42ef6ceccb3c6a20bea2481d87949a51c81`. It distributes GLSL shader packs;
there is no Horizon client patch, native mod or custom executable to port.

Horizon now provides a [Shader Options UI](https://github.com/horizon-rust/horizon/blob/fc02103818c212920fd24aa34a2b2f91ba49e56f/docs/shaders.md)
for the GLSL format, including profiles, pages, sliders and saved selections.
Markti uses that interface. Test new official builds and record the result; shader
interfaces can still change, so this is not a promise of unlimited compatibility.

Horizon also has a [native WGSL shader API](https://github.com/horizon-rust/horizon/blob/fc02103818c212920fd24aa34a2b2f91ba49e56f/docs/api/shaders-reference.md)
with typed material inputs and a built-in block-light color grid. Its material
resources differ from the GLSL compatibility API. A later WGSL port could use them;
Markti does not pretend that grid exists in its current GLSL path.

[Native mods](https://github.com/horizon-rust/horizon/blob/fc02103818c212920fd24aa34a2b2f91ba49e56f/docs/native-mods.md)
can use versioned hook points, but they still compile game code. Repackaging a
renderer patch as a mod would not automatically remove its update burden.
The retired custom FSR and voxel-light client is archived, not a Markti dependency.

On an update: keep the two ZIP filenames, install the new official Horizon,
validate both packs and saved options, and update `tested_horizon` in the manifest
through `tools/package.py`. Leave native upscaling/generation to Horizon's own
[graphics implementation](https://github.com/horizon-rust/horizon/blob/fc02103818c212920fd24aa34a2b2f91ba49e56f/docs/graphics.md).
