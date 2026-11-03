#version 120
#include "/lib/settings.glsl"
uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
varying vec2 uv;
vec3 tonemap(vec3 c) {
    return clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0);
}
void main() {
    vec3 color = texture2D(colortex0, uv).rgb;
    if (BLOOM_STRENGTH > 0.0) {
    vec2 t = vec2(2.0 / viewWidth, 2.0 / viewHeight);
    vec3 glow = max(texture2D(colortex0, uv + t).rgb - 0.9, 0.0);
    glow += max(texture2D(colortex0, uv - t).rgb - 0.9, 0.0);
    glow += max(texture2D(colortex0, uv + t * vec2(-1.0, 1.0)).rgb - 0.9, 0.0);
    glow += max(texture2D(colortex0, uv + t * vec2(1.0, -1.0)).rgb - 0.9, 0.0);
    color += glow * BLOOM_STRENGTH * 0.25;
#if RADIANCE_DIMENSION != 0
    // A wider, restrained halo around lava, lamps and End rods. Work stays
    // fixed at four extra reads, without an iterative blur chain.
    vec2 wide = t * 4.0;
    vec3 halo = max(texture2D(colortex0, uv + wide).rgb - 1.1, 0.0);
    halo += max(texture2D(colortex0, uv - wide).rgb - 1.1, 0.0);
    halo += max(texture2D(colortex0, uv + wide * vec2(-1.0, 1.0)).rgb - 1.1, 0.0);
    halo += max(texture2D(colortex0, uv + wide * vec2(1.0, -1.0)).rgb - 1.1, 0.0);
    color += halo * BLOOM_STRENGTH * 0.10;
#endif
    }
    color *= EXPOSURE;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, SATURATION);
    color = tonemap(max(color, vec3(0.0)));
    vec2 centered = uv - 0.5;
    color *= 1.0 - dot(centered, centered) * 0.12;
    gl_FragColor = vec4(pow(clamp(color, 0.0, 1.0), vec3(1.0 / 2.2)), 1.0);
}
