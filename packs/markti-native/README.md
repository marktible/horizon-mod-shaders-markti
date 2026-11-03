# Markti native shaders

WGSL shader mods for official Horizon, shader API 0.1. The packager produces
Markti Shader and Markti Shaders Ultra Performance from this source.

Features include colored placed and dynamic light, LabPBR material inputs,
filtered tinted shadows, water ripples/refraction, screen-space reflections and
an optional terrain mirror. Typed settings are exposed in Shader Options.

This is a `.hshader` shader package. It needs no Rust `.hnmod` or custom client.
Colored lighting is not ray-traced diffuse bounce; the official API's lighting,
material and reflection visibility limits apply. See the repository's native
format documentation and validation summary for the tested build.
