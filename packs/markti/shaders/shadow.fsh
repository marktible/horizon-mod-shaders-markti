#version 120
#include "/lib/settings.glsl"
uniform sampler2D texture;
/* const int shadowcolor0Format = R8; */
const bool shadowcolor0Clear = false;
varying vec2 uv;
varying float blockId;
void main() {
    // Filter cutout coverage before rasterising the shadow. A binary alpha
    // test turns sub-texel leaf holes on/off as the sun moves, even with PCF.
    // Preserve that fractional coverage in shadowcolor0 for the receiver.
    float coverage = texture2DLod(texture, uv, SHADOW_FOLIAGE_LOD).a;
    if (abs(blockId - 10001.0) < 0.5 || abs(blockId - 10006.0) < 0.5 || coverage < 0.025) discard;
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(vec3(coverage), 1.0);
}
