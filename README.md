# Markti Shaders

Standalone shaders for [Horizon](https://github.com/horizon-rust/horizon), maintained
in [horizon-mod-shaders-markti](https://github.com/marktible/horizon-mod-shaders-markti).
**No custom Horizon build is required.** The tested target is official
`nightly-2026-11-03-f42ef42`.

| Pack | Based on | Default budget | Download |
| --- | --- | --- | --- |
| **Markti Shaders Ultra Performance** | Ultra Performance | 1024 shadows, 48-block shadow range, 12-step water reflections, solid reflections and screen AO off | [Ultra Performance](<dist/Markti Shaders Ultra Performance.zip>) |
| **Markti Shader** | Performance | 2048 shadows, 56-block shadow range, 20-step water reflections, solid reflections and 6-sample screen AO | [Markti Shader](<dist/Markti Shader.zip>) |

Both include filtered sun/moon shadows, rippled reflective/refractive water,
procedural skies, held-item lighting, and Nether/End atmosphere. Balance, Quality
and Raytraced are retired.

Current version: **1.0.1**. This release fixes shadows and sunlight moving when the
camera turns. See the [changelog](CHANGELOG.md) and [validation summary](reports/validation-1.0.1.json).

Put the ZIPs in Horizon's `shaderpacks/` folder. Select one under **Options →
Horizon Settings → Shader Packs**, then open **Shader Options**. Lighting, Shadows,
Water, Materials and Color controls replace the old lighting-variant downloads.
The names stay the same across updates so saved settings can persist.

Use an official Horizon Nightly rather than the old `radiance-*` launcher builds.
Upscaling and frame generation use the official client's own controls and limits.
These packs do not include the retired custom colored placed-light volume or custom
FSR implementation. Ordinary placed block light and colored held-item light remain.
Reflections use visible screen geometry and procedural environment fallback.

Start at [DEVELOPING.md](DEVELOPING.md) for development, compatibility and isolated
testing. Build the two ZIPs with `python3 tools/package.py`; checksums and the tested
Horizon version are in [the manifest](dist/manifest.json).
