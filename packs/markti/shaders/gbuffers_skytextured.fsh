#version 120
#include "/lib/settings.glsl"
#include "/lib/atmosphere.glsl"
uniform sampler2D texture;
uniform int renderStage;
varying vec2 uv;
varying vec4 vertexColor;
varying vec3 direction;

void main() {
    // Horizon supplies the player's native sun and phase-correct moon atlas.
    vec4 texel = texture2D(texture, uv);
    vec3 ray = normalize(direction);
    bool sun = renderStage == MC_RENDER_STAGE_SUN;
    vec3 tint = sun ? mix(vec3(1.0, 0.54, 0.22), vec3(1.0, 0.95, 0.80),
                         smoothstep(0.0, 0.5, sunDirection().y)) : vec3(0.68, 0.80, 1.0);
    vec3 radiance = toLinear(texel.rgb * vertexColor.rgb) * tint * (sun ? 4.0 : 1.4);
    float cloud = radianceCloudField(ray).y;
    float alpha = texel.a * vertexColor.a * (1.0 - cloud * (sun ? 0.94 : 0.98));
    alpha *= smoothstep(-0.035, 0.015, ray.y);
    if (alpha < 0.001 || max(radiance.r, max(radiance.g, radiance.b)) < 0.0001) discard;
    // Both attachments use the native additive celestial blend. The encoded
    // copy preserves bodies when deferred repairs the low-horizon background.
    /* DRAWBUFFERS:06 */
    gl_FragData[0] = vec4(radiance, alpha);
    gl_FragData[1] = vec4(radiance / CELESTIAL_STORAGE_SCALE, alpha);
}
