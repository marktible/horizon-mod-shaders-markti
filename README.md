# Markti Shaders

Shaders and native mods for [Horizon](https://github.com/horizon-rust/horizon), maintained
in [horizon-mod-shaders-markti](https://github.com/marktible/horizon-mod-shaders-markti).
Uses official Horizon's shader and mod APIs. Install standalone packs directly,
or use **Add from GitHub** for launcher-built native mods.
Tested on `nightly-2026-11-03-f42ef42`, shader API 0.1.

| Pack | Native download | Default budget | GLSL compatibility download |
| --- | --- | --- | --- |
| **Markti Shaders Ultra Performance** | [markti_shaders_ultra.hshader](dist/markti_shaders_ultra.hshader) | 1024 shadows, 48-block shadow range, 12 reflection steps, solid reflections and screen AO off | [Ultra Performance ZIP](<dist/Markti Shaders Ultra Performance.zip>) |
| **Markti Shader** | [markti_shaders.hshader](dist/markti_shaders.hshader) | 2048 shadows, 56-block shadow range, 24 water / 64 solid reflection steps, solid reflections and screen AO on | [Markti Shader ZIP](<dist/Markti Shader.zip>) |

Version **1.1.1** fixes **Add from GitHub** installation: the repository now holds
two discoverable source-only native mod bundles. Paste
`https://github.com/marktible/horizon-mod-shaders-markti`, choose the preset(s),
then use the launcher's **Build & Play**. At the title screen each mod installs
its shader pack. Select it under **Options → Horizon Settings → Shader Packs**;
the mod preserves your existing selection. See [mod installation](docs/mod-install.md).

The native shader renderer provides colored placed lights, colored held/dropped-item
lighting, LabPBR material inputs, tinted glass shadows, rippled water with
refraction and screen-space reflections. The optional terrain mirror has its own
switch because it draws an additional scene. Both presets have Shader Options.
See the [native format and limits](docs/native.md), [settings](docs/settings.md)
and [changelog](CHANGELOG.md).

Copy a `.hshader` into your instance's `shaderpacks/` folder. Select it under
**Options → Horizon Settings → Shader Packs**, then open **Shader Options**.
The two ZIPs retain the existing GLSL renderer as a compatibility choice. One
pack runs at a time; settings are saved separately for each file.

Standalone `.hshader` packages need no game build. The `.hnmod` files and
[unpacked mod source](native-mod/README.md) are native Rust extensions built by
the launcher; both routes use identical shader code. The rendering features
come from the native shader API.
Balance, Quality, Raytraced and the old custom client fork remain retired.

[Catalog metadata](horizon-registry.toml) and [candidate entries](registry/README.md)
are included. A GitHub release and Horizon's initial review are still required
before these appear in the launcher's catalog; committing files does not list them.

For development, start with [DEVELOPING.md](DEVELOPING.md). Build both formats with
`python3 tools/package.py`; the [manifest](dist/manifest.json) records checksums,
settings and the tested Horizon version.
