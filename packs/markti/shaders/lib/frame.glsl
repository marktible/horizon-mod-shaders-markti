#ifndef RADIANCE_FRAME
#define RADIANCE_FRAME
#include "/lib/dimension.glsl"
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float rainStrength;
uniform float fogStart;
uniform float fogEnd;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float nightVision;
uniform float screenBrightness;
uniform int isEyeInWater;
uniform int moonPhase;
uniform vec3 radianceShadowLight;

vec3 sunDirection() { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
vec3 lightDirection() {
#if RADIANCE_DIMENSION == 0
    return radianceShadowLight;
#else
    // A fixed ambient orientation, independent of Overworld time of day.
    return normalize(vec3(0.35, 0.85, -0.40));
#endif
}
#if RADIANCE_DIMENSION == 0
float daylight() { return smoothstep(-0.08, 0.12, sunDirection().y); }
float moonlight() { return (1.0 - daylight()) * abs(float(moonPhase) - 4.0) * 0.25; }
#else
float daylight() { return 0.0; }
float moonlight() { return 0.0; }
#endif
vec3 toLinear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
vec3 toDisplay(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

vec2 projectView(vec3 p) {
    vec4 clip = gbufferProjection * vec4(p, 1.0);
    return clip.xy / clip.w * 0.5 + 0.5;
}
float linearDepth(float depth) {
    return gbufferProjection[3].z / (depth * 2.0 - 1.0 + gbufferProjection[2].z);
}
vec3 viewPosition(vec2 coord, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(coord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}
vec3 viewOrigin() {
    // View bobbing is part of the projection and includes a translation.
    // Its optical centre is therefore not necessarily the view-space origin.
    vec4 eye = gbufferProjectionInverse * vec4(0.0, 0.0, 1.0, 0.0);
    return eye.xyz / eye.w;
}
vec3 worldViewOrigin() {
    return (gbufferModelViewInverse * vec4(viewOrigin(), 1.0)).xyz;
}
#endif
