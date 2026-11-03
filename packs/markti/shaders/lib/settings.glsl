#include "/lib/dimension.glsl"
// These defaults are deliberately modest for the i3-1215U's integrated GPU.
#define SHADOW_RESOLUTION 2048 // [1024 1536 2048 3072]
#define SHADOW_DISTANCE 56.0 // [48.0 56.0 64.0 72.0 96.0]
#define SHADOW_FILTER 2 // [0 1 2]
#define SHADOW_STRENGTH 0.94 // [0.75 0.85 0.94 1.0]
#define SHADOW_TEMPORAL 1 // [0 1]
#define SHADOW_FOLIAGE_LOD 2.0 // [1.0 2.0]
#define BLOOM_STRENGTH 0.16 // [0.0 0.08 0.16 0.24]
#define SATURATION 1.05 // [0.9 1.0 1.05 1.15]
#define WATER_REFLECTION 0.95 // [0.5 0.75 0.95 1.0]
#define WATER_RIPPLE_STRENGTH 0.85 // [0.0 0.5 0.85 1.0 1.2]
#define WATER_REFRACTION 1 // [0 1]
#define WATER_CLARITY 1.0 // [0.65 1.0 1.5]
#define WATER_CAUSTICS 1 // [0 1]
#define EXPOSURE 1.15 // [0.8 1.0 1.15 1.3]
#define SSR_STEPS 20 // [12 16 20 24 28 40]
#define AO_SAMPLES 6 // [4 6 8]
#define AO_STRENGTH 0.60 // [0.0 0.35 0.60 0.8]
#define HELD_LIGHTS 1 // [0 1]
#define COLORED_LIGHTS 1 // [0 1]
#define BLOCK_LIGHT_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.25 1.5]
#define SURFACE_REFLECTIONS 1 // [0 1]
#define COMPACT_WATER_BUFFER 1 // [0 1]

/* const int colortex0Format = RGBA16F; */
#if COMPACT_WATER_BUFFER == 1
// The opaque water input is RGB only; retain HDR without unused alpha storage.
/* const int colortex1Format = R11F_G11F_B10F; */
#else
/* const int colortex1Format = RGBA16F; */
#endif
/* const int colortex2Format = R8; */
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
/* const int colortex3Format = RGBA16F; */
/* const int colortex4Format = RGBA16F; */
#endif
/* const int colortex5Format = RGBA8; */
#if RADIANCE_DIMENSION == 0
/* const int colortex6Format = RGBA8; */
#define CELESTIAL_STORAGE_SCALE 4.0
#endif
const bool colortex1Clear = false;
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
const bool colortex4Clear = false;
const vec4 colortex3ClearColor = vec4(0.0);
#endif
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex5ClearColor = vec4(0.0);
#if RADIANCE_DIMENSION == 0
const vec4 colortex6ClearColor = vec4(0.0);

const int shadowMapResolution = SHADOW_RESOLUTION;
const float shadowDistance = SHADOW_DISTANCE;
const float shadowDistanceRenderMul = 1.0;
// lib/shadow_transform.glsl snaps to the actual projected texel grid instead.
const float shadowIntervalSize = 0.0;
const float sunPathRotation = -25.0;
const bool shadowHardwareFiltering = false;
#endif
