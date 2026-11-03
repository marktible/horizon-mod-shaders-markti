#version 120
#include "/lib/settings.glsl"
#include "/lib/atmosphere.glsl"
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
#include "/lib/shadow_history.glsl"
#endif
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
#if RADIANCE_DIMENSION == 0
uniform sampler2D colortex6;
#endif
varying vec2 uv;
void main() {
    vec4 color = texture2D(colortex0, uv);
    float depth = texture2D(depthtex0, uv).r;
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
    vec4 direct = texture2D(colortex3, uv);
    vec4 history = stableShadow(uv, depth, direct.a);
    if (depth < 0.99999 && direct.a > 0.0) {
        color.rgb = max(color.rgb + direct.rgb * (history.x - direct.a), vec3(0.0));
    } else {
        history = vec4(0.0);
    }
#endif
    if (depth >= 0.99999) {
        vec3 ray = normalize(mat3(gbufferModelViewInverse) * (viewPosition(uv, 0.5) - viewOrigin()));
        // The native sky disc ends above the horizon, exposing the vanilla
        // clear colour below it. Fill that uncovered sky using the same
        // procedural atmosphere as the dome, fog and water reflections.
        // Preserve the separately encoded sun/moon contribution at the rim.
#if RADIANCE_DIMENSION == 0
        if (ray.y < 0.08) {
            vec3 bodies = texture2D(colortex6, uv).rgb * CELESTIAL_STORAGE_SCALE;
            color = vec4(radianceSky(ray, true) + bodies, 1.0);
        }
#else
        // Native unlit effects (beams/particles) can have no depth. Preserve
        // their bright contribution rather than erasing it with the new sky.
#if RADIANCE_DIMENSION == 1
        // The pinned host's End sky cube is tinted 0x28; even a white texel
        // cannot exceed this. Bright native effects lie above that bound.
        vec3 nativeGlow = max(color.rgb - vec3(40.0 / 255.0), vec3(0.0));
#else
        // The Nether's native background is the supplied fog clear color.
        vec3 nativeGlow = max(color.rgb - fogColor, vec3(0.0));
#endif
        color = vec4(radianceSky(ray, true) + nativeGlow, 1.0);
#endif
    }
    // Publish the corrected sky and an immutable opaque snapshot for SSR.
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
    /* DRAWBUFFERS:014 */
#else
    /* DRAWBUFFERS:01 */
#endif
    gl_FragData[0] = color;
    gl_FragData[1] = color;
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
    gl_FragData[2] = history;
#endif
}
