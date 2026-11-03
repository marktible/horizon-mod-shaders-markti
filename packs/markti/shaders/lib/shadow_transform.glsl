#ifndef RADIANCE_SHADOW_TRANSFORM
#define RADIANCE_SHADOW_TRANSFORM
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 radianceShadowRight;
uniform vec3 radianceShadowUp;
#include "/lib/frame.glsl"

vec3 shadowRotate(vec3 position) {
    // The basis is evaluated once per frame on the CPU, not per fragment.
    return vec3(dot(radianceShadowRight, position), dot(radianceShadowUp, position), dot(radianceShadowLight, position));
}

vec4 shadowClip(vec3 position) {
    // The engine's camera supplies the depth range and translation. Both
    // passes use the same continuous light basis instead of its ticked basis.
    vec4 clip = shadowProjection * vec4(shadowRotate(position) + shadowModelView[3].xyz, 1.0);
    // Anchor the orthographic map to world texels, for every resolution/distance.
    // Apply exactly the same offset in the caster and receiver programs. The
    // client's fixed block interval is disabled; it is not a whole texel.
    // Rotate around a nearby fixed region, not world (0,0,0). A global
    // origin makes a tiny solar rotation sweep many texels at large world
    // coordinates, constantly re-rasterising stationary foliage. Translation
    // remains texel-stable within each region; screen history softens a rebase.
    vec3 anchor = floor(cameraPosition / 32.0) * 32.0;
    vec4 origin = shadowProjection * vec4(shadowRotate(anchor - cameraPosition) + shadowModelView[3].xyz, 1.0);
    vec2 grid = origin.xy * (0.5 * float(SHADOW_RESOLUTION));
    clip.xy += (floor(grid + 0.5) - grid) * (2.0 / float(SHADOW_RESOLUTION)) * clip.w;
    return clip;
}
#endif
