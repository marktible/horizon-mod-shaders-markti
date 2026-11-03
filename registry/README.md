# Horizon catalog candidates

These are candidate entries for Horizon's registry, not proof of a listing:

- [Markti Shader](markti_shaders.toml): `markti_shaders.hshader`
- [Markti Shaders Ultra Performance](markti_shaders_ultra.toml): `markti_shaders_ultra.hshader`

Both use `kind = "shader"`, the native `.hshader` format. The repository page
metadata is [horizon-registry.toml](../horizon-registry.toml). Source is MIT licensed
and the repository is public. Release asset names avoid spaces for the registry.

Build and validate first:

```bash
./tools/bootstrap.sh
python3 tools/package.py
cargo run --locked --release -- packs/markti-native dist/*.hshader
```

The validator uses Horizon's real shader checker and registry `page` and
`release_version` checks. It checks the candidate ID, version, API, page fields,
release filename and checksum locally; it does not contact reviewers or submit a
project.

Publish a GitHub release with the two native files as assets and a version tag,
then submit each project at [Horizon's submission page](https://playhorizon.dev/mods/submit).
A maintainer must review the initial listing. The existing GLSL ZIPs are compatibility
downloads, not native shader registry assets. Do not rename them to `.hshader`.

The manual **Prepare native release** GitHub workflow validates both formats and
creates a draft release with the native assets. Review its notes and publish the
draft when ready; drafts are not indexed by Horizon.
