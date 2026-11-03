#version 120
varying vec2 uv;
varying vec4 vertexColor;
varying vec3 direction;
void main() {
    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
    direction = gl_Vertex.xyz;
}
