# Horizon compatibility

Markti targets official `nightly-2026-11-03-f42ef42`, commit
`f42ef42ef6ceccb3c6a20bea2481d87949a51c81`. Native `.hshader` packages use shader API
0.1; GLSL compatibility ZIPs use Horizon's separate compatibility loader. Neither
requires a game-source patch or custom executable.

The native format exposes colored placed/dynamic lights, LabPBR maps, translucent
shadow colors and native surface/reflection resources. The GLSL resource set is
different; the native block-light color grid is not a GLSL sampler. See the
[native feature comparison and limits](native.md).

Both formats support the official Shader Options UI and per-file saved values.
Native options are typed overrides; GLSL options come from `shaders.properties`.
The source's old `RADIANCE_*` expression names are shader implementation names,
not client extensions.

A Rust `.hnmod` compiles into a launcher-built game. Wrapping the old renderer fork
as a mod would still carry a build/update burden. Markti's 1.1.1 bundles instead
implement `Hooks::frame` and use the instance-folder helper (native hooks API 326).
Their `.hnmod` JSON manifests carry `"hooks": 326` so the launcher can build on
later official clients with that API, rather than forcing the tested commit.
The standalone shader packages still require no build. The retired custom FSR
and voxel client is not included. Upscaling and generation use official controls.

On an update, test both formats and saved options on the new unmodified client;
update `tested_horizon` in `tools/package.py` and the exact loader/API revision in
`tools/bootstrap.sh` together. Native API 0.1 is experimental. The validator uses
the official Naga source patch too, matching that revision's shader compiler.
This avoids rebasing a game fork, not all future shader maintenance.

References: [shader guide](https://github.com/horizon-rust/horizon/blob/f42ef42ef6ceccb3c6a20bea2481d87949a51c81/docs/shaders.md),
[API](https://github.com/horizon-rust/horizon/blob/f42ef42ef6ceccb3c6a20bea2481d87949a51c81/docs/api/shaders-reference.md),
[native mods](https://github.com/horizon-rust/horizon/blob/f42ef42ef6ceccb3c6a20bea2481d87949a51c81/docs/native-mods.md).
