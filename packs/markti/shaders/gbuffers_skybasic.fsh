#version 120
#include "/lib/settings.glsl"
#include "/lib/atmosphere.glsl"
uniform int renderStage;
varying vec4 vertexColor;
varying vec3 direction;
void main() {
    // The native sunset fan has a geometric rim. Drawing it on top of the
    // procedural sky creates a hard red band during dusk/night transitions.
    if (renderStage == MC_RENDER_STAGE_SUNSET) discard;
    vec3 color = toLinear(vertexColor.rgb);
    if (renderStage == MC_RENDER_STAGE_SKY) {
        color = radianceSky(normalize(direction), true);
    }
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, vertexColor.a);
}
