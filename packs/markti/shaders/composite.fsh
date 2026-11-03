#version 120
#include "/lib/settings.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/materials.glsl"
#if SURFACE_REFLECTIONS == 1
#define SSR_COLOR colortex0
#define SSR_DEPTH depthtex0
#define SSR_MIPS
// Thin entity silhouettes need denser traversal on mirror materials. This
// runs only on reflective pixels; water retains the preset's cheaper budget.
#define SSR_TRACE_STEPS 64
#include "/lib/ssr.glsl"
const bool colortex0MipmapEnabled = true;
uniform sampler2D colortex5;
#if RADIANCE_DIMENSION == 0 && SHADOW_TEMPORAL == 1
uniform sampler2D colortex4;
#endif
#else
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
#endif
uniform sampler2D colortex2;
varying vec2 uv;
void main() {
    vec3 color = texture2D(colortex0, uv).rgb;
    float depth = texture2D(depthtex0, uv).r;
#if SURFACE_REFLECTIONS == 1
    vec4 material = texture2D(colortex5, uv);
    float kind = floor(material.b * 255.0 + 0.5);
    if (depth < 0.99999 && kind > 0.5 && texture2D(colortex2, uv).r < 0.1) {
        vec3 position = (gbufferModelViewInverse * vec4(viewPosition(uv, depth), 1.0)).xyz;
        vec3 normal = surfaceNormalFromOct(material.rg);
        vec3 viewDir = normalize(worldViewOrigin() - position);
        float facing = max(dot(normal, viewDir), 0.0);
        vec3 reflected = reflect(-viewDir, normal);
        float roughness = surfaceRoughness(kind);
        vec3 f0 = surfaceF0(kind);
        vec3 fresnel = f0 + (vec3(1.0) - f0) * pow(1.0 - facing, 5.0);
        float sky = pow(clamp((material.a - 0.03125) / 0.9375, 0.0, 1.0), 2.0);
        // A cloudless ambient fallback cannot paint procedural cloud shapes
        // onto a metal block when screen-space geometry is unavailable.
#if RADIANCE_DIMENSION == 0
        vec3 environment = mix(vec3(0.012, 0.014, 0.018), radianceSky(reflected, false),
                               smoothstep(-0.05, 0.12, reflected.y)) * sky * 0.55;
#else
        // Cavern/void ambient fallback has no daytime sky or cloud shapes.
        vec3 environment = radianceSky(reflected, false) * 0.35;
#endif
        vec4 hit = reflectedSurface(position + normal * 0.06, reflected, normal, dot(position, normal), roughness);
        vec3 reflection = mix(environment, hit.rgb, hit.a);
        float metal = kind > 1.5 && kind < 4.5 ? 1.0 : 0.0;
        float finishStrength = surfaceReflectionStrength(kind);
        float strength = finishStrength * (1.0 - smoothstep(35.0, 55.0, length(position)));
        // Conductors reflect rather than retaining a bright diffuse layer
        // under the reflection. That old layer washed reflected detail out.
        vec3 dielectric = color * (vec3(1.0) - fresnel) + reflection * fresnel;
        vec3 conductor = color * 0.025 + reflection * fresnel;
        color = mix(color, mix(dielectric, conductor, metal), strength);
#if RADIANCE_DIMENSION == 0
        vec3 halfLight = normalize(viewDir + lightDirection());
        float highlight = pow(max(dot(normal, halfLight), 0.0), mix(180.0, 28.0, roughness));
        vec3 glint = vec3(2.4, 2.1, 1.7) * daylight() + vec3(0.12, 0.18, 0.32) * moonlight();
        float keyVisibility = 1.0;
#if SHADOW_TEMPORAL == 1
        keyVisibility = texture2D(colortex4, uv).r;
#endif
        color += glint * f0 * highlight * sky * keyVisibility * finishStrength * 0.5;
#endif
    }
#endif
    float ao = 0.0;
    if (depth < 0.99999 && texture2D(colortex2, uv).r < 0.1 && AO_STRENGTH > 0.0) {
        vec3 p = viewPosition(uv, depth);
        vec3 normal = normalize(cross(dFdx(p), dFdy(p)));
        if (dot(normal, -p) < 0.0) normal = -normal;
        float radius = clamp(gbufferProjection[1].y * viewHeight * 0.65 / max(-p.z, 0.2), 2.0, 55.0);
        vec2 directions[8] = vec2[8](vec2(0.9239,0.3827),vec2(-0.3827,0.9239),vec2(-0.9239,-0.3827),vec2(0.3827,-0.9239),vec2(0.7071,0.7071),vec2(-0.7071,0.7071),vec2(-0.7071,-0.7071),vec2(0.7071,-0.7071));
        for (int i = 0; i < AO_SAMPLES; i++) {
            float spread = i < 4 ? 0.55 : 1.0;
            vec2 coord = clamp(uv + directions[i] * radius * spread / vec2(viewWidth, viewHeight), vec2(0.001), vec2(0.999));
            float sampleDepth = texture2D(depthtex0, coord).r;
            vec3 delta = viewPosition(coord, sampleDepth) - p;
            float distanceToSample = length(delta);
            float angle = max(dot(normal, delta / max(distanceToSample, 0.001)) - 0.12, 0.0);
            float range = 1.0 - smoothstep(0.2, 2.3, distanceToSample);
            if (sampleDepth < 0.99999 && texture2D(colortex2, coord).r < 0.1) ao += angle * range;
        }
        ao *= (1.0 - smoothstep(45.0, 90.0, -p.z)) / float(AO_SAMPLES);
    }
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color * (1.0 - ao * AO_STRENGTH), 1.0);
}
