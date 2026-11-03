#version 120
varying vec4 vertexColor;
varying vec3 direction;
void main() {
    gl_Position = ftransform();
    vertexColor = gl_Color;
    direction = gl_Vertex.xyz;
}
