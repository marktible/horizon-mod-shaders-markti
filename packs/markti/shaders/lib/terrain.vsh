attribute vec4 mc_Entity;
varying vec2 uv;
varying vec2 lightUV;
varying vec4 vertexColor;
varying vec3 worldPosition;
varying vec3 worldNormal;
varying float materialId;

void main() {
    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;
    worldPosition = gl_Vertex.xyz;
    worldNormal = normalize(gl_Normal);
    materialId = mc_Entity.x;
}
