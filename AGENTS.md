# Agent instructions

- Read `DEVELOPING.md` before changing this project.
- Every development change must include an update to `DEVELOPING.md`. Record what
  changed, why, relevant source locations, and the validation performed. Keep its
  current behavior and limitations accurate; do not claim checks that were not run.
- Preserve this documentation rule when editing or extending agent instructions.
- The supported packs are **Markti Shader** (Performance) and **Markti Shaders
  Ultra Performance**. Native WGSL source is under `packs/markti-native`, with
  GLSL compatibility source under `packs/markti`. Target unmodified official Horizon.
  Raytraced, Balance, Quality, and the custom client fork are retired; do not resume
  them unless the user explicitly requests it.
- Follow the isolated test-session workflow in `docs/testing.md`; never test against
  a player's live save. Use the authoritative source paths listed in `DEVELOPING.md`.
- Keep game assets, prepared resources, save files, accounts, and session data out
  of distributed artifacts.
- Publish only current source, docs, the two native `.hshader` packages, the two
  GLSL compatibility ZIPs and sanitized validation
  summaries. Keep local archives, upstream checkouts, build outputs and raw runtime
  reports ignored. Preserve the repository's license and existing Git history.
