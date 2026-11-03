#version 120
#include "/lib/settings.glsl"
#include "/lib/shadow_transform.glsl"
attribute vec4 mc_Entity;
varying vec2 uv;
varying float blockId;
void main() {
    gl_Position = shadowClip(gl_Vertex.xyz);
    uv = gl_MultiTexCoord0.xy;
    blockId = mc_Entity.x;
}
