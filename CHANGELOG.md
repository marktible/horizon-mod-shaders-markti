# Changelog

## 1.0.1 — 2026-11-03

- Fix shadows and sunlight rotating with camera yaw and pitch on official Horizon.
- Match custom-expression matrix indices to the tested November 3 client.
- Validate against that exact loader revision; cover 315 camera orientations.
- Publish the standalone project with reproducible ZIPs, development instructions
  and automated checks. Preserve saved options through stable ZIP filenames.

## 1.0.0 — 2026-11-03

- Introduce **Markti Shader**, based on Performance, and **Markti Shaders Ultra
  Performance**, with Horizon's Shader Options and two profiles.
- Target official Horizon without a custom client fork.
- Retire Balance, Quality and Raytraced. The retired fork's voxel lighting and
  custom FSR integration are not included in the standalone packs.
