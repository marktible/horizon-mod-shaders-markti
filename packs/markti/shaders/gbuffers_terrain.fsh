#version 120
#include "/lib/settings.glsl"
#include "/lib/lighting.glsl"
#include "/lib/material_id.glsl"
#include "/lib/materials.glsl"
uniform sampler2D texture;
varying vec2 uv;
varying vec2 lightUV;
varying vec4 vertexColor;
varying vec3 worldPosition;
varying vec3 worldNormal;
varying float materialId;

void main() {
    vec4 texel = texture2D(texture, uv);
    if (texel.a * vertexColor.a < 0.1) discard;
    vec3 normal = surfaceNormal(worldPosition, worldNormal);
    float id = blockMaterial(materialId, uv);
    // Crossed foliage has no baked cardinal face shade. Treat its light as
    // a soft upward-facing canopy, keeping the biome tint intact on both sides.
    bool foliage = abs(id - 10006.0) < 0.5;
    if (foliage) normal = vec3(0.0, 1.0, 0.0);
    vec3 color = illuminated(texel.rgb, vertexColor.rgb, lightUV, worldPosition, normal);
    // Self-lit blocks retain their colour even in full shade or caves.
    if (abs(id - 10002.0) < 0.5 || abs(id - 10004.0) < 0.5 || abs(id - 10005.0) < 0.5) {
        color = max(color, toLinear(texel.rgb * vertexColor.rgb) * 2.6);
        shadowDirect = vec3(0.0);
    }
    if (abs(id - 10003.0) < 0.5) {
        float backlight = pow(max(dot(-normal, lightDirection()), 0.0), 2.0);
        color += toLinear(texel.rgb * vertexColor.rgb) * vec3(1.2, 1.35, 0.45) * backlight * daylight() * lightUV.y * 0.5;
    }
    color = atmosphericFog(color, worldPosition);
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
#if SURFACE_REFLECTIONS == 1
    /* DRAWBUFFERS:0352 */
#else
    /* DRAWBUFFERS:032 */
#endif
#else
#if SURFACE_REFLECTIONS == 1
    /* DRAWBUFFERS:052 */
#else
    /* DRAWBUFFERS:02 */
#endif
#endif
    gl_FragData[0] = vec4(color, texel.a * vertexColor.a);
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
#if SURFACE_REFLECTIONS == 1
    gl_FragData[3] = vec4(foliage ? 0.5 : 0.0, 0.0, 0.0, 1.0);
#else
    gl_FragData[2] = vec4(foliage ? 0.5 : 0.0, 0.0, 0.0, 1.0);
#endif
#else
#if SURFACE_REFLECTIONS == 1
    gl_FragData[2] = vec4(foliage ? 0.5 : 0.0, 0.0, 0.0, 1.0);
#else
    gl_FragData[1] = vec4(foliage ? 0.5 : 0.0, 0.0, 0.0, 1.0);
#endif
#endif
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
    gl_FragData[1] = vec4(shadowDirect * (1.0 - fogAmount(worldPosition)), shadowVisibility);
#if SURFACE_REFLECTIONS == 1
    gl_FragData[2] = vec4(surfaceOct(normal), surfaceType(id) / 255.0, lightUV.y);
#endif
#else
#if SURFACE_REFLECTIONS == 1
    gl_FragData[1] = vec4(surfaceOct(normal), surfaceType(id) / 255.0, 1.0);
#endif
#endif
}
